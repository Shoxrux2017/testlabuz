<?php

namespace Tests\Feature\Teacher\Concerns;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\BlitzStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Group;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;

trait BuildsTeacherSubmissionContext
{
    use BuildsTeacherBlitzContext, BuildsTeacherHomeworkContext;

    protected Institution $institution;

    protected User $teacher;

    protected User $admin;

    protected Group $group;

    protected Topic $topic;

    protected function submissionContext(): void
    {
        [$this->institution, $this->teacher, $this->admin, $this->group, $this->topic] = $this->homeworkContext(TopicStatus::Active);
    }

    protected function homeworkTask(array $homeworkAttributes = [], array $assessmentAttributes = [], ?Topic $topic = null): Assessment
    {
        return $this->persistedHomework($this->institution, $this->teacher, $topic ?? $this->topic,
            AssessmentAssignmentMode::Group, HomeworkStatus::Closed, $assessmentAttributes, $homeworkAttributes);
    }

    protected function blitzTask(?Topic $topic = null): Assessment
    {
        return $this->persistedBlitz($this->institution, $this->teacher, $topic ?? $this->topic,
            AssessmentAssignmentMode::Group, BlitzStatus::Closed);
    }

    protected function studentNamed(string $fullName): User
    {
        return $this->eligibleStudent($this->institution, $this->admin, $this->group, ['full_name' => $fullName]);
    }

    /** A terminal (or in-progress) Attempt with its recipient; scores are set for `checked` Attempts. */
    protected function submission(Assessment $assessment, User $student, string $status, array $attributes = []): AssessmentAttempt
    {
        $terminal = $status !== 'in_progress';
        $finalizedAt = Carbon::parse($attributes['finalized_at'] ?? now()->subHour());

        return $this->blitzAttempt($assessment, $student, $this->teacher, array_merge([
            'attempt_number' => AssessmentAttempt::query()->where('assessment_id', $assessment->id)
                ->where('student_id', $student->id)->count() + 1,
            'status' => $status,
            'started_at' => $finalizedAt->copy()->subHour(),
            'submitted_at' => $terminal ? $finalizedAt : null,
            'finalized_at' => $terminal ? $finalizedAt : null,
            'locked_at' => $terminal ? $finalizedAt : null,
            'finalization_reason' => $terminal ? 'student_submit' : null,
            'possible_points' => '20.000000',
            'earned_points' => $status === 'checked' ? '15.00000000' : null,
            'normalized_score' => $status === 'checked' ? '75.00000000' : null,
            'scoring_completed_at' => $status === 'checked' ? now()->subMinutes(30) : null,
        ], $attributes))->fresh();
    }

    protected function answerInState(AssessmentAttempt $attempt, string $status, ?string $awarded = null, ?User $reviewer = null): AttemptAnswer
    {
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id]);
        DB::table('attempt_answers')->where('id', $answer->id)->update([
            'checking_status' => $status, 'awarded_points' => $awarded,
            'checked_by_user_id' => $reviewer?->id,
            'checked_at' => in_array($status, ['pending', 'waiting_for_teacher_review'], true) ? null : now()->subMinutes(10),
        ]);

        return $answer->fresh();
    }

    protected function submissionsRequest(User $teacher, array $query = [], string $body = ''): TestResponse
    {
        return $this->homeworkRaw($teacher, 'GET', '/api/v1/teacher/submissions', $body, $query);
    }
}
