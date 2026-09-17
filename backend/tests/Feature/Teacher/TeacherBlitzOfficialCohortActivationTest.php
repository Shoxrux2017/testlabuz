<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\BlitzTimerStartMode;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\GroupStudentMembership;
use App\Models\InstitutionSetting;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\Feature\Teacher\Concerns\BuildsTeacherTopicResultPairContext;
use Tests\TestCase;

class TeacherBlitzOfficialCohortActivationTest extends TestCase
{
    use BuildsTeacherBlitzContext;
    use BuildsTeacherTopicResultPairContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-17 09:00:00 UTC'));
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        parent::tearDown();
    }

    #[DataProvider('pairLockStates')]
    public function test_homework_first_cohort_is_copied_exactly_with_optional_real_homework_activity(bool $locked): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz, $pair] = $this->officialContext();
        $retained = $this->eligibleStudent($institution, $admin, $group);
        $former = $this->eligibleStudent($institution, $admin, $group);
        $identity = $this->pairIdentity($pair);

        $this->activateHomework($teacher, $homework)->assertOk()->assertJsonPath('data.status', 'active');
        $pair->refresh();
        $this->assertSame($identity, $this->pairIdentity($pair));
        $this->assertTrue($pair->cohort_snapshotted_at->equalTo($homework->homeworkAssignment()->firstOrFail()->activated_at));
        $this->assertSame([], $this->recipientIds($blitz));

        if ($locked) {
            $attempt = $this->attemptFor($homework->recipients()->where('student_id', $retained->id)->firstOrFail());
            $pair->forceFill(['locked_at' => $attempt->started_at])->save();
        }

        $pairState = $pair->fresh()->getAttributes();
        $homeworkRecipients = $this->recipientState($homework);
        GroupStudentMembership::query()->where('group_id', $group->id)->where('student_id', $former->id)
            ->update(['ended_at' => now()]);
        $former->forceFill(['is_active' => false])->save();
        $newStudent = $this->eligibleStudent($institution, $admin, $group);
        $this->travel(10)->minutes();

        $this->activateBlitz($teacher, $blitz)->assertOk()->assertJsonPath('data.status', 'active');

        $this->assertSame($this->recipientIds($homework), $this->recipientIds($blitz));
        $this->assertContains($former->id, $this->recipientIds($blitz));
        $this->assertNotContains($newStudent->id, $this->recipientIds($blitz));
        $this->assertSame($homeworkRecipients, $this->recipientState($homework));
        $this->assertSame($pairState, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', $locked ? 1 : 0);
    }

    #[DataProvider('pairLockStates')]
    public function test_blitz_first_cohort_drives_later_homework_activation_with_optional_real_blitz_activity(bool $locked): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz, $pair] = $this->officialContext();
        $retained = $this->eligibleStudent($institution, $admin, $group);
        $former = $this->eligibleStudent($institution, $admin, $group);
        $identity = $this->pairIdentity($pair);

        $this->activateBlitz($teacher, $blitz)->assertOk();

        $pair->refresh();
        $this->assertSame($identity, $this->pairIdentity($pair));
        $this->assertTrue($pair->cohort_snapshotted_at->equalTo($blitz->blitzTask()->firstOrFail()->activated_at));
        $this->assertSame([], $this->recipientIds($homework));
        $this->assertSame(HomeworkStatus::Draft, $homework->homeworkAssignment()->firstOrFail()->status);
        $this->assertDatabaseCount('assessment_attempts', 0);

        if ($locked) {
            $recipient = $blitz->recipients()->where('student_id', $retained->id)->firstOrFail();
            $attempt = AssessmentAttempt::factory()->create([
                'institution_id' => $institution->id,
                'assessment_id' => $blitz->id,
                'assessment_student_id' => $recipient->id,
                'student_id' => $retained->id,
                'deadline_at' => $blitz->blitzTask()->firstOrFail()->synchronized_ends_at,
                'possible_points' => $blitz->fresh()->total_possible_points,
            ]);
            $pair->forceFill(['locked_at' => $attempt->started_at])->save();
        }

        $pairState = $pair->fresh()->getAttributes();
        $blitzRecipients = $this->recipientState($blitz);
        GroupStudentMembership::query()->where('group_id', $group->id)->where('student_id', $former->id)
            ->update(['ended_at' => now()]);
        $former->forceFill(['is_active' => false])->save();
        $newStudent = $this->eligibleStudent($institution, $admin, $group);
        $this->travel(10)->minutes();

        $this->activateHomework($teacher, $homework)->assertOk()->assertJsonPath('data.status', 'active');

        $this->assertSame($this->recipientIds($blitz), $this->recipientIds($homework));
        $this->assertContains($former->id, $this->recipientIds($homework));
        $this->assertNotContains($newStudent->id, $this->recipientIds($homework));
        $this->assertSame($blitzRecipients, $this->recipientState($blitz));
        $this->assertSame($pairState, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', $locked ? 1 : 0);
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => $homework->id]);
    }

    public static function pairLockStates(): array
    {
        return ['unlocked' => [false], 'locked by real official activity' => [true]];
    }

    public function test_matching_preexisting_official_recipient_rows_are_preserved_exactly(): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz, $pair] = $this->officialContext();
        $student = $this->eligibleStudent($institution, $admin, $group);
        $this->activateHomework($teacher, $homework)->assertOk();
        $this->groupRecipient($institution, $teacher, $blitz, $student);
        $recipients = $this->recipientState($blitz);
        $pairState = $pair->fresh()->getAttributes();
        $this->travel(10)->minutes();

        $this->activateBlitz($teacher, $blitz)->assertOk();

        $this->assertSame($recipients, $this->recipientState($blitz));
        $this->assertSame($pairState, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_students', 2);
    }

    #[DataProvider('cohortMismatches')]
    public function test_established_cohort_mismatch_fails_without_repair(string $mismatch, string $target): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz, $pair] = $this->officialContext();
        $student = $this->eligibleStudent($institution, $admin, $group);
        $other = $this->eligibleStudent($institution, $admin, $group);
        $pair->forceFill(['cohort_snapshotted_at' => now()])->save();

        if ($mismatch !== 'empty') {
            $recipient = $this->groupRecipient($institution, $teacher, $homework, $student);

            if ($mismatch === 'different') {
                $this->groupRecipient($institution, $teacher, $blitz, $other);
            } else {
                $recipient->forceFill(['assignment_source' => AssessmentAssignmentSource::Direct])->save();
            }
        }

        $before = $this->cohortState($homework, $blitz, $pair);
        $response = $target === 'homework'
            ? $this->activateHomework($teacher, $homework)
            : $this->activateBlitz($teacher, $blitz);
        $response->assertConflict()->assertJsonPath('code', 'official_cohort_mismatch')
            ->assertJsonPath('message', 'The official assessment cohort does not match the established Topic cohort.');

        $this->assertSame($before, $this->cohortState($homework, $blitz, $pair));
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function cohortMismatches(): array
    {
        $cases = [];
        foreach (['homework', 'blitz'] as $target) {
            foreach (['empty', 'different', 'direct'] as $mismatch) {
                $cases[$target.' '.$mismatch] = [$mismatch, $target];
            }
        }

        return $cases;
    }

    #[DataProvider('lockActivityCorruption')]
    public function test_pair_lock_requires_real_activity_on_either_official_assessment_without_repair(string $activity, string $target): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz, $pair] = $this->officialContext();
        $student = $this->eligibleStudent($institution, $admin, $group);
        $homeworkRecipient = $this->groupRecipient($institution, $teacher, $homework, $student);
        $blitzRecipient = $this->groupRecipient($institution, $teacher, $blitz, $student);
        $pair->forceFill(['cohort_snapshotted_at' => now(), 'locked_at' => $activity === 'none' ? now() : null])->save();

        if ($activity !== 'none') {
            $this->attemptFor($activity === 'homework' ? $homeworkRecipient : $blitzRecipient);
        }

        $before = $this->cohortState($homework, $blitz, $pair);
        $response = $target === 'homework'
            ? $this->activateHomework($teacher, $homework)
            : $this->activateBlitz($teacher, $blitz);
        $response->assertConflict()->assertJsonPath('code', 'business_conflict');

        $this->assertSame($before, $this->cohortState($homework, $blitz, $pair));
        $this->assertDatabaseCount('assessment_attempts', $activity === 'none' ? 0 : 1);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function lockActivityCorruption(): array
    {
        $cases = [];
        foreach (['homework', 'blitz'] as $target) {
            foreach (['none', 'homework', 'blitz'] as $activity) {
                $cases[$target.' with '.$activity.' activity'] = [$activity, $target];
            }
        }

        return $cases;
    }

    public function test_official_blitz_rejects_selected_assignment_without_cohort_changes(): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz, $pair] = $this->officialContext();
        $student = $this->eligibleStudent($institution, $admin, $group);
        $blitz->forceFill(['assignment_mode' => AssessmentAssignmentMode::SelectedStudents])->save();
        $this->blitzRecipient($blitz, $student, $teacher);
        $before = $this->cohortState($homework, $blitz, $pair);

        $this->activateBlitz($teacher, $blitz)->assertConflict()->assertJsonPath('code', 'business_conflict');

        $this->assertSame($before, $this->cohortState($homework, $blitz, $pair));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    private function officialContext(): array
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext(TopicStatus::Active);
        InstitutionSetting::query()->where('institution_id', $institution->id)
            ->update(['blitz_timer_start_mode' => BlitzTimerStartMode::Synchronized->value]);
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $blitz = $this->persistedBlitz($institution, $teacher, $topic);
        $this->persistedQuestion($homework);
        $this->persistedQuestion($blitz);
        $pair = $this->resultPair($institution, $teacher, $topic, $homework, ['blitz_assessment_id' => $blitz->id]);

        return [$institution, $teacher, $admin, $group, $topic, $homework, $blitz, $pair];
    }

    private function activateHomework(User $teacher, Assessment $homework): TestResponse
    {
        return $this->homeworkRaw($teacher, 'POST', "/api/v1/teacher/homework/{$homework->id}/activate", '');
    }

    private function activateBlitz(User $teacher, Assessment $blitz): TestResponse
    {
        $response = $this->call('POST', "/api/v1/teacher/blitz/{$blitz->id}/activate", [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('official-cohort-test')->plainTextToken,
            'HTTP_IDEMPOTENCY_KEY' => $blitz->id,
        ], '{}');
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function recipientIds(Assessment $assessment): array
    {
        return AssessmentStudent::query()->where('assessment_id', $assessment->id)
            ->orderBy('student_id')->pluck('student_id')->all();
    }

    private function recipientState(Assessment $assessment): array
    {
        return AssessmentStudent::query()->where('assessment_id', $assessment->id)->orderBy('student_id')->get()
            ->map(fn (AssessmentStudent $recipient): array => $recipient->getAttributes())->all();
    }

    private function pairIdentity(TopicResultPair $pair): array
    {
        return collect($pair->fresh()->getAttributes())->only([
            'id', 'homework_assessment_id', 'blitz_assessment_id', 'designated_by_user_id', 'designated_at', 'locked_at', 'created_at',
        ])->all();
    }

    private function cohortState(Assessment $homework, Assessment $blitz, TopicResultPair $pair): array
    {
        return [
            $homework->fresh()->getAttributes(), $homework->homeworkAssignment()->firstOrFail()->getAttributes(),
            $blitz->fresh()->getAttributes(), $blitz->blitzTask()->firstOrFail()->getAttributes(),
            $pair->fresh()->getAttributes(), $this->recipientState($homework), $this->recipientState($blitz),
        ];
    }
}
