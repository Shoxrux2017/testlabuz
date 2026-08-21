<?php

namespace App\Actions\Institution;

use App\Models\Group;
use App\Models\User;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ShowInstitutionGroup
{
    public function __invoke(User $actor, string $group): Group
    {
        if (! Str::isUuid($group)) {
            throw new NotFoundHttpException;
        }

        $resolvedGroup = Group::query()
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
            ->first();

        if (! $resolvedGroup instanceof Group) {
            throw new NotFoundHttpException;
        }

        return $resolvedGroup;
    }
}
