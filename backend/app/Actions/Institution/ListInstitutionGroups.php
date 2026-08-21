<?php

namespace App\Actions\Institution;

use App\Enums\GroupStatus;
use App\Models\Group;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use InvalidArgumentException;

class ListInstitutionGroups
{
    public const SORT_NAME = 'name';

    public const SORT_STATUS = 'status';

    public const SORT_CREATED_AT = 'created_at';

    public const SORT_UPDATED_AT = 'updated_at';

    public const DIRECTION_ASC = 'asc';

    public const DIRECTION_DESC = 'desc';

    public const DEFAULT_SORT = self::SORT_NAME;

    public const DEFAULT_DIRECTION = self::DIRECTION_ASC;

    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    /**
     * @return list<string>
     */
    public static function allowedSorts(): array
    {
        return [
            self::SORT_NAME,
            self::SORT_STATUS,
            self::SORT_CREATED_AT,
            self::SORT_UPDATED_AT,
        ];
    }

    /**
     * @return list<string>
     */
    public static function allowedDirections(): array
    {
        return [self::DIRECTION_ASC, self::DIRECTION_DESC];
    }

    public function __invoke(
        User $actor,
        ?string $search,
        ?GroupStatus $status,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $query = Group::query()
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
            ->withCurrentMembershipCounts();

        $this->applySearch($query, $search);

        if ($status instanceof GroupStatus) {
            $query->where('status', $status->value);
        }

        $this->applySorting($query, $sort, $direction);

        return $query->paginate(
            perPage: $perPage,
            pageName: 'page',
            page: $page,
        );
    }

    /**
     * @param  Builder<Group>  $query
     */
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

    /**
     * @param  Builder<Group>  $query
     */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        $direction = $this->safeDirection($direction);

        match ($sort) {
            self::SORT_NAME => $query->orderByRaw('lower(name) '.$direction),
            self::SORT_STATUS => $query->orderBy('status', $direction),
            self::SORT_CREATED_AT => $query->orderBy('created_at', $direction),
            self::SORT_UPDATED_AT => $query->orderBy('updated_at', $direction),
            default => throw new InvalidArgumentException('Unsupported institution group list sort field.'),
        };

        $query->orderBy('id', $direction);
    }

    private function safeDirection(string $direction): string
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported institution group list sort direction.');
        }

        return $direction;
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
