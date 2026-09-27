<?php

namespace Tests\Feature\Seeders;

use App\Actions\Blitz\ReconcileDueBlitzTimeouts;
use App\Actions\Student\SaveStudentBlitzFileAnswer;
use App\Actions\Student\StartStudentBlitzAttempt;
use App\Actions\Student\SubmitStudentBlitzAttempt;
use App\Actions\Teacher\ActivateTeacherBlitz;
use App\Actions\Teacher\GrantTeacherBlitzAttemptException;
use App\Models\Institution;
use App\Models\User;
use Database\Seeders\Stage8E2eSeeder;
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

class Stage8E2eSeederTest extends TestCase
{
    use DatabaseTransactions;

    private const PASSWORD = 'E2E-S08-focused-test-password-only!';

    private string|false $previousPassword;

    private string $privateTestRoot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-27 12:00:00 UTC'));
        $this->previousPassword = getenv('STAGE8_E2E_PASSWORD');
        putenv('STAGE8_E2E_PASSWORD='.self::PASSWORD);
        $this->privateTestRoot = storage_path('app/private/e2e-s08-seeder-test-'.getmypid());
        $this->assertDirectoryDoesNotExist($this->privateTestRoot);
        File::ensureDirectoryExists($this->privateTestRoot);
        config(['filesystems.private_files_disk' => 'stage8_seeder_test', 'filesystems.disks.stage8_seeder_test' => [
            'driver' => 'local', 'root' => $this->privateTestRoot, 'visibility' => 'private', 'throw' => true,
        ]]);
        // The runner removes any real manifest before this test; the transaction restores whatever it finds.
        (new Stage8E2eSeeder)->cleanupOwnedState();
    }

    protected function tearDown(): void
    {
        putenv($this->previousPassword === false ? 'STAGE8_E2E_PASSWORD' : 'STAGE8_E2E_PASSWORD='.$this->previousPassword);
        Storage::forgetDisk('stage8_seeder_test');
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
            config(['database.default' => 'stage8_unsafe', 'database.connections.stage8_unsafe' => ['driver' => 'sqlite', 'database' => ':memory:']]);
        } elseif ($failure === 'database') {
            DB::shouldReceive('connection')->once()->andReturn($database->connection());
            DB::shouldReceive('selectOne')->once()->with('select current_database() as database_name')
                ->andReturn((object) ['database_name' => 'testlabuz']);
        } else {
            putenv($failure === 'missing_password' ? 'STAGE8_E2E_PASSWORD' : 'STAGE8_E2E_PASSWORD=   ');
        }
        try {
            (new Stage8E2eSeeder)->{$operation}();
            $this->fail('Unsafe Stage 8 fixture mutation was allowed.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('Stage 8', $exception->getMessage());
            $this->assertStringNotContainsString(self::PASSWORD, $exception->getMessage());
        } finally {
            DB::swap($database);
            config(['database.default' => $default]);
            $this->app->instance('env', 'testing');
        }
        $this->assertNoStaticRows();
        $this->assertNoSentinelRows();
        $this->assertSame([], Storage::disk('stage8_seeder_test')->allFiles());
    }

    public static function unsafeGuards(): array
    {
        $cases = [];
        foreach (['environment', 'driver', 'database', 'missing_password', 'blank_password'] as $failure) {
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
        $seeder = new Stage8E2eSeeder;
        $seeder->ensureSentinels();
        $sentinels = $seeder->sentinelState();
        $seeder->run();
        $first = $this->structuralSnapshot();
        $seeder->run();
        $this->assertSame($first, $this->structuralSnapshot());
        $this->assertSame($before, $prefixSentinel->fresh()->getAttributes());
        $this->assertSame($sentinels, $seeder->sentinelState());
        $manifest = Stage8E2eSeeder::manifest();
        foreach ($manifest['db'] as $table => $ids) {
            $this->assertCount(count($ids), $first[$table], $table);
            $this->assertSame(count($ids), count(array_unique($ids)), $table.' identities are unique');
        }
        foreach ($manifest['users'] as $name => $id) {
            $user = User::query()->findOrFail($id);
            $this->assertTrue(Hash::check(self::PASSWORD, $user->password));
            $this->assertSame($name !== 'mon_inactive', $user->is_active);
            $this->assertFalse($user->must_change_password);
            $this->assertSame('e2e_s08_'.$name, $user->login_name);
            $this->assertSame(str_ends_with($name, 'teacher') ? 'teacher' : 'student', $user->role->value);
        }
        foreach ($manifest['db'] as $ids) {
            foreach ($ids as $id) {
                $this->assertMatchesRegularExpression('/\A08000000-0000-4000-8000-[0-9]{12}\z/', $id);
            }
        }
    }

    public function test_seeded_relations_stay_inside_their_institution_and_exact_manifest(): void
    {
        (new Stage8E2eSeeder)->run();
        $manifest = Stage8E2eSeeder::manifest();
        $tableForColumn = ['institution_id' => 'institutions', 'group_id' => 'groups', 'teacher_id' => 'users', 'student_id' => 'users',
            'created_by_user_id' => 'users', 'assigned_by_user_id' => 'users', 'designated_by_user_id' => 'users', 'activated_by_user_id' => 'users',
            'granted_by_user_id' => 'users', 'topic_id' => 'topics', 'assessment_id' => 'assessments', 'homework_assessment_id' => 'assessments',
            'blitz_assessment_id' => 'assessments', 'assessment_student_id' => 'assessment_students', 'question_id' => 'questions',
            'blank_id' => 'question_fill_blanks', 'invalidated_attempt_id' => 'assessment_attempts', 'replacement_attempt_id' => 'assessment_attempts'];
        foreach ($this->structuralSnapshot() as $table => $rows) {
            foreach ($rows as $row) {
                foreach ($tableForColumn as $column => $parentTable) {
                    if (! isset($row[$column]) || ($table === 'institutions' && $column === 'institution_id')) {
                        continue;
                    }
                    $this->assertContains($row[$column], $manifest['db'][$parentTable], $table.'.'.$column);
                    $parent = DB::table($parentTable)->where(Stage8E2eSeeder::PRIMARY_KEYS[$parentTable] ?? 'id', $row[$column])->first();
                    $this->assertNotNull($parent, $table.'.'.$column);
                    if ($column !== 'institution_id') {
                        $this->assertSame($row['institution_id'], $parent->institution_id, $table.'.'.$column.' tenant');
                    }
                }
            }
        }
        $timers = DB::table('institution_settings')->whereIn('institution_id', $manifest['institutions'])->pluck('blitz_timer_start_mode', 'institution_id');
        $this->assertSame('synchronized', $timers[$manifest['institutions']['target']]);
        $this->assertSame('synchronized', $timers[$manifest['institutions']['foreign']]);
        $this->assertNull($timers[$manifest['institutions']['unset']]);
        $this->assertSame('individual', $timers[$manifest['institutions']['individual']]);
        $this->assertSame($manifest['institutions']['foreign'], DB::table('assessments')->where('id', $manifest['assessments']['foreign'])->value('institution_id'));
    }

    public function test_locked_partial_official_pair_freezes_a_cohort_that_differs_from_current_membership(): void
    {
        (new Stage8E2eSeeder)->run();
        $manifest = Stage8E2eSeeder::manifest();
        $users = $manifest['users'];
        $pair = DB::table('topic_result_pairs')->where('id', $manifest['pairs']['official'])->sole();
        $homeworkAttempt = DB::table('assessment_attempts')->where('id', $manifest['attempts']['official_homework_1'])->sole();
        $this->assertSame($manifest['assessments']['official_homework'], $pair->homework_assessment_id);
        $this->assertNull($pair->blitz_assessment_id);
        $this->assertTrue(Carbon::parse($pair->locked_at)->equalTo(Carbon::parse($homeworkAttempt->started_at)));
        $this->assertNotNull($pair->cohort_snapshotted_at);
        $this->assertEqualsCanonicalizing([$users['student'], $users['peer']],
            DB::table('assessment_students')->where('assessment_id', $manifest['assessments']['official_homework'])->pluck('student_id')->all());
        $this->assertEqualsCanonicalizing([$users['student'], $users['peer'], $users['late_member']],
            DB::table('group_student_memberships')->where('group_id', $manifest['groups']['official'])->whereNull('ended_at')->pluck('student_id')->all());
        $late = DB::table('group_student_memberships')->where('student_id', $users['late_member'])->sole();
        $this->assertTrue(Carbon::parse($late->started_at)->gt(Carbon::parse($pair->cohort_snapshotted_at)));
        $main = $manifest['assessments']['main'];
        $this->assertSame('draft', DB::table('blitz_tasks')->where('assessment_id', $main)->value('status'));
        $this->assertSame('group', DB::table('assessments')->where('id', $main)->value('assignment_mode'));
        $this->assertSame(0, DB::table('assessment_students')->where('assessment_id', $main)->count());
        $this->assertSame(0, DB::table('assessment_attempts')->where('assessment_id', $main)->count());
        $questions = DB::table('questions')->where('assessment_id', $main)->orderBy('position')->get();
        $this->assertSame([...Stage8E2eSeeder::QUESTION_TYPES, 'short_written'], $questions->pluck('type')->all());
        $this->assertSame(range(1, 10), $questions->pluck('position')->all());
        $this->assertSame('10.000000', DB::table('assessments')->where('id', $main)->value('total_possible_points'));
    }

    public function test_stage_level_fixture_families_are_isolated_and_unstarted(): void
    {
        (new Stage8E2eSeeder)->run();
        $manifest = Stage8E2eSeeder::manifest();
        $users = $manifest['users'];
        $assessments = $manifest['assessments'];
        $practicePair = DB::table('topic_result_pairs')->where('id', $manifest['pairs']['practice'])->sole();
        $this->assertSame($assessments['practice_homework'], $practicePair->homework_assessment_id);
        $this->assertNull($practicePair->blitz_assessment_id);
        $this->assertSame('selected_students', DB::table('assessments')->where('id', $assessments['practice_blitz'])->value('assignment_mode'));
        $this->assertSame([$users['practice_member']], DB::table('assessment_students')->where('assessment_id', $assessments['practice_blitz'])->pluck('student_id')->all());
        $this->assertContains($users['practice_outsider'], DB::table('group_student_memberships')->where('group_id', $manifest['groups']['practice'])->pluck('student_id')->all());

        $blitzFirst = DB::table('topic_result_pairs')->where('id', $manifest['pairs']['blitz_first'])->sole();
        $this->assertSame([$assessments['bf_homework'], $assessments['bf_blitz'], null, null],
            [$blitzFirst->homework_assessment_id, $blitzFirst->blitz_assessment_id, $blitzFirst->cohort_snapshotted_at, $blitzFirst->locked_at]);
        foreach (['bf_homework', 'bf_blitz', 'practice_homework'] as $name) {
            $this->assertSame(0, DB::table('assessment_students')->where('assessment_id', $assessments[$name])->count(), $name);
            $this->assertSame(0, DB::table('assessment_attempts')->where('assessment_id', $assessments[$name])->count(), $name);
        }
        $this->assertSame('draft', DB::table('homework_assignments')->where('assessment_id', $assessments['bf_homework'])->value('status'));

        $this->assertSame($manifest['institutions']['unset'], DB::table('assessments')->where('id', $assessments['unset'])->value('institution_id'));
        $this->assertSame('draft', DB::table('blitz_tasks')->where('assessment_id', $assessments['unset'])->value('status'));
        $this->assertSame(1, DB::table('questions')->where('assessment_id', $assessments['unset'])->count());

        $expected = ['late_typed' => [6, 'd_late_typed'], 'late_file' => [8, 'd_late_file'], 'race_typed' => [3600, 'd_race_typed'], 'race_file' => [3600, 'd_race_file'],
            'matrix_timeout' => [3, 'd_timeout_resume'], 'matrix_late_submit' => [3, 'd_late_submit'], 'timeout_ui' => [45, 'd_timeout_ui']];
        foreach ($expected as $name => [$duration, $student]) {
            $blitz = DB::table('blitz_tasks')->where('assessment_id', $assessments[$name])->sole();
            $this->assertSame(['active', 'individual', $duration, null], [$blitz->status, $blitz->timer_start_mode_snapshot, $blitz->duration_seconds, $blitz->synchronized_ends_at], $name);
            $this->assertSame([$users[$student]], DB::table('assessment_students')->where('assessment_id', $assessments[$name])->pluck('student_id')->all(), $name);
            $this->assertSame(0, DB::table('assessment_attempts')->where('assessment_id', $assessments[$name])->count(), $name);
        }
        $this->assertSame('file_based', DB::table('questions')->where('assessment_id', $assessments['race_file'])->value('type'));
        $this->assertSame('file_based', DB::table('questions')->where('assessment_id', $assessments['late_file'])->value('type'));
        $forward = DB::table('assessment_attempts')->where('assessment_id', $assessments['forward_status'])->orderBy('status')->get();
        $this->assertSame(['checked', 'waiting_for_teacher_review'], $forward->pluck('status')->all());
        foreach ($forward as $attempt) {
            $this->assertSame([null, null, null], [$attempt->earned_points, $attempt->normalized_score, $attempt->scoring_completed_at]);
        }
        $this->assertSame(['mon_due', 'mon_exception', 'mon_inactive', 'mon_never', 'mon_submitted'],
            collect(array_flip($users))->only(DB::table('assessment_students')->where('assessment_id', $assessments['monitoring'])->pluck('student_id')->all())->sort()->values()->all());
        $this->assertFalse(User::query()->findOrFail($users['mon_inactive'])->is_active);
    }

    public function test_scheduler_aggregate_is_the_only_exact_candidate_and_keeps_a_future_replacement(): void
    {
        $seeder = new Stage8E2eSeeder;
        $seeder->ensureSentinels();
        $seeder->run();
        $manifest = Stage8E2eSeeder::manifest();
        $candidates = DB::table('blitz_tasks')->where('status', 'active')->whereExists(fn ($query) => $query->selectRaw('1')->from('assessment_attempts')
            ->whereColumn('assessment_attempts.institution_id', 'blitz_tasks.institution_id')->whereColumn('assessment_attempts.assessment_id', 'blitz_tasks.assessment_id')
            ->where('assessment_attempts.status', 'in_progress')->where('assessment_attempts.deadline_at', '<=', now()))->get(['institution_id', 'assessment_id']);
        $withCloseAndMonitoring = [$manifest['assessments']['scheduler'], $manifest['assessments']['close'], $manifest['assessments']['monitoring']];
        $this->assertEqualsCanonicalizing($withCloseAndMonitoring, $candidates->pluck('assessment_id')->all());
        $superset = DB::table('blitz_tasks')->join('assessment_attempts', fn ($join) => $join->on('assessment_attempts.assessment_id', '=', 'blitz_tasks.assessment_id')
            ->on('assessment_attempts.institution_id', '=', 'blitz_tasks.institution_id'))->where('blitz_tasks.status', 'active')
            ->where('assessment_attempts.status', 'in_progress')->whereNotNull('assessment_attempts.deadline_at')->pluck('assessment_attempts.id')->all();
        $this->assertEqualsCanonicalizing([$manifest['attempts']['sched_due_1'], $manifest['attempts']['sched_future_2'], $manifest['attempts']['close_due_1'], $manifest['attempts']['mon_due_1']], $superset);

        $future = DB::table('assessment_attempts')->where('id', $manifest['attempts']['sched_future_2'])->sole();
        $this->assertSame([2, 'in_progress', true], [$future->attempt_number, $future->status, $future->official_score_eligible]);
        $this->assertTrue(Carbon::parse($future->started_at)->equalTo(now()->startOfSecond()));
        $this->assertTrue(Carbon::parse($future->deadline_at)->equalTo(now()->startOfSecond()->addSeconds(Stage8E2eSeeder::SCHEDULER_DURATION)));
        $blitz = DB::table('blitz_tasks')->where('assessment_id', $manifest['assessments']['scheduler'])->sole();
        $this->assertTrue(Carbon::parse($blitz->synchronized_ends_at)->lt(now()));
        $exception = DB::table('blitz_attempt_exceptions')->where('id', $manifest['exceptions']['sched_future'])->sole();
        $this->assertSame([$manifest['attempts']['sched_future_1'], $future->id], [$exception->invalidated_attempt_id, $exception->replacement_attempt_id]);

        // The close and monitoring fixtures are terminalized by their scenarios before the runner's first command.
        DB::table('blitz_tasks')->whereIn('assessment_id', [$manifest['assessments']['close'], $manifest['assessments']['monitoring']])
            ->update(['status' => 'closed', 'closed_at' => now()]);
        $sentinels = $seeder->sentinelState();
        $this->assertSame(['candidates' => 1, 'finalized_attempts' => 1, 'failures' => 0], app(ReconcileDueBlitzTimeouts::class)());
        $due = DB::table('assessment_attempts')->where('id', $manifest['attempts']['sched_due_1'])->sole();
        $this->assertSame(['timed_out_finalized', 'timeout_auto_submit', null], [$due->status, $due->finalization_reason, $due->submitted_at]);
        $this->assertTrue(Carbon::parse($due->finalized_at)->equalTo(Carbon::parse($due->deadline_at)));
        $this->assertSame('in_progress', DB::table('assessment_attempts')->where('id', $future->id)->value('status'));
        $this->assertSame(['candidates' => 0, 'finalized_attempts' => 0, 'failures' => 0], app(ReconcileDueBlitzTimeouts::class)());
        $this->assertSame($sentinels, $seeder->sentinelState());
    }

    public function test_seeded_matching_and_ordering_item_ids_reveal_no_answer_key(): void
    {
        (new Stage8E2eSeeder)->run();
        $manifest = Stage8E2eSeeder::manifest();
        $this->assertSame(2, count(array_filter($manifest['questions'], fn (array $questions): bool => isset($questions['matching']))));
        foreach (['main', 'matrix'] as $name) {
            $items = DB::table('question_matching_items')->where('question_id', $manifest['questions'][$name]['matching'])->get();
            $pairs = $items->groupBy('match_key')->map(fn ($pair): array => [$pair->firstWhere('side', 'left')->id, $pair->firstWhere('side', 'right')->id])->sort()->values()->all();
            $left = $items->where('side', 'left')->pluck('id')->sort()->values();
            $right = $items->where('side', 'right')->pluck('id')->sort()->values();
            $rankPairs = $left->zip($right)->map(fn ($pair): array => $pair->all())->sort()->values()->all();
            $this->assertNotSame($pairs, $rankPairs, $name.' matching rank pairing');
            $combined = $items->pluck('id')->sort()->values()->chunk(2)->map(fn ($chunk): array => $chunk->values()->all())->sort()->values()->all();
            $this->assertNotSame($pairs, $combined, $name.' matching combined sort');
            foreach ($pairs as [$leftId, $rightId]) {
                $this->assertNotContains([$leftId, $rightId], $rankPairs, $name.' no pair recoverable by rank');
            }
            $ordering = DB::table('question_ordering_items')->where('question_id', $manifest['questions'][$name]['ordering'])->get();
            $byId = $ordering->sortBy('id')->pluck('correct_position')->values()->all();
            $this->assertNotSame([1, 2, 3, 4], $byId, $name.' ordering by ID');
            $this->assertNotSame([4, 3, 2, 1], $byId, $name.' ordering by reversed ID');
        }
    }

    public function test_cleanup_removes_dynamic_file_answer_and_blob_then_reseed_converges(): void
    {
        $prefixSentinel = $this->prefixSentinel();
        $prefixBefore = $prefixSentinel->getAttributes();
        $disk = Storage::disk('stage8_seeder_test');
        $unrelatedKey = 'student-submissions/'.$prefixSentinel->id.'/unrelated.pdf';
        $disk->put($unrelatedKey, 'E2E S08 unrelated private bytes');
        $seeder = new Stage8E2eSeeder;
        $seeder->ensureSentinels();
        $sentinels = $seeder->sentinelState();
        $seeder->run();
        $baseline = $this->structuralSnapshot();
        $manifest = Stage8E2eSeeder::manifest();
        $user = fn (string $name): User => User::query()->findOrFail($manifest['users'][$name]);

        $raceFile = app(StartStudentBlitzAttempt::class)($user('d_race_file'), $manifest['assessments']['race_file'], Stage8E2eSeeder::id(9_900_001), 'start_normal');
        app(SaveStudentBlitzFileAnswer::class)($user('d_race_file'), $raceFile->attemptId, $manifest['questions']['race_file']['file_based'],
            UploadedFile::fake()->createWithContent('e2e_s08_answer.pdf', "%PDF-1.7\nE2E S08 saved bytes"));
        $matrix = app(StartStudentBlitzAttempt::class)($user('d_matrix'), $manifest['assessments']['matrix'], Stage8E2eSeeder::id(9_900_002), 'start_normal');
        app(SubmitStudentBlitzAttempt::class)($user('d_matrix'), $matrix->attemptId, Stage8E2eSeeder::id(9_900_003));
        app(GrantTeacherBlitzAttemptException::class)($user('individual_teacher'), $manifest['assessments']['matrix'], $manifest['users']['d_matrix'],
            Stage8E2eSeeder::id(9_900_004), ['reason_type' => 'technical', 'reason' => 'E2E S08 cleanup test grant']);
        app(ActivateTeacherBlitz::class)($user('teacher'), $manifest['assessments']['sync_replacement'], Stage8E2eSeeder::id(9_900_005));
        $user('d_race_file')->createToken('E2E S08 cleanup test');
        $builderBlitz = (string) Str::uuid();
        $builderQuestion = (string) Str::uuid();
        $stamps = ['created_at' => now(), 'updated_at' => now()];
        DB::table('assessments')->insert(['id' => $builderBlitz, 'institution_id' => $manifest['institutions']['target'], 'topic_id' => $manifest['topics']['builder'],
            'teacher_id' => $manifest['users']['teacher'], 'type' => 'blitz', 'title' => 'E2E S08 UI draft', 'student_instructions' => 'E2E S08',
            'assignment_mode' => 'group', 'total_possible_points' => '1.000000'] + $stamps);
        DB::table('blitz_tasks')->insert(['assessment_id' => $builderBlitz, 'institution_id' => $manifest['institutions']['target'], 'status' => 'draft', 'duration_seconds' => 300] + $stamps);
        DB::table('questions')->insert(['id' => $builderQuestion, 'institution_id' => $manifest['institutions']['target'], 'assessment_id' => $builderBlitz,
            'type' => 'single_choice', 'prompt' => 'E2E S08 UI Question', 'points' => '1.000000', 'position' => 1, 'checking_mode' => 'automatic'] + $stamps);
        DB::table('question_choice_options')->insert(['id' => (string) Str::uuid(), 'institution_id' => $manifest['institutions']['target'],
            'question_id' => $builderQuestion, 'option_text' => 'E2E S08 UI option', 'is_correct' => true, 'position' => 1] + $stamps);

        $state = $seeder->ownedState();
        $this->assertCount(count($manifest['attempts']) + 2, $state['db']['assessment_attempts']);
        $this->assertCount(1, $state['db']['files']);
        $this->assertCount(1, $state['db']['attempt_answers']);
        $this->assertCount(count($manifest['exceptions']) + 1, $state['db']['blitz_attempt_exceptions']);
        $this->assertCount(5, $state['db']['idempotency_records']);
        $this->assertCount(1, $state['db']['personal_access_tokens']);
        $this->assertSame([$builderBlitz], $state['dynamic']['assessments']);
        $this->assertSame([$builderQuestion], $state['dynamic']['questions']);
        $this->assertCount(1, $state['dynamic']['question_choice_options']);
        $this->assertCount(1, $state['dynamic']['assessment_students']);
        $this->assertCount(1, $state['blobs']);
        $predecessor = collect($state['directories'])->pluck('key')->first(fn (string $key): bool => str_contains($key, $raceFile->attemptId)).'/'.Stage8E2eSeeder::id(8_000_001).'.pdf';
        $disk->put($predecessor, 'E2E S08 replaced predecessor bytes');

        $seeder->cleanupOwnedState();
        $seeder->cleanupOwnedState();
        $this->assertNoStaticRows();
        foreach (['assessment_attempts', 'attempt_answers', 'files', 'idempotency_records', 'personal_access_tokens', 'blitz_attempt_exceptions'] as $table) {
            $this->assertSame(0, DB::table($table)->whereIn('id', $state['db'][$table])->count(), $table);
        }
        $this->assertSame(0, DB::table('answer_files')->whereIn('answer_id', $state['db']['attempt_answers'])->count());
        $this->assertSame(0, DB::table('assessments')->where('id', $builderBlitz)->count());
        $this->assertSame(0, DB::table('assessment_students')->whereIn('id', $state['dynamic']['assessment_students'])->count());
        foreach ([...array_column($state['blobs'], 'key'), $predecessor] as $key) {
            $this->assertFalse($disk->exists($key), $key);
        }
        $this->assertSame('E2E S08 unrelated private bytes', $disk->get($unrelatedKey));
        $this->assertSame($prefixBefore, $prefixSentinel->fresh()->getAttributes());
        $this->assertSame($sentinels, $seeder->sentinelState());
        $seeder->run();
        $this->assertEquals($this->withoutSeededClock($baseline), $this->withoutSeededClock($this->structuralSnapshot()));
        $this->assertSame($sentinels, $seeder->sentinelState());
        $seeder->removeSentinels();
        $seeder->removeSentinels();
        $this->assertNoSentinelRows();
        $this->assertFalse($disk->exists(Stage8E2eSeeder::sentinelBlob()['key']));
    }

    public function test_cleanup_fails_closed_on_an_unowned_actor_or_an_unsafe_file_row(): void
    {
        $seeder = new Stage8E2eSeeder;
        $seeder->run();
        $manifest = Stage8E2eSeeder::manifest();
        $student = User::query()->findOrFail($manifest['users']['d_race_file']);
        $start = app(StartStudentBlitzAttempt::class)($student, $manifest['assessments']['race_file'], Stage8E2eSeeder::id(9_900_011), 'start_normal');
        app(SaveStudentBlitzFileAnswer::class)($student, $start->attemptId, $manifest['questions']['race_file']['file_based'],
            UploadedFile::fake()->createWithContent('e2e_s08_answer.pdf', "%PDF-1.7\nE2E S08 saved bytes"));
        $fileId = DB::table('answer_files')->whereIn('answer_id', DB::table('attempt_answers')->where('attempt_id', $start->attemptId)->pluck('id'))->value('file_id');
        foreach ([['files', $fileId, ['storage_key' => 'public/escaped.pdf']], ['files', $fileId, ['storage_disk' => 'public']],
            ['users', $manifest['users']['d_close_never'], ['login_name' => 'e2e_s08_someone_else']]] as [$table, $id, $change]) {
            $original = (array) DB::table($table)->where('id', $id)->first();
            DB::table($table)->where('id', $id)->update($change);
            $before = $this->structuralSnapshot();
            try {
                $seeder->cleanupOwnedState();
                $this->fail('Cleanup accepted an unsafe or unowned '.$table.' row.');
            } catch (RuntimeException $exception) {
                $this->assertStringContainsString('Stage 8', $exception->getMessage());
            }
            $this->assertSame($before, $this->structuralSnapshot());
            $this->assertSame(1, DB::table('assessment_attempts')->where('id', $start->attemptId)->count());
            DB::table($table)->where('id', $id)->update(array_intersect_key($original, $change));
        }
    }

    public function test_read_only_inspection_does_not_need_the_password(): void
    {
        $seeder = new Stage8E2eSeeder;
        $seeder->run();
        $seeder->ensureSentinels();
        putenv('STAGE8_E2E_PASSWORD');
        $this->assertCount(count(Stage8E2eSeeder::manifest()['attempts']), $seeder->ownedState()['db']['assessment_attempts']);
        $this->assertNotNull($seeder->sentinelState()['blob']);
    }

    private function prefixSentinel(): Institution
    {
        return Institution::factory()->create(['id' => Stage8E2eSeeder::id(999999), 'name' => 'E2E S08 unrelated prefix sentinel',
            'type' => 'school', 'contact_email' => null, 'contact_phone' => null, 'address' => null, 'description' => null])->fresh();
    }

    private function assertNoStaticRows(): void
    {
        foreach (Stage8E2eSeeder::manifest()['db'] as $table => $ids) {
            $this->assertSame(0, DB::table($table)->whereIn(Stage8E2eSeeder::PRIMARY_KEYS[$table] ?? 'id', $ids)->count(), $table);
        }
    }

    private function assertNoSentinelRows(): void
    {
        foreach (Stage8E2eSeeder::sentinelRows() as $table => $rows) {
            $primaryKey = Stage8E2eSeeder::PRIMARY_KEYS[$table] ?? 'id';
            $this->assertSame(0, DB::table($table)->whereIn($primaryKey, array_column($rows, $primaryKey))->count(), 'sentinel '.$table);
        }
    }

    private function structuralSnapshot(): array
    {
        $snapshot = [];
        foreach (Stage8E2eSeeder::manifest()['db'] as $table => $ids) {
            $primaryKey = Stage8E2eSeeder::PRIMARY_KEYS[$table] ?? 'id';
            $snapshot[$table] = DB::table($table)->whereIn($primaryKey, $ids)->orderBy($primaryKey)->get()->map(function (object $row): array {
                $attributes = (array) $row;
                unset($attributes['password']);

                return $attributes;
            })->all();
        }

        return $snapshot;
    }

    /** The seeded replacement #2 follows the seeding clock; everything else is fixed. */
    private function withoutSeededClock(array $snapshot): array
    {
        $future = Stage8E2eSeeder::manifest()['attempts']['sched_future_2'];
        foreach ($snapshot['assessment_attempts'] as $index => $attempt) {
            if ($attempt['id'] === $future) {
                unset($snapshot['assessment_attempts'][$index]['started_at'], $snapshot['assessment_attempts'][$index]['deadline_at'],
                    $snapshot['assessment_attempts'][$index]['created_at'], $snapshot['assessment_attempts'][$index]['updated_at']);
            }
        }

        return $snapshot;
    }
}
