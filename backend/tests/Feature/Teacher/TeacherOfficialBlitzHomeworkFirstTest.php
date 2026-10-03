<?php

namespace Tests\Feature\Teacher;

use App\Actions\Student\StartStudentBlitzAttempt;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzTimerStartMode;
use App\Enums\HomeworkStatus;
use App\Enums\TopicResultMissingComponent;
use App\Enums\TopicResultStatus;
use App\Enums\TopicStatus;
use App\Exceptions\HomeworkNotSubmittedException;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\InstitutionSetting;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Results\TopicResultReader;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\Feature\Teacher\Concerns\BuildsTeacherTopicResultPairContext;
use Tests\TestCase;

/** S10-BE-004 (S10-D8): the official Homework comes before the official Blitz (docs/09 §19.1). */
class TeacherOfficialBlitzHomeworkFirstTest extends TestCase
{
    use BuildsTeacherBlitzContext;
    use BuildsTeacherTopicResultPairContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-17 09:00:00 UTC'));
    }

    public function test_a_draft_official_homework_blocks_the_official_blitz_activation(): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz, $pair] = $this->officialContext();
        $this->eligibleStudent($institution, $admin, $group);
        $before = $this->state($homework, $blitz, $pair);

        $this->activateBlitz($teacher, $blitz)->assertConflict()->assertJsonPath('code', 'official_homework_not_activated');

        $this->assertSame($before, $this->state($homework, $blitz, $pair));
        $this->assertDatabaseCount('idempotency_records', 0);
        $this->assertDatabaseCount('assessment_students', 0);
    }

    public function test_the_timer_setting_check_comes_before_the_draft_homework_check(): void
    {
        [$institution, $teacher, , , , , $blitz] = $this->officialContext();
        InstitutionSetting::query()->where('institution_id', $institution->id)->update(['blitz_timer_start_mode' => null]);

        $this->activateBlitz($teacher, $blitz)->assertConflict()->assertJsonPath('code', 'institution_settings_incomplete');
    }

    public function test_activating_the_official_blitz_closes_the_active_official_homework(): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz] = $this->officialContext();
        $working = $this->eligibleStudent($institution, $admin, $group);
        $submitted = $this->eligibleStudent($institution, $admin, $group);
        $this->activateHomework($teacher, $homework)->assertOk();
        $this->travel(5)->minutes();
        $inProgress = $this->attemptFor($this->recipient($homework, $working));
        TopicResultPair::query()->update(['locked_at' => $inProgress->started_at]);
        $done = $this->attemptFor($this->recipient($homework, $submitted));
        $done->update(['status' => AssessmentAttemptStatus::Submitted, 'submitted_at' => now(), 'finalized_at' => now(),
            'locked_at' => now(), 'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit]);
        $doneBefore = collect($done->fresh()->getAttributes())->except(['status', 'earned_points', 'normalized_score', 'scoring_completed_at', 'updated_at'])->all();
        $this->travelTo(CarbonImmutable::parse('2026-09-17 09:30:00.400 UTC'));

        $this->activateBlitz($teacher, $blitz)->assertOk()->assertJsonPath('data.status', 'active');

        $assignment = HomeworkAssignment::query()->findOrFail($homework->id);
        $this->assertSame(HomeworkStatus::Closed, $assignment->status);
        // One activation instant: the Blitz timer truncates it to the second; the Homework close stores it like every model time.
        $instant = now()->startOfSecond();
        $this->assertTrue($instant->equalTo($assignment->closed_at));
        $this->assertTrue($instant->equalTo($assignment->updated_at));
        $this->assertTrue($instant->equalTo($homework->fresh()->updated_at));
        $this->assertTrue($instant->equalTo($blitz->blitzTask()->firstOrFail()->activated_at));
        $inProgress->refresh();
        $this->assertSame([AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize, null],
            [$inProgress->finalization_reason, $inProgress->submitted_at]);
        $this->assertTrue($instant->equalTo($inProgress->finalized_at));
        $this->assertTrue($instant->equalTo($inProgress->locked_at));
        // The freeze is checked right after the activation response, like every other freeze.
        $this->assertSame(AssessmentAttemptStatus::Checked, $inProgress->status);
        $this->assertSame($doneBefore, collect($done->fresh()->getAttributes())
            ->except(['status', 'earned_points', 'normalized_score', 'scoring_completed_at', 'updated_at'])->all());
        $this->assertSame(AssessmentAttemptFinalizationReason::StudentSubmit, $done->fresh()->finalization_reason);
    }

    public function test_a_passed_homework_deadline_is_reconciled_first(): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz] = $this->officialContext();
        $student = $this->eligibleStudent($institution, $admin, $group);
        $this->activateHomework($teacher, $homework)->assertOk();
        $deadline = now()->addMinutes(20);
        HomeworkAssignment::query()->whereKey($homework->id)->update(['deadline_at' => $deadline]);
        $attempt = $this->attemptFor($this->recipient($homework, $student));
        TopicResultPair::query()->update(['locked_at' => $attempt->started_at]);
        $this->travelTo(CarbonImmutable::parse('2026-09-17 09:30:00 UTC'));

        $this->activateBlitz($teacher, $blitz)->assertOk();

        $attempt->refresh();
        $this->assertSame(AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit, $attempt->finalization_reason);
        $this->assertTrue($deadline->equalTo($attempt->finalized_at));
        $this->assertSame(HomeworkStatus::Closed, HomeworkAssignment::query()->findOrFail($homework->id)->status);
    }

    /** @return array<string, array{list<string>}> */
    public static function finishedHomeworkLifecycles(): array
    {
        return ['closed' => [['close']], 'archived' => [['close', 'archive']]];
    }

    /** @param list<string> $transitions */
    #[DataProvider('finishedHomeworkLifecycles')]
    public function test_a_closed_or_archived_official_homework_and_a_practice_blitz_are_left_alone(array $transitions): void
    {
        [$institution, $teacher, $admin, $group, $topic, $homework, $blitz] = $this->officialContext();
        $this->eligibleStudent($institution, $admin, $group);
        $this->activateHomework($teacher, $homework)->assertOk();
        foreach ($transitions as $transition) {
            $this->homeworkRaw($teacher, 'POST', "/api/v1/teacher/homework/{$homework->id}/{$transition}", '')->assertOk();
        }
        $closed = HomeworkAssignment::query()->findOrFail($homework->id)->getAttributes();
        $this->travel(10)->minutes();

        $practice = $this->persistedBlitz($institution, $teacher, $topic);
        $this->persistedQuestion($practice);
        $this->activateBlitz($teacher, $practice)->assertOk();
        $this->activateBlitz($teacher, $blitz)->assertOk();

        $this->assertSame($closed, HomeworkAssignment::query()->findOrFail($homework->id)->getAttributes());
    }

    public function test_a_replay_and_the_already_active_no_op_close_nothing(): void
    {
        [$institution, $teacher, $admin, $group, , $homework, $blitz] = $this->officialContext();
        $this->eligibleStudent($institution, $admin, $group);
        $this->activateHomework($teacher, $homework)->assertOk();
        $this->activateBlitz($teacher, $blitz)->assertOk();
        // A Homework reopened after the activation (only possible by writing rows) stays open on a replay or a new key.
        HomeworkAssignment::query()->whereKey($homework->id)->update(['status' => 'active', 'closed_at' => null]);

        $this->activateBlitz($teacher, $blitz)->assertOk();
        $this->activateBlitz($teacher, $blitz, (string) Str::uuid())->assertOk();

        $this->assertSame(HomeworkStatus::Active, HomeworkAssignment::query()->findOrFail($homework->id)->status);
    }

    public function test_a_student_without_a_submitted_homework_is_barred_and_not_completed_once_the_activation_closed_it(): void
    {
        [$institution, $teacher, $admin, $group, $topic, $homework, $blitz] = $this->officialContext();
        $barred = $this->eligibleStudent($institution, $admin, $group);
        $this->activateHomework($teacher, $homework)->assertOk();
        $this->travel(10)->minutes();
        $this->activateBlitz($teacher, $blitz)->assertOk();

        $result = app(TopicResultReader::class)->forStudent($topic, $barred->id);
        $this->assertSame([TopicResultStatus::NotCompleted, TopicResultMissingComponent::Both], [$result->status, $result->missingComponent]);
        $this->expectException(HomeworkNotSubmittedException::class);
        app(StartStudentBlitzAttempt::class)($barred, $blitz->id, (string) Str::uuid(), 'start_normal', null);
    }

    /** @return array<int, mixed> */
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

    private function recipient(Assessment $assessment, User $student): AssessmentStudent
    {
        return AssessmentStudent::query()->where('assessment_id', $assessment->id)->where('student_id', $student->id)->sole();
    }

    /** @return list<mixed> */
    private function state(Assessment $homework, Assessment $blitz, TopicResultPair $pair): array
    {
        return [
            $homework->fresh()->getAttributes(), HomeworkAssignment::query()->findOrFail($homework->id)->getAttributes(),
            $blitz->fresh()->getAttributes(), $blitz->blitzTask()->firstOrFail()->getAttributes(), $pair->fresh()->getAttributes(),
        ];
    }

    private function activateHomework(User $teacher, Assessment $homework): TestResponse
    {
        return $this->homeworkRaw($teacher, 'POST', "/api/v1/teacher/homework/{$homework->id}/activate", '');
    }

    private function activateBlitz(User $teacher, Assessment $blitz, ?string $key = null): TestResponse
    {
        $response = $this->call('POST', "/api/v1/teacher/blitz/{$blitz->id}/activate", [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('official-blitz-homework-first-test')->plainTextToken,
            'HTTP_IDEMPOTENCY_KEY' => $key ?? $blitz->id,
        ], '{}');
        $this->app['auth']->forgetGuards();

        return $response;
    }
}
