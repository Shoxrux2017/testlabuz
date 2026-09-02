<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentAssignmentSource;
use App\Enums\UserRole;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Validation\ValidationException;

final class TeacherHomeworkRecipients
{
    /**
     * @param  list<string>  $studentIds
     * @return list<string>
     */
    public function lockSelected(User $teacher, Group $group, array $studentIds): array
    {
        $sortedStudentIds = array_map(strtolower(...), $studentIds);
        sort($sortedStudentIds, SORT_STRING);

        if ($sortedStudentIds === [] || count(array_unique($sortedStudentIds)) !== count($sortedStudentIds)) {
            $this->rejectSelected();
        }

        $students = User::query()
            ->select(['id'])
            ->where('institution_id', $teacher->institution_id)
            ->where('role', UserRole::Student->value)
            ->where('is_active', true)
            ->whereKey($sortedStudentIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        if ($students->count() !== count($sortedStudentIds)) {
            $this->rejectSelected();
        }

        $memberships = GroupStudentMembership::query()
            ->select(['id', 'student_id'])
            ->where('institution_id', $teacher->institution_id)
            ->where('group_id', $group->id)
            ->whereIn('student_id', $sortedStudentIds)
            ->whereNull('ended_at')
            ->orderBy('student_id')
            ->lockForUpdate()
            ->get();

        if ($memberships->count() !== count($sortedStudentIds)) {
            $this->rejectSelected();
        }

        return $sortedStudentIds;
    }

    /** @return list<string> */
    public function lockAllEligible(User $teacher, Group $group): array
    {
        $studentIds = GroupStudentMembership::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('group_id', $group->id)
            ->whereNull('ended_at')
            ->whereHas('student', function ($query) use ($teacher): void {
                $query
                    ->where('institution_id', $teacher->institution_id)
                    ->where('role', UserRole::Student->value)
                    ->where('is_active', true);
            })
            ->orderBy('student_id')
            ->pluck('student_id')
            ->map(static fn (string $studentId): string => strtolower($studentId))
            ->all();

        if ($studentIds === []) {
            return [];
        }

        $students = User::query()
            ->select('id')
            ->where('institution_id', $teacher->institution_id)
            ->where('role', UserRole::Student->value)
            ->where('is_active', true)
            ->whereKey($studentIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        $studentIds = $students
            ->pluck('id')
            ->map(static fn (string $studentId): string => strtolower($studentId))
            ->sort()
            ->values()
            ->all();

        if ($studentIds === []) {
            return [];
        }

        GroupStudentMembership::query()
            ->select(['id', 'student_id'])
            ->where('institution_id', $teacher->institution_id)
            ->where('group_id', $group->id)
            ->whereIn('student_id', $studentIds)
            ->whereNull('ended_at')
            ->orderBy('student_id')
            ->lockForUpdate()
            ->get();

        return $studentIds;
    }

    /** @return Collection<int, AssessmentStudent> */
    public function lockExisting(User $teacher, Assessment $assessment): Collection
    {
        return AssessmentStudent::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('student_id')
            ->lockForUpdate()
            ->get();
    }

    /**
     * @param  list<string>  $desiredStudentIds
     * @param  Collection<int, AssessmentStudent>  $existingRecipients
     */
    public function synchronize(
        User $teacher,
        Assessment $assessment,
        array $desiredStudentIds,
        AssessmentAssignmentSource $source,
        Collection $existingRecipients,
    ): void {
        $desiredLookup = array_fill_keys($desiredStudentIds, true);
        $existingByStudent = $existingRecipients->keyBy('student_id');

        foreach ($existingRecipients as $recipient) {
            if (! isset($desiredLookup[strtolower($recipient->student_id)])) {
                $recipient->delete();
            }
        }

        foreach ($desiredStudentIds as $studentId) {
            $recipient = $existingByStudent->get($studentId);

            if ($recipient instanceof AssessmentStudent) {
                if ($recipient->assignment_source !== $source) {
                    $recipient->assignment_source = $source;
                    $recipient->save();
                }

                continue;
            }

            AssessmentStudent::query()->create([
                'institution_id' => $teacher->institution_id,
                'assessment_id' => $assessment->id,
                'student_id' => $studentId,
                'assignment_source' => $source,
                'assigned_at' => now(),
                'assigned_by_user_id' => $teacher->id,
            ]);
        }
    }

    private function rejectSelected(): never
    {
        throw ValidationException::withMessages([
            'student_ids' => ['The selected students must all be current active members of the Topic group.'],
        ]);
    }
}
