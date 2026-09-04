<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\OfficialTaskRequiresGroupAssignmentException;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskClosedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\HomeworkAssignment;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Teacher\InstitutionHomeworkDeadlineAt;
use App\Support\Teacher\TeacherHomeworkLifecycleAccess;
use App\Support\Teacher\TeacherHomeworkRecipients;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class UpdateTeacherHomework
{
    private const FAIRNESS_FIELDS = [
        'student_instructions',
        'assignment_mode',
        'student_ids',
        'deadline_at',
    ];

    public function __construct(
        private readonly TeacherHomeworkLifecycleAccess $access,
        private readonly TeacherHomeworkRecipients $recipients,
        private readonly InstitutionHomeworkDeadlineAt $deadlineAt,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    /** @param array<string, mixed> $attributes */
    public function __invoke(User $teacher, string $homeworkId, array $attributes): Assessment
    {
        $preliminaryAssessment = $this->access->resolveHomework($teacher, $homeworkId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment, $attributes): Assessment {
            [
                'group' => $group,
                'topic' => $topic,
                'assessment' => $assessment,
                'homework' => $homework,
            ] = $this->access->lockHomework($teacher, $preliminaryAssessment);

            $this->ensureEditable($homework, $topic->status);
            $pair = $this->access->lockResultPair($teacher, $topic, $assessment);

            $hasAttempts = AssessmentAttempt::query()
                ->where('institution_id', $teacher->institution_id)
                ->where('assessment_id', $assessment->id)
                ->orderBy('id')
                ->lockForUpdate()
                ->get(['id'])
                ->isNotEmpty();
            $existingRecipients = $this->recipients->lockExisting($teacher, $assessment);
            $currentStudentIds = $assessment->assignment_mode === AssessmentAssignmentMode::SelectedStudents
                ? $existingRecipients->pluck('student_id')->map(strtolower(...))->sort()->values()->all()
                : [];
            $resulting = [
                'title' => $assessment->title,
                'description' => $assessment->description,
                'student_instructions' => $assessment->student_instructions,
                'assignment_mode' => $assessment->assignment_mode->value,
                'student_ids' => $currentStudentIds,
                'deadline_at' => $homework->deadline_at,
            ];

            foreach ($attributes as $field => $value) {
                if ($field === 'student_ids') {
                    $value = $this->canonicalStudentIds($value);
                } elseif ($field === 'deadline_at' && is_string($value)) {
                    $value = $this->deadlineAt->parse($teacher, $value);
                }

                $resulting[$field] = $value;
            }

            $changes = $this->semanticChanges($assessment, $homework, $currentStudentIds, $resulting);

            if ($changes === []) {
                return ($this->showTeacherHomework)($teacher, $assessment->id);
            }

            $hasFairnessChange = array_intersect(array_keys($changes), self::FAIRNESS_FIELDS) !== [];

            if ($hasAttempts && $hasFairnessChange) {
                throw new BusinessConflictException;
            }

            if ($pair instanceof TopicResultPair
                && $pair->homework_assessment_id === $assessment->id
                && isset($changes['assignment_mode'])
                && $assessment->assignment_mode === AssessmentAssignmentMode::Group
                && $resulting['assignment_mode'] === AssessmentAssignmentMode::SelectedStudents->value) {
                throw new OfficialTaskRequiresGroupAssignmentException;
            }

            $this->validateAssignmentState($resulting['assignment_mode'], $resulting['student_ids']);

            $hasEstablishedOfficialCohort = $pair instanceof TopicResultPair
                && $pair->homework_assessment_id === $assessment->id
                && $pair->cohort_snapshotted_at !== null
                && $assessment->assignment_mode === AssessmentAssignmentMode::Group;

            if (! $hasAttempts && ! $hasEstablishedOfficialCohort) {
                $mode = AssessmentAssignmentMode::from($resulting['assignment_mode']);

                if ($mode === AssessmentAssignmentMode::SelectedStudents) {
                    $desiredStudentIds = $this->recipients->lockSelected($teacher, $group, $resulting['student_ids']);
                    $source = AssessmentAssignmentSource::Direct;
                } elseif ($homework->status === HomeworkStatus::Active) {
                    $desiredStudentIds = $this->recipients->lockAllEligible($teacher, $group);
                    $source = AssessmentAssignmentSource::Group;
                } else {
                    $desiredStudentIds = [];
                    $source = AssessmentAssignmentSource::Group;
                }

                $this->recipients->synchronize(
                    $teacher,
                    $assessment,
                    $desiredStudentIds,
                    $source,
                    $existingRecipients,
                );
            }

            foreach (['title', 'description', 'student_instructions', 'assignment_mode'] as $field) {
                if (isset($changes[$field])) {
                    $assessment->setAttribute($field, $resulting[$field]);
                }
            }

            if ($assessment->isDirty()) {
                $assessment->save();
            }

            if (isset($changes['deadline_at'])) {
                $homework->deadline_at = $resulting['deadline_at'];
                $homework->save();
            }

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }

    private function ensureEditable(HomeworkAssignment $homework, TopicStatus $topicStatus): void
    {
        if ($homework->status === HomeworkStatus::Closed) {
            throw new TaskClosedException;
        }

        if ($homework->status === HomeworkStatus::Archived) {
            throw new TaskArchivedException;
        }

        if (in_array($topicStatus, [TopicStatus::Closed, TopicStatus::Archived], true)) {
            throw new TopicNotEditableException;
        }
    }

    /** @return list<string> */
    private function canonicalStudentIds(mixed $studentIds): array
    {
        if (! is_array($studentIds)) {
            return [];
        }

        $canonical = array_map(static fn (mixed $studentId): string => strtolower((string) $studentId), $studentIds);
        sort($canonical, SORT_STRING);

        return $canonical;
    }

    /** @param list<string> $studentIds */
    private function validateAssignmentState(mixed $mode, array $studentIds): void
    {
        if (($mode === AssessmentAssignmentMode::Group->value && $studentIds !== [])
            || ($mode === AssessmentAssignmentMode::SelectedStudents->value && $studentIds === [])) {
            throw ValidationException::withMessages([
                'student_ids' => ['The student_ids do not match the resulting assignment mode.'],
            ]);
        }
    }

    /**
     * @param  list<string>  $currentStudentIds
     * @param  array<string, mixed>  $resulting
     * @return array<string, true>
     */
    private function semanticChanges(
        Assessment $assessment,
        HomeworkAssignment $homework,
        array $currentStudentIds,
        array $resulting,
    ): array {
        $changes = [];

        foreach ([
            'title' => $assessment->title,
            'description' => $assessment->description,
            'student_instructions' => $assessment->student_instructions,
            'assignment_mode' => $assessment->assignment_mode->value,
            'student_ids' => $currentStudentIds,
        ] as $field => $current) {
            if ($resulting[$field] !== $current) {
                $changes[$field] = true;
            }
        }

        if (! $this->sameInstant($homework->deadline_at, $resulting['deadline_at'])) {
            $changes['deadline_at'] = true;
        }

        return $changes;
    }

    private function sameInstant(?CarbonInterface $current, mixed $resulting): bool
    {
        if ($current === null || $resulting === null) {
            return $current === null && $resulting === null;
        }

        return $resulting instanceof CarbonInterface
            && $current->format('U.u') === $resulting->format('U.u');
    }
}
