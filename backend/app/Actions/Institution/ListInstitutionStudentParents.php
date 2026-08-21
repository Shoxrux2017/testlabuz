<?php

namespace App\Actions\Institution;

use App\Enums\UserRole;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\JoinClause;
use Illuminate\Support\Str;
use InvalidArgumentException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ListInstitutionStudentParents
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
        string $student,
        ?string $search,
        ?bool $isActive,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $resolvedStudent = $this->resolveStudent($actor, $student);

        $query = ParentStudentRelationship::query()
            ->select([
                'parent_student_relationships.id',
                'parent_student_relationships.parent_id',
                'parent_student_relationships.student_id',
                'parent_student_relationships.started_at',
                'parent_student_relationships.ended_at',
                'parents.id as related_user_id',
                'parents.full_name as related_user_full_name',
                'parents.login_name as related_user_login_name',
                'parents.email as related_user_email',
                'parents.phone as related_user_phone',
                'parents.is_active as related_user_is_active',
            ])
            ->join('users as parents', function (JoinClause $join): void {
                $join
                    ->on('parents.id', '=', 'parent_student_relationships.parent_id')
                    ->on('parents.institution_id', '=', 'parent_student_relationships.institution_id');
            })
            ->where('parent_student_relationships.institution_id', $actor->institution_id)
            ->where('parent_student_relationships.student_id', $resolvedStudent->id)
            ->whereNull('parent_student_relationships.ended_at')
            ->where('parents.institution_id', $actor->institution_id)
            ->where('parents.role', UserRole::Parent->value);

        $this->applySearch($query, $search);

        if (is_bool($isActive)) {
            $query->where('parents.is_active', $isActive);
        }

        $this->applySorting($query, $sort, $direction);

        return $query->paginate(
            perPage: $perPage,
            pageName: 'page',
            page: $page,
        );
    }

    private function resolveStudent(User $actor, string $student): User
    {
        if (! Str::isUuid($student)) {
            throw new NotFoundHttpException;
        }

        $resolvedStudent = User::query()
            ->select('id')
            ->where('institution_id', $actor->institution_id)
            ->where('role', UserRole::Student->value)
            ->whereKey($student)
            ->first();

        if (! $resolvedStudent instanceof User) {
            throw new NotFoundHttpException;
        }

        return $resolvedStudent;
    }

    /** @param Builder<ParentStudentRelationship> $query */
    private function applySearch(Builder $query, ?string $search): void
    {
        if ($search === null || $search === '') {
            return;
        }

        $literalPattern = '%'.$this->escapeLikePattern($search).'%';

        $query->where(function (Builder $query) use ($literalPattern): void {
            $query
                ->whereRaw("parents.full_name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("parents.login_name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("parents.email ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("parents.phone ILIKE ? ESCAPE '!'", [$literalPattern]);
        });
    }

    /** @param Builder<ParentStudentRelationship> $query */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        $direction = $this->safeDirection($direction);

        match ($sort) {
            self::SORT_FULL_NAME => $query->orderByRaw('lower(parents.full_name) '.$direction),
            self::SORT_STARTED_AT => $query->orderBy('parent_student_relationships.started_at', $direction),
            default => throw new InvalidArgumentException('Unsupported institution student parent list sort field.'),
        };

        $query->orderBy('parent_student_relationships.id', $direction);
    }

    private function safeDirection(string $direction): string
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported institution student parent list sort direction.');
        }

        return $direction;
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
