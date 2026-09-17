<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentType;
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

final class AssessmentRecipientSnapshotter
{
    /**
     * @param  Collection<int, AssessmentStudent>|null  $recipients
     * @return array{recipients: Collection<int, AssessmentStudent>, memberships: Collection<int, GroupStudentMembership>, students: Collection<int, User>}
     */
    public function lock(
        User $teacher,
        Group $group,
        Assessment $assessment,
        AssessmentAssignmentMode $assignmentMode,
        ?Collection $recipients = null,
    ): array {
        $recipients ??= AssessmentStudent::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('student_id')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        $candidateStudentIds = $assignmentMode === AssessmentAssignmentMode::Group
            ? GroupStudentMembership::query()
                ->where('institution_id', $teacher->institution_id)
                ->where('group_id', $group->id)
                ->whereNull('ended_at')
                ->orderBy('student_id')
                ->pluck('student_id')->map(strtolower(...))->unique()->values()->all()
            : $recipients->pluck('student_id')->map(strtolower(...))->unique()->sort()->values()->all();

        // Preserve the established user-before-membership snapshot lock order.
        $students = $this->lockStudents($teacher, $candidateStudentIds);
        $memberships = $this->lockMemberships($teacher, $group, $candidateStudentIds);

        return compact('recipients', 'memberships', 'students');
    }

    /**
     * @param  array{recipients: Collection<int, AssessmentStudent>, memberships: Collection<int, GroupStudentMembership>, students: Collection<int, User>}  $lockedSnapshot
     * @return list<string> Student IDs requiring new group recipient rows; selected rows are preserved.
     */
    public function validate(User $teacher, Assessment $assessment, AssessmentAssignmentMode $assignmentMode, array $lockedSnapshot): array
    {
        ['recipients' => $recipients, 'memberships' => $memberships, 'students' => $students] = $lockedSnapshot;

        if ($assignmentMode === AssessmentAssignmentMode::SelectedStudents) {
            $this->validateSelectedRecipients($teacher, $assessment, $recipients, $memberships, $students);

            return [];
        }

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
            ->pluck('id')->map(strtolower(...))->sort()->values()->all();

        if ($eligibleStudentIds === []) {
            throw new AssessmentNotAssignedException;
        }

        return $eligibleStudentIds;
    }

    /** @param list<string> $studentIds */
    public function snapshot(User $teacher, Assessment $assessment, CarbonInterface $activatedAt, array $studentIds): void
    {
        foreach ($studentIds as $studentId) {
            AssessmentStudent::query()->create([
                'institution_id' => $teacher->institution_id,
                'assessment_id' => $assessment->id,
                'student_id' => $studentId,
                'assignment_source' => AssessmentAssignmentSource::Group,
                'assigned_at' => $activatedAt,
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
        Assessment $assessment,
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
                throw $assessment->type === AssessmentType::Blitz
                    ? new AssessmentNotAssignedException
                    : new BusinessConflictException;
            }

            $studentIds[$studentId] = true;
        }

        if ($students->count() !== count($studentIds)
            || $students->contains(fn (User $student): bool => $student->role !== UserRole::Student || ! $student->is_active)
            || $memberships->count() !== count($studentIds)
            || $memberships->pluck('student_id')->map(strtolower(...))->unique()->count() !== count($studentIds)) {
            throw new AssessmentNotAssignedException;
        }
    }

    /**
     * @param  list<string>  $studentIds
     * @return Collection<int, User>
     */
    private function lockStudents(User $teacher, array $studentIds): Collection
    {
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
