<?php

namespace Tests\Feature\Student\Concerns;

use App\Models\BlitzTask;

trait BuildsStudentBlitzAnswerContext
{
    use BuildsStudentBlitzContext, BuildsStudentHomeworkAnswerContext;

    protected function answerContext(string $timerMode = 'individual'): array
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $timerMode, assessmentAttributes: ['total_possible_points' => '8.000000']);
        $attempt = $this->studentBlitzAttempt($assessment, $student);

        return [$student, BlitzTask::query()->findOrFail($assessment->id), $attempt];
    }
}
