<?php

namespace App\Actions\Institution;

use App\Enums\UserRole;
use App\Models\Group;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use InvalidArgumentException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ListInstitutionGroupTeachers
{
    public const SORT_FULL_NAME = 'full_name';

    public const SORT_STARTED_AT = 'started_at';

    public const DIRECTION_ASC = 'asc';

    public const DIRECTION_DESC = 'desc';

    public const DEFAULT_SORT = self::SORT_FULL_NAME;

    public const DEFAULT_DIRECTION = self::DIRECTION_ASC;

    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    /** @return list<string> */
    public static function allowedSorts(): array
    {
        return [self::SORT_FULL_NAME, self::SORT_STARTED_AT];
    }

    /** @return list<string> */
    public static function allowedDirections(): array
    {
        return [self::DIRECTION_ASC, self::DIRECTION_DESC];
    }

    public function __invoke(
        User $actor,
        string $group,
        ?string $search,
        ?bool $isActive,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $resolvedGroup = $this->resolveGroup($actor, $group);

        $query = User::query()
            ->select([
                'users.id',
                'users.full_name',
                'users.login_name',
                'users.email',
                'users.phone',
                'users.is_active',
                'group_teacher_memberships.started_at',
            ])
            ->join('group_teacher_memberships', 'group_teacher_memberships.teacher_id', '=', 'users.id')
            ->where('users.institution_id', $actor->institution_id)
            ->where('users.role', UserRole::Teacher->value)
            ->where('group_teacher_memberships.institution_id', $actor->institution_id)
            ->where('group_teacher_memberships.group_id', $resolvedGroup->id)
            ->whereNull('group_teacher_memberships.ended_at');

        $this->applySearch($query, $search);

        if (is_bool($isActive)) {
            $query->where('users.is_active', $isActive);
        }

        $this->applySorting($query, $sort, $direction);

        return $query->paginate(
            perPage: $perPage,
            pageName: 'page',
            page: $page,
        );
    }

    private function resolveGroup(User $actor, string $group): Group
    {
        if (! Str::isUuid($group)) {
            throw new NotFoundHttpException;
        }

        $resolvedGroup = Group::query()
            ->select('id')
            ->where('institution_id', $actor->institution_id)
            ->whereKey($group)
            ->first();

        if (! $resolvedGroup instanceof Group) {
            throw new NotFoundHttpException;
        }

        return $resolvedGroup;
    }

    /** @param Builder<User> $query */
    private function applySearch(Builder $query, ?string $search): void
    {
        if ($search === null || $search === '') {
            return;
        }

        $literalPattern = '%'.$this->escapeLikePattern($search).'%';

        $query->where(function (Builder $query) use ($literalPattern): void {
            $query
                ->whereRaw("users.full_name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("users.login_name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("users.email ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("users.phone ILIKE ? ESCAPE '!'", [$literalPattern]);
        });
    }

    /** @param Builder<User> $query */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        $direction = $this->safeDirection($direction);

        match ($sort) {
            self::SORT_FULL_NAME => $query->orderByRaw('lower(users.full_name) '.$direction),
            self::SORT_STARTED_AT => $query->orderBy('group_teacher_memberships.started_at', $direction),
            default => throw new InvalidArgumentException('Unsupported institution group teacher list sort field.'),
        };

        $query->orderBy('users.id', $direction);
    }

    private function safeDirection(string $direction): string
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported institution group teacher list sort direction.');
        }

        return $direction;
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
