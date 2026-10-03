<?php

namespace Tests\Feature\Student;

use App\Actions\Teacher\GrantTeacherBlitzAttemptException;
use App\Enums\AssessmentAssignmentSource;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzContext;
use Tests\TestCase;

class StudentOfficialBlitzAttemptStartTest extends TestCase
{
    use BuildsStudentBlitzContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_a_student_without_a_submitted_official_homework_cannot_start_the_official_blitz(): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        $before = $pair->fresh()->getAttributes();

        // S10-D8: the Blitz checks the Student's own Homework, so it can no longer be the first official activity.
        $this->startStudentBlitz($student, $assessment)->assertConflict()->assertJsonPath('code', 'homework_not_submitted');
        $this->assertSame($before, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);

        // An Attempt still in progress is not a submitted Homework, and a classmate's submitted Homework does not count.
        $prior = $this->homeworkAttempt($student, $pair, ['started_at' => now()->subMinutes(2)]);
        $pair->forceFill(['locked_at' => $prior->started_at, 'updated_at' => $prior->started_at])->save();
        $this->homeworkAttempt($this->studentBlitzActor($student->institution), $pair, ['status' => 'submitted', 'started_at' => now()->subMinutes(2),
            'submitted_at' => now()->subMinute(), 'finalized_at' => now()->subMinute(), 'locked_at' => now()->subMinute(),
            'finalization_reason' => 'student_submit']);

        $this->startStudentBlitz($student, $assessment)->assertConflict()->assertJsonPath('code', 'homework_not_submitted');
        $this->assertDatabaseCount('assessment_attempts', 2);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    /** @return array<string, array{string}> */
    public static function terminalHomeworkStatuses(): array
    {
        return ['submitted' => ['submitted'], 'waiting for review' => ['waiting_for_teacher_review'], 'checked' => ['checked']];
    }

    #[DataProvider('terminalHomeworkStatuses')]
    public function test_a_submitted_official_homework_lets_the_student_start_without_pair_timestamp_churn(string $status): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        $prior = $this->homeworkAttempt($student, $pair, ['status' => $status, 'started_at' => now()->subMinutes(8),
            'submitted_at' => now()->subMinutes(6), 'finalized_at' => now()->subMinutes(6), 'locked_at' => now()->subMinutes(6),
            'finalization_reason' => 'student_submit', 'normalized_score' => $status === 'checked' ? '50.00000000' : null,
            'scoring_completed_at' => $status === 'checked' ? now()->subMinutes(5) : null]);
        $pair->forceFill(['locked_at' => $prior->started_at, 'updated_at' => $prior->started_at])->save();
        $before = $pair->fresh()->getAttributes();
        $priorBefore = $prior->fresh()->getAttributes();
        $recipients = fn (): array => AssessmentStudent::query()->whereIn('assessment_id', [$assessment->id, $pair->homework_assessment_id])
            ->orderBy('id')->get()->map->getAttributes()->all();
        $recipientsBefore = $recipients();
        // The Student starts from the persisted cohort, not from a current group membership.
        $this->assertFalse(GroupStudentMembership::query()->where('student_id', $student->id)->exists());

        $this->startStudentBlitz($student, $assessment)->assertCreated()->assertJsonPath('data.attempt_number', 1);

        $this->assertSame($before, $pair->fresh()->getAttributes());
        $this->assertSame($priorBefore, $prior->fresh()->getAttributes());
        $this->assertSame($recipientsBefore, $recipients());
        $this->assertDatabaseCount('assessment_attempts', 2);
    }

    public function test_an_existing_first_attempt_and_a_practice_blitz_are_not_barred(): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        // History from before S10-D8: the Student started the official Blitz without a submitted Homework.
        $existing = $this->studentBlitzAttempt($assessment, $student);
        $pair->forceFill(['locked_at' => $existing->started_at])->save();

        $this->startStudentBlitz($student, $assessment)->assertOk()->assertJsonPath('data.id', $existing->id);
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $existing->id)->assertOk();

        // The replacement after an approved exception is not a first Attempt either.
        $this->terminateStudentBlitzAttempt($existing);
        $teacher = $assessment->teacher;
        GroupTeacherMembership::factory()->create(['institution_id' => $student->institution_id, 'group_id' => $assessment->topic->group_id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $teacher->id]);
        app(GrantTeacherBlitzAttemptException::class)($teacher, $assessment->id, $student->id, (string) Str::uuid(),
            ['reason_type' => 'technical', 'reason' => 'Device interruption.']);
        $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertCreated()->assertJsonPath('data.attempt_number', 2);

        $practice = $this->studentBlitz($student);
        $this->startStudentBlitz($student, $practice)->assertCreated();
    }

    #[DataProvider('pairCorruptions')]
    public function test_official_pair_conflicts_are_not_repaired_and_commit_no_blitz_attempt_or_claim(string $corruption): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        if ($corruption === 'unlocked with homework activity') {
            $recipient = AssessmentStudent::factory()->create(['assessment_id' => $pair->homework_assessment_id, 'student_id' => $student->id]);
            AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id]);
        } elseif ($corruption === 'unlocked with other student blitz activity') {
            $this->studentBlitzAttempt($assessment, $this->studentBlitzActor($student->institution));
        } elseif ($corruption === 'locked without activity') {
            $pair->update(['locked_at' => now()->subMinute()]);
        } elseif ($corruption === 'missing cohort') {
            $pair->update(['cohort_snapshotted_at' => null]);
        } elseif ($corruption === 'direct recipient') {
            AssessmentStudent::query()->where('assessment_id', $assessment->id)->update(['assignment_source' => AssessmentAssignmentSource::Direct]);
        } else {
            $assessment->update(['assignment_mode' => 'selected_students']);
        }
        $before = $pair->fresh()->getAttributes();
        $attemptsBefore = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $this->startStudentBlitz($student, $assessment)->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->assertSame($before, $pair->fresh()->getAttributes());
        $this->assertSame($attemptsBefore, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_practice_blitz_does_not_mutate_existing_topic_pair(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $pair = $this->officialBlitzPair($assessment, $assessment->teacher);
        $pair->update(['blitz_assessment_id' => null]);
        $before = $pair->fresh()->getAttributes();
        $this->startStudentBlitz($student, $assessment)->assertCreated();
        $this->assertSame($before, $pair->fresh()->getAttributes());
        $this->assertNull($pair->fresh()->locked_at);
    }

    /** @param array<string, mixed> $attributes */
    private function homeworkAttempt(User $student, TopicResultPair $pair, array $attributes): AssessmentAttempt
    {
        $homework = Assessment::query()->findOrFail($pair->homework_assessment_id);
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $homework->id, 'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Group]);

        return AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id,
            'possible_points' => $homework->total_possible_points, ...$attributes]);
    }

    public static function pairCorruptions(): array
    {
        return [['unlocked with homework activity'], ['unlocked with other student blitz activity'],
            ['locked without activity'], ['missing cohort'], ['direct recipient'], ['non-group assignment']];
    }
}
