<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\AssessmentPointMath;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use App\Support\Teacher\InstitutionBlitzScheduledAt;
use App\Support\Teacher\TeacherAssessmentRecipients;
use App\Support\Teacher\TeacherBlitzAccess;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

final class CreateTeacherBlitz
{
    public function __construct(
        private readonly TeacherBlitzAccess $access,
        private readonly TeacherAssessmentRecipients $recipients,
        private readonly InstitutionBlitzScheduledAt $scheduledAt,
        private readonly AssessmentPointMath $pointMath,
        private readonly QuestionConfigurationWriter $questionWriter,
        private readonly ShowTeacherBlitz $showTeacherBlitz,
    ) {}

    /**
     * @param array{
     *     title: string,
     *     description: ?string,
     *     student_instructions: string,
     *     assignment_mode: string,
     *     student_ids: list<string>,
     *     scheduled_at: ?string,
     *     duration_seconds: int,
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
            $scheduledAt = is_string($attributes['scheduled_at'])
                ? $this->scheduledAt->requireFuture($teacher, $attributes['scheduled_at'], now())
                : null;
            $totalPoints = $this->pointMath->sum(array_map(
                static fn (array $question): int|float|string => $question['points'],
                $attributes['questions'],
            ));

            $assessment = Assessment::query()->create([
                'institution_id' => $teacher->institution_id,
                'topic_id' => $topic->id,
                'teacher_id' => $teacher->id,
                'type' => AssessmentType::Blitz,
                'title' => $attributes['title'],
                'description' => $attributes['description'],
                'student_instructions' => $attributes['student_instructions'],
                'assignment_mode' => $assignmentMode,
                'total_possible_points' => $totalPoints,
            ]);

            BlitzTask::query()->create([
                'assessment_id' => $assessment->id,
                'institution_id' => $teacher->institution_id,
                'status' => BlitzStatus::Draft,
                'duration_seconds' => $attributes['duration_seconds'],
                'timer_start_mode_snapshot' => null,
                'synchronized_ends_at' => null,
                'activated_by_user_id' => null,
                'scheduled_at' => $scheduledAt,
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

            return ($this->showTeacherBlitz)($teacher, $assessment->id);
        });
    }
}
