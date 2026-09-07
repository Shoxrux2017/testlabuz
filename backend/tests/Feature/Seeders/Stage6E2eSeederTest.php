<?php

namespace Tests\Feature\Seeders;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Institution;
use App\Models\User;
use Database\Seeders\Stage6E2eSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use RuntimeException;
use Tests\TestCase;

class Stage6E2eSeederTest extends TestCase
{
    use RefreshDatabase;

    private const TARGET_INSTITUTION_ID = '06000000-0000-4000-8000-000000000101';

    private const FOREIGN_INSTITUTION_ID = '06000000-0000-4000-8000-000000000102';

    private const TARGET_TEACHER_ID = '06000000-0000-4000-9000-000000000201';

    private const STUDENT_ALPHA_ID = '06000000-0000-4000-9000-000000000301';

    private const STUDENT_BETA_ID = '06000000-0000-4000-9000-000000000302';

    private const STUDENT_ENDED_ID = '06000000-0000-4000-9000-000000000303';

    private const STUDENT_INACTIVE_ID = '06000000-0000-4000-9000-000000000304';

    private const FOREIGN_TEACHER_ID = '06000000-0000-4000-9000-000000000502';

    private const FOREIGN_STUDENT_ID = '06000000-0000-4000-9000-000000000503';

    private const MAIN_GROUP_ID = '06000000-0000-4000-a000-000000000101';

    private const AUTHORING_TOPIC_ID = '06000000-0000-4000-c000-000000000101';

    private const LOCKED_TOPIC_ID = '06000000-0000-4000-c000-000000000102';

    private const EXPIRED_TOPIC_ID = '06000000-0000-4000-c000-000000000103';

    private const FOREIGN_TOPIC_ID = '06000000-0000-4000-c000-000000000105';

    private const LOCKED_HOMEWORK_ID = '06000000-0000-4000-d000-000000000101';

    private const EXPIRED_HOMEWORK_ID = '06000000-0000-4000-d000-000000000103';

    private const FOREIGN_HOMEWORK_ID = '06000000-0000-4000-d000-000000000105';

    private const LOCKED_ALPHA_RECIPIENT_ID = '06000000-0000-4000-e000-000000000101';

    private const LOCKED_ATTEMPT_ID = '06000000-0000-4000-f000-000000000101';

    private const LOCKED_PAIR_ID = '06000000-0000-4000-f100-000000000101';

    private const DYNAMIC_MAIN_HOMEWORK_ID = '06000000-0000-4000-d000-000000000201';

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow('2026-09-07 08:00:00+00');
        $this->setPassword();
    }

    public function test_seeder_refuses_non_testing_wrong_driver_and_wrong_database_before_mutation(): void
    {
        $unrelated = Institution::factory()->create(['name' => 'Preserved Stage 6 runtime guard Institution']);
        $unsafeSeeders = [
            new class extends Stage6E2eSeeder
            {
                protected function runtimeEnvironment(): string
                {
                    return 'local';
                }
            },
            new class extends Stage6E2eSeeder
            {
                protected function connectionDriver(): string
                {
                    return 'sqlite';
                }
            },
            new class extends Stage6E2eSeeder
            {
                protected function pdoDriver(): string
                {
                    return 'mysql';
                }
            },
            new class extends Stage6E2eSeeder
            {
                protected function currentDatabase(): string
                {
                    return 'testlabuz';
                }
            },
        ];

        foreach ($unsafeSeeders as $seeder) {
            try {
                $seeder->run();
                self::fail('The Stage 6 E2E seeder accepted unsafe runtime facts.');
            } catch (RuntimeException) {
                $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
                $this->assertDatabaseMissing('institutions', ['id' => self::TARGET_INSTITUTION_ID]);
            }
        }
    }

    public function test_seeder_requires_a_non_blank_transient_password_before_mutation(): void
    {
        $this->clearPassword();

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('STAGE6_E2E_PASSWORD must be provided');

        (new Stage6E2eSeeder)->run();
    }

    public function test_seeder_creates_the_explicit_tenant_safe_stage_6_fixture_manifest(): void
    {
        (new Stage6E2eSeeder)->run();

        $this->assertDatabaseCount('institutions', 2);
        $this->assertDatabaseCount('users', 11);
        $this->assertDatabaseCount('groups', 3);
        $this->assertDatabaseCount('group_teacher_memberships', 3);
        $this->assertDatabaseCount('group_student_memberships', 6);
        $this->assertDatabaseCount('topics', 6);
        $this->assertDatabaseCount('assessments', 5);
        $this->assertDatabaseCount('homework_assignments', 5);
        $this->assertDatabaseCount('questions', 3);
        $this->assertDatabaseCount('question_true_false_answers', 3);
        $this->assertDatabaseCount('assessment_students', 3);
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('topic_result_pairs', 1);

        $this->assertDatabaseHas('institutions', [
            'id' => self::TARGET_INSTITUTION_ID,
            'name' => 'E2E S06 Target Institution',
        ]);
        $this->assertDatabaseHas('institutions', [
            'id' => self::FOREIGN_INSTITUTION_ID,
            'name' => 'E2E S06 Foreign Institution',
        ]);
        foreach ([self::TARGET_INSTITUTION_ID, self::FOREIGN_INSTITUTION_ID] as $institutionId) {
            $this->assertDatabaseHas('institution_settings', [
                'institution_id' => $institutionId,
                'timezone' => 'Asia/Tashkent',
            ]);
        }
        self::assertTrue(Hash::check($this->password(), User::query()->findOrFail(self::TARGET_TEACHER_ID)->password));
        self::assertFalse(User::query()->findOrFail(self::STUDENT_INACTIVE_ID)->is_active);

        $currentStudents = DB::table('group_student_memberships')
            ->where('group_id', self::MAIN_GROUP_ID)
            ->whereNull('ended_at')
            ->orderBy('student_id')
            ->pluck('student_id')
            ->all();
        self::assertSame([
            self::STUDENT_ALPHA_ID,
            self::STUDENT_BETA_ID,
            self::STUDENT_INACTIVE_ID,
        ], $currentStudents);
        $this->assertDatabaseHas('group_student_memberships', [
            'group_id' => self::MAIN_GROUP_ID,
            'student_id' => self::STUDENT_ENDED_ID,
        ]);
        self::assertNotNull(DB::table('group_student_memberships')
            ->where('group_id', self::MAIN_GROUP_ID)
            ->where('student_id', self::STUDENT_ENDED_ID)
            ->value('ended_at'));

        $topics = DB::table('topics')->where('title', 'like', 'E2E S06%')->get();
        self::assertCount(6, $topics);
        foreach ($topics as $topic) {
            self::assertSame(TopicStatus::Active->value, $topic->status);
            self::assertNotNull($topic->activated_at);
            self::assertNull($topic->closed_at);
            self::assertNull($topic->archived_at);
        }
        $this->assertDatabaseMissing('assessments', ['topic_id' => self::AUTHORING_TOPIC_ID]);

        $pair = DB::table('topic_result_pairs')->where('id', self::LOCKED_PAIR_ID)->sole();
        self::assertSame(self::LOCKED_TOPIC_ID, $pair->topic_id);
        self::assertSame(self::LOCKED_HOMEWORK_ID, $pair->homework_assessment_id);
        self::assertNull($pair->blitz_assessment_id);
        self::assertNotNull($pair->cohort_snapshotted_at);
        self::assertNotNull($pair->locked_at);

        $lockedRecipients = DB::table('assessment_students')
            ->where('assessment_id', self::LOCKED_HOMEWORK_ID)
            ->orderBy('student_id')
            ->get();
        self::assertSame([self::STUDENT_ALPHA_ID, self::STUDENT_BETA_ID], $lockedRecipients->pluck('student_id')->all());
        self::assertSame(['group', 'group'], $lockedRecipients->pluck('assignment_source')->all());

        $attempt = DB::table('assessment_attempts')->where('id', self::LOCKED_ATTEMPT_ID)->sole();
        self::assertSame(self::LOCKED_ALPHA_RECIPIENT_ID, $attempt->assessment_student_id);
        self::assertSame(self::STUDENT_ALPHA_ID, $attempt->student_id);
        self::assertSame(1, $attempt->attempt_number);
        self::assertSame(AssessmentAttemptStatus::InProgress->value, $attempt->status);
        self::assertTrue($attempt->official_score_eligible);
        self::assertSame('1.000000', $attempt->possible_points);
        self::assertNull($attempt->submitted_at);
        self::assertNull($attempt->finalized_at);
        self::assertNull($attempt->finalization_reason);

        $expired = DB::table('homework_assignments')->where('assessment_id', self::EXPIRED_HOMEWORK_ID)->sole();
        self::assertSame(HomeworkStatus::Draft->value, $expired->status);
        self::assertTrue(Carbon::parse($expired->deadline_at)->isPast());
        $this->assertDatabaseMissing('assessment_students', ['assessment_id' => self::EXPIRED_HOMEWORK_ID]);
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => self::EXPIRED_HOMEWORK_ID]);
        $this->assertDatabaseHas('questions', [
            'assessment_id' => self::EXPIRED_HOMEWORK_ID,
            'type' => 'true_false',
            'points' => '1.000000',
        ]);

        $foreign = DB::table('assessments')->where('id', self::FOREIGN_HOMEWORK_ID)->sole();
        self::assertSame(self::FOREIGN_INSTITUTION_ID, $foreign->institution_id);
        self::assertSame(self::FOREIGN_TOPIC_ID, $foreign->topic_id);
        self::assertSame(self::FOREIGN_TEACHER_ID, $foreign->teacher_id);
        $this->assertDatabaseHas('users', [
            'id' => self::FOREIGN_STUDENT_ID,
            'institution_id' => self::FOREIGN_INSTITUTION_ID,
        ]);
        $this->assertDatabaseMissing('assessment_students', [
            'assessment_id' => self::FOREIGN_HOMEWORK_ID,
            'institution_id' => self::TARGET_INSTITUTION_ID,
        ]);
    }

    public function test_two_runs_are_logically_identical_and_preserve_unrelated_rows_and_tokens(): void
    {
        $unrelatedInstitution = Institution::factory()->create(['name' => 'Unrelated Stage 6 sentinel Institution']);
        $unrelatedUser = User::factory()->teacher($unrelatedInstitution)->create(['must_change_password' => false]);
        $unrelatedTokenId = $unrelatedUser->createToken('unrelated-stage6-token')->accessToken->id;
        $beforeUnrelated = $this->unrelatedSnapshot($unrelatedInstitution->id, $unrelatedUser->id, $unrelatedTokenId);

        (new Stage6E2eSeeder)->run();
        $ownedUser = User::query()->findOrFail(self::TARGET_TEACHER_ID);
        $ownedTokenId = $ownedUser->createToken('owned-stage6-token')->accessToken->id;
        $first = $this->logicalSnapshot();

        (new Stage6E2eSeeder)->run();
        $second = $this->logicalSnapshot();

        self::assertSame($first, $second);
        self::assertSame($beforeUnrelated, $this->unrelatedSnapshot(
            $unrelatedInstitution->id,
            $unrelatedUser->id,
            $unrelatedTokenId,
        ));
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $ownedTokenId]);
        $this->assertDatabaseHas('personal_access_tokens', ['id' => $unrelatedTokenId]);
    }

    public function test_seeder_resets_completed_authoring_state_and_preserves_unrelated_rows(): void
    {
        $unrelatedInstitution = Institution::factory()->create(['name' => 'Unrelated Stage 6 completed-run sentinel']);
        $unrelatedBefore = DB::table('institutions')->where('id', $unrelatedInstitution->id)->sole();

        (new Stage6E2eSeeder)->run();

        $transitionedAt = now();
        DB::table('topics')->where('id', self::AUTHORING_TOPIC_ID)->update([
            'status' => TopicStatus::Closed->value,
            'closed_at' => $transitionedAt,
            'updated_at' => $transitionedAt,
        ]);
        DB::table('assessments')->insert([
            'id' => self::DYNAMIC_MAIN_HOMEWORK_ID,
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'topic_id' => self::AUTHORING_TOPIC_ID,
            'teacher_id' => self::TARGET_TEACHER_ID,
            'type' => 'homework',
            'title' => 'E2E S06 Official Homework',
            'description' => 'E2E S06 official draft description',
            'student_instructions' => 'Complete every question carefully.',
            'assignment_mode' => 'group',
            'total_possible_points' => '20.500000',
            'created_at' => $transitionedAt->copy()->subMinutes(3),
            'updated_at' => $transitionedAt,
        ]);
        DB::table('homework_assignments')->insert([
            'assessment_id' => self::DYNAMIC_MAIN_HOMEWORK_ID,
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'status' => HomeworkStatus::Archived->value,
            'deadline_at' => '2035-06-15 13:00:00+00',
            'activated_at' => $transitionedAt->copy()->subMinutes(2),
            'closed_at' => $transitionedAt->copy()->subMinute(),
            'archived_at' => $transitionedAt,
            'created_at' => $transitionedAt->copy()->subMinutes(3),
            'updated_at' => $transitionedAt,
        ]);

        (new Stage6E2eSeeder)->run();

        $authoringTopic = DB::table('topics')->where('id', self::AUTHORING_TOPIC_ID)->sole();
        self::assertSame(TopicStatus::Active->value, $authoringTopic->status);
        self::assertNotNull($authoringTopic->activated_at);
        self::assertNull($authoringTopic->closed_at);
        self::assertNull($authoringTopic->archived_at);
        $this->assertDatabaseMissing('assessments', ['id' => self::DYNAMIC_MAIN_HOMEWORK_ID]);
        $this->assertDatabaseMissing('homework_assignments', ['assessment_id' => self::DYNAMIC_MAIN_HOMEWORK_ID]);
        self::assertEquals(
            $unrelatedBefore,
            DB::table('institutions')->where('id', $unrelatedInstitution->id)->sole(),
        );
    }

    public function test_seeder_does_not_accept_closed_lifecycle_for_other_owned_topics(): void
    {
        (new Stage6E2eSeeder)->run();

        $transitionedAt = now();
        DB::table('topics')->where('id', self::LOCKED_TOPIC_ID)->update([
            'status' => TopicStatus::Closed->value,
            'closed_at' => $transitionedAt,
            'updated_at' => $transitionedAt,
        ]);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Stage 6 E2E Topic manifest collision detected.');

        (new Stage6E2eSeeder)->run();
    }

    protected function tearDown(): void
    {
        $this->clearPassword();
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function logicalSnapshot(): string
    {
        $institutionIds = [self::TARGET_INSTITUTION_ID, self::FOREIGN_INSTITUTION_ID];

        return json_encode([
            'institutions' => DB::table('institutions')->whereIn('id', $institutionIds)->orderBy('id')->get(),
            'settings' => DB::table('institution_settings')->whereIn('institution_id', $institutionIds)->orderBy('institution_id')->get(),
            'users' => DB::table('users')->where('login_name', 'like', 'e2e_s06_%')->select([
                'id', 'institution_id', 'role', 'full_name', 'login_name', 'email', 'phone', 'is_active',
                'must_change_password', 'last_login_at', 'deactivated_at', 'created_by_user_id', 'created_at', 'updated_at',
            ])->orderBy('id')->get(),
            'groups' => DB::table('groups')->whereIn('institution_id', $institutionIds)->where('name', 'like', 'E2E S06%')->orderBy('id')->get(),
            'teacher_memberships' => DB::table('group_teacher_memberships')->where('id', 'like', '06000000-%')->orderBy('id')->get(),
            'student_memberships' => DB::table('group_student_memberships')->where('id', 'like', '06000000-%')->orderBy('id')->get(),
            'topics' => DB::table('topics')->where('title', 'like', 'E2E S06%')->orderBy('id')->get(),
            'assessments' => DB::table('assessments')->whereIn('institution_id', $institutionIds)->where('title', 'like', 'E2E S06%')->orderBy('id')->get(),
            'homework' => DB::table('homework_assignments')->whereIn('institution_id', $institutionIds)->orderBy('assessment_id')->get(),
            'recipients' => DB::table('assessment_students')->whereIn('institution_id', $institutionIds)->orderBy('id')->get(),
            'attempts' => DB::table('assessment_attempts')->whereIn('institution_id', $institutionIds)->orderBy('id')->get(),
            'pairs' => DB::table('topic_result_pairs')->whereIn('institution_id', $institutionIds)->orderBy('id')->get(),
            'questions' => DB::table('questions')->whereIn('institution_id', $institutionIds)->orderBy('id')->get(),
            'true_false' => DB::table('question_true_false_answers')->whereIn('institution_id', $institutionIds)->orderBy('question_id')->get(),
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
    }

    private function unrelatedSnapshot(string $institutionId, string $userId, int|string $tokenId): string
    {
        return json_encode([
            'institution' => DB::table('institutions')->where('id', $institutionId)->first(),
            'user' => DB::table('users')->where('id', $userId)->first(),
            'token' => DB::table('personal_access_tokens')->where('id', $tokenId)->first(),
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
    }

    private function setPassword(): void
    {
        $password = $this->password();
        putenv('STAGE6_E2E_PASSWORD='.$password);
        $_ENV['STAGE6_E2E_PASSWORD'] = $password;
        $_SERVER['STAGE6_E2E_PASSWORD'] = $password;
    }

    private function clearPassword(): void
    {
        putenv('STAGE6_E2E_PASSWORD');
        unset($_ENV['STAGE6_E2E_PASSWORD'], $_SERVER['STAGE6_E2E_PASSWORD']);
    }

    private function password(): string
    {
        return 'S06-Test-Aa9-Deterministic-Password';
    }
}
