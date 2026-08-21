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

class ListInstitutionParentStudents
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
        string $parent,
        ?string $search,
        ?bool $isActive,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $resolvedParent = $this->resolveParent($actor, $parent);

        $query = ParentStudentRelationship::query()
            ->select([
                'parent_student_relationships.id',
                'parent_student_relationships.parent_id',
                'parent_student_relationships.student_id',
                'parent_student_relationships.started_at',
                'parent_student_relationships.ended_at',
            ])
            ->join('users as students', function (JoinClause $join): void {
                $join
                    ->on('students.id', '=', 'parent_student_relationships.student_id')
                    ->on('students.institution_id', '=', 'parent_student_relationships.institution_id');
            })
            ->where('parent_student_relationships.institution_id', $actor->institution_id)
            ->where('parent_student_relationships.parent_id', $resolvedParent->id)
            ->whereNull('parent_student_relationships.ended_at')
            ->where('students.institution_id', $actor->institution_id)
            ->where('students.role', UserRole::Student->value);

        $this->applySearch($query, $search);

        if (is_bool($isActive)) {
            $query->where('students.is_active', $isActive);
        }

        $this->applySorting($query, $sort, $direction);

        return $query->paginate(
            perPage: $perPage,
            pageName: 'page',
            page: $page,
        );
    }

    private function resolveParent(User $actor, string $parent): User
    {
        if (! Str::isUuid($parent)) {
            throw new NotFoundHttpException;
        }

        $resolvedParent = User::query()
            ->select('id')
            ->where('institution_id', $actor->institution_id)
            ->where('role', UserRole::Parent->value)
            ->whereKey($parent)
            ->first();

        if (! $resolvedParent instanceof User) {
            throw new NotFoundHttpException;
        }

        return $resolvedParent;
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
                ->whereRaw("students.full_name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("students.login_name ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("students.email ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("students.phone ILIKE ? ESCAPE '!'", [$literalPattern]);
        });
    }

    /** @param Builder<ParentStudentRelationship> $query */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        $direction = $this->safeDirection($direction);

        match ($sort) {
            self::SORT_FULL_NAME => $query->orderByRaw('lower(students.full_name) '.$direction),
            self::SORT_STARTED_AT => $query->orderBy('parent_student_relationships.started_at', $direction),
            default => throw new InvalidArgumentException('Unsupported institution parent student list sort field.'),
        };

        $query->orderBy('parent_student_relationships.id', $direction);
    }

    private function safeDirection(string $direction): string
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported institution parent student list sort direction.');
        }

        return $direction;
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
