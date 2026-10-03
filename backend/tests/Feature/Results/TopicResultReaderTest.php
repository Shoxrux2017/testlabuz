<?php

namespace Tests\Feature\Results;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\TopicResultCalculationMethod;
use App\Enums\TopicResultClosureReason;
use App\Enums\TopicResultConsistency;
use App\Enums\TopicResultMissingComponent;
use App\Enums\TopicResultOutcome;
use App\Enums\TopicResultSideState as State;
use App\Enums\TopicResultStatus;
use App\Enums\UnderstandingCategoryCode as Code;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\OfficialTaskScore;
use App\Models\Topic;
use App\Models\TopicResult;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Results\TopicResultReader;
use App\Support\Results\TopicResultView;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TopicResultReaderTest extends TestCase
{
    use RefreshDatabase;

    private Topic $topic;

    private Assessment $homework;

    private ?Assessment $blitz = null;

    private TopicResultPair $pair;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-05 10:00:00 UTC'));
    }

    public function test_homework_side_is_ready_with_a_confirmed_official_score(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $student = $this->student();
        $official = $this->attempt($this->homework, $student, 2, 'checked', '88.00000000');
        $this->attempt($this->homework, $student, 1, 'checked', '60.00000000');
        $this->official($official);

        $side = $this->read($student)->homework;

        $this->assertSame(State::Ready, $side->state);
        $this->assertSame([$this->homework->id, $official->id, 2, '88.00000000'], [$side->assessmentId, $side->attemptId, $side->attemptNumber, $side->score]);
    }

    public function test_homework_side_waits_for_teacher_review(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $student = $this->student();
        $this->attempt($this->homework, $student, 1, 'waiting_for_teacher_review');

        $this->assertSame(State::WaitingForTeacherReview, $this->read($student)->homework->state);
    }

    public function test_homework_side_is_checking_while_an_attempt_awaits_automatic_checking_or_the_row_is_stale(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        [$submitted, $stale] = [$this->student(), $this->student()];
        $this->attempt($this->homework, $submitted, 1, 'submitted');
        $this->attempt($this->homework, $stale, 1, 'checked', '70.00000000');

        $this->assertSame(State::Checking, $this->read($submitted)->homework->state);
        $this->assertSame(State::Checking, $this->read($stale)->homework->state);
    }

    public function test_homework_side_is_not_activated_while_the_homework_is_a_draft(): void
    {
        $this->topicWithPair('draft', 'activeIndividual');
        $student = $this->student(homework: false);

        $this->assertSame(State::NotActivated, $this->read($student)->homework->state);
    }

    public function test_homework_side_is_open_with_an_attempt_in_progress_even_after_the_deadline(): void
    {
        $this->topicWithPair('active', null, ['deadline_at' => now()->subMinute()]);
        $student = $this->student();
        $this->attempt($this->homework, $student, 1, 'in_progress');

        $this->assertSame(State::Open, $this->read($student)->homework->state);
    }

    public function test_homework_side_is_open_before_the_deadline_and_missing_after_it(): void
    {
        $this->topicWithPair('active', null, ['deadline_at' => now()->addHour()]);
        $student = $this->student();

        $this->assertSame(State::Open, $this->read($student)->homework->state);

        $this->travelTo(now()->addHour());

        $this->assertSame(State::Missing, $this->read($student)->homework->state);
    }

    public function test_homework_side_is_missing_once_the_homework_is_closed_without_attempts(): void
    {
        $this->topicWithPair('closed', null);
        $student = $this->student();

        $result = $this->read($student);

        $this->assertSame(State::Missing, $result->homework->state);
        $this->assertSame(TopicResultStatus::NotCompleted, $result->status);
        $this->assertSame(TopicResultMissingComponent::Homework, $result->missingComponent);
        $this->assertSame(Code::NotCompleted, $result->category);
    }

    public function test_blitz_side_is_not_designated_without_a_pair_blitz(): void
    {
        $this->topicWithPair('closed', null);
        $student = $this->student();
        $this->official($this->attempt($this->homework, $student, 1, 'checked', '80.00000000'));

        $result = $this->read($student);

        $this->assertSame([State::NotDesignated, null], [$result->blitz->state, $result->blitz->assessmentId]);
        $this->assertSame(TopicResultStatus::WaitingForBlitz, $result->status);
        $this->assertFalse($result->workFinished);
    }

    public function test_blitz_side_follows_the_official_blitz_status(): void
    {
        $this->topicWithPair('closed', 'activeIndividual');
        [$ready, $waiting, $checking] = [$this->student(), $this->student(), $this->student()];
        $this->official($this->attempt($this->blitz, $ready, 1, 'checked', '84.00000000'));
        $this->attempt($this->blitz, $waiting, 1, 'waiting_for_teacher_review');
        $this->attempt($this->blitz, $checking, 1, 'timed_out_finalized');

        $this->assertSame([State::Ready, '84.00000000'], [$this->read($ready)->blitz->state, $this->read($ready)->blitz->score]);
        $this->assertSame(State::WaitingForTeacherReview, $this->read($waiting)->blitz->state);
        $this->assertSame(State::Checking, $this->read($checking)->blitz->state);
    }

    public function test_blitz_side_is_open_while_an_approved_replacement_can_still_be_taken(): void
    {
        $this->topicWithPair('closed', 'activeIndividual');
        $student = $this->student();
        $this->exception($student, $this->attempt($this->blitz, $student, 1, 'checked', '90.00000000', eligible: false));

        $this->assertSame(State::Open, $this->read($student)->blitz->state);
    }

    public function test_blitz_side_is_ready_from_the_checked_replacement_after_an_exception(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $student = $this->readyStudent('80', '95');
        $replacement = $this->attempt($this->blitz, $student, 2, 'checked', '70.00000000');
        $this->exception($student, $replacement, fromFirst: true);

        $side = $this->read($student)->blitz;

        $this->assertSame([State::Ready, $replacement->id, 2, '70.00000000'], [$side->state, $side->attemptId, $side->attemptNumber, $side->score]);
    }

    public function test_a_blitz_attempt_keeps_the_blitz_open_even_without_a_submitted_homework(): void
    {
        // History from before S10-D8: the Student started the Blitz while the Homework was still open.
        $this->topicWithPair('closed', 'activeIndividual');
        $student = $this->student();
        $this->attempt($this->blitz, $student, 1, 'in_progress');

        $result = $this->read($student);

        $this->assertSame([State::Missing, State::Open], [$result->homework->state, $result->blitz->state]);
        $this->assertSame(TopicResultMissingComponent::Homework, $result->missingComponent);
    }

    public function test_blitz_side_is_not_activated_while_the_blitz_is_scheduled(): void
    {
        $this->topicWithPair('closed', 'scheduled');
        $student = $this->student(blitz: false);

        $this->assertSame(State::NotActivated, $this->read($student)->blitz->state);
    }

    public function test_a_student_without_a_submitted_homework_is_missing_both_sides_while_the_blitz_runs(): void
    {
        $this->topicWithPair('closed', 'activeIndividual');
        [$barred, $allowed] = [$this->student(), $this->student()];
        $this->official($this->attempt($this->homework, $allowed, 1, 'checked', '80.00000000'));

        $barredResult = $this->read($barred);

        $this->assertSame([State::Missing, State::Missing], [$barredResult->homework->state, $barredResult->blitz->state]);
        $this->assertSame(TopicResultMissingComponent::Both, $barredResult->missingComponent);
        $this->assertSame(State::Open, $this->read($allowed)->blitz->state);
    }

    public function test_blitz_side_is_missing_once_the_blitz_is_closed_without_a_counting_attempt(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        [$absent, $invalidated] = [$this->student(), $this->student()];
        $this->exception($invalidated, $this->attempt($this->blitz, $invalidated, 1, 'waiting_for_teacher_review', eligible: false));

        $this->assertSame(State::Missing, $this->read($absent)->blitz->state);
        $this->assertSame(State::Missing, $this->read($invalidated)->blitz->state);
    }

    public function test_a_calculated_result_with_finished_work_is_closable(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $student = $this->readyStudent('88.00000000', '84.00000000');

        $result = $this->read($student);

        $this->assertSame(TopicResultStatus::Calculated, $result->status);
        $this->assertSame(['4.00000000', '10.00000000', '86.00000000', 86], [$result->difference, $result->threshold, $result->finalScore, $result->categoryScore]);
        $this->assertSame([TopicResultCalculationMethod::Average, TopicResultConsistency::Consistent], [$result->method, $result->consistency]);
        $this->assertSame([Code::UnderstoodWell, 86, 100], [$result->category, $result->categoryMinScore, $result->categoryMaxScore]);
        $this->assertSame($student->full_name, $result->student->full_name);
        $this->assertTrue($result->terminal);
        $this->assertTrue($result->workFinished);
        $this->assertTrue($result->closable);
        $this->assertNull($result->row);
    }

    public function test_work_is_not_finished_while_the_blitz_runs_or_the_homework_can_still_be_submitted(): void
    {
        $this->topicWithPair('active', 'activeIndividual');
        $student = $this->readyStudent('88', '84');

        $result = $this->read($student);

        $this->assertSame(TopicResultStatus::Calculated, $result->status);
        $this->assertFalse($result->workFinished);
        $this->assertFalse($result->closable);

        BlitzTask::query()->whereKey($this->blitz->id)->update(['status' => 'closed', 'closed_at' => now()]);

        $this->assertFalse($this->read($student)->workFinished, 'the Homework is still active without a deadline');

        HomeworkAssignment::query()->whereKey($this->homework->id)->update(['deadline_at' => now()->subSecond()]);

        $this->assertTrue($this->read($student)->workFinished, 'the deadline has passed');
    }

    public function test_three_used_homework_attempts_finish_the_homework_but_an_attempt_in_progress_does_not(): void
    {
        $this->topicWithPair('active', 'closedIndividual');
        $student = $this->readyStudent('84', '84');
        $this->attempt($this->homework, $student, 2, 'checked', '50.00000000');
        $third = $this->attempt($this->homework, $student, 3, 'in_progress');

        $this->assertFalse($this->read($student)->workFinished);

        AssessmentAttempt::query()->whereKey($third->id)->update([
            'status' => 'checked', 'normalized_score' => '40.00000000', 'earned_points' => '0.00000000',
            'finalized_at' => now(), 'locked_at' => now(), 'finalization_reason' => 'student_submit', 'submitted_at' => now(),
            'scoring_completed_at' => now(),
        ]);

        $this->assertTrue($this->read($student)->workFinished);
    }

    public function test_ready_scores_wait_for_a_missing_or_invalid_category_set(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $student = $this->readyStudent('88', '84');
        InstitutionUnderstandingCategory::query()->where('code', Code::NeedsRevision->value)->update(['min_score' => 52]);

        $this->assertSame(TopicResultStatus::WaitingForSettings, $this->read($student)->status);

        InstitutionUnderstandingCategory::query()->delete();

        $this->assertSame(TopicResultStatus::WaitingForSettings, $this->read($student)->status);
        $this->assertFalse($this->read($student)->terminal);
    }

    public function test_an_open_result_uses_the_current_threshold_and_a_closed_one_keeps_its_snapshot(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        [$open, $closed] = [$this->readyStudent('92', '80'), $this->readyStudent('92', '80')];
        $this->closedRow($closed, ['score_difference' => '12.00000000', 'acceptable_difference_used' => '10.00000000',
            'calculation_method' => 'blitz', 'consistency' => 'inconsistent', 'final_score' => '80.00000000', 'category_score' => 80,
            'category_code' => 'partially_understood', 'category_min_score_used' => 71, 'category_max_score_used' => 85]);

        $this->assertSame(TopicResultCalculationMethod::Blitz, $this->read($open)->method);

        InstitutionSetting::query()->update(['acceptable_score_difference' => '15.00000000']);

        $this->assertSame([TopicResultCalculationMethod::Average, '86.00000000'], [$this->read($open)->method, $this->read($open)->finalScore]);
        $closedResult = $this->read($closed);
        $this->assertSame([TopicResultStatus::Closed, TopicResultOutcome::Calculated], [$closedResult->status, $closedResult->closedOutcome]);
        $this->assertSame([TopicResultCalculationMethod::Blitz, '80.00000000', '10.00000000'], [$closedResult->method, $closedResult->finalScore, $closedResult->threshold]);
        $this->assertSame([State::Ready, 1], [$closedResult->homework->state, $closedResult->homework->attemptNumber]);
        $this->assertTrue($closedResult->workFinished);
        $this->assertFalse($closedResult->closable);
        $this->assertFalse($closedResult->terminal);
    }

    public function test_a_result_the_teacher_closed_counts_as_finished_even_if_the_homework_reopened(): void
    {
        // History from before S10-D8: a Homework deadline moved later reopens the Homework window.
        $this->topicWithPair('active', 'closedIndividual');
        $student = $this->readyStudent('88', '84');
        $this->closedRow($student, ['score_difference' => '4.00000000', 'acceptable_difference_used' => '10.00000000',
            'calculation_method' => 'average', 'consistency' => 'consistent', 'final_score' => '86.00000000', 'category_score' => 86,
            'category_code' => 'understood_well', 'category_min_score_used' => 86, 'category_max_score_used' => 100]);

        $this->assertTrue($this->read($student)->workFinished);
    }

    public function test_a_result_closed_at_archive_follows_the_work_finished_rule(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $student = $this->readyStudent('88', '84');
        $this->closedRow($student, ['closure_reason' => TopicResultClosureReason::TopicArchived, 'score_difference' => '4.00000000',
            'acceptable_difference_used' => '10.00000000', 'calculation_method' => 'average', 'consistency' => 'consistent',
            'final_score' => '86.00000000', 'category_score' => 86, 'category_code' => 'understood_well',
            'category_min_score_used' => 86, 'category_max_score_used' => 100]);

        $this->assertTrue($this->read($student)->workFinished);
    }

    public function test_the_homework_deadline_finishes_the_homework_at_the_exact_instant(): void
    {
        $this->topicWithPair('active', 'closedIndividual', ['deadline_at' => now()->addMinute()]);
        [$ready, $absent] = [$this->readyStudent('88', '84'), $this->student()];

        $this->travelTo(now()->addMinute());

        $this->assertTrue($this->read($ready)->workFinished);
        $this->assertSame(State::Missing, $this->read($absent)->homework->state);
    }

    public function test_a_result_closed_at_archive_without_an_official_blitz_never_has_finished_work(): void
    {
        $this->topicWithPair('closed', null);
        $student = $this->student();
        TopicResult::factory()->create([
            'institution_id' => $this->topic->institution_id, 'topic_id' => $this->topic->id, 'student_id' => $student->id,
            'closed_at' => now(), 'closed_by_user_id' => $this->topic->teacher_id, 'closure_reason' => TopicResultClosureReason::TopicArchived,
            'closed_outcome' => TopicResultOutcome::NotCompleted, 'missing_component' => TopicResultMissingComponent::Homework,
            'homework_assessment_id' => $this->homework->id, 'homework_state' => State::Missing, 'blitz_state' => State::NotDesignated,
            'category_code' => Code::NotCompleted,
        ]);

        $result = $this->read($student);

        $this->assertSame([TopicResultStatus::Closed, TopicResultOutcome::NotCompleted], [$result->status, $result->closedOutcome]);
        $this->assertSame([State::Missing, State::NotDesignated], [$result->homework->state, $result->blitz->state]);
        $this->assertFalse($result->workFinished);
    }

    public function test_the_cohort_is_empty_before_the_snapshot_and_is_the_union_of_recipients_after_it(): void
    {
        $this->topicWithPair('draft', 'activeIndividual');
        $blitzOnly = $this->student(homework: false);
        $reader = app(TopicResultReader::class);
        $this->pair->update(['cohort_snapshotted_at' => null]);

        $this->assertSame([], $reader->forTopic($this->topic));

        $this->pair->update(['cohort_snapshotted_at' => now()->subHour()]);

        $this->assertSame([$blitzOnly->id], array_map(fn (TopicResultView $view): string => $view->student->id, $reader->forTopic($this->topic)));
    }

    public function test_students_and_stored_rows_outside_the_cohort_are_ignored(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $member = $this->student();
        $outsider = User::factory()->student()->create(['institution_id' => $this->topic->institution_id]);
        TopicResult::factory()->withComment()->create(['institution_id' => $this->topic->institution_id, 'topic_id' => $this->topic->id, 'student_id' => $outsider->id]);

        $this->assertNull(app(TopicResultReader::class)->forStudent($this->topic, $outsider->id));
        $this->assertSame([$member->id], array_map(fn (TopicResultView $view): string => $view->student->id, app(TopicResultReader::class)->forTopic($this->topic)));
    }

    public function test_a_topic_without_a_pair_has_no_results(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $this->pair->delete();

        $this->assertSame([], app(TopicResultReader::class)->forTopic($this->topic));
    }

    public function test_the_number_of_queries_does_not_grow_with_the_cohort(): void
    {
        $this->topicWithPair('closed', 'closedIndividual');
        $counts = [];

        foreach ([2, 6] as $size) {
            while (count(app(TopicResultReader::class)->forTopic($this->topic)) < $size) {
                $student = $this->readyStudent('88', '84');
                $this->exception($student, $this->attempt($this->blitz, $student, 2, 'checked', '70.00000000'), fromFirst: true);
                $this->attempt($this->homework, $student, 2, 'waiting_for_teacher_review');
            }

            DB::flushQueryLog();
            DB::enableQueryLog();
            app(TopicResultReader::class)->forTopic($this->topic);
            $counts[$size] = count(DB::getQueryLog());
            DB::disableQueryLog();
        }

        $this->assertSame($counts[2], $counts[6]);
    }

    /** @param array<string, mixed> $homeworkAttributes */
    private function topicWithPair(string $homeworkState, ?string $blitzState, array $homeworkAttributes = []): void
    {
        $this->topic = Topic::factory()->active()->create();
        $this->homework = $this->task('homework');
        HomeworkAssignment::factory()->{$homeworkState}()->create(['assessment_id' => $this->homework->id, ...$homeworkAttributes]);

        if ($blitzState !== null) {
            $this->blitz = $this->task('blitz');
            BlitzTask::factory()->{$blitzState}()->create(['assessment_id' => $this->blitz->id]);
        }

        $this->pair = TopicResultPair::factory()->create([
            'homework_assessment_id' => $this->homework->id, 'blitz_assessment_id' => $this->blitz?->id,
            'designated_by_user_id' => $this->topic->teacher_id, 'designated_at' => now()->subHours(2),
            'cohort_snapshotted_at' => now()->subHour(),
        ]);
        InstitutionSetting::factory()->configuredEducationalPolicy()->create(['institution_id' => $this->topic->institution_id]);
        $admin = User::factory()->institutionAdmin()->create(['institution_id' => $this->topic->institution_id]);

        foreach ([[Code::UnderstoodWell, 86, 100], [Code::PartiallyUnderstood, 71, 85], [Code::NeedsRevision, 51, 70],
            [Code::NeedsTeacherSupport, 0, 50], [Code::NotCompleted, null, null]] as [$code, $min, $max]) {
            InstitutionUnderstandingCategory::factory()->forInstitution($this->topic->institution, $admin)->forCode($code, $min, $max)->create();
        }
    }

    private function task(string $type): Assessment
    {
        return Assessment::factory()->{$type}()->groupAssignment()->create([
            'institution_id' => $this->topic->institution_id, 'teacher_id' => $this->topic->teacher_id, 'topic_id' => $this->topic->id,
        ]);
    }

    private function student(bool $homework = true, bool $blitz = true): User
    {
        $student = User::factory()->student()->create(['institution_id' => $this->topic->institution_id]);

        foreach ([$homework ? $this->homework : null, $blitz ? $this->blitz : null] as $task) {
            if ($task !== null) {
                AssessmentStudent::factory()->create([
                    'institution_id' => $task->institution_id, 'assessment_id' => $task->id, 'student_id' => $student->id,
                    'assigned_by_user_id' => $this->topic->teacher_id,
                ]);
            }
        }

        return $student;
    }

    private function readyStudent(string $homeworkScore, string $blitzScore): User
    {
        $student = $this->student();
        $this->official($this->attempt($this->homework, $student, 1, 'checked', $homeworkScore));
        $this->official($this->attempt($this->blitz, $student, 1, 'checked', $blitzScore));

        return $student;
    }

    private function attempt(Assessment $task, User $student, int $number, string $status, ?string $score = null, bool $eligible = true): AssessmentAttempt
    {
        $recipient = AssessmentStudent::query()->where('assessment_id', $task->id)->where('student_id', $student->id)->sole();
        $terminal = $status !== 'in_progress';

        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id, 'attempt_number' => $number, 'status' => $status,
            'started_at' => now()->subHour(), 'finalized_at' => $terminal ? now()->subMinutes(30) : null,
            'locked_at' => $terminal ? now()->subMinutes(30) : null,
            'finalization_reason' => $terminal ? AssessmentAttemptFinalizationReason::TimeoutAutoSubmit : null,
            'official_score_eligible' => $eligible, 'possible_points' => '4.000000', 'normalized_score' => $score,
            'earned_points' => $score === null ? null : '0.00000000',
            'scoring_completed_at' => $status === 'checked' ? now() : null,
        ])->fresh();
    }

    private function official(AssessmentAttempt $attempt): void
    {
        OfficialTaskScore::factory()->create(['official_attempt_id' => $attempt->id]);
    }

    /** An approved exception on #1; with fromFirst the given Attempt is replacement #2 and #1 is invalidated. */
    private function exception(User $student, AssessmentAttempt $attempt, bool $fromFirst = false): void
    {
        $recipient = AssessmentStudent::query()->where('assessment_id', $this->blitz->id)->where('student_id', $student->id)->sole();
        $normal = $fromFirst ? AssessmentAttempt::query()->where('assessment_student_id', $recipient->id)->where('attempt_number', 1)->sole() : $attempt;

        if ($fromFirst) {
            $normal->update(['official_score_eligible' => false]);
            OfficialTaskScore::query()->where('official_attempt_id', $normal->id)->delete();
            $this->official($attempt);
        }

        BlitzAttemptException::factory()->create([
            'assessment_id' => $this->blitz->id, 'assessment_student_id' => $recipient->id,
            'invalidated_attempt_id' => $normal->id, 'replacement_attempt_id' => $fromFirst ? $attempt->id : null,
        ]);
    }

    /** @param array<string, mixed> $values */
    private function closedRow(User $student, array $values): void
    {
        $attempts = AssessmentAttempt::query()->where('student_id', $student->id)->get()->keyBy('assessment_id');
        TopicResult::factory()->create([
            'institution_id' => $this->topic->institution_id, 'topic_id' => $this->topic->id, 'student_id' => $student->id,
            'closed_at' => now(), 'closed_by_user_id' => $this->topic->teacher_id, 'closure_reason' => TopicResultClosureReason::Teacher,
            'closed_outcome' => TopicResultOutcome::Calculated, 'homework_assessment_id' => $this->homework->id,
            'blitz_assessment_id' => $this->blitz->id, 'homework_state' => State::Ready, 'blitz_state' => State::Ready,
            'homework_attempt_id' => $attempts[$this->homework->id]->id, 'homework_score' => $attempts[$this->homework->id]->normalized_score,
            'blitz_attempt_id' => $attempts[$this->blitz->id]->id, 'blitz_score' => $attempts[$this->blitz->id]->normalized_score,
            ...$values,
        ]);
    }

    private function read(User $student): TopicResultView
    {
        $view = app(TopicResultReader::class)->forStudent($this->topic, $student->id);
        $this->assertNotNull($view);

        return $view;
    }
}
