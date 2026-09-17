<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAssignmentSource;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\GroupStudentMembership;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
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

    public function test_first_official_blitz_activity_locks_pair_at_exact_attempt_start_without_changing_cohort_or_identities(): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        $before = $pair->fresh()->getAttributes();
        $recipientsBefore = AssessmentStudent::query()->where('assessment_id', $assessment->id)->get()->map->getAttributes()->all();
        $this->assertFalse(GroupStudentMembership::query()->where('student_id', $student->id)->exists());
        $this->travelTo(Carbon::parse('2026-09-17T12:00:00.500000Z'));
        $this->startStudentBlitz($student, $assessment)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $pair->refresh();
        $this->assertTrue($attempt->started_at->equalTo($pair->locked_at));
        $this->assertTrue($attempt->started_at->equalTo($pair->updated_at));
        foreach (['homework_assessment_id', 'blitz_assessment_id', 'cohort_snapshotted_at', 'designated_at', 'designated_by_user_id'] as $field) {
            $this->assertSame($before[$field], $pair->getRawOriginal($field));
        }
        $this->assertSame($recipientsBefore, AssessmentStudent::query()->where('assessment_id', $assessment->id)->get()->map->getAttributes()->all());
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public function test_prior_homework_activity_justifies_existing_pair_lock_without_timestamp_churn(): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        $homework = Assessment::query()->findOrFail($pair->homework_assessment_id);
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $homework->id, 'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Group]);
        $prior = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id,
            'started_at' => now()->subMinutes(2), 'possible_points' => $homework->total_possible_points]);
        $pair->forceFill(['locked_at' => $prior->started_at, 'updated_at' => $prior->started_at])->save();
        $before = $pair->fresh()->getAttributes();
        $priorBefore = $prior->fresh()->getAttributes();

        $this->startStudentBlitz($student, $assessment)->assertCreated()->assertJsonPath('data.attempt_number', 1);

        $this->assertSame($before, $pair->fresh()->getAttributes());
        $this->assertSame($priorBefore, $prior->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 2);
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

    public static function pairCorruptions(): array
    {
        return [['unlocked with homework activity'], ['unlocked with other student blitz activity'],
            ['locked without activity'], ['missing cohort'], ['direct recipient'], ['non-group assignment']];
    }
}
