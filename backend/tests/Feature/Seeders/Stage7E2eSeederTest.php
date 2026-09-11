<?php

namespace Tests\Feature\Seeders;

use App\Actions\Student\SaveStudentHomeworkFileAnswer;
use App\Actions\Student\StartStudentHomeworkAttempt;
use App\Models\Institution;
use App\Models\User;
use Database\Seeders\Stage7E2eSeeder;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class Stage7E2eSeederTest extends TestCase
{
    use DatabaseTransactions;

    private const PASSWORD = 'E2E-S07-focused-test-password-only!';

    private string|false $previousPassword;

    private string $privateTestRoot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-11 12:00:00 UTC'));
        $this->previousPassword = getenv('STAGE7_E2E_PASSWORD');
        putenv('STAGE7_E2E_PASSWORD='.self::PASSWORD);
        $this->privateTestRoot = storage_path('app/private/e2e-s07-seeder-test-'.getmypid());
        $this->assertDirectoryDoesNotExist($this->privateTestRoot);
        File::ensureDirectoryExists($this->privateTestRoot);
        config(['filesystems.private_files_disk' => 'stage7_seeder_test', 'filesystems.disks.stage7_seeder_test' => [
            'driver' => 'local', 'root' => $this->privateTestRoot, 'visibility' => 'private', 'throw' => true,
        ]]);
        // Existing fixture rows are restored by the test transaction. A real Stage 7
        // File uses a different disk, so the ownership guard stops before deleting it.
        (new Stage7E2eSeeder)->cleanupOwnedState();
    }

    protected function tearDown(): void
    {
        putenv($this->previousPassword === false ? 'STAGE7_E2E_PASSWORD' : 'STAGE7_E2E_PASSWORD='.$this->previousPassword);
        Storage::forgetDisk('stage7_seeder_test');
        File::deleteDirectory($this->privateTestRoot);
        parent::tearDown();
    }

    #[DataProvider('unsafeGuards')]
    public function test_seed_and_cleanup_fail_before_writes_when_any_guard_is_unsafe(string $failure, string $operation): void
    {
        $database = DB::getFacadeRoot();
        $default = config('database.default');
        if ($failure === 'environment') {
            $this->app->instance('env', 'production');
        } elseif ($failure === 'driver') {
            config(['database.default' => 'stage7_unsafe', 'database.connections.stage7_unsafe' => ['driver' => 'sqlite', 'database' => ':memory:']]);
        } elseif ($failure === 'database') {
            DB::shouldReceive('connection')->once()->andReturn($database->connection());
            DB::shouldReceive('selectOne')->once()->with('select current_database() as database_name')
                ->andReturn((object) ['database_name' => 'testlabuz']);
        } else {
            putenv($failure === 'missing_password' ? 'STAGE7_E2E_PASSWORD' : 'STAGE7_E2E_PASSWORD=   ');
        }
        try {
            (new Stage7E2eSeeder)->{$operation}();
            $this->fail('Unsafe Stage 7 fixture mutation was allowed.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('Stage 7', $exception->getMessage());
            $this->assertStringNotContainsString(self::PASSWORD, $exception->getMessage());
        } finally {
            DB::swap($database);
            config(['database.default' => $default]);
            $this->app->instance('env', 'testing');
        }
        $this->assertNoStaticRows();
        $this->assertSame([], Storage::disk('stage7_seeder_test')->allFiles());
    }

    public static function unsafeGuards(): array
    {
        $cases = [];
        foreach (['environment', 'driver', 'database', 'missing_password', 'blank_password'] as $failure) {
            foreach (['run', 'cleanupOwnedState'] as $operation) {
                $cases[$failure.' '.$operation] = [$failure, $operation];
            }
        }

        return $cases;
    }

    public function test_reseeding_preserves_the_complete_deterministic_structure_and_unrelated_prefix_sentinel(): void
    {
        $sentinel = $this->sentinel();
        $before = $sentinel->getAttributes();
        $seeder = new Stage7E2eSeeder;
        $seeder->run();
        $first = $this->structuralSnapshot();
        $this->travel(1)->days();
        $seeder->run();
        $this->assertSame($first, $this->structuralSnapshot());
        $this->assertSame($before, $sentinel->fresh()->getAttributes());
        $manifest = Stage7E2eSeeder::manifest();
        foreach ($manifest['db'] as $table => $ids) {
            $this->assertCount(count($ids), $first[$table], $table);
        }
        foreach ($manifest['users'] as $name => $id) {
            $user = User::query()->findOrFail($id);
            $this->assertTrue(Hash::check(self::PASSWORD, $user->password));
            $this->assertTrue($user->is_active);
            $this->assertFalse($user->must_change_password);
            $this->assertSame('e2e_s07_'.$name, $user->login_name);
            $this->assertSame(str_contains($name, 'teacher') ? 'teacher' : ($name === 'parent' ? 'parent' : 'student'), $user->role->value);
            $this->assertSame($manifest['institutions'][str_starts_with($name, 'foreign_') ? 'foreign' : 'target'], $user->institution_id);
        }
    }

    public function test_seeded_relations_stay_inside_their_institution_and_exact_manifest(): void
    {
        (new Stage7E2eSeeder)->run();
        $manifest = Stage7E2eSeeder::manifest();
        $tableForColumn = ['institution_id' => 'institutions', 'group_id' => 'groups', 'teacher_id' => 'users', 'student_id' => 'users',
            'created_by_user_id' => 'users', 'assigned_by_user_id' => 'users', 'designated_by_user_id' => 'users',
            'topic_id' => 'topics', 'assessment_id' => 'assessments', 'homework_assessment_id' => 'assessments',
            'assessment_student_id' => 'assessment_students', 'question_id' => 'questions', 'blank_id' => 'question_fill_blanks',
            'attempt_id' => 'assessment_attempts', 'answer_id' => 'attempt_answers'];
        foreach ($this->structuralSnapshot() as $table => $rows) {
            foreach ($rows as $row) {
                foreach ($tableForColumn as $column => $parentTable) {
                    if (! isset($row[$column])) {
                        continue;
                    }
                    $this->assertContains($row[$column], $manifest['db'][$parentTable], $table.'.'.$column);
                    $parent = DB::table($parentTable)->where('id', $row[$column])->first();
                    $this->assertNotNull($parent, $table.'.'.$column);
                    if ($column !== 'institution_id') {
                        $this->assertSame($row['institution_id'], $parent->institution_id, $table.'.'.$column.' tenant');
                    }
                }
            }
        }
        $this->assertDatabaseHas('institution_settings', ['institution_id' => $manifest['institutions']['target'], 'timezone' => 'Asia/Tashkent', 'student_submission_max_mb' => 2]);
        $this->assertDatabaseHas('institution_settings', ['institution_id' => $manifest['institutions']['foreign'], 'timezone' => 'Asia/Tashkent']);
        $this->assertSame(2, DB::table('group_student_memberships')->where('group_id', $manifest['groups']['main'])->whereNull('ended_at')->count());
        $historical = DB::table('group_student_memberships')->where('group_id', $manifest['groups']['historical'])->sole();
        $this->assertSame($manifest['users']['student'], $historical->student_id);
        $this->assertTrue(Carbon::parse($historical->started_at)->lt(Carbon::parse($manifest['timestamps']['activated'])));
        $this->assertTrue(Carbon::parse($historical->ended_at)->gt(Carbon::parse($manifest['timestamps']['activated'])));
        $this->assertDatabaseHas('assessment_students', ['assessment_id' => $manifest['homework']['historical'], 'student_id' => $manifest['users']['student']]);
    }

    public function test_main_official_homework_has_nine_safe_surfaces_frozen_recipients_and_no_initial_attempt(): void
    {
        (new Stage7E2eSeeder)->run();
        $manifest = Stage7E2eSeeder::manifest();
        $questions = DB::table('questions')->where('assessment_id', $manifest['homework']['main'])->orderBy('position')->get();
        $this->assertSame(Stage7E2eSeeder::QUESTION_TYPES, $questions->pluck('type')->all());
        $this->assertSame(range(1, 9), $questions->pluck('position')->all());
        $this->assertSame(3, DB::table('question_choice_options')->where('question_id', $manifest['questions']['main']['single_choice'])->count());
        $this->assertSame(2, DB::table('question_choice_options')->where('question_id', $manifest['questions']['main']['multiple_choice'])->where('is_correct', true)->count());
        $this->assertSame(4, DB::table('question_matching_items')->where('question_id', $manifest['questions']['main']['matching'])->count());
        $this->assertSame(3, DB::table('question_ordering_items')->where('question_id', $manifest['questions']['main']['ordering'])->count());
        $this->assertSame(2, DB::table('question_fill_blanks')->where('question_id', $manifest['questions']['main']['fill_in_blank'])->count());
        $this->assertEqualsCanonicalizing([$manifest['users']['student'], $manifest['users']['peer_student']],
            DB::table('assessment_students')->where('assessment_id', $manifest['homework']['main'])->where('assignment_source', 'group')->pluck('student_id')->all());
        $pair = DB::table('topic_result_pairs')->where('id', $manifest['pair'])->sole();
        $this->assertSame($manifest['homework']['main'], $pair->homework_assessment_id);
        $this->assertSame($manifest['topics']['main'], $pair->topic_id);
        $this->assertNull($pair->blitz_assessment_id);
        $this->assertNull($pair->locked_at);
        $this->assertTrue(Carbon::parse($pair->cohort_snapshotted_at)->equalTo(Carbon::parse($manifest['timestamps']['activated'])));
        foreach (['main', 'idempotency', 'android_smoke'] as $name) {
            $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => $manifest['homework'][$name]]);
            $homework = DB::table('homework_assignments')->where('assessment_id', $manifest['homework'][$name])->sole();
            $this->assertSame('active', $homework->status);
            $this->assertTrue(Carbon::parse($homework->deadline_at)->isFuture());
        }
    }

    public function test_four_lifecycle_fixtures_are_unconsumed_pending_and_preserve_never_started_peer(): void
    {
        (new Stage7E2eSeeder)->run();
        $manifest = Stage7E2eSeeder::manifest();
        $this->assertSame(4, DB::table('assessment_attempts')->whereIn('assessment_id', $manifest['homework'])->count());
        foreach (Stage7E2eSeeder::LIFECYCLE as $name) {
            $homework = DB::table('homework_assignments')->where('assessment_id', $manifest['homework'][$name])->sole();
            $attempt = DB::table('assessment_attempts')->where('id', $manifest['attempts'][$name])->sole();
            $this->assertSame('active', $homework->status);
            $this->assertSame($name === 'teacher_close', Carbon::parse($homework->deadline_at)->isFuture());
            $this->assertSame('in_progress', $attempt->status);
            $this->assertSame(1, $attempt->attempt_number);
            $this->assertSame($manifest['users']['student'], $attempt->student_id);
            $this->assertTrue(Carbon::parse($attempt->started_at)->lt(Carbon::parse($homework->deadline_at)));
            foreach (['submitted_at', 'finalized_at', 'locked_at', 'finalization_reason', 'earned_points', 'normalized_score', 'scoring_completed_at'] as $column) {
                $this->assertNull($attempt->{$column}, $name.'.'.$column);
            }
            $answer = DB::table('attempt_answers')->where('attempt_id', $attempt->id)->sole();
            $this->assertSame('pending', $answer->checking_status);
            foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $column) {
                $this->assertNull($answer->{$column});
            }
            $this->assertDatabaseHas('answer_text_values', ['answer_id' => $answer->id, 'text_value' => $manifest['saved_text']]);
            $this->assertDatabaseHas('assessment_students', ['assessment_id' => $homework->assessment_id, 'student_id' => $manifest['users']['peer_student']]);
            $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => $homework->assessment_id, 'student_id' => $manifest['users']['peer_student']]);
        }
    }

    public function test_cleanup_removes_dynamic_attempt_answer_token_idempotency_and_private_keys_but_preserves_sentinels(): void
    {
        $sentinel = $this->sentinel();
        $sentinelBefore = $sentinel->getAttributes();
        $disk = Storage::disk('stage7_seeder_test');
        $sentinelKey = 'student-submissions/'.$sentinel->id.'/unrelated.pdf';
        $disk->put($sentinelKey, 'E2E S07 unrelated private bytes');
        $seeder = new Stage7E2eSeeder;
        $seeder->run();
        $manifest = Stage7E2eSeeder::manifest();
        $student = User::query()->findOrFail($manifest['users']['student']);
        $attempt = app(StartStudentHomeworkAttempt::class)($student, $manifest['homework']['main'], Stage7E2eSeeder::id(7001));
        $student->createToken('E2E S07 cleanup test');
        app(SaveStudentHomeworkFileAnswer::class)($student, $attempt->attemptId, $manifest['questions']['main']['file_based'], UploadedFile::fake()->createWithContent('e2e_s07_answer.pdf', "%PDF-1.7\nE2E S07 saved bytes"));
        $state = $seeder->ownedState();
        $this->assertCount(5, $state['db']['assessment_attempts']);
        $this->assertCount(1, $state['db']['files']);
        $this->assertCount(1, $state['db']['idempotency_records']);
        $this->assertCount(1, $state['db']['personal_access_tokens']);
        $this->assertCount(1, $state['blobs']);
        $oldKey = $state['directories'][0]['key'].'/'.Stage7E2eSeeder::id(8001).'.pdf';
        $disk->put($oldKey, 'E2E S07 replacement predecessor bytes');
        $seeder->cleanupOwnedState();
        $seeder->cleanupOwnedState();
        $this->assertNoStaticRows();
        foreach (['assessment_attempts', 'attempt_answers', 'files', 'idempotency_records', 'personal_access_tokens'] as $table) {
            $this->assertSame(0, DB::table($table)->whereIn('id', $state['db'][$table])->count(), $table);
        }
        $this->assertSame(0, DB::table('answer_files')->whereIn('answer_id', $state['db']['attempt_answers'])->count());
        foreach ([...array_column($state['blobs'], 'key'), $oldKey] as $key) {
            $this->assertFalse($disk->exists($key));
        }
        $this->assertSame('E2E S07 unrelated private bytes', $disk->get($sentinelKey));
        $this->assertSame($sentinelBefore, $sentinel->fresh()->getAttributes());
        $seeder->run();
        $this->assertSame($sentinelBefore, $sentinel->fresh()->getAttributes());
        $this->assertSame('E2E S07 unrelated private bytes', $disk->get($sentinelKey));
    }

    public function test_cleanup_fails_closed_on_an_existing_manifest_id_with_an_unexpected_owner(): void
    {
        $seeder = new Stage7E2eSeeder;
        $seeder->run();
        $manifest = Stage7E2eSeeder::manifest();
        DB::table('users')->where('id', $manifest['users']['unassigned_student'])->update(['institution_id' => $manifest['institutions']['foreign']]);
        $before = $this->structuralSnapshot();
        try {
            $seeder->cleanupOwnedState();
            $this->fail('Cleanup accepted a foreign-owned manifest actor.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('ownership mismatch', $exception->getMessage());
        }
        $this->assertSame($before, $this->structuralSnapshot());
    }

    public function test_read_only_ownership_inspection_does_not_need_the_password(): void
    {
        $seeder = new Stage7E2eSeeder;
        $seeder->run();
        putenv('STAGE7_E2E_PASSWORD');
        $this->assertCount(4, $seeder->ownedState()['db']['assessment_attempts']);
    }

    private function sentinel(): Institution
    {
        return Institution::factory()->create(['id' => Stage7E2eSeeder::id(999999), 'name' => 'E2E S07 unrelated sentinel',
            'type' => 'school', 'contact_email' => null, 'contact_phone' => null, 'address' => null, 'description' => null])->fresh();
    }

    private function assertNoStaticRows(): void
    {
        foreach (Stage7E2eSeeder::manifest()['db'] as $table => $ids) {
            $this->assertSame(0, DB::table($table)->whereIn(Stage7E2eSeeder::PRIMARY_KEYS[$table] ?? 'id', $ids)->count(), $table);
        }
    }

    private function structuralSnapshot(): array
    {
        $snapshot = [];
        foreach (Stage7E2eSeeder::manifest()['db'] as $table => $ids) {
            $primaryKey = Stage7E2eSeeder::PRIMARY_KEYS[$table] ?? 'id';
            $snapshot[$table] = DB::table($table)->whereIn($primaryKey, $ids)->orderBy($primaryKey)->get()->map(function (object $row): array {
                $attributes = (array) $row;
                unset($attributes['password']);

                return $attributes;
            })->all();
        }

        return $snapshot;
    }
}
