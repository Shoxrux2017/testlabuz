<?php

namespace App\Actions\Institution;

use App\Enums\BlitzTimerStartMode;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class UpdateInstitutionAssessmentSettings
{
    public function __invoke(
        User $actor,
        string $acceptableScoreDifference,
        BlitzTimerStartMode $blitzTimerStartMode,
        StudentResultReleaseMode $studentResultReleaseMode,
        ParentResultReleaseMode $parentResultReleaseMode,
        string $timezone,
        int $learningMaterialMaxMb,
        int $studentSubmissionMaxMb,
    ): InstitutionSetting {
        if ($actor->institution_id === null) {
            throw new RuntimeException;
        }

        return DB::transaction(function () use (
            $actor,
            $acceptableScoreDifference,
            $blitzTimerStartMode,
            $studentResultReleaseMode,
            $parentResultReleaseMode,
            $timezone,
            $learningMaterialMaxMb,
            $studentSubmissionMaxMb,
        ): InstitutionSetting {
            $settings = InstitutionSetting::query()
                ->where('institution_id', $actor->institution_id)
                ->lockForUpdate()
                ->first();

            if (! $settings instanceof InstitutionSetting) {
                throw new RuntimeException;
            }

            $settings->forceFill([
                'acceptable_score_difference' => $acceptableScoreDifference,
                'blitz_timer_start_mode' => $blitzTimerStartMode,
                'student_result_release_mode' => $studentResultReleaseMode,
                'parent_result_release_mode' => $parentResultReleaseMode,
                'timezone' => $timezone,
                'learning_material_max_mb' => $learningMaterialMaxMb,
                'student_submission_max_mb' => $studentSubmissionMaxMb,
                'updated_by_user_id' => $actor->getKey(),
            ]);

            if (! $settings->isDirty()) {
                return $settings;
            }

            $settings->save();

            return $settings->refresh();
        });
    }
}
