<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\GroupStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionShortAcceptedAnswer;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Teacher\Concerns\BuildsTeacherHomeworkContext;
use Tests\TestCase;

class TeacherHomeworkLifecycleApiTest extends TestCase
{
    use BuildsTeacherHomeworkContext;
    use RefreshDatabase;

    private const URI = '/api/v1/teacher/homework';

    public function test_exact_homework_lifecycle_routes_are_registered_once_with_teacher_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => in_array($route['uri'], [
                'api/v1/teacher/homework/{homework}/activate',
                'api/v1/teacher/homework/{homework}/close',
                'api/v1/teacher/homework/{homework}/archive',
            ], true))
            ->values()
            ->all();
        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'];

        $this->assertSame([
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/homework/{homework}/activate', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/homework/{homework}/close', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/homework/{homework}/archive', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_valid_activation_recalculates_points_and_uses_one_transition_instant(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $original = CarbonImmutable::parse('2026-09-03 08:00:00', 'UTC');
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            assessmentAttributes: ['total_possible_points' => '99.000000', 'created_at' => $original, 'updated_at' => $original],
            homeworkAttributes: ['created_at' => $original, 'updated_at' => $original],
        );
        $this->scoreableQuestion($assessment, '2.250000');

        try {
            CarbonImmutable::setTestNow('2026-09-03 10:00:00 UTC');
            $response = $this->lifecycle($teacher, $assessment, 'activate');
        } finally {
            CarbonImmutable::setTestNow();
        }

        $response->assertOk()
            ->assertJsonPath('message', 'Homework activated successfully.')
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.total_possible_points', 2.25)
            ->assertJsonPath('data.activated_at', '2026-09-03T10:00:00Z')
            ->assertJsonPath('data.updated_at', '2026-09-03T10:00:00Z');
        $homework = $assessment->homeworkAssignment()->firstOrFail();
        $recipient = $assessment->recipients()->firstOrFail();
        $this->assertSame('2.250000', $assessment->fresh()?->total_possible_points);
        $this->assertSame('2026-09-03T10:00:00+00:00', $homework->activated_at?->toIso8601String());
        $this->assertSame('2026-09-03T10:00:00+00:00', $homework->updated_at?->toIso8601String());
        $this->assertSame('2026-09-03T10:00:00+00:00', $recipient->assigned_at?->toIso8601String());
        $this->assertSame($student->id, $recipient->student_id);
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    public function test_activation_bulk_locks_typed_configuration_with_a_constant_query_bound(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            assessmentAttributes: ['total_possible_points' => '1.000000'],
        );

        foreach (range(1, 100) as $position) {
            $this->scoreableQuestion($assessment, position: $position);
        }

        $this->assertSame(100, Question::query()->where('assessment_id', $assessment->id)->count());

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $response = $this->lifecycle($teacher, $assessment, 'activate');
            $activationQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $typedConfigurationTables = [
            'question_choice_options',
            'question_true_false_answers',
            'question_short_accepted_answers',
            'question_matching_items',
            'question_ordering_items',
            'question_fill_blanks',
            'question_fill_blank_accepted_answers',
        ];
        $typedLockQueryCounts = collect($typedConfigurationTables)->mapWithKeys(function (string $table) use ($activationQueries): array {
            $count = collect($activationQueries)->filter(function (array $query) use ($table): bool {
                $sql = strtolower((string) $query['query']);

                return str_contains($sql, 'from "'.$table.'"')
                    && str_contains($sql, 'for update');
            })->count();

            return [$table => $count];
        });

        $response->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.total_possible_points', 100);
        $this->assertSame(HomeworkStatus::Active, $assessment->homeworkAssignment()->firstOrFail()->status);
        $this->assertSame('100.000000', $assessment->fresh()?->total_possible_points);
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertSame(array_fill_keys($typedConfigurationTables, 1), $typedLockQueryCounts->all());
        $this->assertLessThanOrEqual(7, $typedLockQueryCounts->sum());
    }

    public function test_active_activate_is_a_no_op_before_parent_deadline_question_and_recipient_validation(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Closed);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            status: HomeworkStatus::Active,
            assessmentAttributes: ['total_possible_points' => '7.000000'],
            homeworkAttributes: ['deadline_at' => now()->subDay()],
        );
        $this->scoreableQuestion($assessment);
        $before = $this->aggregateState($assessment);

        $response = $this->lifecycle($teacher, $assessment, 'activate');

        $response->assertOk()->assertJsonPath('data.status', 'active');
        $this->assertSame($before, $this->aggregateState($assessment));
        $this->assertDatabaseCount('assessment_students', 0);
    }

    public function test_activate_uses_exact_closed_archived_parent_and_group_conflicts(): void
    {
        foreach ([
            [HomeworkStatus::Closed, 'task_closed', 'The task is closed.'],
            [HomeworkStatus::Archived, 'task_archived', 'The task is archived.'],
        ] as [$status, $code, $message]) {
            [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
            $assessment = $this->persistedHomework($institution, $teacher, $topic, status: $status);
            $this->scoreableQuestion($assessment);
            $this->assertConflictPayload($this->lifecycle($teacher, $assessment, 'activate'), $code, $message);
        }

        foreach ([TopicStatus::Draft, TopicStatus::Closed, TopicStatus::Archived] as $topicStatus) {
            [$institution, $teacher, , , $topic] = $this->homeworkContext($topicStatus);
            $assessment = $this->persistedHomework($institution, $teacher, $topic);
            $this->assertConflictPayload(
                $this->lifecycle($teacher, $assessment, 'activate'),
                'topic_not_editable',
                'The topic is not editable.',
            );
        }

        [$institution, $teacher, , $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $group->forceFill(['status' => GroupStatus::Archived, 'archived_at' => now()])->save();
        $assessment = $this->persistedHomework($institution, $teacher, $topic);
        $this->assertConflictPayload(
            $this->lifecycle($teacher, $assessment, 'activate'),
            'topic_not_editable',
            'The topic is not editable.',
        );
    }

    public function test_corrupt_homework_metadata_blocks_activation_with_zero_writes(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            assessmentAttributes: ['student_instructions' => str_repeat('x', 10001), 'total_possible_points' => '8.000000'],
        );
        $this->scoreableQuestion($assessment, '2.000000');
        $before = $this->aggregateState($assessment);

        $this->assertConflictPayload(
            $this->lifecycle($teacher, $assessment, 'activate'),
            'business_conflict',
            'The requested change conflicts with current task activity.',
        );

        $this->assertSame($before, $this->aggregateState($assessment));
        $this->assertDatabaseCount('assessment_students', 0);
    }

    public function test_question_count_points_positions_and_typed_configuration_are_revalidated_atomically(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $this->eligibleStudent($institution, $admin, $group);

        $empty = $this->persistedHomework($institution, $teacher, $topic);
        $this->assertConflictPayload(
            $this->lifecycle($teacher, $empty, 'activate'),
            'assessment_has_no_scoreable_points',
            'The assessment must contain at least one scoreable point.',
        );

        $zero = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($zero, '0.000000');
        $this->assertConflictPayload(
            $this->lifecycle($teacher, $zero, 'activate'),
            'assessment_has_no_scoreable_points',
            'The assessment must contain at least one scoreable point.',
        );

        $missingTyped = $this->persistedHomework($institution, $teacher, $topic);
        Question::factory()->trueFalse()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $missingTyped->id,
        ]);
        $this->assertBusinessConflict($this->lifecycle($teacher, $missingTyped, 'activate'));

        $nonCanonicalTyped = $this->persistedHomework($institution, $teacher, $topic);
        $shortQuestion = Question::factory()->shortWrittenAutomatic()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $nonCanonicalTyped->id,
        ]);
        QuestionShortAcceptedAnswer::factory()->create([
            'institution_id' => $institution->id,
            'question_id' => $shortQuestion->id,
            'position' => 2,
        ]);
        $this->assertBusinessConflict($this->lifecycle($teacher, $nonCanonicalTyped, 'activate'));

        $gapped = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($gapped, position: 1);
        $this->scoreableQuestion($gapped, position: 3);
        $this->assertBusinessConflict($this->lifecycle($teacher, $gapped, 'activate'));
    }

    public function test_incompatible_extra_typed_row_blocks_otherwise_valid_question_with_zero_writes(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            assessmentAttributes: ['total_possible_points' => '6.000000'],
        );
        $question = $this->scoreableQuestion($assessment, '3.000000');
        QuestionChoiceOption::factory()->create([
            'institution_id' => $institution->id,
            'question_id' => $question->id,
        ]);
        $before = $this->aggregateState($assessment);

        $this->assertBusinessConflict($this->lifecycle($teacher, $assessment, 'activate'));

        $this->assertSame($before, $this->aggregateState($assessment));
        $this->assertDatabaseCount('assessment_students', 0);
    }

    public function test_deadline_must_be_strictly_future_and_uses_exact_error_contract(): void
    {
        try {
            CarbonImmutable::setTestNow('2026-09-03 10:00:00 UTC');

            [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
            $deadlinePrecedence = $this->persistedHomework(
                $institution,
                $teacher,
                $topic,
                homeworkAttributes: ['deadline_at' => CarbonImmutable::parse('2026-09-03 10:00:00 UTC')],
            );
            $this->scoreableQuestion($deadlinePrecedence);
            $this->assertConflictPayload(
                $this->lifecycle($teacher, $deadlinePrecedence, 'activate'),
                'deadline_passed',
                'The homework deadline has passed.',
            );

            foreach (['2026-09-03 10:00:00 UTC', '2026-09-03 09:59:59 UTC'] as $deadline) {
                [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
                $this->eligibleStudent($institution, $admin, $group);
                $assessment = $this->persistedHomework(
                    $institution,
                    $teacher,
                    $topic,
                    homeworkAttributes: ['deadline_at' => CarbonImmutable::parse($deadline)],
                );
                $this->scoreableQuestion($assessment);
                $this->assertConflictPayload(
                    $this->lifecycle($teacher, $assessment, 'activate'),
                    'deadline_passed',
                    'The homework deadline has passed.',
                );
            }

            [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
            $this->eligibleStudent($institution, $admin, $group);
            $future = $this->persistedHomework(
                $institution,
                $teacher,
                $topic,
                homeworkAttributes: ['deadline_at' => CarbonImmutable::parse('2026-09-03 10:00:01 UTC')],
            );
            $this->scoreableQuestion($future);
            $this->lifecycle($teacher, $future, 'activate')->assertOk();
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_close_matrix_attempt_guard_history_and_idempotency_are_exact(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);

        $draft = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($draft);
        $this->assertConflictPayload(
            $this->lifecycle($teacher, $draft, 'close'),
            'task_not_active',
            'The task is not active.',
        );

        $archived = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Archived);
        $this->scoreableQuestion($archived);
        $this->assertConflictPayload(
            $this->lifecycle($teacher, $archived, 'close'),
            'task_archived',
            'The task is archived.',
        );

        $blocked = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $this->scoreableQuestion($blocked);
        $blockedAttempt = $this->attempt($teacher, $student, $blocked);
        $blockedBefore = $this->aggregateState($blocked);
        $attemptBefore = $blockedAttempt->fresh()?->getAttributes();
        $this->assertConflictPayload(
            $this->lifecycle($teacher, $blocked, 'close'),
            'business_conflict',
            'Homework cannot be closed while student work is still in progress.',
        );
        $this->assertSame($blockedBefore, $this->aggregateState($blocked));
        $this->assertSame($attemptBefore, $blockedAttempt->fresh()?->getAttributes());

        $closable = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $this->scoreableQuestion($closable);
        $submittedAttempt = $this->attempt($teacher, $student, $closable, AssessmentAttemptStatus::Submitted);
        $attemptSnapshot = $submittedAttempt->fresh()?->getAttributes();
        $this->lifecycle($teacher, $closable, 'close')
            ->assertOk()
            ->assertJsonPath('message', 'Homework closed successfully.')
            ->assertJsonPath('data.status', 'closed');
        $closedState = $this->aggregateState($closable);
        $this->assertSame($attemptSnapshot, $submittedAttempt->fresh()?->getAttributes());

        $closedWithInProgress = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            status: HomeworkStatus::Closed,
        );
        $this->scoreableQuestion($closedWithInProgress);
        $inProgress = $this->attempt($teacher, $student, $closedWithInProgress);
        $closedNoOpState = $this->aggregateState($closedWithInProgress);
        $inProgressState = $inProgress->fresh()?->getAttributes();
        $this->lifecycle($teacher, $closedWithInProgress, 'close')->assertOk();
        $this->assertSame($closedNoOpState, $this->aggregateState($closedWithInProgress));
        $this->assertSame($inProgressState, $inProgress->fresh()?->getAttributes());

        CarbonImmutable::setTestNow(now()->addHour());
        try {
            $this->lifecycle($teacher, $closable, 'close')->assertOk()->assertJsonPath('data.status', 'closed');
        } finally {
            CarbonImmutable::setTestNow();
        }
        $this->assertSame($closedState, $this->aggregateState($closable));
        $this->assertDatabaseCount('assessment_attempts', 3);
    }

    public function test_close_preserves_a_complete_checked_attempt_without_creating_another_attempt(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            status: HomeworkStatus::Active,
            assessmentAttributes: ['total_possible_points' => '12.500000'],
        );
        $this->scoreableQuestion($assessment, '12.500000');
        $startedAt = CarbonImmutable::parse('2026-09-03 08:00:00 UTC');
        $checkedAttempt = $this->attempt($teacher, $student, $assessment, AssessmentAttemptStatus::Checked);
        $checkedAttempt->forceFill([
            'started_at' => $startedAt,
            'deadline_at' => $startedAt->addHours(2),
            'submitted_at' => $startedAt->addMinutes(30),
            'finalized_at' => $startedAt->addMinutes(31),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
            'locked_at' => $startedAt->addMinutes(31),
            'official_score_eligible' => true,
            'earned_points' => '9.75000000',
            'possible_points' => '12.500000',
            'normalized_score' => '78.00000000',
            'scoring_completed_at' => $startedAt->addMinutes(32),
        ])->save();
        $attemptSnapshot = $checkedAttempt->fresh()?->getAttributes();

        $this->lifecycle($teacher, $assessment, 'close')
            ->assertOk()
            ->assertJsonPath('message', 'Homework closed successfully.')
            ->assertJsonPath('data.status', 'closed');

        $this->assertSame(HomeworkStatus::Closed, $assessment->homeworkAssignment()->firstOrFail()->status);
        $this->assertSame($attemptSnapshot, $checkedAttempt->fresh()?->getAttributes());
        $this->assertSame(
            1,
            AssessmentAttempt::query()->where('assessment_id', $assessment->id)->count(),
        );
    }

    public function test_active_close_uses_one_authoritative_transition_instant_and_preserves_history(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $original = CarbonImmutable::parse('2026-09-01 07:00:00 UTC');
        $activatedAt = CarbonImmutable::parse('2026-09-01 08:00:00 UTC');
        $deadlineAt = CarbonImmutable::parse('2026-09-10 18:00:00 UTC');
        $transitionedAt = CarbonImmutable::parse('2026-09-03 10:15:30 UTC');
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            status: HomeworkStatus::Active,
            assessmentAttributes: [
                'total_possible_points' => '7.500000',
                'created_at' => $original,
                'updated_at' => $original,
            ],
            homeworkAttributes: [
                'deadline_at' => $deadlineAt,
                'activated_at' => $activatedAt,
                'created_at' => $original,
                'updated_at' => $original,
            ],
        );
        $question = $this->scoreableQuestion($assessment, '7.500000');
        $attempt = $this->attempt($teacher, $student, $assessment, AssessmentAttemptStatus::Submitted);
        $recipient = $attempt->assessmentStudent()->firstOrFail();
        $questionSnapshot = $question->fresh()?->getAttributes();
        $recipientSnapshot = $recipient->fresh()?->getAttributes();
        $attemptSnapshot = $attempt->fresh()?->getAttributes();

        try {
            CarbonImmutable::setTestNow($transitionedAt);
            $this->lifecycle($teacher, $assessment, 'close')
                ->assertOk()
                ->assertJsonPath('data.status', 'closed');
        } finally {
            CarbonImmutable::setTestNow();
        }

        $freshAssessment = Assessment::query()->findOrFail($assessment->id);
        $homework = $freshAssessment->homeworkAssignment()->firstOrFail();
        $this->assertSame($transitionedAt->toIso8601String(), $homework->closed_at?->toIso8601String());
        $this->assertSame($transitionedAt->toIso8601String(), $homework->updated_at?->toIso8601String());
        $this->assertSame($transitionedAt->toIso8601String(), $freshAssessment->updated_at?->toIso8601String());
        $this->assertSame($activatedAt->toIso8601String(), $homework->activated_at?->toIso8601String());
        $this->assertSame($deadlineAt->toIso8601String(), $homework->deadline_at?->toIso8601String());
        $this->assertNull($homework->archived_at);
        $this->assertSame('7.500000', $freshAssessment->total_possible_points);
        $this->assertSame($questionSnapshot, Question::query()->findOrFail($question->id)->getAttributes());
        $this->assertSame($recipientSnapshot, AssessmentStudent::query()->findOrFail($recipient->id)->getAttributes());
        $this->assertSame($attemptSnapshot, AssessmentAttempt::query()->findOrFail($attempt->id)->getAttributes());
    }

    public function test_close_allows_closed_topic_but_rejects_archived_topic_for_a_real_transition(): void
    {
        foreach ([TopicStatus::Closed, TopicStatus::Archived] as $topicStatus) {
            [$institution, $teacher, , , $topic] = $this->homeworkContext($topicStatus);
            $assessment = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
            $this->scoreableQuestion($assessment);
            $response = $this->lifecycle($teacher, $assessment, 'close');

            if ($topicStatus === TopicStatus::Closed) {
                $response->assertOk()->assertJsonPath('data.status', 'closed');
            } else {
                $this->assertConflictPayload($response, 'topic_not_editable', 'The topic is not editable.');
            }
        }
    }

    public function test_designated_activation_snapshots_the_pair_and_later_lifecycle_preserves_it(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($assessment);
        $pair = TopicResultPair::factory()->create([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'homework_assessment_id' => $assessment->id,
            'designated_by_user_id' => $teacher->id,
            'designated_at' => now()->subMinutes(3),
        ]);

        $this->lifecycle($teacher, $assessment, 'activate')->assertOk();
        $pair->refresh();
        $this->assertNotNull($pair->cohort_snapshotted_at);
        $this->assertNull($pair->locked_at);
        $afterActivation = $pair->getAttributes();

        $this->lifecycle($teacher, $assessment, 'close')->assertOk();
        $this->lifecycle($teacher, $assessment, 'archive')->assertOk();

        $this->assertSame($afterActivation, $pair->fresh()?->getAttributes());
        $this->assertDatabaseCount('topic_result_pairs', 1);
    }

    public function test_archive_matrix_attempt_rules_history_and_idempotency_are_exact(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Archived);
        $student = $this->eligibleStudent($institution, $admin, $group);

        $draft = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($draft);
        $this->lifecycle($teacher, $draft, 'archive')
            ->assertOk()->assertJsonPath('message', 'Homework archived successfully.')
            ->assertJsonPath('data.status', 'archived');
        $draftArchivedState = $this->aggregateState($draft);
        $this->lifecycle($teacher, $draft, 'archive')->assertOk();
        $this->assertSame($draftArchivedState, $this->aggregateState($draft));

        $archivedWithAttempt = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            status: HomeworkStatus::Archived,
        );
        $this->scoreableQuestion($archivedWithAttempt);
        $archivedAttempt = $this->attempt($teacher, $student, $archivedWithAttempt);
        $archivedNoOpState = $this->aggregateState($archivedWithAttempt);
        $archivedAttemptState = $archivedAttempt->fresh()?->getAttributes();
        $this->lifecycle($teacher, $archivedWithAttempt, 'archive')->assertOk();
        $this->assertSame($archivedNoOpState, $this->aggregateState($archivedWithAttempt));
        $this->assertSame($archivedAttemptState, $archivedAttempt->fresh()?->getAttributes());

        $active = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $this->scoreableQuestion($active);
        $this->assertBusinessConflict($this->lifecycle($teacher, $active, 'archive'));

        $corruptDraft = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($corruptDraft);
        $this->attempt($teacher, $student, $corruptDraft);
        $this->assertBusinessConflict($this->lifecycle($teacher, $corruptDraft, 'archive'));

        $corruptClosed = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Closed);
        $this->scoreableQuestion($corruptClosed);
        $this->attempt($teacher, $student, $corruptClosed);
        $this->assertBusinessConflict($this->lifecycle($teacher, $corruptClosed, 'archive'));

        $closed = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Closed);
        $this->scoreableQuestion($closed);
        $checked = $this->attempt($teacher, $student, $closed, AssessmentAttemptStatus::Checked);
        $checkedSnapshot = $checked->fresh()?->getAttributes();
        $originalHomework = $closed->homeworkAssignment()->firstOrFail();
        $activatedAt = $originalHomework->activated_at?->toIso8601String();
        $closedAt = $originalHomework->closed_at?->toIso8601String();
        $this->lifecycle($teacher, $closed, 'archive')->assertOk()->assertJsonPath('data.status', 'archived');
        $archivedHomework = $closed->homeworkAssignment()->firstOrFail();
        $this->assertSame($activatedAt, $archivedHomework->activated_at?->toIso8601String());
        $this->assertSame($closedAt, $archivedHomework->closed_at?->toIso8601String());
        $this->assertSame($checkedSnapshot, $checked->fresh()?->getAttributes());
    }

    public function test_draft_archive_uses_one_authoritative_transition_instant_and_preserves_content(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $original = CarbonImmutable::parse('2026-09-01 07:00:00 UTC');
        $transitionedAt = CarbonImmutable::parse('2026-09-03 11:20:40 UTC');
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            assessmentAttributes: [
                'total_possible_points' => '6.250000',
                'created_at' => $original,
                'updated_at' => $original,
            ],
            homeworkAttributes: ['created_at' => $original, 'updated_at' => $original],
        );
        $question = $this->scoreableQuestion($assessment, '6.250000');
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Group,
            'assigned_by_user_id' => $teacher->id,
        ]);
        $questionSnapshot = $question->fresh()?->getAttributes();
        $recipientSnapshot = $recipient->fresh()?->getAttributes();

        try {
            CarbonImmutable::setTestNow($transitionedAt);
            $this->lifecycle($teacher, $assessment, 'archive')
                ->assertOk()
                ->assertJsonPath('data.status', 'archived');
        } finally {
            CarbonImmutable::setTestNow();
        }

        $freshAssessment = Assessment::query()->findOrFail($assessment->id);
        $homework = $freshAssessment->homeworkAssignment()->firstOrFail();
        $this->assertSame($transitionedAt->toIso8601String(), $homework->archived_at?->toIso8601String());
        $this->assertSame($transitionedAt->toIso8601String(), $homework->updated_at?->toIso8601String());
        $this->assertSame($transitionedAt->toIso8601String(), $freshAssessment->updated_at?->toIso8601String());
        $this->assertNull($homework->activated_at);
        $this->assertNull($homework->closed_at);
        $this->assertSame('6.250000', $freshAssessment->total_possible_points);
        $this->assertSame($questionSnapshot, Question::query()->findOrFail($question->id)->getAttributes());
        $this->assertSame($recipientSnapshot, AssessmentStudent::query()->findOrFail($recipient->id)->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    public function test_closed_archive_uses_one_authoritative_transition_instant_and_preserves_history(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Archived);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $original = CarbonImmutable::parse('2026-09-01 07:00:00 UTC');
        $activatedAt = CarbonImmutable::parse('2026-09-01 08:00:00 UTC');
        $closedAt = CarbonImmutable::parse('2026-09-02 09:10:00 UTC');
        $deadlineAt = CarbonImmutable::parse('2026-09-10 18:00:00 UTC');
        $transitionedAt = CarbonImmutable::parse('2026-09-03 12:25:50 UTC');
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            status: HomeworkStatus::Closed,
            assessmentAttributes: [
                'total_possible_points' => '8.750000',
                'created_at' => $original,
                'updated_at' => $original,
            ],
            homeworkAttributes: [
                'deadline_at' => $deadlineAt,
                'activated_at' => $activatedAt,
                'closed_at' => $closedAt,
                'created_at' => $original,
                'updated_at' => $original,
            ],
        );
        $question = $this->scoreableQuestion($assessment, '8.750000');
        $attempt = $this->attempt($teacher, $student, $assessment, AssessmentAttemptStatus::Submitted);
        $recipient = $attempt->assessmentStudent()->firstOrFail();
        $questionSnapshot = $question->fresh()?->getAttributes();
        $recipientSnapshot = $recipient->fresh()?->getAttributes();
        $attemptSnapshot = $attempt->fresh()?->getAttributes();

        try {
            CarbonImmutable::setTestNow($transitionedAt);
            $this->lifecycle($teacher, $assessment, 'archive')
                ->assertOk()
                ->assertJsonPath('data.status', 'archived');
        } finally {
            CarbonImmutable::setTestNow();
        }

        $freshAssessment = Assessment::query()->findOrFail($assessment->id);
        $homework = $freshAssessment->homeworkAssignment()->firstOrFail();
        $this->assertSame($transitionedAt->toIso8601String(), $homework->archived_at?->toIso8601String());
        $this->assertSame($transitionedAt->toIso8601String(), $homework->updated_at?->toIso8601String());
        $this->assertSame($transitionedAt->toIso8601String(), $freshAssessment->updated_at?->toIso8601String());
        $this->assertSame($activatedAt->toIso8601String(), $homework->activated_at?->toIso8601String());
        $this->assertSame($closedAt->toIso8601String(), $homework->closed_at?->toIso8601String());
        $this->assertSame($deadlineAt->toIso8601String(), $homework->deadline_at?->toIso8601String());
        $this->assertSame('8.750000', $freshAssessment->total_possible_points);
        $this->assertSame($questionSnapshot, Question::query()->findOrFail($question->id)->getAttributes());
        $this->assertSame($recipientSnapshot, AssessmentStudent::query()->findOrFail($recipient->id)->getAttributes());
        $this->assertSame($attemptSnapshot, AssessmentAttempt::query()->findOrFail($attempt->id)->getAttributes());
    }

    public function test_lifecycle_request_accepts_only_no_body_or_empty_json_object(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
        $targets = [
            'activate' => $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active),
            'close' => $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Closed),
            'archive' => $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Archived),
        ];
        foreach ($targets as $assessment) {
            $this->scoreableQuestion($assessment);
        }

        foreach ($targets as $operation => $assessment) {
            $this->lifecycle($teacher, $assessment, $operation, '')->assertOk();
            $this->lifecycle($teacher, $assessment, $operation, '{}')->assertOk();

            foreach (['{', '42', '[]', 'null', '{"status":"active"}', 'payload'] as $content) {
                $this->lifecycle($teacher, $assessment, $operation, $content)
                    ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            }

            $this->lifecycle($teacher, $assessment, $operation, '', ['unexpected' => 'x'])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
    }

    private function scoreableQuestion(Assessment $assessment, string $points = '1.000000', int $position = 1): Question
    {
        return Question::factory()->openWritten()->create([
            'institution_id' => $assessment->institution_id,
            'assessment_id' => $assessment->id,
            'points' => $points,
            'position' => $position,
        ]);
    }

    private function attempt(
        User $teacher,
        User $student,
        Assessment $assessment,
        AssessmentAttemptStatus $status = AssessmentAttemptStatus::InProgress,
    ): AssessmentAttempt {
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $teacher->institution_id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => $assessment->assignment_mode === AssessmentAssignmentMode::SelectedStudents
                ? AssessmentAssignmentSource::Direct
                : AssessmentAssignmentSource::Group,
            'assigned_by_user_id' => $teacher->id,
        ]);

        return AssessmentAttempt::factory()->create([
            'institution_id' => $teacher->institution_id,
            'assessment_id' => $assessment->id,
            'assessment_student_id' => $recipient->id,
            'student_id' => $student->id,
            'status' => $status,
            'possible_points' => $assessment->total_possible_points,
        ]);
    }

    /** @return array<string, mixed> */
    private function aggregateState(Assessment $assessment): array
    {
        $freshAssessment = $assessment->fresh();
        $homework = $assessment->homeworkAssignment()->firstOrFail();

        return [
            'assessment' => collect($freshAssessment?->getAttributes())
                ->only(['total_possible_points', 'updated_at'])
                ->all(),
            'homework' => collect($homework->getAttributes())
                ->only(['status', 'deadline_at', 'activated_at', 'closed_at', 'archived_at', 'updated_at'])
                ->all(),
        ];
    }

    /** @param array<string, mixed> $query */
    private function lifecycle(
        User $teacher,
        Assessment $assessment,
        string $operation,
        string $content = '',
        array $query = [],
    ): TestResponse {
        return $this->homeworkRaw(
            $teacher,
            'POST',
            self::URI.'/'.$assessment->id.'/'.$operation,
            $content,
            $query,
        );
    }

    private function assertBusinessConflict(TestResponse $response): void
    {
        $this->assertConflictPayload(
            $response,
            'business_conflict',
            'The requested change conflicts with current task activity.',
        );
    }

    private function assertConflictPayload(TestResponse $response, string $code, string $message): void
    {
        $this->assertSame([
            'message' => $message,
            'code' => $code,
            'errors' => [],
        ], $response->assertConflict()->json());
    }
}
