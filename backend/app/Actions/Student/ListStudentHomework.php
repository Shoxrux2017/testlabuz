<?php

namespace App\Actions\Student;

use App\Models\User;
use App\Support\Student\StudentHomeworkAccess;
use App\Support\Student\StudentHomeworkAttemptSummary;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class ListStudentHomework
{
    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    public function __construct(
        private readonly StudentHomeworkAccess $access,
        private readonly ReconcileStudentHomeworkDeadlines $reconcileDeadlines,
        private readonly StudentHomeworkAttemptSummary $attemptSummary,
    ) {}

    public function __invoke(
        User $student,
        ?string $topicId,
        ?string $status,
        int $page,
        int $perPage,
        string $sort,
        string $direction,
    ): LengthAwarePaginator {
        $readAt = now();
        $this->reconcileDeadlines->all($student, $readAt);
        $query = $this->access->readQuery($student);

        if ($topicId !== null) {
            $query->where('assessments.topic_id', $topicId);
        }

        if ($status !== null) {
            $query->where('homework_assignments.status', $status);
        }

        $direction = $direction === 'asc' ? 'asc' : 'desc';

        match ($sort) {
            'title' => $query->orderByRaw('lower(assessments.title) '.$direction),
            'deadline_at' => $query->orderByRaw('homework_assignments.deadline_at '.$direction.' NULLS LAST'),
            'status' => $query->orderBy('homework_assignments.status', $direction),
            default => $query->orderBy('assessments.created_at', $direction),
        };

        $homework = $query->orderBy('assessments.id', $direction)
            ->paginate(perPage: $perPage, pageName: 'page', page: $page);

        foreach ($homework->items() as $assessment) {
            $assessment->setAttribute('student_attempt_summary', ($this->attemptSummary)($student, $assessment, $readAt));
        }

        return $homework;
    }
}
