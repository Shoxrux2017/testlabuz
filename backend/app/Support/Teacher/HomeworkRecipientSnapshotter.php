<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\UserRole;
use App\Exceptions\Teacher\AssessmentNotAssignedException;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;

final class HomeworkRecipientSnapshotter
{
    /**
     * @return array{
     *     recipients: Collection<int, AssessmentStudent>,
     *     memberships: Collection<int, GroupStudentMembership>,
     *     students: Collection<int, User>
     * }
     */
    public function lock(
        User $teacher,
        Group $group,
        Assessment $assessment,
        AssessmentAssignmentMode $assignmentMode,
    ): array {
        $recipients = AssessmentStudent::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('student_id')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        if ($assignmentMode === AssessmentAssignmentMode::Group) {
            $candidateStudentIds = GroupStudentMembership::query()
                ->where('institution_id', $teacher->institution_id)
                ->where('group_id', $group->id)
                ->whereNull('ended_at')
                ->orderBy('student_id')
                ->pluck('student_id')
                ->map(strtolower(...))
                ->unique()
                ->values()
                ->all();
            $students = $this->lockStudents($teacher, $candidateStudentIds);
            $memberships = $this->lockMemberships($teacher, $group, $candidateStudentIds);

            return compact('recipients', 'memberships', 'students');
        }

        $selectedStudentIds = $recipients->pluck('student_id')->map(strtolower(...))->unique()->values()->all();
        sort($selectedStudentIds, SORT_STRING);
        $students = $this->lockStudents($teacher, $selectedStudentIds);
        $memberships = $this->lockMemberships($teacher, $group, $selectedStudentIds);

        return compact('recipients', 'memberships', 'students');
    }

    /**
     * @param array{
     *     recipients: Collection<int, AssessmentStudent>,
     *     memberships: Collection<int, GroupStudentMembership>,
     *     students: Collection<int, User>
     * } $lockedSnapshot
     */
    public function snapshot(
        User $teacher,
        Assessment $assessment,
        AssessmentAssignmentMode $assignmentMode,
        CarbonInterface $transitionedAt,
        array $lockedSnapshot,
    ): void {
        if ($assignmentMode === AssessmentAssignmentMode::Group) {
            $this->snapshotGroupRecipients(
                $teacher,
                $assessment,
                $lockedSnapshot['recipients'],
                $lockedSnapshot['memberships'],
                $lockedSnapshot['students'],
                $transitionedAt,
            );

            return;
        }

        $this->validateSelectedRecipients(
            $teacher,
            $lockedSnapshot['recipients'],
            $lockedSnapshot['memberships'],
            $lockedSnapshot['students'],
        );
    }

    /**
     * @param  Collection<int, AssessmentStudent>  $recipients
     * @param  Collection<int, GroupStudentMembership>  $memberships
     * @param  Collection<int, User>  $students
     */
    private function snapshotGroupRecipients(
        User $teacher,
        Assessment $assessment,
        Collection $recipients,
        Collection $memberships,
        Collection $students,
        CarbonInterface $transitionedAt,
    ): void {
        if ($recipients->isNotEmpty()) {
            throw new BusinessConflictException;
        }

        $memberLookup = array_fill_keys(
            $memberships->pluck('student_id')->map(strtolower(...))->unique()->all(),
            true,
        );
        $eligibleStudentIds = $students
            ->filter(fn (User $student): bool => isset($memberLookup[strtolower($student->id)])
                && $student->role === UserRole::Student
                && $student->is_active)
            ->pluck('id')
            ->map(strtolower(...))
            ->sort()
            ->values()
            ->all();

        if ($eligibleStudentIds === []) {
            throw new AssessmentNotAssignedException;
        }

        foreach ($eligibleStudentIds as $studentId) {
            AssessmentStudent::query()->create([
                'institution_id' => $teacher->institution_id,
                'assessment_id' => $assessment->id,
                'student_id' => $studentId,
                'assignment_source' => AssessmentAssignmentSource::Group,
                'assigned_at' => $transitionedAt,
                'assigned_by_user_id' => $teacher->id,
            ]);
        }
    }

    /**
     * @param  Collection<int, AssessmentStudent>  $recipients
     * @param  Collection<int, GroupStudentMembership>  $memberships
     * @param  Collection<int, User>  $students
     */
    private function validateSelectedRecipients(
        User $teacher,
        Collection $recipients,
        Collection $memberships,
        Collection $students,
    ): void {
        if ($recipients->isEmpty()) {
            throw new AssessmentNotAssignedException;
        }

        $studentIds = [];

        foreach ($recipients as $recipient) {
            $studentId = strtolower($recipient->student_id);

            if ($recipient->getRawOriginal('assignment_source') !== AssessmentAssignmentSource::Direct->value
                || $recipient->assigned_by_user_id !== $teacher->id
                || $recipient->assigned_at === null
                || isset($studentIds[$studentId])) {
                throw new BusinessConflictException;
            }

            $studentIds[$studentId] = true;
        }

        $selectedStudentIds = array_keys($studentIds);
        sort($selectedStudentIds, SORT_STRING);

        if ($students->count() !== count($selectedStudentIds)
            || $students->contains(fn (User $student): bool => $student->role !== UserRole::Student || ! $student->is_active)) {
            throw new AssessmentNotAssignedException;
        }

        if ($memberships->count() !== count($selectedStudentIds)
            || $memberships->pluck('student_id')->map(strtolower(...))->unique()->count() !== count($selectedStudentIds)) {
            throw new AssessmentNotAssignedException;
        }
    }

    /**
     * @param  list<string>  $studentIds
     * @return Collection<int, User>
     */
    private function lockStudents(User $teacher, array $studentIds): Collection
    {
        if ($studentIds === []) {
            return new Collection;
        }

        return User::query()
            ->select(['id', 'role', 'is_active'])
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($studentIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }

    /**
     * @param  list<string>  $studentIds
     * @return Collection<int, GroupStudentMembership>
     */
    private function lockMemberships(User $teacher, Group $group, array $studentIds): Collection
    {
        if ($studentIds === []) {
            return new Collection;
        }

        return GroupStudentMembership::query()
            ->select(['id', 'student_id'])
            ->where('institution_id', $teacher->institution_id)
            ->where('group_id', $group->id)
            ->whereIn('student_id', $studentIds)
            ->whereNull('ended_at')
            ->orderBy('student_id')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }
}
