<?php

namespace Tests\Feature\Homework;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\QuestionType;
use App\Models\AnswerTextValue;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\Question;
use App\Support\Assessment\HomeworkAttemptFinalizer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class HomeworkDeadlineFinalizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-09 09:00:00 UTC'));
    }

    #[DataProvider('deadlineDelays')]
    public function test_deadline_freezes_only_existing_work_at_the_exact_deadline_and_retries_are_write_free(int $delay): void
    {
        $deadline = now()->addHour();
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => $deadline]);
        $attempt = $this->attempt($homework);
        $second = $this->attempt($homework);
        $answer = AttemptAnswer::factory()->forQuestionType(QuestionType::ShortWritten)->create(['attempt_id' => $attempt]);
        $payload = AnswerTextValue::factory()->create(['answer_id' => $answer, 'text_value' => 'Saved before deadline.']);
        Question::factory()->openWritten()->create([
            'institution_id' => $homework->institution_id,
            'assessment_id' => $homework->assessment_id,
            'position' => 2,
        ]);
        $neverStarted = AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);
        $answerBefore = $answer->fresh()->getAttributes();
        $payloadBefore = $payload->fresh()->getAttributes();
        $homeworkBefore = $homework->fresh()->getAttributes();
        $assessmentBefore = $homework->assessment->getAttributes();
        $attemptBefore = $attempt->fresh()->getAttributes();

        $this->travelTo($deadline->copy()->addMinutes($delay));

        $this->assertSame(2, $this->reconcile($homework));
        foreach ([$attempt, $second] as $finalized) {
            $finalized->refresh();
            $this->assertSame(AssessmentAttemptStatus::Submitted, $finalized->status);
            $this->assertNull($finalized->submitted_at);
            $this->assertTrue($deadline->equalTo($finalized->finalized_at));
            $this->assertTrue($deadline->equalTo($finalized->locked_at));
            $this->assertSame(AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit, $finalized->finalization_reason);
            $this->assertTrue(now()->equalTo($finalized->updated_at));
        }
        $this->assertSame(
            collect($attemptBefore)->except(['status', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at'])->all(),
            collect($attempt->getAttributes())->except(['status', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at'])->all(),
        );
        $this->assertSame($answerBefore, $answer->fresh()->getAttributes());
        $this->assertSame($payloadBefore, $payload->fresh()->getAttributes());
        $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->fresh()->checking_status);
        $this->assertNull($answer->fresh()->awarded_points);
        $this->assertSame($homeworkBefore, $homework->fresh()->getAttributes());
        $this->assertSame($assessmentBefore, $homework->assessment()->firstOrFail()->getAttributes());
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_student_id' => $neverStarted->id]);
        $this->assertDatabaseCount('assessment_attempts', 2);
        $this->assertDatabaseCount('attempt_answers', 1);
        $snapshots = [$attempt->getAttributes(), $second->getAttributes()];

        $this->travelTo(now()->addHour());

        $this->assertSame(0, $this->reconcile($homework));
        $this->assertSame($snapshots, [$attempt->fresh()->getAttributes(), $second->fresh()->getAttributes()]);
        $this->assertSame($homeworkBefore, $homework->fresh()->getAttributes());
    }

    public static function deadlineDelays(): array
    {
        return ['exact deadline' => [0], 'three minutes late' => [3]];
    }

    #[DataProvider('noOpHomeworkStates')]
    public function test_ineligible_homework_reconciliation_is_write_free(string $state, ?int $deadlineOffset): void
    {
        $homework = HomeworkAssignment::factory()->{$state}()->create([
            'deadline_at' => $deadlineOffset === null ? null : now()->addSeconds($deadlineOffset),
        ]);
        $attempt = $this->attempt($homework);
        $before = [$homework->fresh()->getAttributes(), $attempt->fresh()->getAttributes()];

        $this->assertSame(0, $this->reconcile($homework));
        $this->assertSame($before, [$homework->fresh()->getAttributes(), $attempt->fresh()->getAttributes()]);
    }

    public static function noOpHomeworkStates(): array
    {
        return [
            'before deadline' => ['active', 1],
            'no deadline' => ['active', null],
            'draft' => ['draft', -1],
            'closed' => ['closed', -1],
            'archived' => ['archivedFromDraft', -1],
        ];
    }

    public function test_due_homework_without_attempts_does_not_create_work_or_change_homework(): void
    {
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);
        $before = $homework->fresh()->getAttributes();

        $this->assertSame(0, $this->reconcile($homework));
        $this->assertSame($before, $homework->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('attempt_answers', 0);
    }

    public function test_missing_wrong_tenant_and_non_homework_aggregates_do_not_mutate_attempts(): void
    {
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $attempt = $this->attempt($homework);
        $before = $attempt->fresh()->getAttributes();
        $reconcile = app(FinalizeHomeworkAttemptsAtDeadline::class);
        $otherInstitution = Institution::factory()->create();
        $missingHomework = Assessment::factory()->homework()->create();
        $blitz = Assessment::factory()->blitz()->create();
        $blitzRecipient = AssessmentStudent::factory()->create(['assessment_id' => $blitz]);
        $blitzAttempt = AssessmentAttempt::factory()->create(['assessment_student_id' => $blitzRecipient]);
        $blitzBefore = $blitzAttempt->fresh()->getAttributes();

        $this->assertSame(0, $reconcile($otherInstitution->id, $homework->assessment_id));
        $this->assertSame(0, $reconcile($homework->institution_id, (string) Str::uuid()));
        $this->assertSame(0, $reconcile($missingHomework->institution_id, $missingHomework->id));
        $this->assertSame(0, $reconcile($blitz->institution_id, $blitz->id));
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertSame($blitzBefore, $blitzAttempt->fresh()->getAttributes());
    }

    #[DataProvider('terminalStates')]
    public function test_terminal_attempts_are_unchanged_by_both_finalizers_and_reconciliation(AssessmentAttemptStatus $status): void
    {
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $attempt = $this->attempt($homework);
        $attempt->update([
            'status' => $status,
            'submitted_at' => now(),
            'finalized_at' => now(),
            'locked_at' => now(),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
        ]);
        $before = $attempt->fresh()->getAttributes();
        $this->travelTo(now()->addHour());

        DB::transaction(function () use ($attempt): void {
            $locked = AssessmentAttempt::query()->whereKey($attempt->id)->lockForUpdate()->firstOrFail();
            $finalizer = app(HomeworkAttemptFinalizer::class);
            $this->assertFalse($finalizer->finalizeAtDeadline($locked, now()));
            $this->assertFalse($finalizer->finalizeAtClose($locked, now()));
        });

        $this->assertSame(0, $this->reconcile($homework));
        $this->assertSame($before, $attempt->fresh()->getAttributes());
    }

    public static function terminalStates(): array
    {
        return array_map(fn ($status) => [$status], array_values(array_filter(
            AssessmentAttemptStatus::cases(),
            fn ($status) => $status !== AssessmentAttemptStatus::InProgress,
        )));
    }

    #[DataProvider('inconsistentFields')]
    public function test_inconsistent_in_progress_attempt_rolls_back_prior_finalization_without_repair(string $field): void
    {
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $first = $this->attempt($homework, ['id' => '00000000-0000-4000-8000-000000000001']);
        $inconsistent = $this->attempt($homework, ['id' => '00000000-0000-4000-8000-000000000002']);
        $inconsistent->update([$field => $field === 'finalization_reason'
            ? AssessmentAttemptFinalizationReason::StudentSubmit : now()]);
        $before = [$first->fresh()->getAttributes(), $inconsistent->fresh()->getAttributes()];

        try {
            $this->reconcile($homework);
            $this->fail('Inconsistent in-progress work must fail as an internal invariant.');
        } catch (LogicException) {
            $this->assertSame($before, [$first->fresh()->getAttributes(), $inconsistent->fresh()->getAttributes()]);
        }
    }

    public static function inconsistentFields(): array
    {
        return array_map(fn ($field) => [$field], ['submitted_at', 'finalized_at', 'locked_at', 'finalization_reason']);
    }

    #[DataProvider('aggregateMismatches')]
    public function test_locked_finalization_validates_every_aggregate_before_any_transition(bool $foreignInstitution, bool $due): void
    {
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()->addSeconds($due ? 0 : 1)]);
        $valid = $this->attempt($homework);
        $otherAssessment = Assessment::factory()->homework()->create($foreignInstitution ? [] : [
            'institution_id' => $homework->institution_id,
            'topic_id' => $homework->assessment->topic_id,
            'teacher_id' => $homework->assessment->teacher_id,
        ]);
        $otherRecipient = AssessmentStudent::factory()->create(['assessment_id' => $otherAssessment]);
        $foreign = AssessmentAttempt::factory()->create(['assessment_student_id' => $otherRecipient]);
        $before = [$valid->fresh()->getAttributes(), $foreign->fresh()->getAttributes(), $homework->fresh()->getAttributes()];
        $attemptUpdates = [];
        DB::listen(function ($query) use (&$attemptUpdates): void {
            if (str_starts_with($query->sql, 'update "assessment_attempts"')) {
                $attemptUpdates[] = $query->sql;
            }
        });

        try {
            DB::transaction(function () use ($homework, $valid, $foreign): void {
                $lockedHomework = HomeworkAssignment::query()->whereKey($homework->assessment_id)->lockForUpdate()->firstOrFail();
                $lockedValid = AssessmentAttempt::query()->whereKey($valid->id)->lockForUpdate()->firstOrFail();
                $lockedForeign = AssessmentAttempt::query()->whereKey($foreign->id)->lockForUpdate()->firstOrFail();
                $lockedHomework->update(['updated_at' => now()->addMinute()]);
                app(FinalizeHomeworkAttemptsAtDeadline::class)->finalizeLocked($lockedHomework, collect([$lockedValid, $lockedForeign]), now());
            });
            $this->fail('A mismatching locked Attempt must fail as an internal invariant.');
        } catch (LogicException) {
            $this->assertSame([], $attemptUpdates);
            $this->assertSame($before, [$valid->fresh()->getAttributes(), $foreign->fresh()->getAttributes(), $homework->fresh()->getAttributes()]);
        }
    }

    public static function aggregateMismatches(): array
    {
        return ['another assessment' => [false, true], 'another institution' => [true, true], 'future deadline' => [true, false]];
    }

    private function attempt(HomeworkAssignment $homework, array $attributes = []): AssessmentAttempt
    {
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);

        return AssessmentAttempt::factory()->create(array_merge(['assessment_student_id' => $recipient], $attributes));
    }

    private function reconcile(HomeworkAssignment $homework): int
    {
        return app(FinalizeHomeworkAttemptsAtDeadline::class)($homework->institution_id, $homework->assessment_id);
    }
}
