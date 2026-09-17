<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentType;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\OfficialCohortMismatchException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\HomeworkAssignment;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;

final class TeacherOfficialAssessmentCohort
{
    public function __construct(private readonly AssessmentRecipientSnapshotter $recipientSnapshotter) {}

    /**
     * @return array{student_ids: list<string>, pair: ?TopicResultPair, attempts: Collection<int, AssessmentAttempt>, current_snapshot: ?array}
     */
    public function lock(
        User $teacher,
        Group $group,
        Assessment $assessment,
        AssessmentAssignmentMode $assignmentMode,
        ?TopicResultPair $pair,
    ): array {
        $isOfficial = $pair instanceof TopicResultPair
            && in_array($assessment->id, [$pair->homework_assessment_id, $pair->blitz_assessment_id], true);
        $officialPair = $isOfficial ? $pair : null;
        $assessmentIds = $officialPair instanceof TopicResultPair
            ? array_values(array_filter([$officialPair->homework_assessment_id, $officialPair->blitz_assessment_id]))
            : [$assessment->id];
        sort($assessmentIds, SORT_STRING);

        if ($officialPair instanceof TopicResultPair) {
            if ($assignmentMode !== AssessmentAssignmentMode::Group) {
                throw new BusinessConflictException;
            }

            $this->lockOfficialAssessments($teacher, $assessment, $officialPair, $assessmentIds);
        }

        $attempts = AssessmentAttempt::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereIn('assessment_id', $assessmentIds)
            ->orderBy('assessment_id')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        if ($officialPair instanceof TopicResultPair
            && (($officialPair->locked_at === null) !== $attempts->isEmpty())) {
            throw new BusinessConflictException;
        }

        if ($assessment->type === AssessmentType::Blitz && $attempts->contains('assessment_id', $assessment->id)) {
            throw new BusinessConflictException;
        }

        $recipients = AssessmentStudent::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereIn('assessment_id', $assessmentIds)
            ->orderBy('assessment_id')
            ->orderBy('student_id')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
        $targetRecipients = $recipients->where('assessment_id', $assessment->id)->values();

        $currentSnapshot = null;
        $studentIds = [];

        if ($officialPair?->cohort_snapshotted_at !== null) {
            $cohortIds = $this->establishedStudentIds($teacher, $recipients, $assessmentIds);
            $studentIds = $targetRecipients->isEmpty() ? $cohortIds : [];
        } else {
            $currentSnapshot = $this->recipientSnapshotter->lock(
                $teacher,
                $group,
                $assessment,
                $assignmentMode,
                $targetRecipients,
            );
        }

        return ['student_ids' => $studentIds, 'pair' => $officialPair, 'attempts' => $attempts, 'current_snapshot' => $currentSnapshot];
    }

    /**
     * @param  array{student_ids: list<string>, pair: ?TopicResultPair, attempts: Collection<int, AssessmentAttempt>, current_snapshot: ?array{recipients: Collection<int, AssessmentStudent>, memberships: Collection<int, GroupStudentMembership>, students: Collection<int, User>}}  $locked
     * @return array{student_ids: list<string>, pair: ?TopicResultPair, attempts: Collection<int, AssessmentAttempt>, current_snapshot: ?array}
     */
    public function validate(User $teacher, Assessment $assessment, AssessmentAssignmentMode $assignmentMode, array $locked): array
    {
        if ($locked['current_snapshot'] !== null) {
            $locked['student_ids'] = $this->recipientSnapshotter->validate($teacher, $assessment, $assignmentMode, $locked['current_snapshot']);
        }

        return $locked;
    }

    /**
     * @param  array{student_ids: list<string>, pair: ?TopicResultPair, attempts: Collection<int, AssessmentAttempt>, current_snapshot: ?array}  $prepared
     */
    public function apply(User $teacher, Assessment $assessment, CarbonInterface $activatedAt, array $prepared): void
    {
        $this->recipientSnapshotter->snapshot($teacher, $assessment, $activatedAt, $prepared['student_ids']);
        $pair = $prepared['pair'];

        if ($pair instanceof TopicResultPair && $pair->cohort_snapshotted_at === null) {
            $pair->cohort_snapshotted_at = $activatedAt;
            $pair->updated_at = $activatedAt;
            $pair->save();
        }
    }

    /** @param list<string> $assessmentIds */
    private function lockOfficialAssessments(User $teacher, Assessment $activatingAssessment, TopicResultPair $pair, array $assessmentIds): void
    {
        $assessments = Assessment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('topic_id', $activatingAssessment->topic_id)
            ->whereKey($assessmentIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        if ($assessments->count() !== count($assessmentIds)) {
            throw new BusinessConflictException;
        }

        foreach ($assessments as $officialAssessment) {
            $isHomework = $officialAssessment->id === $pair->homework_assessment_id;
            $expectedType = $isHomework ? AssessmentType::Homework : AssessmentType::Blitz;

            if ($officialAssessment->type !== $expectedType
                || $officialAssessment->assignment_mode !== AssessmentAssignmentMode::Group) {
                throw new BusinessConflictException;
            }

            $details = ($isHomework ? HomeworkAssignment::query() : BlitzTask::query())
                ->where('institution_id', $teacher->institution_id)
                ->where('assessment_id', $officialAssessment->id)
                ->lockForUpdate()
                ->first();

            if ($details === null) {
                throw new BusinessConflictException;
            }
        }
    }

    /**
     * @param  Collection<int, AssessmentStudent>  $recipients
     * @param  list<string>  $assessmentIds
     * @return list<string>
     */
    private function establishedStudentIds(User $teacher, Collection $recipients, array $assessmentIds): array
    {
        $authoritativeIds = null;

        foreach ($assessmentIds as $assessmentId) {
            $studentIds = [];

            foreach ($recipients->where('assessment_id', $assessmentId) as $recipient) {
                $studentId = strtolower($recipient->student_id);

                if ($recipient->institution_id !== $teacher->institution_id
                    || $recipient->getRawOriginal('assignment_source') !== AssessmentAssignmentSource::Group->value
                    || $recipient->assigned_at === null
                    || isset($studentIds[$studentId])) {
                    throw new OfficialCohortMismatchException;
                }

                $studentIds[$studentId] = true;
            }

            if ($studentIds === []) {
                continue;
            }

            $sortedIds = array_keys($studentIds);
            sort($sortedIds, SORT_STRING);

            if ($authoritativeIds !== null && $authoritativeIds !== $sortedIds) {
                throw new OfficialCohortMismatchException;
            }

            $authoritativeIds = $sortedIds;
        }

        if ($authoritativeIds === null) {
            throw new OfficialCohortMismatchException;
        }

        return $authoritativeIds;
    }
}
