<?php

namespace App\Actions\Institution;

use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Exceptions\Institution\GroupArchivedException;
use App\Exceptions\Institution\InactiveGroupMemberException;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class AssignStudentToInstitutionGroup
{
    /**
     * @param  list<string>  $studentIds
     */
    public function __invoke(User $actor, string $group, array $studentIds): GroupMembershipAssignmentResult
    {
        return DB::transaction(function () use ($actor, $group, $studentIds): GroupMembershipAssignmentResult {
            $lockedGroup = $this->lockGroup($actor, $group);

            if ($lockedGroup->status === GroupStatus::Archived) {
                throw new GroupArchivedException;
            }

            $normalizedStudentIds = array_map(strtolower(...), $studentIds);
            $sortedStudentIds = $normalizedStudentIds;
            sort($sortedStudentIds, SORT_STRING);

            $students = User::query()
                ->select(['id', 'full_name', 'login_name', 'email', 'phone', 'is_active'])
                ->where('institution_id', $actor->institution_id)
                ->where('role', UserRole::Student->value)
                ->whereKey($sortedStudentIds)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            if ($students->count() !== count($studentIds)) {
                throw new NotFoundHttpException;
            }

            $memberships = GroupStudentMembership::query()
                ->select(['id', 'student_id', 'started_at'])
                ->where('institution_id', $actor->institution_id)
                ->where('group_id', $lockedGroup->id)
                ->whereIn('student_id', $sortedStudentIds)
                ->whereNull('ended_at')
                ->orderBy('student_id')
                ->lockForUpdate()
                ->get()
                ->keyBy('student_id');

            $studentsById = $students->keyBy('id');
            $createdCount = 0;

            foreach ($sortedStudentIds as $studentId) {
                if ($memberships->has($studentId)) {
                    continue;
                }

                $student = $studentsById->get($studentId);

                if (! $student instanceof User) {
                    throw new NotFoundHttpException;
                }

                if (! $student->is_active) {
                    throw new InactiveGroupMemberException;
                }

                $membership = GroupStudentMembership::query()->create([
                    'institution_id' => $actor->institution_id,
                    'group_id' => $lockedGroup->id,
                    'student_id' => $student->id,
                    'assigned_by_user_id' => $actor->id,
                    'started_at' => now(),
                    'ended_at' => null,
                ]);

                $memberships->put($studentId, $membership);
                $createdCount++;
            }

            return new GroupMembershipAssignmentResult(
                $this->orderedStudents($normalizedStudentIds, $studentsById, $memberships),
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
     * @param  list<string>  $studentIds
     * @param  Collection<string, User>  $studentsById
     * @param  Collection<string, GroupStudentMembership>  $memberships
     * @return Collection<int, User>
     */
    private function orderedStudents(array $studentIds, Collection $studentsById, Collection $memberships): Collection
    {
        return collect($studentIds)->map(function (string $studentId) use ($studentsById, $memberships): User {
            /** @var User $student */
            $student = $studentsById->get($studentId);
            /** @var GroupStudentMembership $membership */
            $membership = $memberships->get($studentId);
            $student->setAttribute('started_at', $membership->started_at);

            return $student;
        })->values();
    }
}
