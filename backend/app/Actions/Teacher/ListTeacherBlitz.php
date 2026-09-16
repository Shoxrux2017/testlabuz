<?php

namespace App\Actions\Teacher;

use App\Models\Assessment;
use App\Models\User;
use App\Support\Teacher\InstitutionBlitzScheduledAt;
use App\Support\Teacher\TeacherBlitzAccess;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

final class ListTeacherBlitz
{
    public function __construct(
        private readonly TeacherBlitzAccess $access,
        private readonly InstitutionBlitzScheduledAt $scheduledAt,
    ) {}

    /** @param array<string, mixed> $filters */
    public function __invoke(User $teacher, array $filters): LengthAwarePaginator
    {
        if (isset($filters['group_id'])) {
            $this->access->resolveGroup($teacher, $filters['group_id']);
        }

        if (isset($filters['topic_id'])) {
            $this->access->resolveTopic($teacher, $filters['topic_id']);
        }

        $query = $this->access->visibleBlitzQuery($teacher)
            ->with('blitzTask:assessment_id,institution_id,status,duration_seconds,scheduled_at')
            ->withCount('questions');

        if (isset($filters['topic_id'])) {
            $query->where('topic_id', $filters['topic_id']);
        }

        if (isset($filters['group_id'])) {
            $query->whereHas('topic', fn ($query) => $query
                ->where('topics.institution_id', $teacher->institution_id)
                ->where('group_id', $filters['group_id']));
        }

        if (isset($filters['status'])) {
            $query->whereHas('blitzTask', fn ($query) => $query
                ->where('institution_id', $teacher->institution_id)
                ->where('status', $filters['status']));
        }

        $paginator = $query
            ->orderByDesc('assessments.created_at')
            ->orderByDesc('assessments.id')
            ->paginate(perPage: $filters['per_page'] ?? 20, pageName: 'page', page: $filters['page'] ?? 1);
        $timezone = $this->scheduledAt->timezone($teacher);
        $paginator->getCollection()->each(
            static fn (Assessment $assessment) => $assessment->setAttribute('institution_timezone', $timezone),
        );

        return $paginator;
    }
}
