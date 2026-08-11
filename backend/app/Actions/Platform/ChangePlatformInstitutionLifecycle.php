<?php

namespace App\Actions\Platform;

use App\Enums\InstitutionStatus;
use App\Models\Institution;
use Illuminate\Support\Facades\DB;

class ChangePlatformInstitutionLifecycle
{
    public function activate(Institution $institution): Institution
    {
        return $this->transitionTo($institution, InstitutionStatus::Active);
    }

    public function deactivate(Institution $institution): Institution
    {
        return $this->transitionTo($institution, InstitutionStatus::Inactive);
    }

    private function transitionTo(Institution $institution, InstitutionStatus $targetStatus): Institution
    {
        return DB::transaction(function () use ($institution, $targetStatus): Institution {
            /** @var Institution $lockedInstitution */
            $lockedInstitution = Institution::query()
                ->whereKey($institution->getKey())
                ->lockForUpdate()
                ->firstOrFail();

            if ($lockedInstitution->status === $targetStatus) {
                return $lockedInstitution;
            }

            $lockedInstitution->forceFill([
                'status' => $targetStatus,
                'deactivated_at' => $targetStatus === InstitutionStatus::Inactive ? now() : null,
            ])->save();

            return $lockedInstitution->refresh();
        });
    }
}
