<?php

namespace App\Actions\Institution;

use App\Enums\GroupStatus;
use App\Models\Group;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ArchiveInstitutionGroup
{
    public function __invoke(User $actor, string $group): Group
    {
        return DB::transaction(function () use ($actor, $group): Group {
            $lockedGroup = $this->lockInstitutionGroup($actor, $group);

            if ($lockedGroup->status === GroupStatus::Active) {
                $lockedGroup->forceFill([
                    'status' => GroupStatus::Archived,
                    'archived_at' => now(),
                ])->save();
            }

            return $this->resourceGroup($actor, $lockedGroup->id);
        });
    }

    private function lockInstitutionGroup(User $actor, string $group): Group
    {
        if (! Str::isUuid($group)) {
            throw new NotFoundHttpException;
        }

        $lockedGroup = Group::query()
            ->where('institution_id', $actor->institution_id)
            ->whereKey($group)
            ->lockForUpdate()
            ->first();

        if (! $lockedGroup instanceof Group) {
            throw new NotFoundHttpException;
        }

        return $lockedGroup;
    }

    private function resourceGroup(User $actor, string $group): Group
    {
        return Group::query()
            ->select([
                'id',
                'name',
                'level',
                'subject_direction',
                'description',
                'status',
                'archived_at',
                'created_at',
                'updated_at',
            ])
            ->where('institution_id', $actor->institution_id)
            ->whereKey($group)
            ->withCurrentMembershipCounts()
            ->firstOrFail();
    }
}
