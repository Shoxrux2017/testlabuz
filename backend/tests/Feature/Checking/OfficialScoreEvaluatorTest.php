<?php

namespace Tests\Feature\Checking;

use App\Enums\OfficialScoreSelectionPolicy;
use App\Enums\QuestionType;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\Question;
use App\Support\Checking\OfficialScoreEvaluation;
use App\Support\Checking\OfficialScoreEvaluator;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class OfficialScoreEvaluatorTest extends TestCase
{
    use RefreshDatabase;

    private AssessmentStudent $recipient;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
    }

    public function test_the_highest_checked_homework_attempt_is_official_with_ties_to_the_lowest_number(): void
    {
        $this->homework();
        $this->attempt(1, 'checked', '80.00000000');
        $second = $this->attempt(2, 'checked', '90.00000000');
        $this->attempt(3, 'checked', '90.00000000');

        $this->assertReady($this->evaluate(), $second, OfficialScoreSelectionPolicy::HighestValidCompleted);
    }

    public function test_without_a_checked_homework_attempt_every_terminal_attempt_blocks(): void
    {
        $this->homework();
        $submitted = $this->attempt(1, 'submitted');
        $waiting = $this->attempt(2, 'waiting_for_teacher_review');
        $this->attempt(3, 'in_progress');

        $this->assertNotReady($this->evaluate(), [$submitted, $waiting]);
    }

    public function test_a_homework_attempt_awaiting_automatic_checking_could_overtake_with_a_full_bound(): void
    {
        $this->homework();
        $this->attempt(1, 'checked', '99.99999999');
        $frozen = $this->attempt(2, 'submitted');

        $this->assertNotReady($this->evaluate(), [$frozen]);
    }

    /** @return array<string, array{string, int, bool}> */
    public static function waitingBounds(): array
    {
        // Best is 66.66666667 (2 of 3 points); the waiting Attempt earns 1 + 0.5 and may still get the
        // listed full waiting points, so its bound is (1.5 + waiting) × 100 / 3, rounded half-up.
        return [
            'bound above best' => ['1.000000', 2, false],
            'bound equal to best with a lower number' => ['0.500000', 1, false],
            'bound equal to best with a higher number' => ['0.500000', 2, true],
            'bound below best' => ['0.400000', 1, true],
        ];
    }

    #[DataProvider('waitingBounds')]
    public function test_a_waiting_homework_attempt_could_overtake_only_above_best_or_equal_with_a_lower_number(string $waitingPoints, int $waitingNumber, bool $ready): void
    {
        $this->homework();
        $best = $this->attempt(3 - $waitingNumber, 'checked', '66.66666667', possible: '3.000000');
        $waiting = $this->attempt($waitingNumber, 'waiting_for_teacher_review', possible: '3.000000');
        $this->answer($waiting, '1.000000', 'auto_checked', '1.00000000');
        $this->answer($waiting, '1.000000', 'teacher_checked', '0.50000000');
        $this->answer($waiting, $waitingPoints, 'waiting_for_teacher_review');

        $evaluation = $this->evaluate();

        $ready ? $this->assertReady($evaluation, $best, OfficialScoreSelectionPolicy::HighestValidCompleted)
            : $this->assertNotReady($evaluation, [$waiting]);
    }

    public function test_in_progress_homework_attempts_neither_count_nor_block(): void
    {
        $this->homework();
        $checked = $this->attempt(1, 'checked', '50.00000000');
        $this->attempt(2, 'in_progress');

        $this->assertReady($this->evaluate(), $checked, OfficialScoreSelectionPolicy::HighestValidCompleted);
    }

    /** @return array<string, array{string}> */
    public static function brokenHomework(): array
    {
        return ['checked without a score' => ['unscored'], 'ineligible Homework Attempt' => ['ineligible']];
    }

    #[DataProvider('brokenHomework')]
    public function test_a_broken_homework_history_fails(string $defect): void
    {
        $this->homework();
        $attempt = $this->attempt(1, 'checked', '50.00000000');
        DB::table('assessment_attempts')->where('id', $attempt->id)->update($defect === 'unscored'
            ? ['normalized_score' => null] : ['official_score_eligible' => false]);

        $this->expectException(LogicException::class);
        $this->evaluate();
    }

    /** @return array<string, array{string}> */
    public static function foreignFields(): array
    {
        return ['another Institution' => ['institution_id'], 'another task' => ['assessment_id'],
            'another recipient' => ['assessment_student_id'], 'another Student' => ['student_id']];
    }

    #[DataProvider('foreignFields')]
    public function test_an_attempt_that_is_not_the_recipients_own_fails(string $field): void
    {
        $this->homework();
        $this->attempt(1, 'checked', '50.00000000');
        $attempts = $this->attempts();
        $attempts->first()->setAttribute($field, (string) Str::uuid());

        $this->expectException(LogicException::class);
        app(OfficialScoreEvaluator::class)->evaluate($this->assessment(), $this->recipient, $attempts);
    }

    /** @return array<string, array{string, bool}> */
    public static function normalBlitzStates(): array
    {
        return [
            'checked' => ['checked', true],
            'waiting for review' => ['waiting_for_teacher_review', false],
            'awaiting automatic checking' => ['timed_out_finalized', false],
        ];
    }

    #[DataProvider('normalBlitzStates')]
    public function test_the_normal_blitz_attempt_is_official_once_checked(string $status, bool $ready): void
    {
        $this->blitz();
        $normal = $this->attempt(1, $status, $status === 'checked' ? '40.00000000' : null);

        $ready ? $this->assertReady($this->evaluate(), $normal, OfficialScoreSelectionPolicy::ValidNormalBlitz)
            : $this->assertNotReady($this->evaluate(), [$normal]);
    }

    public function test_a_normal_blitz_attempt_in_progress_neither_counts_nor_blocks(): void
    {
        $this->blitz();
        $this->attempt(1, 'in_progress');

        $this->assertNotReady($this->evaluate(), []);
    }

    /** @return array<string, array{?string, bool}> */
    public static function replacementStates(): array
    {
        return [
            'no replacement yet' => [null, false],
            'replacement in progress' => ['in_progress', false],
            'replacement waiting for review' => ['waiting_for_teacher_review', false],
            'replacement checked' => ['checked', true],
        ];
    }

    #[DataProvider('replacementStates')]
    public function test_after_an_exception_only_the_checked_replacement_is_official(?string $status, bool $ready): void
    {
        $this->blitz();
        // A checked normal Attempt is invalidated and never official or blocking.
        $normal = $this->attempt(1, 'checked', '100.00000000', eligible: false);
        $replacement = $status === null ? null
            : $this->attempt(2, $status, $status === 'checked' ? '25.00000000' : null);
        $this->exception($normal, $replacement);

        $evaluation = $this->evaluate();

        if ($ready) {
            $this->assertReady($evaluation, $replacement, OfficialScoreSelectionPolicy::ApprovedBlitzExceptionReplacement);
        } else {
            $this->assertNotReady($evaluation, $status === 'waiting_for_teacher_review' ? [$replacement] : []);
        }
    }

    /**
     * Normal #1 eligibility (null: no #1), eligibility of each later Attempt (#2, #3), the exception
     * (none, without a replacement, naming #2) and whether #2 is missing from the evaluated set.
     *
     * @return array<string, array{?bool, list<bool>, string, bool}>
     */
    public static function brokenBlitz(): array
    {
        return [
            'replacement without an exception' => [true, [true], 'none', false],
            'invalidated normal without an exception' => [false, [], 'none', false],
            'exception keeping the normal eligible' => [true, [], 'unlinked', false],
            'replacement the exception does not name' => [false, [true], 'unlinked', false],
            'exception naming a replacement that is not there' => [false, [true], 'linked', true],
            'ineligible replacement' => [false, [false], 'linked', false],
            'replacement without a normal Attempt' => [null, [true], 'none', false],
            'three Attempts' => [true, [true, true], 'none', false],
        ];
    }

    /** @param list<bool> $laterEligible */
    #[DataProvider('brokenBlitz')]
    public function test_a_broken_blitz_history_fails(?bool $normalEligible, array $laterEligible, string $exception, bool $omitReplacement): void
    {
        $this->blitz();
        $normal = $normalEligible === null ? null : $this->attempt(1, 'checked', '40.00000000', eligible: $normalEligible);
        $later = [];
        foreach ($laterEligible as $index => $eligible) {
            $later[] = $this->attempt($index + 2, 'checked', '50.00000000', eligible: $eligible);
        }
        if ($exception !== 'none') {
            $this->exception($normal, $exception === 'linked' ? $later[0] : null);
        }
        $attempts = $this->attempts();
        if ($omitReplacement) {
            $attempts = $attempts->reject(fn (AssessmentAttempt $attempt): bool => $attempt->id === $later[0]->id)->values();
        }

        $this->expectException(LogicException::class);
        app(OfficialScoreEvaluator::class)->evaluate($this->assessment(), $this->recipient, $attempts);
    }

    private function homework(): void
    {
        $homework = HomeworkAssignment::factory()->closed()->create();
        $this->recipient = AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);
    }

    private function blitz(): void
    {
        $blitz = BlitzTask::factory()->activeIndividual()->create();
        $this->recipient = AssessmentStudent::factory()->create(['assessment_id' => $blitz->assessment_id]);
    }

    private function attempt(int $number, string $status, ?string $normalized = null, bool $eligible = true, string $possible = '4.000000'): AssessmentAttempt
    {
        $terminal = $status !== 'in_progress';

        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $this->recipient->id, 'attempt_number' => $number, 'status' => $status,
            'started_at' => now()->subHour(), 'finalized_at' => $terminal ? now()->subMinutes(30) : null,
            'locked_at' => $terminal ? now()->subMinutes(30) : null,
            'finalization_reason' => $terminal ? 'timeout_auto_submit' : null,
            'official_score_eligible' => $eligible, 'possible_points' => $possible, 'normalized_score' => $normalized,
            'earned_points' => $normalized === null ? null : '0.00000000',
            'scoring_completed_at' => $normalized === null ? null : now(),
        ])->fresh();
    }

    private function answer(AssessmentAttempt $attempt, string $points, string $status, ?string $awarded = null): void
    {
        $answer = AttemptAnswer::factory()->forQuestionType(QuestionType::OpenWritten)->create(['attempt_id' => $attempt->id]);
        Question::query()->whereKey($answer->question_id)->update(['points' => $points]);
        DB::table('attempt_answers')->where('id', $answer->id)->update([
            'checking_status' => $status, 'awarded_points' => $awarded,
            'checked_at' => $status === 'waiting_for_teacher_review' ? null : now(),
        ]);
    }

    private function exception(AssessmentAttempt $normal, ?AssessmentAttempt $replacement): void
    {
        BlitzAttemptException::factory()->create([
            'assessment_id' => $this->recipient->assessment_id, 'assessment_student_id' => $this->recipient->id,
            'invalidated_attempt_id' => $normal->id, 'replacement_attempt_id' => $replacement?->id,
        ]);
    }

    private function evaluate(): OfficialScoreEvaluation
    {
        return app(OfficialScoreEvaluator::class)->evaluate($this->assessment(), $this->recipient, $this->attempts());
    }

    private function assessment(): Assessment
    {
        return Assessment::query()->findOrFail($this->recipient->assessment_id);
    }

    private function attempts(): Collection
    {
        return AssessmentAttempt::query()->where('assessment_student_id', $this->recipient->id)->orderBy('id')->get();
    }

    private function assertReady(OfficialScoreEvaluation $evaluation, AssessmentAttempt $official, OfficialScoreSelectionPolicy $policy): void
    {
        $this->assertSame($official->id, $evaluation->official?->id);
        $this->assertSame($policy, $evaluation->policy);
        $this->assertSame([], $evaluation->blocking);
    }

    /** @param list<AssessmentAttempt> $blocking */
    private function assertNotReady(OfficialScoreEvaluation $evaluation, array $blocking): void
    {
        $this->assertNull($evaluation->official);
        $this->assertNull($evaluation->policy);
        $this->assertSame(array_map(fn (AssessmentAttempt $attempt): string => $attempt->id, $blocking),
            array_map(fn (AssessmentAttempt $attempt): string => $attempt->id, $evaluation->blocking));
    }
}
