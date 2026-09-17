<?php

namespace Tests\Feature\Blitz;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\QuestionType;
use App\Models\AnswerTextValue;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\Question;
use App\Support\Assessment\BlitzAttemptFinalizer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class BlitzTimeoutFinalizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('timeoutModes')]
    public function test_timeout_uses_the_exact_persisted_deadline_without_changing_saved_work(string $mode, int $delay): void
    {
        $deadline = now()->subSeconds($delay);
        $blitz = BlitzTask::factory()->{$mode}()->create([
            'created_at' => $deadline->copy()->subMinutes(11),
            'activated_at' => $deadline->copy()->subMinutes(10),
        ]);
        $attempt = $this->attempt($blitz, ['deadline_at' => $deadline]);
        $answer = AttemptAnswer::factory()->forQuestionType(QuestionType::OpenWritten)->create(['attempt_id' => $attempt]);
        $text = AnswerTextValue::factory()->create(['answer_id' => $answer, 'text_value' => '  My saved answer  ']);
        $unanswered = Question::factory()->openWritten()->create([
            'assessment_id' => $blitz->assessment_id, 'institution_id' => $blitz->institution_id, 'position' => 2,
        ]);
        $neverStarted = AssessmentStudent::factory()->create(['assessment_id' => $blitz->assessment_id]);
        $preservedModels = [$blitz, $blitz->assessment, $answer, $text, $unanswered, $neverStarted];
        $before = array_map(fn ($model) => $model->fresh()->getAttributes(), $preservedModels);
        $attemptBefore = $attempt->getAttributes();

        $this->assertSame(1, app(FinalizeTimedOutBlitzAttempts::class)($blitz->institution_id, $blitz->assessment_id));

        $frozen = $attempt->fresh();
        $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $frozen->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::TimeoutAutoSubmit, $frozen->finalization_reason);
        $this->assertNull($frozen->submitted_at);
        $this->assertTrue($frozen->finalized_at->equalTo($deadline));
        $this->assertTrue($frozen->locked_at->equalTo($deadline));
        foreach (['started_at', 'deadline_at', 'attempt_number', 'assessment_student_id', 'student_id',
            'official_score_eligible', 'possible_points', 'earned_points', 'normalized_score', 'scoring_completed_at'] as $field) {
            $this->assertSame($attemptBefore[$field], $frozen->getAttributes()[$field]);
        }
        $this->assertSame($before, array_map(fn ($model) => $model->fresh()->getAttributes(), $preservedModels));
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('attempt_answers', 1);
        $this->assertDatabaseMissing('attempt_answers', ['question_id' => $unanswered->id]);
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_student_id' => $neverStarted->id]);
    }

    public static function timeoutModes(): array
    {
        return [
            'synchronized equality' => ['activeSynchronized', 0],
            'synchronized delayed' => ['activeSynchronized', 180],
            'individual equality' => ['activeIndividual', 0],
            'individual delayed' => ['activeIndividual', 180],
        ];
    }

    public function test_mixed_individual_deadlines_are_evaluated_independently_and_repeated_calls_do_not_rewrite_history(): void
    {
        $blitz = BlitzTask::factory()->activeIndividual()->create();
        $past = $this->attempt($blitz, ['deadline_at' => now()->subMinutes(5)]);
        $equal = $this->attempt($blitz);
        $future = $this->attempt($blitz, ['deadline_at' => now()->addMinutes(5)]);
        $futureBefore = $future->getAttributes();
        $reconcile = app(FinalizeTimedOutBlitzAttempts::class);

        $this->assertSame(2, $reconcile($blitz->institution_id, $blitz->assessment_id));
        $this->assertSame($futureBefore, $future->fresh()->getAttributes());
        $frozenBefore = [$past->fresh()->getAttributes(), $equal->fresh()->getAttributes()];
        $this->travelTo(now()->addMinute());
        $this->assertSame(0, $reconcile($blitz->institution_id, $blitz->assessment_id));
        $this->assertSame($frozenBefore, [$past->fresh()->getAttributes(), $equal->fresh()->getAttributes()]);
        $this->assertSame($futureBefore, $future->fresh()->getAttributes());
    }

    public function test_timeout_does_not_assume_a_synchronized_attempt_matches_the_common_end(): void
    {
        $blitz = BlitzTask::factory()->activeSynchronized()->create();
        $attempt = $this->attempt($blitz);
        $this->assertTrue($blitz->synchronized_ends_at->gt($attempt->deadline_at));

        $this->assertSame(1, app(FinalizeTimedOutBlitzAttempts::class)($blitz->institution_id, $blitz->assessment_id));
        $this->assertTrue($attempt->fresh()->finalized_at->equalTo($attempt->deadline_at));
    }

    #[DataProvider('terminalStatuses')]
    public function test_terminal_attempts_are_unchanged_by_reconciliation_and_both_finalizers(AssessmentAttemptStatus $status): void
    {
        $blitz = BlitzTask::factory()->activeIndividual()->create();
        $attempt = $this->attempt($blitz, [
            'status' => $status,
            'submitted_at' => now()->subMinutes(2), 'finalized_at' => now()->subMinutes(2),
            'locked_at' => now()->subMinutes(2), 'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
        ]);
        $before = $attempt->getAttributes();
        $this->travelTo(now()->addHour());

        $this->assertSame(0, app(FinalizeTimedOutBlitzAttempts::class)($blitz->institution_id, $blitz->assessment_id));
        $this->assertFalse(app(BlitzAttemptFinalizer::class)->finalizeAtTimeout($attempt));
        $this->assertFalse(app(BlitzAttemptFinalizer::class)->finalizeAtClose($attempt, now()));
        $this->assertSame($before, $attempt->fresh()->getAttributes());
    }

    public static function terminalStatuses(): array
    {
        return array_map(fn ($status) => [$status], [
            AssessmentAttemptStatus::Submitted, AssessmentAttemptStatus::TimedOutFinalized,
            AssessmentAttemptStatus::WaitingForTeacherReview, AssessmentAttemptStatus::Checked,
        ]);
    }

    #[DataProvider('invalidAttemptFields')]
    public function test_invalid_attempt_history_rolls_back_the_entire_aggregate(string $field): void
    {
        $blitz = BlitzTask::factory()->activeIndividual()->create();
        $valid = $this->attempt($blitz, ['id' => '00000000-0000-4000-8000-000000000001']);
        $invalid = $this->attempt($blitz, ['id' => '00000000-0000-4000-8000-000000000002']);
        $invalid->update([$field => match ($field) {
            'deadline_at' => null,
            'started_at' => now(),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
            default => now(),
        }]);
        $before = [$valid->fresh()->getAttributes(), $invalid->fresh()->getAttributes(), $blitz->fresh()->getAttributes()];

        try {
            app(FinalizeTimedOutBlitzAttempts::class)($blitz->institution_id, $blitz->assessment_id);
            $this->fail('Corrupt in-progress history must fail reconciliation.');
        } catch (LogicException) {
            $this->assertSame($before, [$valid->fresh()->getAttributes(), $invalid->fresh()->getAttributes(), $blitz->fresh()->getAttributes()]);
        }
    }

    public static function invalidAttemptFields(): array
    {
        return array_map(fn ($field) => [$field], [
            'deadline_at', 'started_at', 'submitted_at', 'finalized_at', 'locked_at', 'finalization_reason',
        ]);
    }

    public function test_wrong_aggregate_integrity_failure_rolls_back_a_prior_transition(): void
    {
        $first = BlitzTask::factory()->activeIndividual()->create();
        $second = BlitzTask::factory()->activeIndividual()->create();
        $valid = $this->attempt($first);
        $foreign = $this->attempt($second);
        $before = [$valid->getAttributes(), $foreign->getAttributes()];
        $finalizer = app(BlitzAttemptFinalizer::class);

        try {
            DB::transaction(function () use ($first, $valid, $foreign, $finalizer): void {
                $locked = AssessmentAttempt::query()->whereKey([$valid->id, $foreign->id])->orderBy('id')->lockForUpdate()->get()->keyBy('id');
                $finalizer->finalizeAtTimeout($locked[$valid->id]);
                $finalizer->assertValidAttempt($locked[$foreign->id], $first->institution_id, $first->assessment_id);
            });
            $this->fail('The finalizer must reject a wrong aggregate.');
        } catch (LogicException) {
            $this->assertSame($before, [$valid->fresh()->getAttributes(), $foreign->fresh()->getAttributes()]);
        }
    }

    public function test_reconciler_scopes_institution_and_ignores_inactive_and_empty_blitz(): void
    {
        $active = BlitzTask::factory()->activeIndividual()->create();
        $attempt = $this->attempt($active);
        $foreign = BlitzTask::factory()->activeIndividual()->create();
        $reconcile = app(FinalizeTimedOutBlitzAttempts::class);
        $this->assertSame(0, $reconcile($foreign->institution_id, $active->assessment_id));
        $this->assertSame(0, $reconcile($foreign->institution_id, $foreign->assessment_id));
        $this->assertSame(AssessmentAttemptStatus::InProgress, $attempt->fresh()->status);

        foreach (['draft', 'scheduled', 'closedIndividual', 'archivedFromDraft'] as $state) {
            $blitz = BlitzTask::factory()->{$state}()->create();
            $ignored = $this->attempt($blitz);
            $before = $ignored->getAttributes();
            $this->assertSame(0, $reconcile($blitz->institution_id, $blitz->assessment_id));
            $this->assertSame($before, $ignored->fresh()->getAttributes());
        }
    }

    private function attempt(BlitzTask $blitz, array $attributes = []): AssessmentAttempt
    {
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $blitz->assessment_id]);

        return AssessmentAttempt::factory()->create(array_merge([
            'assessment_student_id' => $recipient,
            'started_at' => now()->subHour(), 'deadline_at' => now(), 'possible_points' => '4.000000',
        ], $attributes))->fresh();
    }
}
