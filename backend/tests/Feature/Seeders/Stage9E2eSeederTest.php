<?php

namespace Tests\Feature\Seeders;

use App\Actions\Student\SaveStudentAttemptAnswer;
use App\Actions\Student\StartStudentBlitzAttempt;
use App\Actions\Student\StartStudentHomeworkAttempt;
use App\Actions\Student\SubmitStudentBlitzAttempt;
use App\Actions\Student\SubmitStudentHomeworkAttempt;
use App\Actions\Teacher\GrantTeacherBlitzAttemptException;
use App\Actions\Teacher\ReviewTeacherSubmission;
use App\Domain\Assessment\AssessmentActivationValidator;
use App\Models\Institution;
use App\Models\Question;
use App\Models\User;
use App\Support\Checking\FrozenAttemptCheckQueue;
use Database\Seeders\Stage9E2eSeeder;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class Stage9E2eSeederTest extends TestCase
{
    use DatabaseTransactions;

    private const PASSWORD = 'E2E-S09-focused-test-password-only!';

    private string|false $previousPassword;

    private string $privateTestRoot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-02 12:00:00 UTC'));
        $this->previousPassword = getenv('STAGE9_E2E_PASSWORD');
        putenv('STAGE9_E2E_PASSWORD='.self::PASSWORD);
        $this->privateTestRoot = storage_path('app/private/e2e-s09-seeder-test-'.getmypid());
        $this->assertDirectoryDoesNotExist($this->privateTestRoot);
        File::ensureDirectoryExists($this->privateTestRoot);
        config(['filesystems.private_files_disk' => 'stage9_seeder_test', 'filesystems.disks.stage9_seeder_test' => [
            'driver' => 'local', 'root' => $this->privateTestRoot, 'visibility' => 'private', 'throw' => true,
        ]]);
        // The runner removes any real manifest before this test; the transaction restores whatever it finds.
        // The real sentinel graph keeps its blob on the real disk, so the test works on its own copy.
        (new Stage9E2eSeeder)->cleanupOwnedState();
        (new Stage9E2eSeeder)->removeSentinels();
    }

    protected function tearDown(): void
    {
        putenv($this->previousPassword === false ? 'STAGE9_E2E_PASSWORD' : 'STAGE9_E2E_PASSWORD='.$this->previousPassword);
        Storage::forgetDisk('stage9_seeder_test');
        File::deleteDirectory($this->privateTestRoot);
        parent::tearDown();
    }

    #[DataProvider('unsafeGuards')]
    public function test_every_mutation_fails_before_writes_when_any_guard_is_unsafe(string $failure, string $operation): void
    {
        $database = DB::getFacadeRoot();
        $default = config('database.default');
        if ($failure === 'environment') {
            $this->app->instance('env', 'production');
        } elseif ($failure === 'driver') {
            config(['database.default' => 'stage9_unsafe', 'database.connections.stage9_unsafe' => ['driver' => 'sqlite', 'database' => ':memory:']]);
        } elseif ($failure === 'database') {
            DB::shouldReceive('connection')->once()->andReturn($database->connection());
            DB::shouldReceive('selectOne')->once()->with('select current_database() as database_name')
                ->andReturn((object) ['database_name' => 'testlabuz']);
        } elseif ($failure === 'disk') {
            config(['filesystems.disks.stage9_seeder_test.visibility' => 'public']);
        } else {
            putenv($failure === 'missing_password' ? 'STAGE9_E2E_PASSWORD' : 'STAGE9_E2E_PASSWORD=   ');
        }
        try {
            (new Stage9E2eSeeder)->{$operation}();
            $this->fail('Unsafe Stage 9 fixture mutation was allowed.');
        } catch (RuntimeException $exception) {
            $this->assertMatchesRegularExpression('/\A(?:Static |Unowned )?Stage 9 /', $exception->getMessage());
            $this->assertStringNotContainsString(self::PASSWORD, $exception->getMessage());
        } finally {
            DB::swap($database);
            config(['database.default' => $default, 'filesystems.disks.stage9_seeder_test.visibility' => 'private']);
            $this->app->instance('env', 'testing');
        }
        $this->assertNoStaticRows();
        $this->assertNoSentinelRows();
        $this->assertSame([], Storage::disk('stage9_seeder_test')->allFiles());
    }

    public static function unsafeGuards(): array
    {
        $cases = [];
        foreach (['environment', 'driver', 'database', 'missing_password', 'blank_password', 'disk'] as $failure) {
            foreach (['run', 'cleanupOwnedState', 'ensureSentinels', 'removeSentinels'] as $operation) {
                $cases[$failure.' '.$operation] = [$failure, $operation];
            }
        }

        return $cases;
    }

    public function test_reseeding_converges_to_the_deterministic_structure_and_preserves_unrelated_sentinels(): void
    {
        $prefixSentinel = $this->prefixSentinel();
        $before = $prefixSentinel->getAttributes();
        $seeder = new Stage9E2eSeeder;
        $seeder->ensureSentinels();
        $sentinels = $seeder->sentinelState();
        $seeder->run();
        $first = $this->structuralSnapshot();
        $seeder->run();
        $this->assertSame($first, $this->structuralSnapshot());
        $this->assertSame(Stage9E2eSeeder::manifest(), Stage9E2eSeeder::manifest());
        $this->assertSame($before, $prefixSentinel->fresh()->getAttributes());
        $this->assertSame($sentinels, $seeder->sentinelState());
        $manifest = Stage9E2eSeeder::manifest();
        foreach ($manifest['db'] as $table => $ids) {
            $this->assertCount(count($ids), $first[$table], $table);
            $this->assertSame(count($ids), count(array_unique($ids)), $table.' identities are unique');
            foreach ($ids as $id) {
                $this->assertMatchesRegularExpression('/\A09000000-0000-4000-8000-[0-9]{12}\z/', $id);
            }
        }
        $this->assertCount(5, $first['assessment_attempts']);
        $this->assertCount(14, $first['attempt_answers']);
        foreach ($manifest['users'] as $name => $id) {
            $user = User::query()->findOrFail($id);
            $this->assertTrue(Hash::check(self::PASSWORD, $user->password));
            $this->assertTrue($user->is_active);
            $this->assertFalse($user->must_change_password);
            $this->assertSame('e2e_s09_'.$name, $user->login_name);
            $this->assertSame(str_ends_with($name, 'teacher') ? 'teacher' : 'student', $user->role->value);
        }
        $this->assertSame('E2E S09 Teacher', User::query()->findOrFail($manifest['users']['teacher'])->full_name);
    }

    public function test_seeded_relations_stay_inside_their_institution_and_exact_manifest(): void
    {
        (new Stage9E2eSeeder)->run();
        $manifest = Stage9E2eSeeder::manifest();
        $parents = [...$manifest['db'], 'assessment_attempts' => array_values($manifest['attempts'])];
        $tableForColumn = ['institution_id' => 'institutions', 'group_id' => 'groups', 'teacher_id' => 'users', 'student_id' => 'users',
            'created_by_user_id' => 'users', 'assigned_by_user_id' => 'users', 'designated_by_user_id' => 'users', 'activated_by_user_id' => 'users',
            'topic_id' => 'topics', 'assessment_id' => 'assessments', 'homework_assessment_id' => 'assessments', 'blitz_assessment_id' => 'assessments',
            'assessment_student_id' => 'assessment_students', 'question_id' => 'questions', 'blank_id' => 'question_fill_blanks', 'attempt_id' => 'assessment_attempts',
            'option_id' => 'question_choice_options', 'left_item_id' => 'question_matching_items', 'right_item_id' => 'question_matching_items',
            'ordering_item_id' => 'question_ordering_items'];
        $children = $this->seededHistory();
        foreach ([...$this->structuralSnapshot(), ...$children] as $table => $rows) {
            foreach ($rows as $row) {
                foreach ($tableForColumn as $column => $parentTable) {
                    if (! isset($row[$column]) || ($table === 'institutions' && $column === 'institution_id')) {
                        continue;
                    }
                    $this->assertContains($row[$column], $parents[$parentTable], $table.'.'.$column);
                    $parent = DB::table($parentTable)->where(Stage9E2eSeeder::PRIMARY_KEYS[$parentTable] ?? 'id', $row[$column])->first();
                    $this->assertNotNull($parent, $table.'.'.$column);
                    if ($column !== 'institution_id') {
                        $this->assertSame($row['institution_id'], $parent->institution_id, $table.'.'.$column.' tenant');
                    }
                }
            }
        }
        $settings = DB::table('institution_settings')->whereIn('institution_id', $manifest['institutions'])->get()->keyBy('institution_id');
        // Asia/Tokyo (+09:00, no DST) differs from the +05:00 runner host, so the UI cannot pass on device time.
        $this->assertSame(['automatic', 'synchronized', 'Asia/Tokyo'], [$settings[$manifest['institutions']['auto']]->student_result_release_mode,
            $settings[$manifest['institutions']['auto']]->blitz_timer_start_mode, $settings[$manifest['institutions']['auto']]->timezone]);
        $this->assertSame('manual_teacher', $settings[$manifest['institutions']['manual']]->student_result_release_mode);
        $this->assertSame($manifest['institutions']['manual'], DB::table('assessments')->where('id', $manifest['assessments']['manual_hw'])->value('institution_id'));
        $peer = DB::table('group_teacher_memberships')->where('teacher_id', $manifest['users']['peer_teacher'])->sole();
        $this->assertSame($manifest['groups']['review'], $peer->group_id);
        $this->assertSame(0, DB::table('topics')->where('teacher_id', $manifest['users']['peer_teacher'])->count());
    }

    public function test_official_pairs_have_one_established_cohort_and_lock_only_with_activity(): void
    {
        (new Stage9E2eSeeder)->run();
        $manifest = Stage9E2eSeeder::manifest();
        $expected = ['review' => [['review_hw', 'exception_blitz'], ['student', 'classmate'], false], 'backfill' => [['repair_hw', 'backfill_blitz'],
            ['backfill_student', 'repair_student', 'deadline_student', 'timeout_student'], true], 'android' => [['android_hw', 'android_blitz'],
                ['android_student', 'android_classmate'], false], 'manual' => [['manual_hw'], ['manual_student'], false]];
        foreach ($expected as $topic => [$tasks, $students, $locked]) {
            $pair = DB::table('topic_result_pairs')->where('id', $manifest['pairs'][$topic])->sole();
            $this->assertSame([$manifest['assessments'][$tasks[0]], isset($tasks[1]) ? $manifest['assessments'][$tasks[1]] : null],
                [$pair->homework_assessment_id, $pair->blitz_assessment_id], $topic);
            $this->assertNotNull($pair->cohort_snapshotted_at, $topic);
            $this->assertSame($locked, $pair->locked_at !== null, $topic.' lock');
            foreach ($tasks as $task) {
                $this->assertSame('group', DB::table('assessments')->where('id', $manifest['assessments'][$task])->value('assignment_mode'), $task);
                $recipients = DB::table('assessment_students')->where('assessment_id', $manifest['assessments'][$task])->get();
                $this->assertEqualsCanonicalizing(array_map(fn (string $student): string => $manifest['users'][$student], $students), $recipients->pluck('student_id')->all(), $task);
                $this->assertSame(['group'], $recipients->pluck('assignment_source')->unique()->values()->all(), $task);
            }
        }
        foreach (['backfill_hw' => 'backfill_student', 'deadline_hw' => 'deadline_student', 'timeout_blitz' => 'timeout_student'] as $task => $student) {
            $this->assertSame('selected_students', DB::table('assessments')->where('id', $manifest['assessments'][$task])->value('assignment_mode'), $task);
            $this->assertSame([$manifest['users'][$student]], DB::table('assessment_students')->where('assessment_id', $manifest['assessments'][$task])->pluck('student_id')->all(), $task);
        }
        $blitz = DB::table('blitz_tasks')->where('assessment_id', $manifest['assessments']['exception_blitz'])->sole();
        $this->assertSame(['active', 'synchronized', 3600], [$blitz->status, $blitz->timer_start_mode_snapshot, $blitz->duration_seconds]);
        $this->assertTrue(Carbon::parse($blitz->activated_at)->equalTo(now()) && Carbon::parse($blitz->synchronized_ends_at)->equalTo(now()->addHour()));
        $this->assertTrue(Carbon::parse(DB::table('homework_assignments')->where('assessment_id', $manifest['assessments']['review_hw'])->value('review_due_at'))
            ->equalTo(Carbon::parse('2026-01-15 13:00:00 UTC')));
    }

    public function test_every_seeded_question_set_passes_the_production_activation_validator(): void
    {
        (new Stage9E2eSeeder)->run();
        $validator = app(AssessmentActivationValidator::class);
        foreach (Stage9E2eSeeder::manifest()['assessments'] as $name => $id) {
            $questions = Question::query()->where('assessment_id', $id)->orderBy('position')->get();
            $expected = DB::table('assessments')->where('id', $id)->value('total_possible_points');
            $this->assertSame($expected, $validator->validateQuestions($questions), $name);
        }
        $this->assertSame('20.000000', DB::table('assessments')->where('id', Stage9E2eSeeder::manifest()['assessments']['review_hw'])->value('total_possible_points'));
        $this->assertSame('manual', DB::table('questions')->where('id', Stage9E2eSeeder::manifest()['questions']['review_hw']['q3'])->value('checking_mode'));
    }

    public function test_seeded_matching_and_ordering_item_ids_reveal_no_answer_key(): void
    {
        (new Stage9E2eSeeder)->run();
        $manifest = Stage9E2eSeeder::manifest();
        $items = DB::table('question_matching_items')->where('question_id', $manifest['questions']['backfill_hw']['q6'])->get();
        $pairs = $items->groupBy('match_key')->map(fn ($pair): array => [$pair->firstWhere('side', 'left')->id, $pair->firstWhere('side', 'right')->id])->sort()->values()->all();
        $rankPairs = $items->where('side', 'left')->pluck('id')->sort()->values()->zip($items->where('side', 'right')->pluck('id')->sort()->values())
            ->map(fn ($pair): array => $pair->all())->sort()->values()->all();
        foreach ($pairs as $pair) {
            $this->assertNotContains($pair, $rankPairs, 'no pair recoverable by rank');
        }
        foreach ([['backfill_hw', 'q7'], ['backfill_blitz', 'q2']] as [$assessment, $label]) {
            $byId = DB::table('question_ordering_items')->where('question_id', $manifest['questions'][$assessment][$label])->get()->sortBy('id')->pluck('correct_position')->values()->all();
            $this->assertNotSame([1, 2, 3], $byId, $assessment.' ordering by id');
            $this->assertNotSame([3, 2, 1], $byId, $assessment.' ordering by reversed id');
        }
    }

    public function test_scheduled_commands_see_exactly_the_seeded_candidates_and_reach_the_contract_scores(): void
    {
        $seeder = new Stage9E2eSeeder;
        $seeder->ensureSentinels();
        $seeder->run();
        $manifest = Stage9E2eSeeder::manifest();
        $sentinels = $seeder->sentinelState();
        $answersBefore = DB::table('attempt_answers')->whereIn('attempt_id', $manifest['attempts'])->orderBy('id')->pluck('updated_at', 'id')->all();

        $this->artisan('homework:reconcile-deadlines')->expectsOutput('Candidates: 1; finalized attempts: 1; failures: 0.')->assertExitCode(0);
        $this->artisan('blitz:reconcile-timeouts')->expectsOutput('Candidates: 1; finalized attempts: 1; failures: 0.')->assertExitCode(0);
        $this->artisan('attempts:check-frozen')->expectsOutput('Candidates: 2; checked attempts: 2; failures: 0.')
            ->expectsOutput('Official scores repaired: 1; failures: 0.')->assertExitCode(0);

        $attempt = fn (string $name): object => DB::table('assessment_attempts')->where('id', $manifest['attempts'][$name])->sole();
        $points = fn (string $name, string $assessment): array => DB::table('attempt_answers')->where('attempt_id', $manifest['attempts'][$name])->get()
            ->mapWithKeys(fn (object $answer): array => [array_flip($manifest['questions'][$assessment])[$answer->question_id] => [$answer->checking_status, $answer->awarded_points]])
            ->sortKeys()->all();
        $auto = fn (string $value): array => ['auto_checked', $value];
        $this->assertSame(['q1' => $auto('2.00000000'), 'q2' => $auto('1.00000000'), 'q3' => $auto('1.00000000'), 'q4' => $auto('2.00000000'),
            'q5' => $auto('1.50000000'), 'q6' => $auto('1.00000000'), 'q7' => $auto('1.33333333'), 'q8' => ['waiting_for_teacher_review', null]], $points('backfill_hw_1', 'backfill_hw'));
        $backfill = $attempt('backfill_hw_1');
        $this->assertSame(['waiting_for_teacher_review', null, null, 'student_submit'], [$backfill->status, $backfill->earned_points, $backfill->normalized_score, $backfill->finalization_reason]);
        // 2/3 rounds half-up to 0.66666667: truncation would give 0.66666666 and 55.55555533, unrounded points 55.55555556.
        $this->assertSame(['q1' => $auto('0.66666667'), 'q2' => $auto('0.00000000'), 'q3' => $auto('1.00000000')], $points('backfill_blitz_1', 'backfill_blitz'));
        $blitz = $attempt('backfill_blitz_1');
        $this->assertSame(['checked', '1.66666667', '55.55555567', 'timeout_auto_submit'], [$blitz->status, $blitz->earned_points, $blitz->normalized_score, $blitz->finalization_reason]);
        $deadline = $attempt('deadline_hw_1');
        $this->assertSame(['checked', '3.00000000', '75.00000000', 'homework_deadline_auto_submit', null],
            [$deadline->status, $deadline->earned_points, $deadline->normalized_score, $deadline->finalization_reason, $deadline->submitted_at]);
        $this->assertTrue(Carbon::parse($deadline->finalized_at)->equalTo(Carbon::parse($deadline->deadline_at)));
        $timeout = $attempt('timeout_blitz_1');
        $this->assertSame(['checked', '2.00000000', '50.00000000', 'timeout_auto_submit', null],
            [$timeout->status, $timeout->earned_points, $timeout->normalized_score, $timeout->finalization_reason, $timeout->submitted_at]);
        $this->assertTrue(Carbon::parse($timeout->finalized_at)->equalTo(Carbon::parse($timeout->deadline_at)));

        $official = DB::table('official_task_scores')->whereIn('student_id', $manifest['users'])->orderBy('selection_policy_code')->get();
        $this->assertSame([[$manifest['assessments']['repair_hw'], $manifest['users']['repair_student'], $manifest['attempts']['repair_hw_1'], '100.00000000', 'highest_valid_completed'],
            [$manifest['assessments']['backfill_blitz'], $manifest['users']['backfill_student'], $manifest['attempts']['backfill_blitz_1'], '55.55555567', 'valid_normal_blitz']],
            $official->map(fn (object $row): array => [$row->assessment_id, $row->student_id, $row->official_attempt_id, $row->normalized_score, $row->selection_policy_code])->all());
        $this->assertSame($answersBefore, DB::table('attempt_answers')->whereIn('attempt_id', $manifest['attempts'])->orderBy('id')->pluck('updated_at', 'id')->all());
        $this->assertNull(DB::table('attempt_answers')->whereIn('attempt_id', $manifest['attempts'])->whereNotNull('checked_by_user_id')->value('id'));

        $this->artisan('attempts:check-frozen')->expectsOutput('Candidates: 0; checked attempts: 0; failures: 0.')
            ->expectsOutput('Official scores repaired: 0; failures: 0.')->assertExitCode(0);
        $this->artisan('homework:reconcile-deadlines')->expectsOutput('Candidates: 0; finalized attempts: 0; failures: 0.')->assertExitCode(0);
        $this->artisan('blitz:reconcile-timeouts')->expectsOutput('Candidates: 0; finalized attempts: 0; failures: 0.')->assertExitCode(0);
        $this->assertSame($sentinels, $seeder->sentinelState());
    }

    public function test_cleanup_removes_rows_created_by_real_actions_then_reseed_converges(): void
    {
        $prefixSentinel = $this->prefixSentinel();
        $prefixBefore = $prefixSentinel->getAttributes();
        $disk = Storage::disk('stage9_seeder_test');
        $unrelatedKey = 'student-submissions/'.$prefixSentinel->id.'/unrelated.pdf';
        $disk->put($unrelatedKey, 'E2E S09 unrelated private bytes');
        $seeder = new Stage9E2eSeeder;
        $seeder->ensureSentinels();
        $sentinels = $seeder->sentinelState();
        $seeder->run();
        $baseline = $this->structuralSnapshot();
        $history = $this->seededHistory();
        $manifest = Stage9E2eSeeder::manifest();
        $user = fn (string $name): User => User::query()->findOrFail($manifest['users'][$name]);
        $question = fn (string $assessment, string $label): string => $manifest['questions'][$assessment][$label];
        $option = fn (string $assessment, string $label, int $position): string => $manifest['nested'][$assessment][$label][$position - 1];
        $save = app(SaveStudentAttemptAnswer::class);
        $checks = app(FrozenAttemptCheckQueue::class);

        $homework = app(StartStudentHomeworkAttempt::class)($user('student'), $manifest['assessments']['review_hw'], Stage9E2eSeeder::id(9_900_001));
        $save($user('student'), $homework->attemptId, $question('review_hw', 'q1'), ['type' => 'single_choice', 'selected_option_ids' => [$option('review_hw', 'q1', 2)]]);
        $save($user('student'), $homework->attemptId, $question('review_hw', 'q2'), ['type' => 'multiple_choice',
            'selected_option_ids' => [$option('review_hw', 'q2', 1), $option('review_hw', 'q2', 3), $option('review_hw', 'q2', 4)]]);
        $save($user('student'), $homework->attemptId, $question('review_hw', 'q3'), ['type' => 'short_written', 'text' => 'Photosynthesis needs light.']);
        $save($user('student'), $homework->attemptId, $question('review_hw', 'q4'), ['type' => 'open_written', 'text' => 'Open written answer for review.']);
        $upload = UploadedFile::fake()->createWithContent('e2e_s09_answer.pdf', "%PDF-1.7\nE2E S09 saved bytes\n%%EOF\n");
        $save($user('student'), $homework->attemptId, $question('review_hw', 'q5'), ['type' => 'file_based', 'file' => $upload], $upload);
        app(SubmitStudentHomeworkAttempt::class)($user('student'), $homework->attemptId, Stage9E2eSeeder::id(9_900_002));
        $checks->drain();
        $waiting = DB::table('attempt_answers')->where('attempt_id', $homework->attemptId)->where('checking_status', 'waiting_for_teacher_review')->pluck('id');
        $this->assertCount(3, $waiting);
        app(ReviewTeacherSubmission::class)($user('teacher'), $homework->attemptId,
            $waiting->map(fn (string $id): array => ['answer_id' => $id, 'awarded_points' => 4, 'feedback' => 'E2E S09 cleanup test review'])->all());
        $this->assertSame('80.00000000', DB::table('official_task_scores')->where('official_attempt_id', $homework->attemptId)->value('normalized_score'));

        $blitz = app(StartStudentBlitzAttempt::class)($user('student'), $manifest['assessments']['exception_blitz'], Stage9E2eSeeder::id(9_900_003), 'start_normal');
        $save($user('student'), $blitz->attemptId, $question('exception_blitz', 'q1'), ['type' => 'single_choice', 'selected_option_ids' => [$option('exception_blitz', 'q1', 1)]]);
        $save($user('student'), $blitz->attemptId, $question('exception_blitz', 'q2'), ['type' => 'open_written', 'text' => 'Blitz answer one.']);
        app(SubmitStudentBlitzAttempt::class)($user('student'), $blitz->attemptId, Stage9E2eSeeder::id(9_900_004));
        $checks->drain();
        $blitzAnswer = DB::table('attempt_answers')->where('attempt_id', $blitz->attemptId)->where('checking_status', 'waiting_for_teacher_review')->value('id');
        app(ReviewTeacherSubmission::class)($user('teacher'), $blitz->attemptId, [['answer_id' => $blitzAnswer, 'awarded_points' => 3, 'feedback' => null]]);
        $this->assertSame(1, DB::table('official_task_scores')->where('official_attempt_id', $blitz->attemptId)->count());
        app(GrantTeacherBlitzAttemptException::class)($user('teacher'), $manifest['assessments']['exception_blitz'], $manifest['users']['student'],
            Stage9E2eSeeder::id(9_900_005), ['reason_type' => 'technical', 'reason' => 'E2E S09 cleanup test grant']);
        $this->assertSame(0, DB::table('official_task_scores')->where('official_attempt_id', $blitz->attemptId)->count());
        app(StartStudentBlitzAttempt::class)($user('student'), $manifest['assessments']['exception_blitz'], Stage9E2eSeeder::id(9_900_006), 'start_replacement');
        $user('student')->createToken('E2E S09 cleanup test');

        // A replaced upload may leave a File row without an answer link; it is still owned through its key.
        $directory = 'student-submissions/'.$manifest['institutions']['auto'].'/'.$homework->attemptId.'/'.$question('review_hw', 'q5');
        $orphanKey = $directory.'/'.Stage9E2eSeeder::id(8_000_002).'.docx';
        $disk->put($orphanKey, 'E2E S09 unlinked staged bytes');
        $orphanFile = (string) Str::uuid();
        DB::table('files')->insert(['id' => $orphanFile, 'institution_id' => $manifest['institutions']['auto'], 'uploaded_by_user_id' => $manifest['users']['student'],
            'category' => 'student_submission', 'original_name' => 'e2e_s09_orphan.docx', 'storage_disk' => 'stage9_seeder_test', 'storage_key' => $orphanKey,
            'mime_type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'extension' => 'docx', 'size_bytes' => 29,
            'created_at' => now(), 'updated_at' => now()]);

        $state = $seeder->ownedState();
        $this->assertCount(count($manifest['attempts']) + 3, $state['db']['assessment_attempts']);
        $this->assertCount(14 + 5 + 2, $state['db']['attempt_answers']);
        $this->assertCount(2, $state['db']['files']);
        $this->assertCount(1, $state['db']['official_task_scores']);
        $this->assertCount(1, $state['db']['blitz_attempt_exceptions']);
        $this->assertCount(6, $state['db']['idempotency_records']);
        $this->assertCount(1, $state['db']['personal_access_tokens']);
        $this->assertCount(2, $state['blobs']);
        $predecessor = $directory.'/'.Stage9E2eSeeder::id(8_000_001).'.pdf';
        $disk->put($predecessor, 'E2E S09 replaced predecessor bytes');

        $seeder->cleanupOwnedState();
        $seeder->cleanupOwnedState();
        $this->assertNoStaticRows();
        foreach (['assessment_attempts', 'attempt_answers', 'files', 'idempotency_records', 'personal_access_tokens', 'blitz_attempt_exceptions', 'official_task_scores'] as $table) {
            $this->assertSame(0, DB::table($table)->whereIn('id', $state['db'][$table])->count(), $table);
        }
        $this->assertSame(0, DB::table('answer_files')->whereIn('answer_id', $state['db']['attempt_answers'])->count());
        foreach ([...array_column($state['blobs'], 'key'), $predecessor] as $key) {
            $this->assertFalse($disk->exists($key), $key);
        }
        $this->assertFalse($disk->exists($directory), 'empty owned submission directory removed');
        $this->assertSame('E2E S09 unrelated private bytes', $disk->get($unrelatedKey));
        $this->assertSame($prefixBefore, $prefixSentinel->fresh()->getAttributes());
        $this->assertSame($sentinels, $seeder->sentinelState());
        $seeder->run();
        $this->assertSame($baseline, $this->structuralSnapshot());
        $this->assertSame($history, $this->seededHistory());
        $this->assertSame($sentinels, $seeder->sentinelState());
        $seeder->removeSentinels();
        $seeder->removeSentinels();
        $this->assertNoSentinelRows();
        $this->assertFalse($disk->exists(Stage9E2eSeeder::sentinelBlob()['key']));
    }

    public function test_cleanup_fails_closed_on_unowned_or_unsafe_rows(): void
    {
        $seeder = new Stage9E2eSeeder;
        $seeder->run();
        $manifest = Stage9E2eSeeder::manifest();
        $student = User::query()->findOrFail($manifest['users']['student']);
        $start = app(StartStudentHomeworkAttempt::class)($student, $manifest['assessments']['review_hw'], Stage9E2eSeeder::id(9_900_011));
        $upload = UploadedFile::fake()->createWithContent('e2e_s09_answer.pdf', "%PDF-1.7\nE2E S09 saved bytes\n%%EOF\n");
        app(SaveStudentAttemptAnswer::class)($student, $start->attemptId, $manifest['questions']['review_hw']['q5'], ['type' => 'file_based', 'file' => $upload], $upload);
        $fileId = DB::table('answer_files')->whereIn('answer_id', DB::table('attempt_answers')->where('attempt_id', $start->attemptId)->pluck('id'))->value('file_id');
        $officialId = (string) Str::uuid();
        DB::table('official_task_scores')->insert(['id' => $officialId, 'institution_id' => $manifest['institutions']['auto'], 'assessment_id' => $manifest['assessments']['repair_hw'],
            'student_id' => $manifest['users']['repair_student'], 'official_attempt_id' => $manifest['attempts']['backfill_hw_1'], 'normalized_score' => '1.00000000',
            'selection_policy_code' => 'highest_valid_completed', 'selected_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        $changes = [
            // An official row whose Attempt belongs to another Assessment.
            ['official_task_scores', $officialId, null],
            ['files', $fileId, ['storage_key' => 'public/escaped.pdf']],
            ['files', $fileId, ['storage_disk' => 'public']],
            ['users', $manifest['users']['deadline_student'], ['login_name' => 'e2e_s09_someone_else']],
            // A seeded Attempt that no longer matches its recipient.
            ['assessment_attempts', $manifest['attempts']['backfill_hw_1'], ['student_id' => $manifest['users']['repair_student']]],
        ];
        foreach ($changes as [$table, $id, $change]) {
            $original = (array) DB::table($table)->where('id', $id)->first();
            if ($change !== null) {
                DB::table($table)->where('id', $id)->update($change);
            }
            $before = $this->structuralSnapshot();
            try {
                $seeder->cleanupOwnedState();
                $this->fail('Cleanup accepted an unsafe or unowned '.$table.' row.');
            } catch (RuntimeException $exception) {
                $this->assertMatchesRegularExpression('/\A(?:Static |Unowned )?Stage 9 /', $exception->getMessage());
            }
            $this->assertSame($before, $this->structuralSnapshot());
            $this->assertSame(1, DB::table('assessment_attempts')->where('id', $start->attemptId)->count());
            if ($change === null) {
                DB::table($table)->where('id', $id)->delete();
            } else {
                DB::table($table)->where('id', $id)->update(array_intersect_key($original, $change));
            }
        }
        $seeder->cleanupOwnedState();
        $this->assertNoStaticRows();
    }

    public function test_ownership_refuses_any_unowned_row_inside_an_owned_institution(): void
    {
        $seeder = new Stage9E2eSeeder;
        $seeder->run();
        $manifest = Stage9E2eSeeder::manifest();
        DB::table('users')->insert(['id' => Stage9E2eSeeder::id(999_001), 'institution_id' => $manifest['institutions']['auto'], 'role' => 'student',
            'full_name' => 'E2E S09 Intruder', 'login_name' => 'e2e_s09_intruder', 'password' => 'x', 'is_active' => true, 'must_change_password' => false,
            'created_at' => now(), 'updated_at' => now()]);
        $before = $this->structuralSnapshot();
        foreach (['ownedState', 'cleanupOwnedState'] as $operation) {
            try {
                $seeder->{$operation}();
                $this->fail($operation.' accepted an unowned row inside an owned Institution.');
            } catch (RuntimeException $exception) {
                $this->assertSame('Unowned Stage 9 row in an owned Institution: users.', $exception->getMessage());
            }
        }
        $this->assertSame($before, $this->structuralSnapshot());
        $this->assertSame(1, DB::table('users')->where('id', Stage9E2eSeeder::id(999_001))->count());
    }

    public function test_ownership_refuses_a_foreign_file_keyed_into_an_owned_attempt_directory(): void
    {
        $seeder = new Stage9E2eSeeder;
        $seeder->ensureSentinels();
        $seeder->run();
        $manifest = Stage9E2eSeeder::manifest();
        $disk = Storage::disk('stage9_seeder_test');
        $directory = 'student-submissions/'.$manifest['institutions']['auto'].'/'.$manifest['attempts']['backfill_hw_1'].'/'.$manifest['questions']['backfill_hw']['q9'];
        $key = $directory.'/'.Stage9E2eSeeder::sentinelId(1_401).'.pdf';
        $disk->put($key, 'E2E S09 foreign bytes in an owned directory');
        DB::table('files')->insert(['id' => Stage9E2eSeeder::sentinelId(1_402), 'institution_id' => Stage9E2eSeeder::sentinelId(1),
            'uploaded_by_user_id' => Stage9E2eSeeder::sentinelId(102), 'category' => 'student_submission', 'original_name' => 'e2e_s09_foreign.pdf',
            'storage_disk' => 'stage9_seeder_test', 'storage_key' => $key, 'mime_type' => 'application/pdf', 'extension' => 'pdf', 'size_bytes' => 41,
            'created_at' => now(), 'updated_at' => now()]);
        $before = $this->structuralSnapshot();
        foreach (['ownedState', 'cleanupOwnedState'] as $operation) {
            try {
                $seeder->{$operation}();
                $this->fail($operation.' accepted a foreign File keyed into an owned Attempt directory.');
            } catch (RuntimeException $exception) {
                $this->assertSame('Unowned Stage 9 File row.', $exception->getMessage());
            }
        }
        $this->assertSame($before, $this->structuralSnapshot());
        $this->assertSame('E2E S09 foreign bytes in an owned directory', $disk->get($key));
        $this->assertSame(1, DB::table('files')->where('id', Stage9E2eSeeder::sentinelId(1_402))->count());
    }

    public function test_sentinel_graph_is_idempotent_and_never_silently_accepts_a_change(): void
    {
        $seeder = new Stage9E2eSeeder;
        $seeder->ensureSentinels();
        $state = $seeder->sentinelState();
        $seeder->ensureSentinels();
        $this->assertSame($state, $seeder->sentinelState());
        $attempt = DB::table('assessment_attempts')->where('id', Stage9E2eSeeder::sentinelId(801))->sole();
        $this->assertSame(['checked', '100.00000000'], [$attempt->status, $attempt->normalized_score]);
        $this->assertSame(0, DB::table('topic_result_pairs')->where('institution_id', Stage9E2eSeeder::sentinelId(1))->count());
        $institution = Stage9E2eSeeder::sentinelId(1);
        DB::table('institutions')->where('id', $institution)->update(['name' => 'E2E S09 changed sentinel']);
        foreach (['ensureSentinels', 'removeSentinels'] as $operation) {
            try {
                $seeder->{$operation}();
                $this->fail('A changed sentinel was accepted by '.$operation.'.');
            } catch (RuntimeException $exception) {
                $this->assertStringContainsString('sentinel row changed', $exception->getMessage());
            }
        }
        $this->assertSame(1, DB::table('institutions')->where('id', $institution)->count());
        DB::table('institutions')->where('id', $institution)->update(['name' => 'E2E S09 Unrelated Sentinel Institution']);
        Storage::disk('stage9_seeder_test')->put(Stage9E2eSeeder::sentinelBlob()['key'], 'tampered');
        try {
            $seeder->ensureSentinels();
            $this->fail('A changed sentinel blob was accepted.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('sentinel blob changed', $exception->getMessage());
        }
    }

    public function test_read_only_inspection_does_not_need_the_password(): void
    {
        $seeder = new Stage9E2eSeeder;
        $seeder->run();
        $seeder->ensureSentinels();
        putenv('STAGE9_E2E_PASSWORD');
        $this->assertCount(count(Stage9E2eSeeder::manifest()['attempts']), $seeder->ownedState()['db']['assessment_attempts']);
        $this->assertNotNull($seeder->sentinelState()['blob']);
    }

    private function prefixSentinel(): Institution
    {
        return Institution::factory()->create(['id' => Stage9E2eSeeder::id(999999), 'name' => 'E2E S09 unrelated prefix sentinel',
            'type' => 'school', 'contact_email' => null, 'contact_phone' => null, 'address' => null, 'description' => null])->fresh();
    }

    private function assertNoStaticRows(): void
    {
        foreach (Stage9E2eSeeder::manifest()['db'] as $table => $ids) {
            $this->assertSame(0, DB::table($table)->whereIn(Stage9E2eSeeder::PRIMARY_KEYS[$table] ?? 'id', $ids)->count(), $table);
        }
        $this->assertSame(0, DB::table('assessment_attempts')->whereIn('id', Stage9E2eSeeder::manifest()['attempts'])->count());
    }

    private function assertNoSentinelRows(): void
    {
        foreach (Stage9E2eSeeder::sentinelRows() as $table => $rows) {
            $primaryKey = match ($table) {
                'institution_settings' => 'institution_id',
                'homework_assignments' => 'assessment_id',
                'answer_choice_selections' => 'answer_id',
                default => 'id',
            };
            $this->assertSame(0, DB::table($table)->whereIn($primaryKey, array_column($rows, $primaryKey))->count(), 'sentinel '.$table);
        }
    }

    private function structuralSnapshot(): array
    {
        $snapshot = [];
        foreach (Stage9E2eSeeder::manifest()['db'] as $table => $ids) {
            $primaryKey = Stage9E2eSeeder::PRIMARY_KEYS[$table] ?? 'id';
            $snapshot[$table] = DB::table($table)->whereIn($primaryKey, $ids)->orderBy($primaryKey)->get()->map(function (object $row): array {
                $attributes = (array) $row;
                unset($attributes['password']);

                return $attributes;
            })->all();
        }

        return $snapshot + $this->seededHistory();
    }

    /** The seeded pre-Stage-9 Attempts, their answers and typed answer rows. */
    private function seededHistory(): array
    {
        $manifest = Stage9E2eSeeder::manifest();
        $answers = collect($manifest['answers'])->flatten()->all();
        $rows = fn ($query): array => $query->get()->map(fn (object $row): array => (array) $row)->all();
        $history = [
            'assessment_attempts' => $rows(DB::table('assessment_attempts')->whereIn('id', $manifest['attempts'])->orderBy('id')),
            'attempt_answers' => $rows(DB::table('attempt_answers')->whereIn('id', $answers)->orderBy('id')),
        ];
        foreach (['answer_choice_selections', 'answer_text_values', 'answer_boolean_values', 'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values'] as $table) {
            $history[$table] = $rows(DB::table($table)->whereIn('answer_id', $answers)->orderBy('answer_id')->orderBy('created_at')
                ->orderBy($table === 'answer_choice_selections' ? 'option_id' : ($table === 'answer_text_values' || $table === 'answer_boolean_values' ? 'answer_id' : 'id')));
        }

        return $history;
    }
}
