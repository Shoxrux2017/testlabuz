<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\AssessmentPointMath;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentType;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use App\Support\Teacher\InstitutionHomeworkDeadlineAt;
use App\Support\Teacher\TeacherHomeworkAccess;
use App\Support\Teacher\TeacherHomeworkRecipients;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

final class CreateTeacherHomework
{
    public function __construct(
        private readonly TeacherHomeworkAccess $access,
        private readonly TeacherHomeworkRecipients $recipients,
        private readonly InstitutionHomeworkDeadlineAt $deadlineAt,
        private readonly AssessmentPointMath $pointMath,
        private readonly QuestionConfigurationWriter $questionWriter,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    /**
     * @param array{
     *     title: string,
     *     description: ?string,
     *     student_instructions: string,
     *     assignment_mode: string,
     *     student_ids: list<string>,
     *     deadline_at: ?string,
     *     questions: list<array<string, mixed>>
     * } $attributes
     */
    public function __invoke(User $teacher, string $topicId, array $attributes): Assessment
    {
        $preliminaryTopic = $this->access->resolveTopic($teacher, $topicId);

        return DB::transaction(function () use ($teacher, $preliminaryTopic, $attributes): Assessment {
            ['group' => $group, 'topic' => $topic] = $this->access->lockTopic($teacher, $preliminaryTopic);

            if (! in_array($topic->status, [TopicStatus::Draft, TopicStatus::Active], true)) {
                throw new TopicNotEditableException;
            }

            $assignmentMode = AssessmentAssignmentMode::from($attributes['assignment_mode']);
            $studentIds = $assignmentMode === AssessmentAssignmentMode::SelectedStudents
                ? $this->recipients->lockSelected($teacher, $group, $attributes['student_ids'])
                : [];
            $deadlineAt = is_string($attributes['deadline_at'])
                ? $this->deadlineAt->parse($teacher, $attributes['deadline_at'])
                : null;
            $totalPoints = $this->pointMath->sum(array_map(
                static fn (array $question): int|float|string => $question['points'],
                $attributes['questions'],
            ));

            $assessment = Assessment::query()->create([
                'institution_id' => $teacher->institution_id,
                'topic_id' => $topic->id,
                'teacher_id' => $teacher->id,
                'type' => AssessmentType::Homework,
                'title' => $attributes['title'],
                'description' => $attributes['description'],
                'student_instructions' => $attributes['student_instructions'],
                'assignment_mode' => $assignmentMode,
                'total_possible_points' => $totalPoints,
            ]);

            HomeworkAssignment::query()->create([
                'assessment_id' => $assessment->id,
                'institution_id' => $teacher->institution_id,
                'status' => HomeworkStatus::Draft,
                'deadline_at' => $deadlineAt,
                'activated_at' => null,
                'closed_at' => null,
                'archived_at' => null,
            ]);

            if ($assignmentMode === AssessmentAssignmentMode::SelectedStudents) {
                /** @var Collection<int, AssessmentStudent> $emptyRecipients */
                $emptyRecipients = new Collection;
                $this->recipients->synchronize(
                    $teacher,
                    $assessment,
                    $studentIds,
                    AssessmentAssignmentSource::Direct,
                    $emptyRecipients,
                );
            }

            foreach ($attributes['questions'] as $question) {
                $this->questionWriter->create($assessment, $question);
            }

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }
}
