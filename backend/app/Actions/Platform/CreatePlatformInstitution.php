<?php

namespace App\Actions\Platform;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class CreatePlatformInstitution
{
    public const DEFAULT_TIMEZONE = 'Asia/Tashkent';

    public const DEFAULT_LEARNING_MATERIAL_MAX_MB = 25;

    public const DEFAULT_STUDENT_SUBMISSION_MAX_MB = 15;

    public function __invoke(
        User $actor,
        string $name,
        InstitutionType $type,
        InstitutionStatus $status,
        ?string $contactEmail,
        ?string $contactPhone,
        ?string $address,
        ?string $description,
    ): Institution {
        return DB::transaction(function () use (
            $actor,
            $name,
            $type,
            $status,
            $contactEmail,
            $contactPhone,
            $address,
            $description,
        ): Institution {
            $institution = Institution::query()->create([
                'name' => $name,
                'type' => $type,
                'status' => $status,
                'contact_email' => $contactEmail,
                'contact_phone' => $contactPhone,
                'address' => $address,
                'description' => $description,
                'created_by_user_id' => $actor->getKey(),
                'deactivated_at' => $status === InstitutionStatus::Inactive ? now() : null,
            ]);

            InstitutionSetting::query()->create([
                'institution_id' => $institution->getKey(),
                'acceptable_score_difference' => null,
                'blitz_timer_start_mode' => null,
                'student_result_release_mode' => null,
                'parent_result_release_mode' => null,
                'timezone' => self::DEFAULT_TIMEZONE,
                'learning_material_max_mb' => self::DEFAULT_LEARNING_MATERIAL_MAX_MB,
                'student_submission_max_mb' => self::DEFAULT_STUDENT_SUBMISSION_MAX_MB,
                'updated_by_user_id' => null,
            ]);

            return $institution->refresh();
        });
    }
}
