<?php

namespace Tests\Feature\Student\Concerns;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzAttemptException;
use App\Models\GroupTeacherMembership;
use App\Models\User;
use Illuminate\Testing\TestResponse;

trait BuildsBlitzExceptionContext
{
    use BuildsStudentBlitzContext;

    protected function exceptionContext(string $mode = 'individual', bool $terminal = true): array
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        $teacher = $assessment->teacher;
        $teacher->update(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $student->institution_id, 'group_id' => $assessment->topic->group_id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $teacher->id,
        ]);
        $normal = $this->studentBlitzAttempt($assessment, $student);
        if ($terminal) {
            $this->terminateStudentBlitzAttempt($normal);
        }

        return [$student, $assessment, $normal->fresh(), $teacher];
    }

    protected function grantException(User $teacher, Assessment $assessment, User $student, ?string $key = '', array $body = []): TestResponse
    {
        return $this->studentBlitzRequest($teacher, 'POST',
            '/api/v1/teacher/blitz/'.$assessment->id.'/students/'.$student->id.'/attempt-exception',
            json_encode($body ?: ['reason_type' => 'technical', 'reason' => 'Device interruption.'], JSON_THROW_ON_ERROR), $key);
    }

    protected function replacementContext(string $mode = 'individual'): array
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext($mode);
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        $response = $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertCreated();
        $replacement = AssessmentAttempt::query()->findOrFail($response->json('data.id'));

        return [$student, $assessment, $normal->fresh(), $teacher, $replacement, BlitzAttemptException::query()->sole()];
    }
}
