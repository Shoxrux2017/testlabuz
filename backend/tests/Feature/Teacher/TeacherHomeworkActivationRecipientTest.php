<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\GroupStudentMembership;
use App\Models\Institution;
use App\Models\Question;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Teacher\Concerns\BuildsTeacherHomeworkContext;
use Tests\TestCase;

class TeacherHomeworkActivationRecipientTest extends TestCase
{
    use BuildsTeacherHomeworkContext;
    use RefreshDatabase;

    public function test_group_activation_snapshots_exact_current_active_group_students(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $eligibleA = $this->eligibleStudent($institution, $admin, $group);
        $eligibleB = $this->eligibleStudent($institution, $admin, $group);
        $inactive = $this->eligibleStudent($institution, $admin, $group, ['is_active' => false]);
        $former = $this->eligibleStudent($institution, $admin, $group);
        GroupStudentMembership::query()
            ->where('group_id', $group->id)
            ->where('student_id', $former->id)
            ->update(['ended_at' => now()]);
        $foreignInstitution = Institution::factory()->create();
        $foreign = User::factory()->student($foreignInstitution)->create();
        $assessment = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($assessment);

        try {
            CarbonImmutable::setTestNow('2026-09-03 12:34:56 UTC');
            $this->activate($teacher, $assessment)
                ->assertOk()
                ->assertJsonPath('data.status', 'active');
        } finally {
            CarbonImmutable::setTestNow();
        }

        $recipients = AssessmentStudent::query()
            ->where('assessment_id', $assessment->id)
            ->orderBy('student_id')
            ->get();
        $this->assertSame(
            collect([$eligibleA->id, $eligibleB->id])->sort()->values()->all(),
            $recipients->pluck('student_id')->all(),
        );
        $this->assertTrue($recipients->every(
            fn (AssessmentStudent $recipient): bool => $recipient->assignment_source === AssessmentAssignmentSource::Group
                && $recipient->assigned_by_user_id === $teacher->id
                && $recipient->assigned_at?->toIso8601String() === '2026-09-03T12:34:56+00:00',
        ));
        $this->assertNotContains($inactive->id, $recipients->pluck('student_id')->all());
        $this->assertNotContains($former->id, $recipients->pluck('student_id')->all());
        $this->assertNotContains($foreign->id, $recipients->pluck('student_id')->all());
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    public function test_group_activation_requires_recipients_and_rolls_back_points_and_lifecycle(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            assessmentAttributes: ['total_possible_points' => '9.000000'],
        );
        $this->scoreableQuestion($assessment, '2.000000');
        $before = $this->aggregateState($assessment);

        $this->assertAssessmentNotAssigned($this->activate($teacher, $assessment));

        $this->assertSame($before, $this->aggregateState($assessment));
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    public function test_selected_activation_preserves_recipient_identity_assignment_time_and_rows(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $studentA = $this->eligibleStudent($institution, $admin, $group);
        $studentB = $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            mode: AssessmentAssignmentMode::SelectedStudents,
        );
        $assignedAt = CarbonImmutable::parse('2026-09-02 09:00:00 UTC');
        $recipients = collect([$studentA, $studentB])->map(fn (User $student): AssessmentStudent => AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct,
            'assigned_at' => $assignedAt,
            'assigned_by_user_id' => $teacher->id,
        ]));
        $before = $this->recipientState($assessment);
        $this->scoreableQuestion($assessment);

        $response = $this->activate($teacher, $assessment);

        $response->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.student_ids', collect([$studentA->id, $studentB->id])->sort()->values()->all());
        $this->assertSame($before, $this->recipientState($assessment));
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    public function test_selected_empty_removed_and_inactive_runtime_sets_use_assessment_not_assigned(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);

        $empty = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            mode: AssessmentAssignmentMode::SelectedStudents,
        );
        $this->scoreableQuestion($empty);
        $this->assertAssessmentNotAssigned($this->activate($teacher, $empty));

        $removedStudent = $this->eligibleStudent($institution, $admin, $group);
        $removed = $this->selectedHomework($institution, $teacher, $topic, $removedStudent);
        GroupStudentMembership::query()
            ->where('group_id', $group->id)
            ->where('student_id', $removedStudent->id)
            ->update(['ended_at' => now()]);
        $this->assertAssessmentNotAssigned($this->activate($teacher, $removed));

        $inactiveStudent = $this->eligibleStudent($institution, $admin, $group);
        $inactive = $this->selectedHomework($institution, $teacher, $topic, $inactiveStudent);
        $inactiveStudent->forceFill(['is_active' => false])->save();
        $this->assertAssessmentNotAssigned($this->activate($teacher, $inactive));

        foreach ([$empty, $removed, $inactive] as $assessment) {
            $this->assertSame(HomeworkStatus::Draft, $assessment->homeworkAssignment()->firstOrFail()->status);
        }
    }

    public function test_group_draft_with_unexpected_recipient_row_is_a_business_conflict(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($assessment);
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Group,
            'assigned_by_user_id' => $teacher->id,
        ]);
        $before = $this->recipientState($assessment);

        $this->assertBusinessConflict($this->activate($teacher, $assessment));

        $this->assertSame($before, $this->recipientState($assessment));
        $this->assertSame(HomeworkStatus::Draft, $assessment->homeworkAssignment()->firstOrFail()->status);
    }

    public function test_selected_draft_with_inconsistent_non_direct_source_is_a_business_conflict(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            mode: AssessmentAssignmentMode::SelectedStudents,
        );
        $this->scoreableQuestion($assessment);
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Group,
            'assigned_by_user_id' => $teacher->id,
        ]);
        $before = $this->recipientState($assessment);

        $this->assertBusinessConflict($this->activate($teacher, $assessment));

        $this->assertSame($before, $this->recipientState($assessment));
        $this->assertSame(HomeworkStatus::Draft, $assessment->homeworkAssignment()->firstOrFail()->status);
    }

    private function selectedHomework(
        Institution $institution,
        User $teacher,
        Topic $topic,
        User $student,
    ): Assessment {
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            mode: AssessmentAssignmentMode::SelectedStudents,
        );
        AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct,
            'assigned_by_user_id' => $teacher->id,
        ]);
        $this->scoreableQuestion($assessment);

        return $assessment;
    }

    private function scoreableQuestion(Assessment $assessment, string $points = '1.000000'): void
    {
        Question::factory()->openWritten()->create([
            'institution_id' => $assessment->institution_id,
            'assessment_id' => $assessment->id,
            'points' => $points,
        ]);
    }

    /** @return array<string, mixed> */
    private function aggregateState(Assessment $assessment): array
    {
        $freshAssessment = $assessment->fresh();
        $homework = $assessment->homeworkAssignment()->firstOrFail();

        return [
            'assessment' => collect($freshAssessment?->getAttributes())
                ->only(['total_possible_points', 'updated_at'])
                ->all(),
            'homework' => collect($homework->getAttributes())
                ->only(['status', 'activated_at', 'closed_at', 'archived_at', 'updated_at'])
                ->all(),
        ];
    }

    /** @return array<string, array<string, mixed>> */
    private function recipientState(Assessment $assessment): array
    {
        return AssessmentStudent::query()
            ->where('assessment_id', $assessment->id)
            ->orderBy('id')
            ->get()
            ->mapWithKeys(fn (AssessmentStudent $recipient): array => [$recipient->id => [
                'student_id' => $recipient->student_id,
                'assignment_source' => $recipient->getRawOriginal('assignment_source'),
                'assigned_at' => $recipient->assigned_at?->format('U.u'),
                'assigned_by_user_id' => $recipient->assigned_by_user_id,
                'created_at' => $recipient->created_at?->format('U.u'),
                'updated_at' => $recipient->updated_at?->format('U.u'),
            ]])
            ->all();
    }

    private function activate(User $teacher, Assessment $assessment): TestResponse
    {
        return $this->homeworkRaw(
            $teacher,
            'POST',
            '/api/v1/teacher/homework/'.$assessment->id.'/activate',
            '',
        );
    }

    private function assertAssessmentNotAssigned(TestResponse $response): void
    {
        $this->assertSame([
            'message' => 'The assessment is not assigned to any eligible students.',
            'code' => 'assessment_not_assigned',
            'errors' => [],
        ], $response->assertConflict()->json());
    }

    private function assertBusinessConflict(TestResponse $response): void
    {
        $this->assertSame([
            'message' => 'The requested change conflicts with current task activity.',
            'code' => 'business_conflict',
            'errors' => [],
        ], $response->assertConflict()->json());
    }
}
