<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Models\User;
use App\Support\Teacher\TeacherSubmissionAccess;
use App\Support\Teacher\TeacherSubmissionProjection;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use LogicException;

/** The Teacher review queue (docs/09 §21.1). */
final class ListTeacherSubmissions
{
    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 25;

    public const MAX_PER_PAGE = 100;

    public const DEFAULT_SORT = 'default';

    public const DEFAULT_DIRECTION = 'asc';

    public const CHECKING_STATUSES = ['waiting_for_teacher_review', 'checked', 'automatic_checking_pending'];

    public const SORTS = ['default', 'finalized_at', 'student_name', 'review_due_at'];

    public const DIRECTIONS = ['asc', 'desc'];

    public function __construct(
        private readonly TeacherSubmissionAccess $access,
        private readonly TeacherSubmissionProjection $projection,
    ) {}

    /** @param array{assessment_id?: string, topic_id?: string, group_id?: string, student_id?: string, checking_status?: string, type?: string, official?: bool, overdue?: bool} $filters */
    public function __invoke(User $teacher, array $filters, string $sort, string $direction, int $page, int $perPage): LengthAwarePaginator
    {
        if (! in_array($direction, self::DIRECTIONS, true)) {
            throw new LogicException('The submission queue direction must be validated before listing.');
        }

        // One server instant for the overdue flag and the overdue filter.
        $now = now();
        $query = $this->projection->apply($this->access->query($teacher), $now);

        foreach (['assessment_id' => 'assessment_attempts.assessment_id', 'student_id' => 'assessment_attempts.student_id',
            'topic_id' => 'assessments.topic_id'] as $filter => $column) {
            if (isset($filters[$filter])) {
                $query->where($column, $filters[$filter]);
            }
        }

        if (isset($filters['group_id'])) {
            $query->whereIn('assessments.topic_id', fn ($topics) => $topics->select('id')->from('topics')
                ->where('institution_id', $teacher->institution_id)->where('group_id', $filters['group_id']));
        }

        if (isset($filters['checking_status'])) {
            $query->whereIn('assessment_attempts.status', match ($filters['checking_status']) {
                'automatic_checking_pending' => [AssessmentAttemptStatus::Submitted->value, AssessmentAttemptStatus::TimedOutFinalized->value],
                default => [$filters['checking_status']],
            });
        }

        if (isset($filters['type'])) {
            $query->where('assessments.type', $filters['type']);
        }

        if (isset($filters['official'])) {
            $this->projection->whereOfficial($query, $filters['official']);
        }

        if (($filters['overdue'] ?? false) === true) {
            $this->projection->whereOverdue($query, $now);
        }

        match ($sort) {
            'default' => $query->orderByDesc('submission_official')->orderByDesc('submission_overdue')
                ->orderBy('assessment_attempts.finalized_at')->orderBy('assessment_attempts.id'),
            'finalized_at' => $query->orderBy('assessment_attempts.finalized_at', $direction),
            'student_name' => $query->join('users as students', fn ($join) => $join->on('students.id', '=', 'assessment_attempts.student_id')
                ->on('students.institution_id', '=', 'assessment_attempts.institution_id'))
                ->orderByRaw('lower(students.full_name) '.$direction),
            'review_due_at' => $query->orderByRaw('homework_assignments.review_due_at '.$direction.' nulls last'),
        };

        if ($sort !== 'default') {
            $query->orderBy('assessment_attempts.id', $direction);
        }

        return $query->paginate(perPage: $perPage, pageName: 'page', page: $page);
    }
}
