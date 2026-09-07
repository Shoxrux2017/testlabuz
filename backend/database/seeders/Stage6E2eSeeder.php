<?php

namespace Database\Seeders;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\GroupStatus;
use App\Enums\HomeworkStatus;
use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

class Stage6E2eSeeder extends Seeder
{
    private const TEST_DATABASE = 'testlabuz_testing';

    private const PASSWORD_ENVIRONMENT_NAME = 'STAGE6_E2E_PASSWORD';

    private const TARGET_INSTITUTION_ID = '06000000-0000-4000-8000-000000000101';

    private const FOREIGN_INSTITUTION_ID = '06000000-0000-4000-8000-000000000102';

    private const TARGET_ADMIN_ID = '06000000-0000-4000-9000-000000000101';

    private const TARGET_TEACHER_ID = '06000000-0000-4000-9000-000000000201';

    private const STUDENT_ALPHA_ID = '06000000-0000-4000-9000-000000000301';

    private const STUDENT_BETA_ID = '06000000-0000-4000-9000-000000000302';

    private const STUDENT_ENDED_ID = '06000000-0000-4000-9000-000000000303';

    private const STUDENT_INACTIVE_ID = '06000000-0000-4000-9000-000000000304';

    private const UNRELATED_TEACHER_ID = '06000000-0000-4000-9000-000000000401';

    private const UNRELATED_STUDENT_ID = '06000000-0000-4000-9000-000000000402';

    private const FOREIGN_ADMIN_ID = '06000000-0000-4000-9000-000000000501';

    private const FOREIGN_TEACHER_ID = '06000000-0000-4000-9000-000000000502';

    private const FOREIGN_STUDENT_ID = '06000000-0000-4000-9000-000000000503';

    private const MAIN_GROUP_ID = '06000000-0000-4000-a000-000000000101';

    private const UNRELATED_GROUP_ID = '06000000-0000-4000-a000-000000000102';

    private const FOREIGN_GROUP_ID = '06000000-0000-4000-a000-000000000103';

    private const AUTHORING_TOPIC_ID = '06000000-0000-4000-c000-000000000101';

    private const LOCKED_TOPIC_ID = '06000000-0000-4000-c000-000000000102';

    private const EXPIRED_TOPIC_ID = '06000000-0000-4000-c000-000000000103';

    private const UNRELATED_TOPIC_ID = '06000000-0000-4000-c000-000000000104';

    private const FOREIGN_TOPIC_ID = '06000000-0000-4000-c000-000000000105';

    private const SECURITY_TOPIC_ID = '06000000-0000-4000-c000-000000000106';

    private const LOCKED_HOMEWORK_ID = '06000000-0000-4000-d000-000000000101';

    private const LOCKED_REPLACEMENT_ID = '06000000-0000-4000-d000-000000000102';

    private const EXPIRED_HOMEWORK_ID = '06000000-0000-4000-d000-000000000103';

    private const SECURITY_SELECTED_ID = '06000000-0000-4000-d000-000000000104';

    private const FOREIGN_HOMEWORK_ID = '06000000-0000-4000-d000-000000000105';

    private const LOCKED_ALPHA_RECIPIENT_ID = '06000000-0000-4000-e000-000000000101';

    private const LOCKED_BETA_RECIPIENT_ID = '06000000-0000-4000-e000-000000000102';

    private const SECURITY_ALPHA_RECIPIENT_ID = '06000000-0000-4000-e000-000000000103';

    private const LOCKED_ATTEMPT_ID = '06000000-0000-4000-f000-000000000101';

    private const LOCKED_PAIR_ID = '06000000-0000-4000-f100-000000000101';

    private const LOCKED_QUESTION_ID = '06000000-0000-4000-6100-000000000101';

    private const EXPIRED_QUESTION_ID = '06000000-0000-4000-6100-000000000102';

    private const FOREIGN_QUESTION_ID = '06000000-0000-4000-6100-000000000103';

    private const DYNAMIC_HOMEWORK_TITLES = [
        'E2E S06 Official Homework',
        'E2E S06 Selected Practice Homework',
        'E2E S06 Manual Smoke Homework',
    ];

    public function run(): void
    {
        $this->assertSafeRuntime();
        $password = $this->requiredPassword();
        $ownership = $this->assertOwnershipGraphSafe();

        DB::transaction(function () use ($ownership, $password): void {
            $this->resetOwnedRows($ownership);
            $this->createManifest($password);
        });
    }

    protected function runtimeEnvironment(): string
    {
        return app()->environment();
    }

    protected function currentDatabase(): string
    {
        return (string) DB::scalar('select current_database()');
    }

    protected function connectionDriver(): string
    {
        return DB::connection()->getDriverName();
    }

    protected function pdoDriver(): string
    {
        return (string) DB::connection()->getPdo()->getAttribute(\PDO::ATTR_DRIVER_NAME);
    }

    private function assertSafeRuntime(): void
    {
        if ($this->runtimeEnvironment() !== 'testing') {
            throw new RuntimeException('Stage6E2eSeeder may only run with APP_ENV=testing.');
        }
        if ($this->connectionDriver() !== 'pgsql' || $this->pdoDriver() !== 'pgsql') {
            throw new RuntimeException('Stage6E2eSeeder requires Laravel pgsql and PDO pgsql.');
        }
        if ($this->currentDatabase() !== self::TEST_DATABASE) {
            throw new RuntimeException('Stage6E2eSeeder may only run against testlabuz_testing.');
        }
    }

    private function requiredPassword(): string
    {
        $password = env(self::PASSWORD_ENVIRONMENT_NAME);
        if (! is_string($password) || trim($password) === '') {
            throw new RuntimeException(self::PASSWORD_ENVIRONMENT_NAME.' must be provided by the local environment.');
        }

        return $password;
    }

    /**
     * @return array{assessment_ids: list<string>, question_ids: list<string>, blank_ids: list<string>, pair_ids: list<string>, recipient_ids: list<string>, attempt_ids: list<string>}
     */
    private function assertOwnershipGraphSafe(): array
    {
        $this->assertInstitutionManifestSafe();
        $this->assertUserManifestSafe();
        $this->assertSettingManifestSafe();
        $this->assertGroupManifestSafe();
        $this->assertMembershipManifestSafe();
        $this->assertTopicManifestSafe();

        return $this->assertAssessmentGraphSafe();
    }

    private function assertInstitutionManifestSafe(): void
    {
        $manifest = $this->institutionManifest();
        $rows = Institution::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('name', array_column($manifest, 'name'))
            ->orWhere('name', 'like', 'E2E S06%')
            ->get();

        foreach ($rows as $institution) {
            $expected = $manifest[$institution->id] ?? null;
            if ($expected === null
                || $institution->name !== $expected['name']
                || $institution->type->value !== $expected['type']
                || $institution->status !== InstitutionStatus::Active) {
                throw new RuntimeException('Stage 6 E2E Institution manifest collision detected.');
            }
        }
    }

    private function assertUserManifestSafe(): void
    {
        $manifest = $this->userManifest();
        $rows = User::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('login_name', array_column($manifest, 'login_name'))
            ->orWhere('login_name', 'like', 'e2e_s06_%')
            ->orWhere('full_name', 'like', 'E2E S06%')
            ->get();

        foreach ($rows as $user) {
            $expected = $manifest[$user->id] ?? null;
            if ($expected === null
                || $user->login_name !== $expected['login_name']
                || $user->full_name !== $expected['full_name']
                || $user->role->value !== $expected['role']
                || $user->institution_id !== $expected['institution_id']
                || $user->is_active !== $expected['active']
                || $user->must_change_password) {
                throw new RuntimeException('Stage 6 E2E User manifest collision detected.');
            }
        }
    }

    private function assertSettingManifestSafe(): void
    {
        foreach (InstitutionSetting::query()->whereIn('institution_id', array_keys($this->institutionManifest()))->get() as $setting) {
            if ($setting->timezone !== 'Asia/Tashkent'
                || $setting->learning_material_max_mb !== 25
                || $setting->student_submission_max_mb !== 15
                || $setting->acceptable_score_difference !== null
                || $setting->blitz_timer_start_mode !== null
                || $setting->student_result_release_mode !== null
                || $setting->parent_result_release_mode !== null
                || $setting->updated_by_user_id !== null) {
                throw new RuntimeException('Stage 6 E2E Institution setting manifest collision detected.');
            }
        }
    }

    private function assertGroupManifestSafe(): void
    {
        $manifest = $this->groupManifest();
        $rows = Group::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('name', array_column($manifest, 'name'))
            ->orWhere('name', 'like', 'E2E S06%')
            ->orWhereIn('created_by_user_id', [self::TARGET_ADMIN_ID, self::FOREIGN_ADMIN_ID])
            ->get();

        foreach ($rows as $group) {
            $expected = $manifest[$group->id] ?? null;
            if ($expected === null
                || $group->name !== $expected['name']
                || $group->institution_id !== $expected['institution_id']
                || $group->created_by_user_id !== $expected['created_by_user_id']
                || $group->status !== GroupStatus::Active) {
                throw new RuntimeException('Stage 6 E2E Group manifest collision detected.');
            }
        }
    }

    private function assertMembershipManifestSafe(): void
    {
        $teacherManifest = $this->teacherMembershipManifest();
        $teacherRows = GroupTeacherMembership::query()
            ->whereIn('id', array_keys($teacherManifest))
            ->orWhereIn('group_id', array_keys($this->groupManifest()))
            ->orWhereIn('teacher_id', [self::TARGET_TEACHER_ID, self::UNRELATED_TEACHER_ID, self::FOREIGN_TEACHER_ID])
            ->get();
        foreach ($teacherRows as $membership) {
            $expected = $teacherManifest[$membership->id] ?? null;
            if ($expected === null || ! $this->membershipMatches($membership, $expected, 'teacher_id')) {
                throw new RuntimeException('Stage 6 E2E Teacher membership manifest collision detected.');
            }
        }

        $studentManifest = $this->studentMembershipManifest();
        $studentRows = GroupStudentMembership::query()
            ->whereIn('id', array_keys($studentManifest))
            ->orWhereIn('group_id', array_keys($this->groupManifest()))
            ->orWhereIn('student_id', [
                self::STUDENT_ALPHA_ID,
                self::STUDENT_BETA_ID,
                self::STUDENT_ENDED_ID,
                self::STUDENT_INACTIVE_ID,
                self::UNRELATED_STUDENT_ID,
                self::FOREIGN_STUDENT_ID,
            ])
            ->get();
        foreach ($studentRows as $membership) {
            $expected = $studentManifest[$membership->id] ?? null;
            if ($expected === null || ! $this->membershipMatches($membership, $expected, 'student_id')) {
                throw new RuntimeException('Stage 6 E2E Student membership manifest collision detected.');
            }
        }
    }

    /** @param array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool} $expected */
    private function membershipMatches(object $membership, array $expected, string $memberColumn): bool
    {
        return $membership->institution_id === $expected['institution_id']
            && $membership->group_id === $expected['group_id']
            && $membership->{$memberColumn} === $expected['member_id']
            && $membership->assigned_by_user_id === $expected['actor_id']
            && ($membership->ended_at !== null) === $expected['ended'];
    }

    private function assertTopicManifestSafe(): void
    {
        $manifest = $this->topicManifest();
        $rows = Topic::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('title', array_column($manifest, 'title'))
            ->orWhere('title', 'like', 'E2E S06%')
            ->orWhereIn('group_id', array_keys($this->groupManifest()))
            ->get();

        foreach ($rows as $topic) {
            $expected = $manifest[$topic->id] ?? null;
            if ($expected === null
                || $topic->institution_id !== $expected['institution_id']
                || $topic->group_id !== $expected['group_id']
                || $topic->teacher_id !== $expected['teacher_id']
                || $topic->title !== $expected['title']
                || $topic->status !== TopicStatus::Active
                || $topic->activated_at === null
                || $topic->closed_at !== null
                || $topic->archived_at !== null) {
                throw new RuntimeException('Stage 6 E2E Topic manifest collision detected.');
            }
        }
    }

    /**
     * @return array{assessment_ids: list<string>, question_ids: list<string>, blank_ids: list<string>, pair_ids: list<string>, recipient_ids: list<string>, attempt_ids: list<string>}
     */
    private function assertAssessmentGraphSafe(): array
    {
        $fixed = $this->assessmentManifest();
        $topicIds = array_keys($this->topicManifest());
        $rows = Assessment::query()
            ->whereIn('id', array_keys($fixed))
            ->orWhereIn('topic_id', $topicIds)
            ->orWhere('title', 'like', 'E2E S06%')
            ->get();
        $assessmentIds = [];

        foreach ($rows as $assessment) {
            $expected = $fixed[$assessment->id] ?? null;
            if ($expected !== null) {
                if (! $this->assessmentMatches($assessment, $expected)) {
                    throw new RuntimeException('Stage 6 E2E Assessment manifest collision detected.');
                }
            } elseif (! $this->dynamicAssessmentMatches($assessment)) {
                throw new RuntimeException('Stage 6 E2E dynamic Homework ownership collision detected.');
            }
            $assessmentIds[] = $assessment->id;
        }

        $questionIds = Question::query()
            ->whereIn('assessment_id', $assessmentIds)
            ->orWhereIn('id', array_keys($this->questionManifest()))
            ->pluck('id')
            ->all();
        $blankIds = DB::table('question_fill_blanks')->whereIn('question_id', $questionIds)->pluck('id')->all();
        $pairIds = TopicResultPair::query()
            ->whereIn('topic_id', $topicIds)
            ->orWhere('id', self::LOCKED_PAIR_ID)
            ->pluck('id')
            ->all();
        $recipientIds = AssessmentStudent::query()
            ->whereIn('assessment_id', $assessmentIds)
            ->orWhereIn('id', array_keys($this->recipientManifest()))
            ->pluck('id')
            ->all();
        $attemptIds = AssessmentAttempt::query()
            ->whereIn('assessment_id', $assessmentIds)
            ->orWhere('id', self::LOCKED_ATTEMPT_ID)
            ->pluck('id')
            ->all();

        $this->assertFixedHomeworkShapesSafe();
        $this->assertFixedQuestionShapesSafe();
        $this->assertFixedRecipientAttemptPairShapesSafe();

        return [
            'assessment_ids' => array_values($assessmentIds),
            'question_ids' => array_values($questionIds),
            'blank_ids' => array_values($blankIds),
            'pair_ids' => array_values($pairIds),
            'recipient_ids' => array_values($recipientIds),
            'attempt_ids' => array_values($attemptIds),
        ];
    }

    /** @param array{institution_id: string, topic_id: string, teacher_id: string, title: string, assignment_mode: string, total: string} $expected */
    private function assessmentMatches(Assessment $assessment, array $expected): bool
    {
        return $assessment->institution_id === $expected['institution_id']
            && $assessment->topic_id === $expected['topic_id']
            && $assessment->teacher_id === $expected['teacher_id']
            && $assessment->type === AssessmentType::Homework
            && $assessment->title === $expected['title']
            && $assessment->assignment_mode->value === $expected['assignment_mode']
            && $assessment->total_possible_points === $expected['total'];
    }

    private function dynamicAssessmentMatches(Assessment $assessment): bool
    {
        return $assessment->institution_id === self::TARGET_INSTITUTION_ID
            && $assessment->topic_id === self::AUTHORING_TOPIC_ID
            && $assessment->teacher_id === self::TARGET_TEACHER_ID
            && $assessment->type === AssessmentType::Homework
            && in_array($assessment->title, self::DYNAMIC_HOMEWORK_TITLES, true);
    }

    private function assertFixedHomeworkShapesSafe(): void
    {
        $expected = [
            self::LOCKED_HOMEWORK_ID => HomeworkStatus::Active,
            self::LOCKED_REPLACEMENT_ID => HomeworkStatus::Draft,
            self::EXPIRED_HOMEWORK_ID => HomeworkStatus::Draft,
            self::SECURITY_SELECTED_ID => HomeworkStatus::Draft,
            self::FOREIGN_HOMEWORK_ID => HomeworkStatus::Draft,
        ];
        foreach (HomeworkAssignment::query()->whereIn('assessment_id', array_keys($expected))->get() as $homework) {
            if ($homework->status !== $expected[$homework->assessment_id]) {
                throw new RuntimeException('Stage 6 E2E Homework lifecycle manifest collision detected.');
            }
        }
    }

    private function assertFixedQuestionShapesSafe(): void
    {
        $manifest = $this->questionManifest();
        foreach (Question::query()->whereIn('id', array_keys($manifest))->get() as $question) {
            $expected = $manifest[$question->id];
            if ($question->institution_id !== $expected['institution_id']
                || $question->assessment_id !== $expected['assessment_id']
                || $question->type !== QuestionType::TrueFalse
                || $question->checking_mode !== QuestionCheckingMode::Automatic
                || $question->prompt !== $expected['prompt']
                || $question->points !== '1.000000'
                || $question->position !== 1) {
                throw new RuntimeException('Stage 6 E2E Question manifest collision detected.');
            }
        }
    }

    private function assertFixedRecipientAttemptPairShapesSafe(): void
    {
        $recipientManifest = $this->recipientManifest();
        foreach (AssessmentStudent::query()->whereIn('id', array_keys($recipientManifest))->get() as $recipient) {
            $expected = $recipientManifest[$recipient->id];
            if ($recipient->institution_id !== self::TARGET_INSTITUTION_ID
                || $recipient->assessment_id !== $expected['assessment_id']
                || $recipient->student_id !== $expected['student_id']
                || $recipient->assignment_source->value !== $expected['source']
                || $recipient->assigned_by_user_id !== self::TARGET_TEACHER_ID) {
                throw new RuntimeException('Stage 6 E2E recipient manifest collision detected.');
            }
        }

        if (($attempt = AssessmentAttempt::query()->find(self::LOCKED_ATTEMPT_ID)) !== null
            && ($attempt->institution_id !== self::TARGET_INSTITUTION_ID
                || $attempt->assessment_id !== self::LOCKED_HOMEWORK_ID
                || $attempt->assessment_student_id !== self::LOCKED_ALPHA_RECIPIENT_ID
                || $attempt->student_id !== self::STUDENT_ALPHA_ID
                || $attempt->attempt_number !== 1
                || $attempt->status !== AssessmentAttemptStatus::InProgress)) {
            throw new RuntimeException('Stage 6 E2E Attempt manifest collision detected.');
        }

        if (($pair = TopicResultPair::query()->find(self::LOCKED_PAIR_ID)) !== null
            && ($pair->institution_id !== self::TARGET_INSTITUTION_ID
                || $pair->topic_id !== self::LOCKED_TOPIC_ID
                || $pair->homework_assessment_id !== self::LOCKED_HOMEWORK_ID
                || $pair->blitz_assessment_id !== null
                || $pair->cohort_snapshotted_at === null
                || $pair->locked_at === null)) {
            throw new RuntimeException('Stage 6 E2E result-pair manifest collision detected.');
        }
    }

    /**
     * @param  array{assessment_ids: list<string>, question_ids: list<string>, blank_ids: list<string>, pair_ids: list<string>, recipient_ids: list<string>, attempt_ids: list<string>}  $ownership
     */
    private function resetOwnedRows(array $ownership): void
    {
        DB::table('question_fill_blank_accepted_answers')->whereIn('blank_id', $ownership['blank_ids'])->delete();
        DB::table('question_fill_blanks')->whereIn('id', $ownership['blank_ids'])->delete();
        foreach (['question_ordering_items', 'question_matching_items', 'question_short_accepted_answers', 'question_true_false_answers', 'question_choice_options'] as $table) {
            DB::table($table)->whereIn('question_id', $ownership['question_ids'])->delete();
        }
        Question::query()->whereIn('id', $ownership['question_ids'])->delete();
        TopicResultPair::query()->whereIn('id', $ownership['pair_ids'])->delete();
        AssessmentAttempt::query()->whereIn('id', $ownership['attempt_ids'])->delete();
        AssessmentStudent::query()->whereIn('id', $ownership['recipient_ids'])->delete();
        HomeworkAssignment::query()->whereIn('assessment_id', $ownership['assessment_ids'])->delete();
        Assessment::query()->whereIn('id', $ownership['assessment_ids'])->delete();
        Topic::query()->whereIn('id', array_keys($this->topicManifest()))->delete();
        GroupTeacherMembership::query()->whereIn('id', array_keys($this->teacherMembershipManifest()))->delete();
        GroupStudentMembership::query()->whereIn('id', array_keys($this->studentMembershipManifest()))->delete();
        Group::query()->whereIn('id', array_keys($this->groupManifest()))->delete();
        DB::table('personal_access_tokens')
            ->where('tokenable_type', User::class)
            ->whereIn('tokenable_id', array_keys($this->userManifest()))
            ->delete();
        InstitutionSetting::query()->whereIn('institution_id', array_keys($this->institutionManifest()))->delete();
        User::query()->whereIn('id', array_keys($this->userManifest()))->delete();
        Institution::query()->whereIn('id', array_keys($this->institutionManifest()))->delete();
    }

    private function createManifest(string $password): void
    {
        Model::unguarded(function () use ($password): void {
            $this->createInstitutions();
            $this->createUsers($password);
            $this->createSettings();
            $this->createGroups();
            $this->createMemberships();
            $this->createTopics();
            $this->createAssessments();
            $this->createQuestions();
            $this->createRecipientsAttemptAndPair();
        });
    }

    private function createInstitutions(): void
    {
        $createdAt = Carbon::parse('2020-06-01 08:00:00+00');
        foreach ($this->institutionManifest() as $id => $specification) {
            Institution::query()->create([
                'id' => $id,
                'name' => $specification['name'],
                'type' => $specification['type'],
                'status' => InstitutionStatus::Active,
                'contact_email' => $specification['key'].'@e2e-s06.invalid',
                'contact_phone' => '+998906'.substr(str_replace('-', '', $id), -6),
                'address' => 'E2E S06 deterministic '.$specification['key'].' address',
                'description' => 'E2E S06 deterministic '.$specification['key'].' Institution.',
                'created_by_user_id' => null,
                'deactivated_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createUsers(string $password): void
    {
        $createdAt = Carbon::parse('2020-06-01 09:00:00+00');
        foreach ($this->userManifest() as $id => $specification) {
            User::query()->create([
                'id' => $id,
                'institution_id' => $specification['institution_id'],
                'role' => $specification['role'],
                'full_name' => $specification['full_name'],
                'login_name' => $specification['login_name'],
                'email' => $specification['login_name'].'@e2e-s06.invalid',
                'phone' => '+998906'.substr(str_replace('-', '', $id), -6),
                'password' => Hash::make($password),
                'is_active' => $specification['active'],
                'must_change_password' => false,
                'last_login_at' => null,
                'deactivated_at' => $specification['active'] ? null : $createdAt->copy()->addMinute(),
                'created_by_user_id' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createSettings(): void
    {
        $createdAt = Carbon::parse('2020-06-01 11:00:00+00');
        foreach (array_keys($this->institutionManifest()) as $institutionId) {
            InstitutionSetting::query()->create([
                'institution_id' => $institutionId,
                'acceptable_score_difference' => null,
                'blitz_timer_start_mode' => null,
                'student_result_release_mode' => null,
                'parent_result_release_mode' => null,
                'timezone' => 'Asia/Tashkent',
                'learning_material_max_mb' => 25,
                'student_submission_max_mb' => 15,
                'updated_by_user_id' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createGroups(): void
    {
        $createdAt = Carbon::parse('2020-06-02 08:00:00+00');
        foreach ($this->groupManifest() as $id => $specification) {
            Group::query()->create([
                'id' => $id,
                'institution_id' => $specification['institution_id'],
                'name' => $specification['name'],
                'level' => 'Stage 6',
                'subject_direction' => 'Homework authoring',
                'description' => 'E2E S06 deterministic Group.',
                'status' => GroupStatus::Active,
                'created_by_user_id' => $specification['created_by_user_id'],
                'archived_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createMemberships(): void
    {
        $startedAt = Carbon::parse('2020-06-02 09:00:00+00');
        foreach ($this->teacherMembershipManifest() as $id => $specification) {
            $this->createMembership(GroupTeacherMembership::class, 'teacher_id', $id, $specification, $startedAt);
            $startedAt = $startedAt->copy()->addMinute();
        }
        foreach ($this->studentMembershipManifest() as $id => $specification) {
            $this->createMembership(GroupStudentMembership::class, 'student_id', $id, $specification, $startedAt);
            $startedAt = $startedAt->copy()->addMinute();
        }
    }

    /**
     * @param  class-string<GroupTeacherMembership|GroupStudentMembership>  $model
     * @param  array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool}  $specification
     */
    private function createMembership(string $model, string $memberColumn, string $id, array $specification, Carbon $startedAt): void
    {
        $endedAt = $specification['ended'] ? $startedAt->copy()->addHour() : null;
        $model::query()->create([
            'id' => $id,
            'institution_id' => $specification['institution_id'],
            'group_id' => $specification['group_id'],
            $memberColumn => $specification['member_id'],
            'assigned_by_user_id' => $specification['actor_id'],
            'started_at' => $startedAt,
            'ended_at' => $endedAt,
            'created_at' => $startedAt,
            'updated_at' => $endedAt ?? $startedAt,
        ]);
    }

    private function createTopics(): void
    {
        $createdAt = Carbon::parse('2020-06-03 08:00:00+00');
        foreach ($this->topicManifest() as $id => $specification) {
            $activatedAt = $createdAt->copy()->addMinute();
            Topic::query()->create([
                'id' => $id,
                'institution_id' => $specification['institution_id'],
                'group_id' => $specification['group_id'],
                'teacher_id' => $specification['teacher_id'],
                'title' => $specification['title'],
                'description' => 'E2E S06 deterministic Topic.',
                'subject' => 'Network foundations',
                'student_instructions' => 'Follow the Homework instructions.',
                'lesson_at' => null,
                'status' => TopicStatus::Active,
                'activated_at' => $activatedAt,
                'closed_at' => null,
                'archived_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $activatedAt,
            ]);
            $createdAt = $createdAt->copy()->addMinutes(5);
        }
    }

    private function createAssessments(): void
    {
        $createdAt = Carbon::parse('2020-06-04 08:00:00+00');
        foreach ($this->assessmentManifest() as $id => $specification) {
            Assessment::query()->create([
                'id' => $id,
                'institution_id' => $specification['institution_id'],
                'topic_id' => $specification['topic_id'],
                'teacher_id' => $specification['teacher_id'],
                'type' => AssessmentType::Homework,
                'title' => $specification['title'],
                'description' => 'E2E S06 deterministic Homework fixture.',
                'student_instructions' => 'Complete the seeded Homework fixture.',
                'assignment_mode' => $specification['assignment_mode'],
                'total_possible_points' => $specification['total'],
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);

            $status = $specification['status'];
            $activatedAt = $status === HomeworkStatus::Active->value ? $createdAt->copy()->addMinutes(5) : null;
            HomeworkAssignment::query()->create([
                'assessment_id' => $id,
                'institution_id' => $specification['institution_id'],
                'status' => $status,
                'deadline_at' => $id === self::EXPIRED_HOMEWORK_ID
                    ? Carbon::now()->startOfMinute()->subDay()
                    : null,
                'activated_at' => $activatedAt,
                'closed_at' => null,
                'archived_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $activatedAt ?? $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinutes(10);
        }
    }

    private function createQuestions(): void
    {
        $createdAt = Carbon::parse('2020-06-04 10:00:00+00');
        foreach ($this->questionManifest() as $id => $specification) {
            Question::query()->create([
                'id' => $id,
                'institution_id' => $specification['institution_id'],
                'assessment_id' => $specification['assessment_id'],
                'type' => QuestionType::TrueFalse,
                'prompt' => $specification['prompt'],
                'instructions' => null,
                'points' => '1.000000',
                'position' => 1,
                'checking_mode' => QuestionCheckingMode::Automatic,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            QuestionTrueFalseAnswer::query()->create([
                'question_id' => $id,
                'institution_id' => $specification['institution_id'],
                'correct_value' => true,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createRecipientsAttemptAndPair(): void
    {
        $assignedAt = Carbon::parse('2020-06-04 12:00:00+00');
        foreach ($this->recipientManifest() as $id => $specification) {
            AssessmentStudent::query()->create([
                'id' => $id,
                'institution_id' => self::TARGET_INSTITUTION_ID,
                'assessment_id' => $specification['assessment_id'],
                'student_id' => $specification['student_id'],
                'assignment_source' => $specification['source'],
                'assigned_at' => $assignedAt,
                'assigned_by_user_id' => self::TARGET_TEACHER_ID,
                'created_at' => $assignedAt,
                'updated_at' => $assignedAt,
            ]);
            $assignedAt = $assignedAt->copy()->addMinute();
        }

        $designatedAt = Carbon::parse('2020-06-04 13:00:00+00');
        $cohortAt = $designatedAt->copy()->addMinute();
        $lockedAt = $cohortAt->copy()->addMinute();
        TopicResultPair::query()->create([
            'id' => self::LOCKED_PAIR_ID,
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'topic_id' => self::LOCKED_TOPIC_ID,
            'homework_assessment_id' => self::LOCKED_HOMEWORK_ID,
            'blitz_assessment_id' => null,
            'designated_by_user_id' => self::TARGET_TEACHER_ID,
            'designated_at' => $designatedAt,
            'cohort_snapshotted_at' => $cohortAt,
            'locked_at' => $lockedAt,
            'created_at' => $designatedAt,
            'updated_at' => $lockedAt,
        ]);
        AssessmentAttempt::query()->create([
            'id' => self::LOCKED_ATTEMPT_ID,
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'assessment_id' => self::LOCKED_HOMEWORK_ID,
            'assessment_student_id' => self::LOCKED_ALPHA_RECIPIENT_ID,
            'student_id' => self::STUDENT_ALPHA_ID,
            'attempt_number' => 1,
            'status' => AssessmentAttemptStatus::InProgress,
            'started_at' => $cohortAt,
            'deadline_at' => null,
            'submitted_at' => null,
            'finalized_at' => null,
            'finalization_reason' => null,
            'locked_at' => null,
            'official_score_eligible' => true,
            'earned_points' => null,
            'possible_points' => '1.000000',
            'normalized_score' => null,
            'scoring_completed_at' => null,
            'created_at' => $cohortAt,
            'updated_at' => $cohortAt,
        ]);
    }

    /** @return array<string, array{key: string, name: string, type: string}> */
    private function institutionManifest(): array
    {
        return [
            self::TARGET_INSTITUTION_ID => ['key' => 'target', 'name' => 'E2E S06 Target Institution', 'type' => InstitutionType::School->value],
            self::FOREIGN_INSTITUTION_ID => ['key' => 'foreign', 'name' => 'E2E S06 Foreign Institution', 'type' => InstitutionType::LearningCenter->value],
        ];
    }

    /** @return array<string, array{login_name: string, full_name: string, role: string, institution_id: string, active: bool}> */
    private function userManifest(): array
    {
        return [
            self::TARGET_ADMIN_ID => $this->userSpec('e2e_s06_target_admin', 'E2E S06 Target Admin', UserRole::InstitutionAdmin, self::TARGET_INSTITUTION_ID),
            self::TARGET_TEACHER_ID => $this->userSpec('e2e_s06_target_teacher', 'E2E S06 Target Teacher', UserRole::Teacher, self::TARGET_INSTITUTION_ID),
            self::STUDENT_ALPHA_ID => $this->userSpec('e2e_s06_student_alpha', 'E2E S06 Student Alpha', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::STUDENT_BETA_ID => $this->userSpec('e2e_s06_student_beta', 'E2E S06 Student Beta', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::STUDENT_ENDED_ID => $this->userSpec('e2e_s06_student_ended', 'E2E S06 Student Ended', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::STUDENT_INACTIVE_ID => $this->userSpec('e2e_s06_student_inactive', 'E2E S06 Student Inactive', UserRole::Student, self::TARGET_INSTITUTION_ID, false),
            self::UNRELATED_TEACHER_ID => $this->userSpec('e2e_s06_unrelated_teacher', 'E2E S06 Unrelated Teacher', UserRole::Teacher, self::TARGET_INSTITUTION_ID),
            self::UNRELATED_STUDENT_ID => $this->userSpec('e2e_s06_unrelated_student', 'E2E S06 Unrelated Student', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::FOREIGN_ADMIN_ID => $this->userSpec('e2e_s06_foreign_admin', 'E2E S06 Foreign Admin', UserRole::InstitutionAdmin, self::FOREIGN_INSTITUTION_ID),
            self::FOREIGN_TEACHER_ID => $this->userSpec('e2e_s06_foreign_teacher', 'E2E S06 Foreign Teacher', UserRole::Teacher, self::FOREIGN_INSTITUTION_ID),
            self::FOREIGN_STUDENT_ID => $this->userSpec('e2e_s06_foreign_student', 'E2E S06 Foreign Student', UserRole::Student, self::FOREIGN_INSTITUTION_ID),
        ];
    }

    /** @return array{login_name: string, full_name: string, role: string, institution_id: string, active: bool} */
    private function userSpec(string $login, string $name, UserRole $role, string $institution, bool $active = true): array
    {
        return ['login_name' => $login, 'full_name' => $name, 'role' => $role->value, 'institution_id' => $institution, 'active' => $active];
    }

    /** @return array<string, array{name: string, institution_id: string, created_by_user_id: string}> */
    private function groupManifest(): array
    {
        return [
            self::MAIN_GROUP_ID => ['name' => 'E2E S06 Main Group', 'institution_id' => self::TARGET_INSTITUTION_ID, 'created_by_user_id' => self::TARGET_ADMIN_ID],
            self::UNRELATED_GROUP_ID => ['name' => 'E2E S06 Unrelated Group', 'institution_id' => self::TARGET_INSTITUTION_ID, 'created_by_user_id' => self::TARGET_ADMIN_ID],
            self::FOREIGN_GROUP_ID => ['name' => 'E2E S06 Foreign Group', 'institution_id' => self::FOREIGN_INSTITUTION_ID, 'created_by_user_id' => self::FOREIGN_ADMIN_ID],
        ];
    }

    /** @return array<string, array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool}> */
    private function teacherMembershipManifest(): array
    {
        return [
            '06000000-0000-4000-b100-000000000101' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::TARGET_TEACHER_ID, self::TARGET_ADMIN_ID),
            '06000000-0000-4000-b100-000000000102' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::UNRELATED_GROUP_ID, self::UNRELATED_TEACHER_ID, self::TARGET_ADMIN_ID),
            '06000000-0000-4000-b100-000000000103' => $this->membershipSpec(self::FOREIGN_INSTITUTION_ID, self::FOREIGN_GROUP_ID, self::FOREIGN_TEACHER_ID, self::FOREIGN_ADMIN_ID),
        ];
    }

    /** @return array<string, array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool}> */
    private function studentMembershipManifest(): array
    {
        return [
            '06000000-0000-4000-b200-000000000101' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::STUDENT_ALPHA_ID, self::TARGET_ADMIN_ID),
            '06000000-0000-4000-b200-000000000102' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::STUDENT_BETA_ID, self::TARGET_ADMIN_ID),
            '06000000-0000-4000-b200-000000000103' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::STUDENT_ENDED_ID, self::TARGET_ADMIN_ID, true),
            '06000000-0000-4000-b200-000000000104' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::STUDENT_INACTIVE_ID, self::TARGET_ADMIN_ID),
            '06000000-0000-4000-b200-000000000105' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::UNRELATED_GROUP_ID, self::UNRELATED_STUDENT_ID, self::TARGET_ADMIN_ID),
            '06000000-0000-4000-b200-000000000106' => $this->membershipSpec(self::FOREIGN_INSTITUTION_ID, self::FOREIGN_GROUP_ID, self::FOREIGN_STUDENT_ID, self::FOREIGN_ADMIN_ID),
        ];
    }

    /** @return array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool} */
    private function membershipSpec(string $institution, string $group, string $member, string $actor, bool $ended = false): array
    {
        return ['institution_id' => $institution, 'group_id' => $group, 'member_id' => $member, 'actor_id' => $actor, 'ended' => $ended];
    }

    /** @return array<string, array{institution_id: string, group_id: string, teacher_id: string, title: string}> */
    private function topicManifest(): array
    {
        return [
            self::AUTHORING_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::TARGET_TEACHER_ID, 'E2E S06 Authoring Topic'),
            self::LOCKED_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::TARGET_TEACHER_ID, 'E2E S06 Locked Topic'),
            self::EXPIRED_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::TARGET_TEACHER_ID, 'E2E S06 Expired Deadline Topic'),
            self::UNRELATED_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::UNRELATED_GROUP_ID, self::UNRELATED_TEACHER_ID, 'E2E S06 Unrelated Topic'),
            self::FOREIGN_TOPIC_ID => $this->topicSpec(self::FOREIGN_INSTITUTION_ID, self::FOREIGN_GROUP_ID, self::FOREIGN_TEACHER_ID, 'E2E S06 Foreign Topic'),
            self::SECURITY_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::MAIN_GROUP_ID, self::TARGET_TEACHER_ID, 'E2E S06 Security Topic'),
        ];
    }

    /** @return array{institution_id: string, group_id: string, teacher_id: string, title: string} */
    private function topicSpec(string $institution, string $group, string $teacher, string $title): array
    {
        return ['institution_id' => $institution, 'group_id' => $group, 'teacher_id' => $teacher, 'title' => $title];
    }

    /** @return array<string, array{institution_id: string, topic_id: string, teacher_id: string, title: string, assignment_mode: string, total: string, status: string}> */
    private function assessmentManifest(): array
    {
        return [
            self::LOCKED_HOMEWORK_ID => $this->assessmentSpec(self::TARGET_INSTITUTION_ID, self::LOCKED_TOPIC_ID, self::TARGET_TEACHER_ID, 'E2E S06 Locked Official Homework', AssessmentAssignmentMode::Group, '1.000000', HomeworkStatus::Active),
            self::LOCKED_REPLACEMENT_ID => $this->assessmentSpec(self::TARGET_INSTITUTION_ID, self::LOCKED_TOPIC_ID, self::TARGET_TEACHER_ID, 'E2E S06 Locked Replacement Candidate', AssessmentAssignmentMode::Group, '0.000000', HomeworkStatus::Draft),
            self::EXPIRED_HOMEWORK_ID => $this->assessmentSpec(self::TARGET_INSTITUTION_ID, self::EXPIRED_TOPIC_ID, self::TARGET_TEACHER_ID, 'E2E S06 Expired Draft Homework', AssessmentAssignmentMode::Group, '1.000000', HomeworkStatus::Draft),
            self::SECURITY_SELECTED_ID => $this->assessmentSpec(self::TARGET_INSTITUTION_ID, self::SECURITY_TOPIC_ID, self::TARGET_TEACHER_ID, 'E2E S06 Security Selected Candidate', AssessmentAssignmentMode::SelectedStudents, '0.000000', HomeworkStatus::Draft),
            self::FOREIGN_HOMEWORK_ID => $this->assessmentSpec(self::FOREIGN_INSTITUTION_ID, self::FOREIGN_TOPIC_ID, self::FOREIGN_TEACHER_ID, 'E2E S06 Foreign Homework', AssessmentAssignmentMode::Group, '1.000000', HomeworkStatus::Draft),
        ];
    }

    /** @return array{institution_id: string, topic_id: string, teacher_id: string, title: string, assignment_mode: string, total: string, status: string} */
    private function assessmentSpec(string $institution, string $topic, string $teacher, string $title, AssessmentAssignmentMode $mode, string $total, HomeworkStatus $status): array
    {
        return ['institution_id' => $institution, 'topic_id' => $topic, 'teacher_id' => $teacher, 'title' => $title, 'assignment_mode' => $mode->value, 'total' => $total, 'status' => $status->value];
    }

    /** @return array<string, array{institution_id: string, assessment_id: string, prompt: string}> */
    private function questionManifest(): array
    {
        return [
            self::LOCKED_QUESTION_ID => ['institution_id' => self::TARGET_INSTITUTION_ID, 'assessment_id' => self::LOCKED_HOMEWORK_ID, 'prompt' => 'DNS uses domain names.'],
            self::EXPIRED_QUESTION_ID => ['institution_id' => self::TARGET_INSTITUTION_ID, 'assessment_id' => self::EXPIRED_HOMEWORK_ID, 'prompt' => 'An expired draft remains structurally valid.'],
            self::FOREIGN_QUESTION_ID => ['institution_id' => self::FOREIGN_INSTITUTION_ID, 'assessment_id' => self::FOREIGN_HOMEWORK_ID, 'prompt' => 'Foreign Homework remains tenant isolated.'],
        ];
    }

    /** @return array<string, array{assessment_id: string, student_id: string, source: string}> */
    private function recipientManifest(): array
    {
        return [
            self::LOCKED_ALPHA_RECIPIENT_ID => ['assessment_id' => self::LOCKED_HOMEWORK_ID, 'student_id' => self::STUDENT_ALPHA_ID, 'source' => AssessmentAssignmentSource::Group->value],
            self::LOCKED_BETA_RECIPIENT_ID => ['assessment_id' => self::LOCKED_HOMEWORK_ID, 'student_id' => self::STUDENT_BETA_ID, 'source' => AssessmentAssignmentSource::Group->value],
            self::SECURITY_ALPHA_RECIPIENT_ID => ['assessment_id' => self::SECURITY_SELECTED_ID, 'student_id' => self::STUDENT_ALPHA_ID, 'source' => AssessmentAssignmentSource::Direct->value],
        ];
    }
}
