<?php

namespace App\Actions\Student;

use App\Enums\AssessmentType;
use App\Models\User;
use App\Support\Student\StudentAttemptAnswerMutationResult;
use App\Support\Student\StudentAttemptTarget;
use Illuminate\Http\UploadedFile;
use LogicException;

final class SaveStudentAttemptAnswer
{
    public function __construct(
        private readonly StudentAttemptTarget $target,
        private readonly SaveStudentHomeworkAttemptAnswer $homeworkAnswer,
        private readonly SaveStudentHomeworkFileAnswer $homeworkFile,
        private readonly SaveStudentBlitzAttemptAnswer $blitzAnswer,
        private readonly SaveStudentBlitzFileAnswer $blitzFile,
    ) {}

    /** @param array<string, mixed> $payload */
    public function __invoke(User $student, string $attemptId, string $questionId, array $payload, ?UploadedFile $upload = null): StudentAttemptAnswerMutationResult
    {
        $assessmentType = $this->target->resolve($student, $attemptId);

        if ($payload['type'] === 'file_based') {
            if ($upload === null) {
                throw new LogicException('A validated file answer requires an uploaded file.');
            }

            return match ($assessmentType) {
                AssessmentType::Homework => ($this->homeworkFile)($student, $attemptId, $questionId, $upload),
                AssessmentType::Blitz => ($this->blitzFile)($student, $attemptId, $questionId, $upload),
            };
        }

        return match ($assessmentType) {
            AssessmentType::Homework => ($this->homeworkAnswer)($student, $attemptId, $questionId, $payload),
            AssessmentType::Blitz => ($this->blitzAnswer)($student, $attemptId, $questionId, $payload),
        };
    }
}
