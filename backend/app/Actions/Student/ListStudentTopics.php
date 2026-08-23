<?php

namespace App\Actions\Student;

use App\Enums\TopicStatus;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;

class ListStudentTopics
{
    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    /** @return list<string> */
    public static function allowedStatuses(): array
    {
        return [
            TopicStatus::Active->value,
            TopicStatus::Closed->value,
            TopicStatus::Archived->value,
        ];
    }

    public function __invoke(
        User $student,
        ?string $status,
        ?string $search,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $query = Topic::query()
            ->select([
                'id',
                'group_id',
                'title',
                'subject',
                'lesson_at',
                'status',
                'created_at',
            ])
            ->visibleToStudent($student)
            ->with(['group:id,name,level,subject_direction,status']);

        if ($status !== null) {
            $query->where('topics.status', $status);
        }

        $this->applySearch($query, $search);

        return $query
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate(perPage: $perPage, pageName: 'page', page: $page);
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

    private function escapeLikePattern(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }
}
