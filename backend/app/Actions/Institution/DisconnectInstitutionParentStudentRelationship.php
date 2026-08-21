<?php

namespace App\Actions\Institution;

use App\Enums\UserRole;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class DisconnectInstitutionParentStudentRelationship
{
    public function __invoke(User $actor, string $relationship): void
    {
        if (! Str::isUuid($relationship)) {
            throw new NotFoundHttpException;
        }

        DB::transaction(function () use ($actor, $relationship): void {
            $resolvedPair = ParentStudentRelationship::query()
                ->select(['parent_id', 'student_id'])
                ->where('institution_id', $actor->institution_id)
                ->whereKey($relationship)
                ->first();

            if (! $resolvedPair instanceof ParentStudentRelationship) {
                throw new NotFoundHttpException;
            }

            $userIds = [$resolvedPair->parent_id, $resolvedPair->student_id];
            sort($userIds, SORT_STRING);

            $lockedUsers = User::query()
                ->select(['id', 'role'])
                ->where('institution_id', $actor->institution_id)
                ->whereKey($userIds)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            $lockedRelationship = ParentStudentRelationship::query()
                ->select(['id', 'parent_id', 'student_id', 'ended_at'])
                ->where('institution_id', $actor->institution_id)
                ->whereKey($relationship)
                ->lockForUpdate()
                ->first();

            if (
                ! $lockedRelationship instanceof ParentStudentRelationship
                || $lockedRelationship->parent_id !== $resolvedPair->parent_id
                || $lockedRelationship->student_id !== $resolvedPair->student_id
            ) {
                throw new NotFoundHttpException;
            }

            $parent = $lockedUsers->firstWhere('id', $lockedRelationship->parent_id);
            $student = $lockedUsers->firstWhere('id', $lockedRelationship->student_id);

            if (
                $lockedUsers->count() !== 2
                || ! $parent instanceof User
                || $parent->role !== UserRole::Parent
                || ! $student instanceof User
                || $student->role !== UserRole::Student
            ) {
                throw new LogicException('Parent-student relationship user roles conflict with persisted relationship data.');
            }

            if ($lockedRelationship->ended_at === null) {
                $lockedRelationship->forceFill(['ended_at' => now()])->save();
            }
        });
    }
}
