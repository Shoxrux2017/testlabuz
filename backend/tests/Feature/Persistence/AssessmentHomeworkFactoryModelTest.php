<?php

namespace Tests\Feature\Persistence;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\HomeworkStatus;
use App\Enums\UserRole;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class AssessmentHomeworkFactoryModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_enums_expose_exact_persisted_machine_values(): void
    {
        $this->assertSame(['homework', 'blitz'], AssessmentType::values());
        $this->assertSame(['group', 'selected_students'], AssessmentAssignmentMode::values());
        $this->assertSame(['draft', 'active', 'closed', 'archived'], HomeworkStatus::values());
        $this->assertSame(['group', 'direct'], AssessmentAssignmentSource::values());
        $this->assertSame([
            'in_progress',
            'submitted',
            'timed_out_finalized',
            'waiting_for_teacher_review',
            'checked',
        ], AssessmentAttemptStatus::values());
        $this->assertSame([
            'student_submit',
            'timeout_auto_submit',
            'task_closed_auto_finalize',
            'homework_deadline_auto_submit',
        ], AssessmentAttemptFinalizationReason::values());
    }

    public function test_models_cast_fields_use_uuid_keys_and_resolve_the_complete_relationship_graph(): void
    {
        $institution = Institution::factory()->create();
        $teacher = User::factory()->teacher($institution)->create();
        $student = User::factory()->student($institution)->create();
        $topic = Topic::factory()->create([
            'institution_id' => $institution,
            'teacher_id' => $teacher,
        ]);
        $assessment = Assessment::factory()->homework()->groupAssignment()->create([
            'institution_id' => $institution,
            'topic_id' => $topic,
            'teacher_id' => $teacher,
            'total_possible_points' => '25.125000',
        ]);
        $homework = HomeworkAssignment::factory()->archivedAfterClose()->create([
            'assessment_id' => $assessment,
            'institution_id' => $institution,
            'deadline_at' => now()->addDay(),
        ]);
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution,
            'assessment_id' => $assessment,
            'student_id' => $student,
            'assigned_by_user_id' => $teacher,
            'assignment_source' => AssessmentAssignmentSource::Group,
        ]);
        $startedAt = now()->subMinutes(2);
        $attempt = AssessmentAttempt::factory()->create([
            'institution_id' => $institution,
            'assessment_id' => $assessment,
            'assessment_student_id' => $recipient,
            'student_id' => $student,
            'status' => AssessmentAttemptStatus::Checked,
            'started_at' => $startedAt,
            'submitted_at' => $startedAt->copy()->addSeconds(30),
            'finalized_at' => $startedAt->copy()->addMinute(),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
            'locked_at' => $startedAt->copy()->addMinute(),
            'earned_points' => '20.12345678',
            'possible_points' => '25.125000',
            'normalized_score' => '80.09336048',
            'scoring_completed_at' => $startedAt->copy()->addSeconds(90),
        ]);
        $blitz = Assessment::factory()->blitz()->groupAssignment()->create([
            'institution_id' => $institution,
            'topic_id' => $topic,
            'teacher_id' => $teacher,
        ]);
        $pair = TopicResultPair::factory()->create([
            'institution_id' => $institution,
            'topic_id' => $topic,
            'homework_assessment_id' => $assessment,
            'blitz_assessment_id' => $blitz,
            'designated_by_user_id' => $teacher,
            'designated_at' => $startedAt,
            'cohort_snapshotted_at' => $startedAt->copy()->addSeconds(30),
            'locked_at' => $startedAt->copy()->addMinute(),
        ]);

        foreach ([$assessment, $recipient, $attempt, $pair] as $model) {
            $this->assertTrue(Str::isUuid($model->id));
        }

        $this->assertSame('assessment_id', $homework->getKeyName());
        $this->assertSame($assessment->id, $homework->getKey());
        $this->assertFalse($homework->getIncrementing());
        $this->assertSame('string', $homework->getKeyType());

        $this->assertSame(AssessmentType::Homework, $assessment->type);
        $this->assertSame(AssessmentAssignmentMode::Group, $assessment->assignment_mode);
        $this->assertSame('25.125000', $assessment->total_possible_points);
        $this->assertSame(HomeworkStatus::Archived, $homework->status);
        $this->assertSame(AssessmentAssignmentSource::Group, $recipient->assignment_source);
        $this->assertSame(AssessmentAttemptStatus::Checked, $attempt->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::StudentSubmit, $attempt->finalization_reason);
        $this->assertTrue($attempt->official_score_eligible);
        $this->assertSame('20.12345678', $attempt->earned_points);
        $this->assertSame('25.125000', $attempt->possible_points);
        $this->assertSame('80.09336048', $attempt->normalized_score);

        foreach ([
            $homework->deadline_at,
            $homework->activated_at,
            $homework->closed_at,
            $homework->archived_at,
            $recipient->assigned_at,
            $attempt->started_at,
            $attempt->submitted_at,
            $attempt->finalized_at,
            $attempt->locked_at,
            $attempt->scoring_completed_at,
            $pair->designated_at,
            $pair->cohort_snapshotted_at,
            $pair->locked_at,
        ] as $instant) {
            $this->assertInstanceOf(CarbonInterface::class, $instant);
        }

        $this->assertTrue($institution->is($assessment->institution));
        $this->assertTrue($topic->is($assessment->topic));
        $this->assertTrue($teacher->is($assessment->teacher));
        $this->assertTrue($homework->is($assessment->homeworkAssignment));
        $this->assertTrue($assessment->recipients->contains($recipient));
        $this->assertTrue($assessment->attempts->contains($attempt));
        $this->assertTrue($pair->is($assessment->resultPairAsHomework));
        $this->assertTrue($pair->is($blitz->resultPairAsBlitz));

        $this->assertTrue($assessment->is($homework->assessment));
        $this->assertTrue($institution->is($homework->institution));
        $this->assertTrue($institution->is($recipient->institution));
        $this->assertTrue($assessment->is($recipient->assessment));
        $this->assertTrue($student->is($recipient->student));
        $this->assertTrue($teacher->is($recipient->assignedBy));
        $this->assertTrue($recipient->attempts->contains($attempt));

        $this->assertTrue($institution->is($attempt->institution));
        $this->assertTrue($assessment->is($attempt->assessment));
        $this->assertTrue($recipient->is($attempt->assessmentStudent));
        $this->assertTrue($student->is($attempt->student));

        $this->assertTrue($institution->is($pair->institution));
        $this->assertTrue($topic->is($pair->topic));
        $this->assertTrue($assessment->is($pair->homeworkAssessment));
        $this->assertTrue($blitz->is($pair->blitzAssessment));
        $this->assertTrue($teacher->is($pair->designatedBy));

        $this->assertTrue($topic->assessments->contains($assessment));
        $this->assertTrue($topic->assessments->contains($blitz));
        $this->assertTrue($pair->is($topic->resultPair));
        $this->assertTrue($institution->assessments->contains($assessment));
        $this->assertTrue($institution->homeworkAssignments->contains($homework));
        $this->assertTrue($institution->assessmentStudents->contains($recipient));
        $this->assertTrue($institution->assessmentAttempts->contains($attempt));
        $this->assertTrue($institution->topicResultPairs->contains($pair));
        $this->assertTrue($teacher->authoredAssessments->contains($assessment));
        $this->assertTrue($student->assessmentAssignments->contains($recipient));
        $this->assertTrue($teacher->assessmentAssignmentsCreated->contains($recipient));
        $this->assertTrue($student->assessmentAttempts->contains($attempt));
        $this->assertTrue($teacher->designatedTopicResultPairs->contains($pair));
    }

    public function test_factories_create_valid_same_institution_assessment_recipient_and_attempt_graphs(): void
    {
        $homework = Assessment::factory()->homework()->groupAssignment()->create();
        $blitz = Assessment::factory()->blitz()->selectedStudentsAssignment()->create();
        $recipient = AssessmentStudent::factory()->create();
        $attempt = AssessmentAttempt::factory()->create();

        foreach ([$homework, $blitz] as $assessment) {
            $this->assertSame($assessment->institution_id, $assessment->topic->institution_id);
            $this->assertSame($assessment->institution_id, $assessment->teacher->institution_id);
            $this->assertSame(UserRole::Teacher, $assessment->teacher->role);
            $this->assertNotSame('', trim($assessment->title));
            $this->assertNotSame('', trim($assessment->student_instructions));
        }

        $this->assertSame(AssessmentType::Homework, $homework->type);
        $this->assertSame(AssessmentAssignmentMode::Group, $homework->assignment_mode);
        $this->assertSame(AssessmentType::Blitz, $blitz->type);
        $this->assertSame(AssessmentAssignmentMode::SelectedStudents, $blitz->assignment_mode);

        $this->assertSame($recipient->institution_id, $recipient->assessment->institution_id);
        $this->assertSame($recipient->institution_id, $recipient->student->institution_id);
        $this->assertSame($recipient->institution_id, $recipient->assignedBy->institution_id);
        $this->assertSame(UserRole::Student, $recipient->student->role);
        $this->assertSame(AssessmentAssignmentSource::Group, $recipient->assignment_source);

        $this->assertSame($attempt->institution_id, $attempt->assessmentStudent->institution_id);
        $this->assertSame($attempt->assessment_id, $attempt->assessmentStudent->assessment_id);
        $this->assertSame($attempt->student_id, $attempt->assessmentStudent->student_id);
        $this->assertSame(1, $attempt->attempt_number);
        $this->assertSame(AssessmentAttemptStatus::InProgress, $attempt->status);
        $this->assertTrue($attempt->official_score_eligible);
        $this->assertNull($attempt->submitted_at);
        $this->assertNull($attempt->finalized_at);
        $this->assertNull($attempt->finalization_reason);
        $this->assertNull($attempt->locked_at);
    }

    public function test_homework_and_result_pair_factory_states_create_only_valid_structural_shapes(): void
    {
        $draft = HomeworkAssignment::factory()->draft()->create();
        $active = HomeworkAssignment::factory()->active()->create();
        $closed = HomeworkAssignment::factory()->closed()->create();
        $archivedFromDraft = HomeworkAssignment::factory()->archivedFromDraft()->create();
        $archivedAfterClose = HomeworkAssignment::factory()->archivedAfterClose()->create();

        $this->assertSame(HomeworkStatus::Draft, $draft->status);
        $this->assertNull($draft->activated_at);
        $this->assertSame(HomeworkStatus::Active, $active->status);
        $this->assertNotNull($active->activated_at);
        $this->assertSame(HomeworkStatus::Closed, $closed->status);
        $this->assertTrue($closed->closed_at->greaterThanOrEqualTo($closed->activated_at));
        $this->assertSame(HomeworkStatus::Archived, $archivedFromDraft->status);
        $this->assertNull($archivedFromDraft->activated_at);
        $this->assertNull($archivedFromDraft->closed_at);
        $this->assertSame(HomeworkStatus::Archived, $archivedAfterClose->status);
        $this->assertTrue($archivedAfterClose->archived_at->greaterThanOrEqualTo($archivedAfterClose->closed_at));

        foreach ([$draft, $active, $closed, $archivedFromDraft, $archivedAfterClose] as $homework) {
            $this->assertSame(AssessmentType::Homework, $homework->assessment->type);
            $this->assertSame($homework->institution_id, $homework->assessment->institution_id);
        }

        $partialPair = TopicResultPair::factory()->create();
        $completePair = TopicResultPair::factory()->withBlitz()->create();

        $this->assertSame(AssessmentType::Homework, $partialPair->homeworkAssessment->type);
        $this->assertNull($partialPair->blitz_assessment_id);
        $this->assertNull($partialPair->blitzAssessment);
        $this->assertSame($partialPair->institution_id, $partialPair->homeworkAssessment->institution_id);
        $this->assertSame($partialPair->topic_id, $partialPair->homeworkAssessment->topic_id);

        $this->assertSame(AssessmentType::Homework, $completePair->homeworkAssessment->type);
        $this->assertSame(AssessmentType::Blitz, $completePair->blitzAssessment->type);
        $this->assertSame($completePair->institution_id, $completePair->blitzAssessment->institution_id);
        $this->assertSame($completePair->topic_id, $completePair->blitzAssessment->topic_id);
    }
}
