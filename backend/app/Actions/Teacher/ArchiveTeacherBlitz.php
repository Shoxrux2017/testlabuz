<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\User;
use App\Support\Teacher\TeacherBlitzAccess;
use Illuminate\Support\Facades\DB;

final class ArchiveTeacherBlitz
{
    public function __construct(
        private readonly TeacherBlitzAccess $access,
        private readonly ShowTeacherBlitz $showTeacherBlitz,
    ) {}

    public function __invoke(User $teacher, string $blitzId): Assessment
    {
        $preliminaryAssessment = $this->access->resolveBlitz($teacher, $blitzId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment): Assessment {
            ['topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] =
                $this->access->lockBlitz($teacher, $preliminaryAssessment);

            if ($blitz->status === BlitzStatus::Archived) {
                return ($this->showTeacherBlitz)($teacher, $assessment->id);
            }

            if ($blitz->status === BlitzStatus::Active) {
                throw new BusinessConflictException;
            }

            $pair = $this->access->lockResultPair($teacher, $topic, $assessment);
            $isPreparation = in_array($blitz->status, [BlitzStatus::Draft, BlitzStatus::Scheduled], true);

            if ($isPreparation && $pair?->blitz_assessment_id === $assessment->id) {
                throw new BusinessConflictException;
            }

            $attempts = $this->access->lockAttempts($teacher, $assessment);

            if (($isPreparation && $attempts->isNotEmpty())
                || ($blitz->status === BlitzStatus::Closed && $attempts->contains(
                    fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::InProgress,
                ))) {
                throw new BusinessConflictException;
            }

            $archivedAt = now();
            $blitz->status = BlitzStatus::Archived;
            $blitz->archived_at = $archivedAt;
            $blitz->updated_at = $archivedAt;
            $blitz->save();
            $assessment->updated_at = $archivedAt;
            $assessment->save();

            return ($this->showTeacherBlitz)($teacher, $assessment->id);
        });
    }
}
