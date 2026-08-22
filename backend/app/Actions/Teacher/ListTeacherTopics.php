<?php

namespace App\Actions\Teacher;

use App\Models\Group;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use InvalidArgumentException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ListTeacherTopics
{
    public const SORT_TITLE = 'title';

    public const SORT_LESSON_AT = 'lesson_at';

    public const SORT_CREATED_AT = 'created_at';

    public const SORT_UPDATED_AT = 'updated_at';

    public const DIRECTION_ASC = 'asc';

    public const DIRECTION_DESC = 'desc';

    public const DEFAULT_SORT = self::SORT_CREATED_AT;

    public const DEFAULT_DIRECTION = self::DIRECTION_DESC;

    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    /** @return list<string> */
    public static function allowedSorts(): array
    {
        return [self::SORT_TITLE, self::SORT_LESSON_AT, self::SORT_CREATED_AT, self::SORT_UPDATED_AT];
    }

    /** @return list<string> */
    public static function allowedDirections(): array
    {
        return [self::DIRECTION_ASC, self::DIRECTION_DESC];
    }

    public function __invoke(
        User $teacher,
        ?string $groupId,
        ?string $status,
        ?string $search,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        if ($groupId !== null) {
            $this->ensureGroupIsReadable($teacher, $groupId);
        }

        $query = Topic::query()
            ->select([
                'id',
                'group_id',
                'title',
                'description',
                'subject',
                'student_instructions',
                'lesson_at',
                'status',
                'activated_at',
                'closed_at',
                'archived_at',
                'created_at',
                'updated_at',
            ])
            ->visibleToTeacher($teacher)
            ->with(['group:id,name,level,subject_direction,status']);

        if ($groupId !== null) {
            $query->where('group_id', $groupId);
        }

        if ($status !== null) {
            $query->where('topics.status', $status);
        }

        $this->applySearch($query, $search);
        $this->applySorting($query, $sort, $direction);

        return $query->paginate(perPage: $perPage, pageName: 'page', page: $page);
    }

    private function ensureGroupIsReadable(User $teacher, string $groupId): void
    {
        $groupExists = Group::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($groupId)
            ->whereHas('teacherMemberships', function (Builder $query) use ($teacher): void {
                $query
                    ->where('institution_id', $teacher->institution_id)
                    ->where('teacher_id', $teacher->id)
                    ->whereNull('ended_at');
            })
            ->exists();

        if (! $groupExists) {
            throw new NotFoundHttpException;
        }
    }

    /** @param Builder<Topic> $query */
    private function applySearch(Builder $query, ?string $search): void
    {
        if ($search === null || $search === '') {
            return;
        }

        $literalPattern = '%'.$this->escapeLikePattern($search).'%';

        $query->where(function (Builder $query) use ($literalPattern): void {
            $query
                ->whereRaw("title ILIKE ? ESCAPE '!'", [$literalPattern])
                ->orWhereRaw("subject ILIKE ? ESCAPE '!'", [$literalPattern]);
        });
    }

    /** @param Builder<Topic> $query */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        $direction = $this->safeDirection($direction);

        match ($sort) {
            self::SORT_TITLE => $query->orderByRaw('lower(title) '.$direction),
            self::SORT_LESSON_AT => $query->orderByRaw('lesson_at '.$direction.' NULLS LAST'),
            self::SORT_CREATED_AT => $query->orderBy('created_at', $direction),
            self::SORT_UPDATED_AT => $query->orderBy('updated_at', $direction),
            default => throw new InvalidArgumentException('Unsupported teacher topic list sort field.'),
        };

        $query->orderBy('id', $direction);
    }

    private function safeDirection(string $direction): string
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported teacher topic list sort direction.');
        }

        return $direction;
    }

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
