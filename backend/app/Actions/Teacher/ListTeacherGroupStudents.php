<?php

namespace App\Actions\Teacher;

use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Models\Group;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class ListTeacherGroupStudents
{
    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 50;

    public const MAX_PER_PAGE = 100;

    public function __invoke(
        User $teacher,
        string $groupId,
        ?string $search,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $this->ensureGroupIsReadable($teacher, $groupId);

        $query = User::query()
            ->select(['id', 'full_name', 'login_name'])
            ->where('institution_id', $teacher->institution_id)
            ->where('role', UserRole::Student->value)
            ->where('is_active', true)
            ->whereHas('studentGroupMemberships', function (Builder $query) use ($teacher, $groupId): void {
                $query
                    ->where('institution_id', $teacher->institution_id)
                    ->where('group_id', $groupId)
                    ->whereNull('ended_at');
            });

        if ($search !== null && $search !== '') {
            $literalPattern = '%'.$this->escapeLikePattern($search).'%';

            $query->where(function (Builder $query) use ($literalPattern): void {
                $query
                    ->whereRaw("full_name ILIKE ? ESCAPE '!'", [$literalPattern])
                    ->orWhereRaw("login_name ILIKE ? ESCAPE '!'", [$literalPattern]);
            });
        }

        return $query
            ->orderByRaw('lower(full_name) asc')
            ->orderBy('id')
            ->paginate(perPage: $perPage, pageName: 'page', page: $page);
    }

    private function ensureGroupIsReadable(User $teacher, string $groupId): void
    {
        if (! Str::isUuid($groupId)) {
            throw new NotFoundHttpException;
        }

        $exists = Group::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('status', GroupStatus::Active->value)
            ->whereKey($groupId)
            ->whereHas('teacherMemberships', function (Builder $query) use ($teacher): void {
                $query
                    ->where('institution_id', $teacher->institution_id)
                    ->where('teacher_id', $teacher->id)
                    ->whereNull('ended_at');
            })
            ->exists();

        if (! $exists) {
            throw new NotFoundHttpException;
        }
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
