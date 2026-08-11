<?php

namespace App\Actions\Platform;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Models\Institution;
use App\Support\Platform\InstitutionUserCounts;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use InvalidArgumentException;

class ListPlatformInstitutions
{
    public const SORT_NAME = 'name';

    public const SORT_CREATED_AT = 'created_at';

    public const SORT_UPDATED_AT = 'updated_at';

    public const SORT_STATUS = 'status';

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
            self::SORT_CREATED_AT,
            self::SORT_UPDATED_AT,
            self::SORT_STATUS,
        ];
    }

    /**
     * @return list<string>
     */
    public static function allowedDirections(): array
    {
        return [
            self::DIRECTION_ASC,
            self::DIRECTION_DESC,
        ];
    }

    public function __invoke(
        ?string $search,
        ?InstitutionStatus $status,
        ?InstitutionType $type,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $query = Institution::query()
            ->select([
                'id',
                'name',
                'type',
                'status',
                'contact_email',
                'contact_phone',
                'created_at',
                'updated_at',
            ]);

        InstitutionUserCounts::addToQuery($query);

        $this->applySearch($query, $search);
        $this->applyFilters($query, $status, $type);
        $this->applySorting($query, $sort, $direction);

        return $query->paginate(
            perPage: $perPage,
            pageName: 'page',
            page: $page,
        );
    }

    /**
     * @param  Builder<Institution>  $query
     */
    private function applySearch(Builder $query, ?string $search): void
    {
        if ($search === null || $search === '') {
            return;
        }

        $literalPattern = '%'.$this->escapeLikePattern($search).'%';

        $query->whereRaw("name ILIKE ? ESCAPE '!'", [$literalPattern]);
    }

    /**
     * @param  Builder<Institution>  $query
     */
    private function applyFilters(Builder $query, ?InstitutionStatus $status, ?InstitutionType $type): void
    {
        if ($status instanceof InstitutionStatus) {
            $query->where('status', $status->value);
        }

        if ($type instanceof InstitutionType) {
            $query->where('type', $type->value);
        }
    }

    /**
     * @param  Builder<Institution>  $query
     */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        $direction = $this->safeDirection($direction);

        match ($sort) {
            self::SORT_NAME => $query->orderByRaw('lower(name) '.$direction),
            self::SORT_CREATED_AT => $query->orderBy('created_at', $direction),
            self::SORT_UPDATED_AT => $query->orderBy('updated_at', $direction),
            self::SORT_STATUS => $query->orderBy('status', $direction),
            default => throw new InvalidArgumentException('Unsupported institution list sort field.'),
        };

        $query->orderBy('id');
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }

    private function safeDirection(string $direction): string
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported institution list sort direction.');
        }

        return $direction;
    }
}
