<?php

namespace App\Actions\Institution;

use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Exceptions\Institution\GroupArchivedException;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class RemoveTeacherFromInstitutionGroup
{
    public function __invoke(User $actor, string $group, string $teacher): void
    {
        DB::transaction(function () use ($actor, $group, $teacher): void {
            $lockedGroup = $this->lockGroup($actor, $group);

            if ($lockedGroup->status === GroupStatus::Archived) {
                throw new GroupArchivedException;
            }

            $lockedTeacher = $this->lockTeacher($actor, $teacher);

            $membership = GroupTeacherMembership::query()
                ->where('institution_id', $actor->institution_id)
                ->where('group_id', $lockedGroup->id)
                ->where('teacher_id', $lockedTeacher->id)
                ->whereNull('ended_at')
                ->lockForUpdate()
                ->first();

            if ($membership instanceof GroupTeacherMembership) {
                $membership->forceFill(['ended_at' => now()])->save();
            }
        });
    }

    private function lockGroup(User $actor, string $group): Group
    {
        if (! Str::isUuid($group)) {
            throw new NotFoundHttpException;
        }

        $lockedGroup = Group::query()
            ->select(['id', 'status'])
            ->where('institution_id', $actor->institution_id)
            ->whereKey($group)
            ->lockForUpdate()
            ->first();

        if (! $lockedGroup instanceof Group) {
            throw new NotFoundHttpException;
        }

        return $lockedGroup;
    }

    private function lockTeacher(User $actor, string $teacher): User
    {
        if (! Str::isUuid($teacher)) {
            throw new NotFoundHttpException;
        }

        $lockedTeacher = User::query()
            ->select('id')
            ->where('institution_id', $actor->institution_id)
            ->where('role', UserRole::Teacher->value)
            ->whereKey($teacher)
            ->lockForUpdate()
            ->first();

        if (! $lockedTeacher instanceof User) {
            throw new NotFoundHttpException;
        }

        return $lockedTeacher;
    }
}
