<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\OfficialTaskRequiresGroupAssignmentException;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\User;
use App\Support\Teacher\TeacherAssessmentRecipients;
use App\Support\Teacher\TeacherBlitzAccess;
use App\Support\Teacher\TeacherBlitzPreparationGuard;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class UpdateTeacherBlitz
{
    public function __construct(
        private readonly TeacherBlitzAccess $access,
        private readonly TeacherBlitzPreparationGuard $preparation,
        private readonly TeacherAssessmentRecipients $recipients,
        private readonly ShowTeacherBlitz $showTeacherBlitz,
    ) {}

    /** @param array<string, mixed> $attributes */
    public function __invoke(User $teacher, string $blitzId, array $attributes): Assessment
    {
        $preliminaryAssessment = $this->access->resolveBlitz($teacher, $blitzId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment, $attributes): Assessment {
            [
                'group' => $group,
                'topic' => $topic,
                'assessment' => $assessment,
                'blitz' => $blitz,
            ] = $this->access->lockBlitz($teacher, $preliminaryAssessment);

            $this->preparation->ensureEditable($blitz, $topic);
            $pair = $this->access->lockResultPair($teacher, $topic, $assessment);

            if ($this->access->lockAttempts($teacher, $assessment)->isNotEmpty()) {
                throw new BusinessConflictException;
            }

            $existingRecipients = $this->recipients->lockExisting($teacher, $assessment);

            if ($existingRecipients->contains(
                fn (AssessmentStudent $recipient): bool => $recipient->assignment_source !== AssessmentAssignmentSource::Direct,
            )) {
                throw new BusinessConflictException;
            }

            $currentStudentIds = $assessment->assignment_mode === AssessmentAssignmentMode::SelectedStudents
                ? $existingRecipients->pluck('student_id')->map(strtolower(...))->sort()->values()->all()
                : [];
            $current = [
                'title' => $assessment->title,
                'description' => $assessment->description,
                'student_instructions' => $assessment->student_instructions,
                'assignment_mode' => $assessment->assignment_mode->value,
                'student_ids' => $currentStudentIds,
                'duration_seconds' => $blitz->duration_seconds,
            ];
            $resulting = array_replace($current, $attributes);
            $resulting['student_ids'] = array_map(strtolower(...), $resulting['student_ids']);
            sort($resulting['student_ids'], SORT_STRING);

            if ($pair?->blitz_assessment_id === $assessment->id
                && $resulting['assignment_mode'] !== AssessmentAssignmentMode::Group->value) {
                throw new OfficialTaskRequiresGroupAssignmentException;
            }

            $mode = AssessmentAssignmentMode::from($resulting['assignment_mode']);

            if (($mode === AssessmentAssignmentMode::Group && $resulting['student_ids'] !== [])
                || ($mode === AssessmentAssignmentMode::SelectedStudents && $resulting['student_ids'] === [])) {
                throw ValidationException::withMessages([
                    'student_ids' => ['The student_ids do not match the resulting assignment mode.'],
                ]);
            }

            $studentIds = $mode === AssessmentAssignmentMode::SelectedStudents
                ? $this->recipients->lockSelected($teacher, $group, $resulting['student_ids'])
                : [];

            if ($resulting === $current) {
                return ($this->showTeacherBlitz)($teacher, $assessment->id);
            }

            $this->recipients->synchronize(
                $teacher,
                $assessment,
                $studentIds,
                AssessmentAssignmentSource::Direct,
                $existingRecipients,
            );

            foreach (['title', 'description', 'student_instructions', 'assignment_mode'] as $field) {
                $assessment->setAttribute($field, $resulting[$field]);
            }

            $updatedAt = now();
            $assessment->updated_at = $updatedAt;
            $assessment->save();

            if ($blitz->duration_seconds !== $resulting['duration_seconds']) {
                $blitz->duration_seconds = $resulting['duration_seconds'];
                $blitz->updated_at = $updatedAt;
                $blitz->save();
            }

            return ($this->showTeacherBlitz)($teacher, $assessment->id);
        });
    }
}
