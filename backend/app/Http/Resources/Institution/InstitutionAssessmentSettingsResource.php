<?php

namespace App\Http\Resources\Institution;

use App\Actions\Platform\CreatePlatformInstitution;
use App\Models\InstitutionSetting;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin InstitutionSetting
 */
class InstitutionAssessmentSettingsResource extends JsonResource
{
    private const HOMEWORK_NORMAL_ATTEMPTS = 3;

    private const BLITZ_NORMAL_ATTEMPTS = 1;

    private const BLITZ_MAX_ADDITIONAL_EXCEPTION_ATTEMPTS = 1;

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'educational_policy_configured' => $this->educationalPolicyConfigured(),
            'acceptable_score_difference' => $this->acceptable_score_difference === null
                ? null
                : (float) $this->acceptable_score_difference,
            'blitz_timer_start_mode' => $this->blitz_timer_start_mode?->value,
            'student_result_release_mode' => $this->student_result_release_mode?->value,
            'parent_result_release_mode' => $this->parent_result_release_mode?->value,
            'timezone' => $this->timezone,
            'upload_limits' => [
                'learning_material_max_mb' => $this->learning_material_max_mb,
                'student_submission_max_mb' => $this->student_submission_max_mb,
                'platform_learning_material_max_mb' => CreatePlatformInstitution::DEFAULT_LEARNING_MATERIAL_MAX_MB,
                'platform_student_submission_max_mb' => CreatePlatformInstitution::DEFAULT_STUDENT_SUBMISSION_MAX_MB,
            ],
            'fixed_attempt_rules' => [
                'homework_normal_attempts' => self::HOMEWORK_NORMAL_ATTEMPTS,
                'blitz_normal_attempts' => self::BLITZ_NORMAL_ATTEMPTS,
                'blitz_max_additional_exception_attempts' => self::BLITZ_MAX_ADDITIONAL_EXCEPTION_ATTEMPTS,
            ],
        ];
    }

    private function educationalPolicyConfigured(): bool
    {
        return $this->acceptable_score_difference !== null
            && $this->blitz_timer_start_mode !== null
            && $this->student_result_release_mode !== null
            && $this->parent_result_release_mode !== null;
    }
}
