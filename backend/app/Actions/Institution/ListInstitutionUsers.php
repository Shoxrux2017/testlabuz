<?php

namespace App\Actions\Institution;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use InvalidArgumentException;

class ListInstitutionUsers
{
    public const SORT_FULL_NAME = 'full_name';

    public const SORT_LOGIN_NAME = 'login_name';

    public const SORT_CREATED_AT = 'created_at';

    public const SORT_UPDATED_AT = 'updated_at';

    public const DIRECTION_ASC = 'asc';

    public const DIRECTION_DESC = 'desc';

    public const DEFAULT_SORT = self::SORT_FULL_NAME;

    public const DEFAULT_DIRECTION = self::DIRECTION_ASC;

    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    /**
     * @return list<string>
     */
    public static function allowedRoles(): array
    {
        return [
            UserRole::Teacher->value,
            UserRole::Student->value,
            UserRole::Parent->value,
        ];
    }

    /**
     * @return list<string>
     */
    public static function allowedSorts(): array
    {
        return [
            self::SORT_FULL_NAME,
            self::SORT_LOGIN_NAME,
            self::SORT_CREATED_AT,
            self::SORT_UPDATED_AT,
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
        User $actor,
        ?string $role,
        ?bool $status,
        ?string $search,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $query = User::query()
            ->select([
                'id',
                'role',
                'full_name',
                'login_name',
                'email',
                'phone',
                'is_active',
                'must_change_password',
                'last_login_at',
                'deactivated_at',
                'created_at',
                'updated_at',
            ])
            ->where('institution_id', $actor->institution_id)
            ->whereIn('role', self::allowedRoles());

        if ($role !== null) {
            $query->where('role', $this->safeRole($role));
        }

        if ($status !== null) {
            $query->where('is_active', $status);
        }

        $this->applySearch($query, $search);
        $this->applySorting($query, $sort, $direction);

        return $query->paginate(
            perPage: $perPage,
            pageName: 'page',
            page: $page,
        );
    }

    /**
     * @param  Builder<User>  $query
     */
    private function applySearch(Builder $query, ?string $search): void
    {
        if ($search === null || $search === '') {
            return;
        }

        $literalPattern = '%'.$this->escapeLikePattern($search).'%';

        $query->where(function (Builder $query) use ($literalPattern): void {
            $query
                ->whereRaw("full_name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("login_name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("email ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("phone ILIKE ? ESCAPE '!'", [$literalPattern]);
        });
    }

    /**
     * @param  Builder<User>  $query
     */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        $direction = $this->safeDirection($direction);

        match ($sort) {
            self::SORT_FULL_NAME => $query->orderByRaw('lower(full_name) '.$direction),
            self::SORT_LOGIN_NAME => $query->orderByRaw('lower(login_name) '.$direction),
            self::SORT_CREATED_AT => $query->orderBy('created_at', $direction),
            self::SORT_UPDATED_AT => $query->orderBy('updated_at', $direction),
            default => throw new InvalidArgumentException('Unsupported institution user list sort field.'),
        };

        $query->orderBy('id', $direction);
    }

    private function safeRole(string $role): string
    {
        if (! in_array($role, self::allowedRoles(), true)) {
            throw new InvalidArgumentException('Unsupported institution user role filter.');
        }

        return $role;
    }

    private function safeDirection(string $direction): string
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported institution user list sort direction.');
        }

        return $direction;
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
