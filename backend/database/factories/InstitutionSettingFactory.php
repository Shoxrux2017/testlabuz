<?php

namespace Database\Factories;

use App\Enums\BlitzTimerStartMode;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<InstitutionSetting>
 */
class InstitutionSettingFactory extends Factory
{
    public function definition(): array
    {
        return [
            'institution_id' => Institution::factory(),
            'acceptable_score_difference' => null,
            'blitz_timer_start_mode' => null,
            'student_result_release_mode' => null,
            'parent_result_release_mode' => null,
            'timezone' => 'Asia/Tashkent',
            'learning_material_max_mb' => 25,
            'student_submission_max_mb' => 15,
            'updated_by_user_id' => null,
        ];
    }

    public function configuredEducationalPolicy(): static
    {
        return $this->state(fn (array $attributes) => [
            'acceptable_score_difference' => '10.00000000',
            'blitz_timer_start_mode' => BlitzTimerStartMode::Synchronized,
            'student_result_release_mode' => StudentResultReleaseMode::Automatic,
            'parent_result_release_mode' => ParentResultReleaseMode::WithStudent,
        ]);
    }

    public function uploadLimits(int $learningMaterialMaxMb, int $studentSubmissionMaxMb): static
    {
        return $this->state(fn (array $attributes) => [
            'learning_material_max_mb' => $learningMaterialMaxMb,
            'student_submission_max_mb' => $studentSubmissionMaxMb,
        ]);
    }
}
