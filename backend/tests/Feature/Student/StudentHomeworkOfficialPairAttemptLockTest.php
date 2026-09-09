<?php

namespace Tests\Feature\Student;

use App\Actions\Student\StartStudentHomeworkAttempt;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentHomeworkOfficialPairAttemptLockTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
    }

    #[DataProvider('blitzPairStates')]
    public function test_first_global_official_start_locks_pair_before_insertion_with_the_same_instant_and_preserves_identity(bool $withBlitz): void
    {
        [$student, $homework, $pair] = $this->officialHomework($withBlitz);
        $before = $pair->fresh()->getAttributes();
        $pairLockedBeforeInsert = false;
        $dispatcher = AssessmentAttempt::getEventDispatcher();
        AssessmentAttempt::setEventDispatcher(clone $dispatcher);
        AssessmentAttempt::creating(function (AssessmentAttempt $attempt) use ($pair, &$pairLockedBeforeInsert): void {
            $lockedPair = $pair->fresh();
            $pairLockedBeforeInsert = $lockedPair->locked_at !== null
                && $lockedPair->locked_at->equalTo($attempt->started_at)
                && $lockedPair->updated_at->equalTo($attempt->started_at)
                && ! AssessmentAttempt::query()->where('assessment_id', $attempt->assessment_id)->exists();
        });
        try {
            $response = $this->start($student, $homework)->assertCreated();
        } finally {
            AssessmentAttempt::setEventDispatcher($dispatcher);
        }
        $attempt = AssessmentAttempt::query()->sole();
        $pair->refresh();
        $this->assertTrue($pairLockedBeforeInsert);
        $this->assertSame($attempt->id, $response->json('data.id'));
        $this->assertSame('2026-09-09 12:00:00', $pair->locked_at->format('Y-m-d H:i:s'));
        $this->assertTrue($pair->locked_at->equalTo($attempt->started_at));
        $this->assertTrue($pair->updated_at->equalTo($attempt->started_at));
        foreach (['homework_assessment_id', 'blitz_assessment_id', 'designated_by_user_id', 'designated_at', 'cohort_snapshotted_at', 'created_at'] as $field) {
            $this->assertSame($before[$field], $pair->getAttributes()[$field], $field.' must remain unchanged.');
        }
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->assertDatabaseCount('attempt_answers', 0);
    }

    public static function blitzPairStates(): array
    {
        return ['Homework-only official pair' => [false], 'pair with existing Blitz identity' => [true]];
    }

    public function test_subsequent_student_resume_and_next_attempt_preserve_the_first_global_pair_lock(): void
    {
        [$firstStudent, $homework, $pair] = $this->officialHomework();
        $this->start($firstStudent, $homework)->assertCreated();
        $pairBefore = $pair->fresh()->getAttributes();
        $second = User::factory()->student($firstStudent->institution)->create(['must_change_password' => false]);
        $this->recipient($homework, $second);
        $this->travel(1)->minutes();
        $secondId = $this->start($second, $homework)->assertCreated()->json('data.id');
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->travel(1)->minutes();
        $this->start($second, $homework)->assertOk()->assertJsonPath('data.id', $secondId);
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        AssessmentAttempt::query()->findOrFail($secondId)->update([
            'status' => AssessmentAttemptStatus::Submitted, 'submitted_at' => now(), 'finalized_at' => now(),
            'locked_at' => now(), 'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
        ]);
        $this->travel(1)->minutes();
        $this->start($second, $homework)->assertCreated()->assertJsonPath('data.attempt_number', 2);
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 3);
    }

    public function test_practice_homework_start_and_resume_do_not_mutate_the_topics_unrelated_official_pair(): void
    {
        [$student, $official, $pair] = $this->officialHomework();
        $practice = Assessment::factory()->homework()->selectedStudentsAssignment()->create([
            'institution_id' => $student->institution_id, 'topic_id' => $official->assessment->topic_id,
            'teacher_id' => $official->assessment->teacher_id, 'total_possible_points' => '2.000000',
        ]);
        $homework = HomeworkAssignment::factory()->active()->create(['assessment_id' => $practice->id]);
        $this->recipient($homework, $student)->update(['assignment_source' => AssessmentAssignmentSource::Direct]);
        $pairBefore = $pair->fresh()->getAttributes();
        $attemptId = $this->start($student, $homework)->assertCreated()->json('data.id');
        $this->travel(1)->minutes();
        $this->start($student, $homework)->assertOk()->assertJsonPath('data.id', $attemptId);
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => $official->assessment_id]);
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    #[DataProvider('officialIntegrityFailures')]
    public function test_invalid_official_integrity_returns_business_conflict_without_attempt_pair_or_claim_mutation(string $failure): void
    {
        [$student, $homework, $pair] = $this->officialHomework();
        if ($failure === 'missing cohort') {
            $pair->update(['cohort_snapshotted_at' => null]);
        } elseif ($failure === 'non-group assessment') {
            $homework->assessment->update(['assignment_mode' => AssessmentAssignmentMode::SelectedStudents]);
        } elseif ($failure === 'non-group recipient') {
            AssessmentStudent::query()->where('assessment_id', $homework->assessment_id)->update(['assignment_source' => AssessmentAssignmentSource::Direct->value]);
        } elseif ($failure === 'existing attempt without pair lock') {
            $recipient = AssessmentStudent::query()->where('assessment_id', $homework->assessment_id)->sole();
            AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id]);
        } elseif ($failure === 'other student history without pair lock') {
            $other = User::factory()->student($student->institution)->create(['must_change_password' => false]);
            AssessmentAttempt::factory()->create(['assessment_student_id' => $this->recipient($homework, $other)->id]);
        } else {
            $pair->update(['locked_at' => now()]);
        }
        $pairBefore = $pair->fresh()->getAttributes();
        $attemptsBefore = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $this->start($student, $homework)->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertSame($attemptsBefore, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function officialIntegrityFailures(): array
    {
        return array_combine($cases = ['missing cohort', 'non-group assessment', 'non-group recipient',
            'existing attempt without pair lock', 'other student history without pair lock', 'locked pair without history'],
            array_map(fn (string $case): array => [$case], $cases));
    }

    public function test_corrupt_other_student_history_cannot_serve_as_official_pair_activity_evidence(): void
    {
        [$student, $homework, $pair] = $this->officialHomework();
        $other = User::factory()->student($student->institution)->create(['must_change_password' => false]);
        $attempt = AssessmentAttempt::factory()->create([
            'assessment_student_id' => $this->recipient($homework, $other)->id,
            'status' => AssessmentAttemptStatus::TimedOutFinalized,
            'finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit,
        ]);
        $pair->update(['locked_at' => now()]);
        $pairBefore = $pair->fresh()->getAttributes();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $this->withoutExceptionHandling();
        try {
            $this->start($student, $homework);
            $this->fail('The entire official Assessment history must pass Homework invariants.');
        } catch (LogicException) {
            $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
            $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
            $this->assertDatabaseCount('assessment_attempts', 1);
            $this->assertDatabaseCount('idempotency_records', 0);
        }
    }

    public function test_real_attempt_insert_constraint_failure_rolls_back_the_preceding_pair_lock_and_idempotency_claim(): void
    {
        [$student, $homework, $pair] = $this->officialHomework();
        $pairBefore = $pair->fresh()->getAttributes();
        $pairLockObserved = false;
        $dispatcher = AssessmentAttempt::getEventDispatcher();
        AssessmentAttempt::setEventDispatcher(clone $dispatcher);
        AssessmentAttempt::creating(function (AssessmentAttempt $attempt) use ($pair, &$pairLockObserved): void {
            $pairLockObserved = $pair->fresh()->locked_at?->equalTo($attempt->started_at) === true;
            // Keep the database constraint active and make this actual Start insert fail it.
            $attempt->possible_points = '-1.000000';
        });
        try {
            app(StartStudentHomeworkAttempt::class)($student, $homework->assessment_id, (string) Str::uuid());
            $this->fail('The real Attempt insertion must fail the existing PostgreSQL points constraint.');
        } catch (QueryException $exception) {
            $this->assertSame('23514', $exception->errorInfo[0]);
        } finally {
            AssessmentAttempt::setEventDispatcher($dispatcher);
        }
        $this->assertTrue($pairLockObserved);
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    private function officialHomework(bool $withBlitz = false): array
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        $topic = Topic::factory()->active()->create(['institution_id' => $institution->id]);
        $assessment = Assessment::factory()->homework()->groupAssignment()->create([
            'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $topic->teacher_id,
            'total_possible_points' => '5.000000',
        ]);
        $homework = HomeworkAssignment::factory()->active()->create(['assessment_id' => $assessment->id]);
        $this->recipient($homework, $student);
        $factory = TopicResultPair::factory();
        if ($withBlitz) {
            $factory = $factory->withBlitz();
        }
        $pair = $factory->create([
            'homework_assessment_id' => $assessment->id, 'designated_by_user_id' => $topic->teacher_id,
            'designated_at' => now()->subMinutes(2), 'cohort_snapshotted_at' => now()->subMinute(),
            'created_at' => now()->subMinutes(2), 'updated_at' => now()->subMinute(),
        ]);

        return [$student, $homework, $pair];
    }

    private function recipient(HomeworkAssignment $homework, User $student): AssessmentStudent
    {
        return AssessmentStudent::factory()->create([
            'assessment_id' => $homework->assessment_id, 'student_id' => $student->id,
            'assigned_by_user_id' => $homework->assessment->teacher_id,
        ]);
    }

    private function start(User $student, HomeworkAssignment $homework): TestResponse
    {
        try {
            return $this->call('POST', '/api/v1/student/homework/'.$homework->assessment_id.'/attempts', [], [], [], [
                'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
                'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(),
                'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('homework-official-pair-test')->plainTextToken,
            ]);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }
}
