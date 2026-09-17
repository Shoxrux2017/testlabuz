<?php

namespace App\Actions\Student;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Exceptions\Student\StudentBlitzTimeExpiredException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\User;
use App\Support\Files\LearningMaterialFileMetadata;
use App\Support\Student\StudentAttemptAnswerMutationResult;
use App\Support\Student\StudentBlitzAttemptAccess;
use App\Support\Student\StudentSubmissionAnswerFiles;
use Closure;
use Illuminate\Http\UploadedFile;
use LogicException;

final class SaveStudentBlitzFileAnswer
{
    public function __construct(
        private readonly StudentBlitzAttemptAccess $access,
        private readonly StudentSubmissionAnswerFiles $files,
        private readonly FinalizeTimedOutBlitzAttempts $finalizeTimeouts,
    ) {}

    public function __invoke(User $student, string $attemptId, string $questionId, UploadedFile $upload): StudentAttemptAnswerMutationResult
    {
        $preliminaryAttempt = $this->access->resolveAttempt($student, $attemptId);
        $this->files->resolveQuestion($student, $preliminaryAttempt->assessment_id, $questionId);
        $preliminaryAssessment = Assessment::query()
            ->select(['id', 'topic_id'])->where('institution_id', $student->institution_id)
            ->whereKey($preliminaryAttempt->assessment_id)->firstOrFail();

        $result = $this->files->withStagedUpload($student, $preliminaryAttempt, $questionId, $upload,
            function (LearningMaterialFileMetadata $metadata, string $diskName, string $storageKey, Closure $cleanupNewBlob) use ($student, $preliminaryAssessment, $preliminaryAttempt, $questionId): ?StudentAttemptAnswerMutationResult {
                ['topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] = $this->access->shareBlitzForAnswer($student, $preliminaryAssessment);
                $attempt = AssessmentAttempt::query()
                    ->where('institution_id', $student->institution_id)->where('student_id', $student->id)
                    ->whereKey($preliminaryAttempt->id)->lockForUpdate()->first();
                $question = $this->files->resolveQuestion($student, $assessment->id, $questionId, lock: true);

                if ($attempt === null) {
                    throw new LogicException('The authorized Blitz Attempt changed its identity.');
                }

                $answer = AttemptAnswer::query()->where('attempt_id', $attempt->id)
                    ->where('question_id', $question->id)->lockForUpdate()->first();
                try {
                    $this->access->assertAnswerEditable($student, $topic, $assessment, $blitz, $attempt);
                } catch (StudentBlitzTimeExpiredException) {
                    return null;
                }

                return $this->files->save($student, $attempt, $question, $answer, $metadata, $diskName, $storageKey, $cleanupNewBlob);
            });

        if ($result === null) {
            // withStagedUpload compensates the new blob before aggregate reconciliation.
            ($this->finalizeTimeouts)($student->institution_id, $preliminaryAssessment->id);

            throw new StudentBlitzTimeExpiredException;
        }

        return $result;
    }
}
