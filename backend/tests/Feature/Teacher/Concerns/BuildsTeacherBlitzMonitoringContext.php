<?php

namespace Tests\Feature\Teacher\Concerns;

use App\Enums\BlitzStatus;
use App\Models\Assessment;
use App\Models\GroupTeacherMembership;
use App\Models\User;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;

trait BuildsTeacherBlitzMonitoringContext
{
    use BuildsBlitzExceptionContext;

    protected function monitoringContext(string $mode = 'individual', BlitzStatus $status = BlitzStatus::Active): array
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode, $status);
        $teacher = $assessment->teacher;
        $teacher->update(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $student->institution_id, 'group_id' => $assessment->topic->group_id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $teacher->id,
        ]);

        return [$student, $assessment, $teacher];
    }

    protected function monitor(User $teacher, Assessment $assessment): TestResponse
    {
        return $this->studentBlitzRequest($teacher, 'GET', '/api/v1/teacher/blitz/'.$assessment->id.'/monitoring');
    }

    protected function assertMonitoringPartition(TestResponse $response): void
    {
        $rows = collect($response->json('data.students'));
        $summary = $response->json('data.summary');
        $this->assertSame($rows->count(), $summary['assigned']);
        foreach (['not_started', 'in_progress', 'finalized', 'waiting_for_teacher_review'] as $status) {
            $this->assertSame($rows->where('status', $status)->count(), $summary[$status]);
        }
        $this->assertSame($rows->whereNotNull('attempt_exception')->count(), $summary['attempt_exceptions_granted']);
        $this->assertSame($summary['assigned'], $summary['not_started'] + $summary['in_progress']
            + $summary['finalized'] + $summary['waiting_for_teacher_review']);
    }
}
