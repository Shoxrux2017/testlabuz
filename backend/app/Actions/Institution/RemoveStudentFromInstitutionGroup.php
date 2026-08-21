<?php

namespace App\Actions\Institution;

use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Exceptions\Institution\GroupArchivedException;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class RemoveStudentFromInstitutionGroup
{
    public function __invoke(User $actor, string $group, string $student): void
    {
        DB::transaction(function () use ($actor, $group, $student): void {
            $lockedGroup = $this->lockGroup($actor, $group);

            if ($lockedGroup->status === GroupStatus::Archived) {
                throw new GroupArchivedException;
            }

            $lockedStudent = $this->lockStudent($actor, $student);

            $membership = GroupStudentMembership::query()
                ->where('institution_id', $actor->institution_id)
                ->where('group_id', $lockedGroup->id)
                ->where('student_id', $lockedStudent->id)
                ->whereNull('ended_at')
                ->lockForUpdate()
                ->first();

            if ($membership instanceof GroupStudentMembership) {
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

    private function lockStudent(User $actor, string $student): User
    {
        if (! Str::isUuid($student)) {
            throw new NotFoundHttpException;
        }

        $lockedStudent = User::query()
            ->select('id')
            ->where('institution_id', $actor->institution_id)
            ->where('role', UserRole::Student->value)
            ->whereKey($student)
            ->lockForUpdate()
            ->first();

        if (! $lockedStudent instanceof User) {
            throw new NotFoundHttpException;
        }

        return $lockedStudent;
    }
}
