<?php

namespace App\Actions\Institution;

use App\Enums\UserRole;
use App\Exceptions\Institution\InactiveParentStudentRelationshipUserException;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ConnectInstitutionParentStudentRelationship
{
    public function __invoke(User $actor, string $parentId, string $studentId): ParentStudentRelationshipConnectResult
    {
        return DB::transaction(function () use ($actor, $parentId, $studentId): ParentStudentRelationshipConnectResult {
            $parentId = strtolower($parentId);
            $studentId = strtolower($studentId);
            $userIds = [$parentId, $studentId];
            sort($userIds, SORT_STRING);

            $lockedUsers = User::query()
                ->select(['id', 'role', 'is_active'])
                ->where('institution_id', $actor->institution_id)
                ->whereKey($userIds)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            $parent = $lockedUsers->firstWhere('id', $parentId);
            $student = $lockedUsers->firstWhere('id', $studentId);

            if (
                $lockedUsers->count() !== 2
                || ! $parent instanceof User
                || $parent->role !== UserRole::Parent
                || ! $student instanceof User
                || $student->role !== UserRole::Student
            ) {
                throw new NotFoundHttpException;
            }

            $relationship = ParentStudentRelationship::query()
                ->select(['id', 'parent_id', 'student_id', 'started_at', 'ended_at'])
                ->where('institution_id', $actor->institution_id)
                ->where('parent_id', $parent->id)
                ->where('student_id', $student->id)
                ->whereNull('ended_at')
                ->lockForUpdate()
                ->first();

            if ($relationship instanceof ParentStudentRelationship) {
                return new ParentStudentRelationshipConnectResult($relationship, false);
            }

            if (! $parent->is_active || ! $student->is_active) {
                throw new InactiveParentStudentRelationshipUserException;
            }

            $relationship = ParentStudentRelationship::query()->create([
                'institution_id' => $actor->institution_id,
                'parent_id' => $parent->id,
                'student_id' => $student->id,
                'connected_by_user_id' => $actor->id,
                'started_at' => now(),
                'ended_at' => null,
            ]);

            return new ParentStudentRelationshipConnectResult($relationship, true);
        });
    }
}
