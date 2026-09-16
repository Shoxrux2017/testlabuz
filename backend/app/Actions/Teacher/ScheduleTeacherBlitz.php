<?php

namespace App\Actions\Teacher;

use App\Enums\BlitzStatus;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\User;
use App\Support\Teacher\InstitutionBlitzScheduledAt;
use App\Support\Teacher\TeacherBlitzAccess;
use App\Support\Teacher\TeacherBlitzPreparationGuard;
use Illuminate\Support\Facades\DB;

final class ScheduleTeacherBlitz
{
    public function __construct(
        private readonly TeacherBlitzAccess $access,
        private readonly TeacherBlitzPreparationGuard $preparation,
        private readonly InstitutionBlitzScheduledAt $scheduledAt,
        private readonly ShowTeacherBlitz $showTeacherBlitz,
    ) {}

    /** @param array{scheduled_at: string} $attributes */
    public function __invoke(User $teacher, string $blitzId, array $attributes): Assessment
    {
        $preliminaryAssessment = $this->access->resolveBlitz($teacher, $blitzId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment, $attributes): Assessment {
            ['topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] =
                $this->access->lockBlitz($teacher, $preliminaryAssessment);
            $this->preparation->ensureEditable($blitz, $topic);

            if ($this->access->lockAttempts($teacher, $assessment)->isNotEmpty()) {
                throw new BusinessConflictException;
            }

            $transitionedAt = now();
            $scheduledAt = $this->scheduledAt->requireFuture($teacher, $attributes['scheduled_at'], $transitionedAt);

            if ($blitz->status === BlitzStatus::Scheduled && $blitz->scheduled_at->equalTo($scheduledAt)) {
                return ($this->showTeacherBlitz)($teacher, $assessment->id);
            }

            $blitz->status = BlitzStatus::Scheduled;
            $blitz->scheduled_at = $scheduledAt;
            $blitz->updated_at = $transitionedAt;
            $blitz->save();
            $assessment->updated_at = $transitionedAt;
            $assessment->save();

            return ($this->showTeacherBlitz)($teacher, $assessment->id);
        });
    }
}
