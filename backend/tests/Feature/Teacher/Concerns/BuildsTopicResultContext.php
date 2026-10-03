<?php

namespace Tests\Feature\Teacher\Concerns;

use App\Enums\TopicResultClosureReason;
use App\Enums\TopicResultOutcome;
use App\Enums\TopicResultSideState;
use App\Enums\UnderstandingCategoryCode as Code;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\OfficialTaskScore;
use App\Models\TopicResult;
use App\Models\TopicResultPair;
use App\Models\User;

/**
 * An active Topic of the submission context with a closed official Homework and a closed official Blitz
 * paired and snapshotted, a configured threshold of 10, manual release modes and the 86/71/51/0 bands.
 */
trait BuildsTopicResultContext
{
    use BuildsTeacherSubmissionContext;

    protected Assessment $homework;

    protected Assessment $blitz;

    protected function topicResultContext(): void
    {
        $this->submissionContext();
        $this->teacher->update(['must_change_password' => false]);
        $this->homework = $this->homeworkTask();
        $this->blitz = $this->blitzTask();
        TopicResultPair::factory()->create([
            'homework_assessment_id' => $this->homework->id, 'blitz_assessment_id' => $this->blitz->id,
            'designated_by_user_id' => $this->teacher->id, 'designated_at' => now()->subHours(3), 'cohort_snapshotted_at' => now()->subHours(2),
        ]);
        InstitutionSetting::query()->where('institution_id', $this->institution->id)->update([
            'acceptable_score_difference' => '10.00000000', 'blitz_timer_start_mode' => 'individual',
            'student_result_release_mode' => 'manual_teacher', 'parent_result_release_mode' => 'manual_teacher',
        ]);

        foreach ([[Code::UnderstoodWell, 86, 100], [Code::PartiallyUnderstood, 71, 85], [Code::NeedsRevision, 51, 70],
            [Code::NeedsTeacherSupport, 0, 50], [Code::NotCompleted, null, null]] as [$code, $min, $max]) {
            InstitutionUnderstandingCategory::factory()->forInstitution($this->institution, $this->admin)->forCode($code, $min, $max)->create();
        }
    }

    protected function releaseModes(?string $studentMode, ?string $parentMode): void
    {
        InstitutionSetting::query()->where('institution_id', $this->institution->id)->update([
            'student_result_release_mode' => $studentMode, 'parent_result_release_mode' => $parentMode,
        ]);
    }

    /** A Student of the group who is a recipient of both official tasks. */
    protected function cohortStudent(string $name): User
    {
        $student = $this->studentNamed($name);
        $this->blitzRecipient($this->homework, $student, $this->teacher);
        $this->blitzRecipient($this->blitz, $student, $this->teacher);

        return $student;
    }

    protected function readyStudent(string $name, string $homeworkScore, string $blitzScore): User
    {
        $student = $this->cohortStudent($name);
        $this->officialAttempt($this->homework, $student, $homeworkScore);
        $this->officialAttempt($this->blitz, $student, $blitzScore);

        return $student;
    }

    protected function officialAttempt(Assessment $task, User $student, string $score): AssessmentAttempt
    {
        $attempt = $this->submission($task, $student, 'checked', ['normalized_score' => $score, 'earned_points' => '0.00000000']);
        OfficialTaskScore::factory()->create(['official_attempt_id' => $attempt->id]);

        return $attempt;
    }

    /**
     * A calculated result the Teacher closed: H 88, B 84, T 12 used, average 86.
     *
     * @param  array<string, mixed>  $attributes
     */
    protected function closedRow(User $student, array $attributes): TopicResult
    {
        $attempts = AssessmentAttempt::query()->where('student_id', $student->id)->get()->keyBy('assessment_id');

        return TopicResult::factory()->create([
            'institution_id' => $this->institution->id, 'topic_id' => $this->topic->id, 'student_id' => $student->id,
            'closed_at' => now()->subMinutes(30), 'closed_by_user_id' => $this->teacher->id, 'closure_reason' => TopicResultClosureReason::Teacher,
            'closed_outcome' => TopicResultOutcome::Calculated, 'homework_assessment_id' => $this->homework->id, 'blitz_assessment_id' => $this->blitz->id,
            'homework_state' => TopicResultSideState::Ready, 'blitz_state' => TopicResultSideState::Ready,
            'homework_attempt_id' => $attempts[$this->homework->id]->id, 'homework_score' => '88.00000000',
            'blitz_attempt_id' => $attempts[$this->blitz->id]->id, 'blitz_score' => '84.00000000',
            'score_difference' => '4.00000000', 'acceptable_difference_used' => '12.00000000', 'calculation_method' => 'average',
            'consistency' => 'consistent', 'final_score' => '86.00000000', 'category_score' => 86, 'category_code' => 'understood_well',
            'category_min_score_used' => 86, 'category_max_score_used' => 100,
            ...$attributes,
        ]);
    }
}
