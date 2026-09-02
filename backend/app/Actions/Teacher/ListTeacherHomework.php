<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentType;
use App\Models\Assessment;
use App\Models\User;
use App\Support\Teacher\InstitutionHomeworkDeadlineAt;
use App\Support\Teacher\TeacherHomeworkAccess;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use InvalidArgumentException;

final class ListTeacherHomework
{
    public const SORT_CREATED_AT = 'created_at';

    public const SORT_TITLE = 'title';

    public const SORT_DEADLINE_AT = 'deadline_at';

    public const SORT_STATUS = 'status';

    public const DIRECTION_ASC = 'asc';

    public const DIRECTION_DESC = 'desc';

    public const DEFAULT_SORT = self::SORT_CREATED_AT;

    public const DEFAULT_DIRECTION = self::DIRECTION_DESC;

    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    public function __construct(
        private readonly TeacherHomeworkAccess $access,
        private readonly InstitutionHomeworkDeadlineAt $deadlineAt,
    ) {}

    /** @return list<string> */
    public static function allowedSorts(): array
    {
        return [self::SORT_CREATED_AT, self::SORT_TITLE, self::SORT_DEADLINE_AT, self::SORT_STATUS];
    }

    /** @return list<string> */
    public static function allowedDirections(): array
    {
        return [self::DIRECTION_ASC, self::DIRECTION_DESC];
    }

    public function __invoke(
        User $teacher,
        string $topicId,
        ?string $status,
        ?string $assignmentMode,
        ?string $search,
        string $sort,
        string $direction,
        int $page,
        int $perPage,
    ): LengthAwarePaginator {
        $topic = $this->access->resolveTopic($teacher, $topicId);
        $timezone = $this->deadlineAt->timezone($teacher);

        $query = Assessment::query()
            ->select('assessments.*')
            ->join('homework_assignments', function ($join) use ($teacher): void {
                $join
                    ->on('homework_assignments.assessment_id', '=', 'assessments.id')
                    ->where('homework_assignments.institution_id', $teacher->institution_id);
            })
            ->where('assessments.institution_id', $teacher->institution_id)
            ->where('assessments.teacher_id', $teacher->id)
            ->where('assessments.topic_id', $topic->id)
            ->where('assessments.type', AssessmentType::Homework->value)
            ->with('homeworkAssignment')
            ->withCount('questions');

        if ($status !== null) {
            $query->where('homework_assignments.status', $status);
        }

        if ($assignmentMode !== null) {
            $query->where('assessments.assignment_mode', $assignmentMode);
        }

        $this->applySearch($query, $search);
        $this->applySorting($query, $sort, $direction);

        $paginator = $query->paginate(perPage: $perPage, pageName: 'page', page: $page);

        $paginator->getCollection()->each(
            static fn (Assessment $assessment) => $assessment->setAttribute('institution_timezone', $timezone)
        );

        return $paginator;
    }

    /** @param Builder<Assessment> $query */
    private function applySearch(Builder $query, ?string $search): void
    {
        if ($search === null || $search === '') {
            return;
        }

        $query->whereRaw("assessments.title ILIKE ? ESCAPE '!'", [
            '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $search).'%',
        ]);
    }

    /** @param Builder<Assessment> $query */
    private function applySorting(Builder $query, string $sort, string $direction): void
    {
        if (! in_array($direction, self::allowedDirections(), true)) {
            throw new InvalidArgumentException('Unsupported Teacher Homework list direction.');
        }

        match ($sort) {
            self::SORT_CREATED_AT => $query->orderBy('assessments.created_at', $direction),
            self::SORT_TITLE => $query->orderByRaw('lower(assessments.title) '.$direction),
            self::SORT_DEADLINE_AT => $query->orderByRaw('homework_assignments.deadline_at '.$direction.' NULLS LAST'),
            self::SORT_STATUS => $query->orderBy('homework_assignments.status', $direction),
            default => throw new InvalidArgumentException('Unsupported Teacher Homework list sort field.'),
        };

        $query->orderBy('assessments.id', $direction);
    }
}
