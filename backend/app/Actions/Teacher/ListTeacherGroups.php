<?php

namespace App\Actions\Teacher;

use App\Enums\GroupStatus;
use App\Models\Group;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use InvalidArgumentException;

class ListTeacherGroups
{
    public const SORT_NAME = 'name';

    public const SORT_LEVEL = 'level';

    public const SORT_SUBJECT_DIRECTION = 'subject_direction';

    public const DIRECTION_ASC = 'asc';

    public const DIRECTION_DESC = 'desc';

    public const DEFAULT_SORT = self::SORT_NAME;

    public const DEFAULT_DIRECTION = self::DIRECTION_ASC;

    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    /** @return list<string> */
    public static function allowedSorts(): array
    {
        return [self::SORT_NAME, self::SORT_LEVEL, self::SORT_SUBJECT_DIRECTION];
    }

    /** @return list<string> */
    public static function allowedDirections(): array
    {
        return [self::DIRECTION_ASC, self::DIRECTION_DESC];
    }

    public function __invoke(
        User $teacher,
        ?string $search,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $query = Group::query()
            ->select(['id', 'name', 'level', 'subject_direction', 'status'])
            ->where('institution_id', $teacher->institution_id)
            ->where('status', GroupStatus::Active->value)
            ->whereHas('teacherMemberships', function (Builder $query) use ($teacher): void {
                $query
                    ->where('institution_id', $teacher->institution_id)
                    ->where('teacher_id', $teacher->id)
                    ->whereNull('ended_at');
            });

        $this->applySearch($query, $search);
        $this->applySorting($query, $sort, $direction);

        return $query->paginate(perPage: $perPage, pageName: 'page', page: $page);
    }

    /** @param Builder<Group> $query */
    private function applySearch(Builder $query, ?string $search): void
    {
        if ($search === null || $search === '') {
            return;
        }

        $literalPattern = '%'.$this->escapeLikePattern($search).'%';

        $query->where(function (Builder $query) use ($literalPattern): void {
            $query
                ->whereRaw("name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("level ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("subject_direction ILIKE ? ESCAPE '!'", [$literalPattern]);
        });
    }

    /** @param Builder<Group> $query */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        $direction = $this->safeDirection($direction);

        match ($sort) {
            self::SORT_NAME => $query->orderByRaw('lower(name) '.$direction),
            self::SORT_LEVEL => $query->orderByRaw('lower(level) '.$direction.' NULLS LAST'),
            self::SORT_SUBJECT_DIRECTION => $query->orderByRaw('lower(subject_direction) '.$direction.' NULLS LAST'),
            default => throw new InvalidArgumentException('Unsupported teacher group list sort field.'),
        };

        $query->orderBy('id', $direction);
    }

    private function safeDirection(string $direction): string
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported teacher group list sort direction.');
        }

        return $direction;
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
