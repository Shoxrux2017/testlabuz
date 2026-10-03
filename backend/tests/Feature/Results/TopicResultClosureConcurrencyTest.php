<?php

namespace Tests\Feature\Results;

use App\Actions\Student\StartStudentHomeworkAttempt;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\HomeworkStatus;
use App\Models\AnswerTextValue;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\HomeworkAssignment;
use App\Models\InstitutionSetting;
use App\Models\OfficialTaskScore;
use App\Models\Question;
use App\Models\TopicResult;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Feature\Results\Concerns\RunsLockRaceWorkers;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTopicResultContext;
use Tests\TestCase;

/**
 * S10-BE-004 closure races (docs/07 §33, S10-T6): closure serializes on the Topic with scoring and
 * Teacher actions, and on the official Attempts with the finalizers that never take the Topic; the
 * official Blitz activation serializes on the Topic with a Homework Submit.
 */
class TopicResultClosureConcurrencyTest extends TestCase
{
    use BuildsTopicResultContext;
    use RunsLockRaceWorkers;
    use UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $this->travelTo(Carbon::parse('2026-10-05 10:00:00 UTC'));
    }

    public function test_a_closure_waiting_for_a_review_correction_snapshots_the_corrected_score(): void
    {
        $this->topicResultContext();
        [$student, $attempt, $answer] = $this->correctableStudent();

        [$review, $close] = $this->lockRace(
            $this->raceInput('review', ['actor' => $this->teacher->id, 'attempt' => $attempt->id, 'items' => [
                ['answer_id' => $answer->id, 'awarded_points' => 4, 'feedback' => 'Complete.']], 'hold' => ['table' => 'assessment_students', 'lock' => 'for update']]),
            $this->raceInput('close_result', ['actor' => $this->teacher->id, 'topic' => $this->topic->id, 'student' => $student->id]),
            'topics',
        );

        $this->assertSame([['outcome' => 'ok', 'status' => 'checked'], ['outcome' => 'ok', 'status' => 'closed']],
            [$this->withoutEvent($review), $this->withoutEvent($close)]);
        // H 100 against B 80 differ by more than T 10, so the Blitz score counts.
        $this->assertSame(['100.00000000', '80.00000000', 'blitz', '80.00000000'], $this->closedValues($student));
    }

    public function test_a_review_correction_waiting_for_a_closure_is_refused_as_result_closed(): void
    {
        $this->topicResultContext();
        [$student, $attempt, $answer] = $this->correctableStudent();

        [$close, $review] = $this->lockRace(
            $this->raceInput('close_result', ['actor' => $this->teacher->id, 'topic' => $this->topic->id, 'student' => $student->id,
                'hold' => ['table' => 'topics', 'lock' => 'for update']]),
            $this->raceInput('review', ['actor' => $this->teacher->id, 'attempt' => $attempt->id, 'items' => [
                ['answer_id' => $answer->id, 'awarded_points' => 4, 'feedback' => 'Complete.']]]),
            'topics',
        );

        $this->assertSame([['outcome' => 'ok', 'status' => 'closed'], ['outcome' => 'result_closed']],
            [$this->withoutEvent($close), $this->withoutEvent($review)]);
        // H 75 and B 80 are within T 10: the average 77.5 stays frozen and the answer keeps its points.
        $this->assertSame(['75.00000000', '80.00000000', 'average', '77.50000000'], $this->closedValues($student));
        $this->assertSame('3.00000000', $answer->fresh()->awarded_points);
    }

    public function test_a_closure_waits_for_the_homework_deadline_finalizer_and_closes_the_committed_state(): void
    {
        $this->topicResultContext();
        $this->homework->homeworkAssignment->update(['status' => HomeworkStatus::Active, 'closed_at' => null, 'deadline_at' => now()->subMinute()]);
        $student = $this->cohortStudent('Alpha Student');
        $attempt = $this->submission($this->homework, $student, 'in_progress');

        [$finalizer, $close] = $this->lockRace(
            $this->raceInput('finalize_homework_deadline', ['institution' => $this->institution->id, 'assessment' => $this->homework->id,
                'hold' => ['table' => 'assessment_attempts', 'lock' => 'for update']]),
            $this->raceInput('close_result', ['actor' => $this->teacher->id, 'topic' => $this->topic->id, 'student' => $student->id]),
            'assessment_attempts',
        );

        // Read before the finalizer's commit, the in-progress Attempt would have made the result unclosable.
        $this->assertSame([['outcome' => 'ok', 'finalized' => 1], ['outcome' => 'ok', 'status' => 'closed']],
            [$this->withoutEvent($finalizer), $this->withoutEvent($close)]);
        $this->assertSame(AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit, $attempt->fresh()->finalization_reason);
        $row = TopicResult::query()->sole();
        $this->assertSame(['not_completed', 'blitz', 'checking', 'missing'], [$row->closed_outcome->value, $row->missing_component->value,
            $row->homework_state->value, $row->blitz_state->value]);
    }

    public function test_the_official_blitz_activation_waits_for_a_homework_submit_and_then_closes_the_homework(): void
    {
        $this->submissionContext();
        $this->teacher->update(['must_change_password' => false]);
        InstitutionSetting::query()->where('institution_id', $this->institution->id)->update(['blitz_timer_start_mode' => 'synchronized']);
        $homework = $this->persistedHomework($this->institution, $this->teacher, $this->topic);
        $blitz = $this->persistedBlitz($this->institution, $this->teacher, $this->topic);
        foreach ([$homework, $blitz] as $task) {
            app(QuestionConfigurationWriter::class)->create($task, ['type' => 'true_false', 'prompt' => 'Is this statement correct?',
                'instructions' => null, 'points' => '2.000000', 'position' => 1, 'checking_mode' => 'automatic',
                'configuration' => ['correct_value' => true]]);
        }
        TopicResultPair::factory()->create(['homework_assessment_id' => $homework->id, 'blitz_assessment_id' => $blitz->id,
            'designated_by_user_id' => $this->teacher->id]);
        $student = $this->studentNamed('Alpha Student');
        $this->homeworkRaw($this->teacher, 'POST', "/api/v1/teacher/homework/{$homework->id}/activate", '')->assertOk();
        $this->travel(5)->minutes();
        $attemptId = app(StartStudentHomeworkAttempt::class)($student, $homework->id, (string) Str::uuid())->attemptId;
        $this->travel(5)->minutes();

        [$submit, $activation] = $this->lockRace(
            $this->raceInput('submit_homework', ['actor' => $student->id, 'attempt' => $attemptId, 'key' => (string) Str::uuid(),
                'hold' => ['table' => 'assessment_attempts', 'lock' => 'for update']]),
            $this->raceInput('activate_blitz', ['actor' => $this->teacher->id, 'assessment' => $blitz->id, 'key' => (string) Str::uuid()]),
            'topics',
        );

        $this->assertSame([['outcome' => 'ok'], ['outcome' => 'ok', 'status' => 'active']],
            [$this->withoutEvent($submit), $this->withoutEvent($activation)]);
        $this->assertSame(HomeworkStatus::Closed, HomeworkAssignment::query()->findOrFail($homework->id)->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::StudentSubmit, AssessmentAttempt::query()->findOrFail($attemptId)->finalization_reason);
    }

    /**
     * A cohort Student whose official Homework #1 is checked at 3 of 4 points (75) through a reviewed
     * written answer, so a review of that answer is a correction; the official Blitz is checked at 80.
     *
     * @return array{User, AssessmentAttempt, AttemptAnswer}
     */
    private function correctableStudent(): array
    {
        $student = $this->cohortStudent('Alpha Student');
        $question = Question::factory()->openWritten()->create(['institution_id' => $this->institution->id,
            'assessment_id' => $this->homework->id, 'position' => 1, 'points' => '4.000000']);
        $attempt = $this->submission($this->homework, $student, 'checked', ['possible_points' => '4.000000',
            'earned_points' => '3.00000000', 'normalized_score' => '75.00000000']);
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        AnswerTextValue::factory()->create(['answer_id' => $answer->id, 'text_value' => 'DNS resolves names.']);
        DB::table('attempt_answers')->where('id', $answer->id)->update(['checking_status' => 'teacher_checked',
            'awarded_points' => '3.00000000', 'feedback' => 'Partly.', 'checked_by_user_id' => $this->teacher->id, 'checked_at' => now()]);
        OfficialTaskScore::factory()->create(['official_attempt_id' => $attempt->id]);
        $this->officialAttempt($this->blitz, $student, '80.00000000');

        return [$student, $attempt, $answer];
    }

    /** @return list<?string> H, B, method and final score of the Student's closed result */
    private function closedValues(User $student): array
    {
        $row = TopicResult::query()->where('student_id', $student->id)->sole();

        return [$row->homework_score, $row->blitz_score, $row->calculation_method?->value, $row->final_score];
    }

    /** @return array<string, mixed> */
    private function withoutEvent(array $result): array
    {
        unset($result['event']);

        return $result;
    }
}
