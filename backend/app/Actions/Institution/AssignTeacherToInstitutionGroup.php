<?php

namespace App\Actions\Institution;

use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Exceptions\Institution\GroupArchivedException;
use App\Exceptions\Institution\InactiveGroupMemberException;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class AssignTeacherToInstitutionGroup
{
    /**
     * @param  list<string>  $teacherIds
     */
    public function __invoke(User $actor, string $group, array $teacherIds): GroupMembershipAssignmentResult
    {
        return DB::transaction(function () use ($actor, $group, $teacherIds): GroupMembershipAssignmentResult {
            $lockedGroup = $this->lockGroup($actor, $group);

            if ($lockedGroup->status === GroupStatus::Archived) {
                throw new GroupArchivedException;
            }

            $normalizedTeacherIds = array_map(strtolower(...), $teacherIds);
            $sortedTeacherIds = $normalizedTeacherIds;
            sort($sortedTeacherIds, SORT_STRING);

            $teachers = User::query()
                ->select(['id', 'full_name', 'login_name', 'email', 'phone', 'is_active'])
                ->where('institution_id', $actor->institution_id)
                ->where('role', UserRole::Teacher->value)
                ->whereKey($sortedTeacherIds)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            if ($teachers->count() !== count($teacherIds)) {
                throw new NotFoundHttpException;
            }

            $memberships = GroupTeacherMembership::query()
                ->select(['id', 'teacher_id', 'started_at'])
                ->where('institution_id', $actor->institution_id)
                ->where('group_id', $lockedGroup->id)
                ->whereIn('teacher_id', $sortedTeacherIds)
                ->whereNull('ended_at')
                ->orderBy('teacher_id')
                ->lockForUpdate()
                ->get()
                ->keyBy('teacher_id');

            $teachersById = $teachers->keyBy('id');
            $createdCount = 0;

            foreach ($sortedTeacherIds as $teacherId) {
                if ($memberships->has($teacherId)) {
                    continue;
                }

                $teacher = $teachersById->get($teacherId);

                if (! $teacher instanceof User) {
                    throw new NotFoundHttpException;
                }

                if (! $teacher->is_active) {
                    throw new InactiveGroupMemberException;
                }

                $membership = GroupTeacherMembership::query()->create([
                    'institution_id' => $actor->institution_id,
                    'group_id' => $lockedGroup->id,
                    'teacher_id' => $teacher->id,
                    'assigned_by_user_id' => $actor->id,
                    'started_at' => now(),
                    'ended_at' => null,
                ]);

                $memberships->put($teacherId, $membership);
                $createdCount++;
            }

            return new GroupMembershipAssignmentResult(
                $this->orderedTeachers($normalizedTeacherIds, $teachersById, $memberships),
                $createdCount,
            );
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

    /**
     * @param  list<string>  $teacherIds
     * @param  Collection<string, User>  $teachersById
     * @param  Collection<string, GroupTeacherMembership>  $memberships
     * @return Collection<int, User>
     */
    private function orderedTeachers(array $teacherIds, Collection $teachersById, Collection $memberships): Collection
    {
        return collect($teacherIds)->map(function (string $teacherId) use ($teachersById, $memberships): User {
            /** @var User $teacher */
            $teacher = $teachersById->get($teacherId);
            /** @var GroupTeacherMembership $membership */
            $membership = $memberships->get($teacherId);
            $teacher->setAttribute('started_at', $membership->started_at);

            return $teacher;
        })->values();
    }
}
