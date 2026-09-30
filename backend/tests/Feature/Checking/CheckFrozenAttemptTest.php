<?php

namespace Tests\Feature\Checking;

use App\Actions\Checking\CheckFrozenAttempt;
use App\Enums\QuestionType;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class CheckFrozenAttemptTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext;
    use RefreshDatabase;

    private const AUTOMATIC_TYPES = ['single_choice', 'multiple_choice', 'true_false', 'short_written', 'matching', 'ordering', 'fill_in_blank'];

    private User $student;

    private HomeworkAssignment $homework;

    private AssessmentAttempt $attempt;

    /** @var list<string> */
    private array $locks = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        [$this->student, $this->homework, $this->attempt] = $this->answerContext();
    }

    public function test_fully_correct_automatic_answers_check_the_attempt_with_full_points(): void
    {
        $questions = [];
        foreach (self::AUTOMATIC_TYPES as $index => $type) {
            $questions[$type] = $this->question($type, $index + 1, '2.000000');
            $this->answer($questions[$type], $this->correctPayload($questions[$type]));
        }
        $this->freeze('14.000000');
        $this->travel(5)->minutes();

        $this->assertTrue($this->check());

        $attempt = $this->attempt->fresh();
        $this->assertSame('checked', $attempt->getRawOriginal('status'));
        $this->assertSame('14.00000000', $attempt->earned_points);
        $this->assertSame('100.00000000', $attempt->normalized_score);
        $this->assertTrue($attempt->scoring_completed_at->equalTo(now()));
        foreach (AttemptAnswer::query()->get() as $answer) {
            $this->assertSame('auto_checked', $answer->getRawOriginal('checking_status'));
            $this->assertSame('2.00000000', $answer->awarded_points);
            $this->assertNull($answer->checked_by_user_id);
            $this->assertNull($answer->feedback);
            $this->assertTrue($answer->checked_at->equalTo(now()));
        }
    }

    public function test_partial_answers_earn_exact_shares_and_wrong_ones_earn_nothing(): void
    {
        $multiple = $this->question('multiple_choice', 1, '3.000000');
        $options = $this->optionIds($multiple);
        $this->answer($multiple, ['type' => 'multiple_choice', 'selected_option_ids' => [$options[0], $options[2]]]);
        $matching = $this->question('matching', 2, '3.000000');
        $pairs = $this->correctPayload($matching)['pairs'];
        $this->answer($matching, ['type' => 'matching', 'pairs' => [
            $pairs[0], ['left_item_id' => $pairs[1]['left_item_id'], 'right_item_id' => $pairs[2]['right_item_id']],
        ]]);
        $ordering = $this->question('ordering', 3, '5.000000');
        $items = $this->correctPayload($ordering)['items'];
        $this->answer($ordering, ['type' => 'ordering', 'items' => [$items[0], $items[1], ['item_id' => $items[2]['item_id'], 'position' => 4]]]);
        $fill = $this->question('fill_in_blank', 4, '3.000000');
        $values = $this->correctPayload($fill)['values'];
        $this->answer($fill, ['type' => 'fill_in_blank', 'values' => [$values[0], ['blank_id' => $values[1]['blank_id'], 'text' => 'wrong']]]);
        $single = $this->question('single_choice', 5, '1.000000');
        $this->answer($single, ['type' => 'single_choice', 'selected_option_ids' => [$this->optionIds($single)[3]]]);
        $this->freeze('15.000000');

        $this->check();

        $this->assertSame('1.50000000', $this->awarded($multiple));
        $this->assertSame('1.00000000', $this->awarded($matching));
        $this->assertSame('2.00000000', $this->awarded($ordering));
        $this->assertSame('1.00000000', $this->awarded($fill));
        $this->assertSame('0.00000000', $this->awarded($single));
        $attempt = $this->attempt->fresh();
        $this->assertSame('5.50000000', $attempt->earned_points);
        $this->assertSame('36.66666667', $attempt->normalized_score);
    }

    /** @return array<string, array{string}> */
    public static function automaticTypes(): array
    {
        return array_map(fn (string $type): array => [$type], array_combine(self::AUTOMATIC_TYPES, self::AUTOMATIC_TYPES));
    }

    #[DataProvider('automaticTypes')]
    public function test_a_wholly_wrong_automatic_answer_checks_at_zero(string $type): void
    {
        $question = $this->question($type, 1, '2.000000');
        $this->answer($question, $this->wrongPayload($question));
        $this->freeze('2.000000');

        $this->assertTrue($this->check());

        [$status, $awarded, $checkedAt] = $this->state($question);
        $this->assertSame(['auto_checked', '0.00000000'], [$status, $awarded]);
        $this->assertTrue($checkedAt->equalTo(now()));
        $attempt = $this->attempt->fresh();
        $this->assertSame(['checked', '0.00000000', '0.00000000'],
            [$attempt->getRawOriginal('status'), $attempt->earned_points, $attempt->normalized_score]);
    }

    public function test_a_false_true_false_key_awards_only_a_false_answer(): void
    {
        $answeredFalse = $this->question('true_false', 1, '2.000000');
        $answeredTrue = $this->question('true_false', 2, '2.000000');
        QuestionTrueFalseAnswer::query()->whereIn('question_id', [$answeredFalse->id, $answeredTrue->id])
            ->update(['correct_value' => false]);
        $this->answer($answeredFalse, ['type' => 'true_false', 'value' => false]);
        $this->answer($answeredTrue, ['type' => 'true_false', 'value' => true]);
        $this->freeze('4.000000');

        $this->check();

        $this->assertSame('2.00000000', $this->awarded($answeredFalse));
        $this->assertSame('0.00000000', $this->awarded($answeredTrue));
        $this->assertSame('50.00000000', $this->attempt->fresh()->normalized_score);
    }

    public function test_manual_answers_wait_for_review_and_zero_point_manual_answers_close_at_zero(): void
    {
        $open = $this->question('open_written', 1, '5.000000');
        $this->answer($open, $this->answerPayload($open));
        $manualShort = $this->question('short_written', 2, '2.000000', manual: true);
        $this->answer($manualShort, ['type' => 'short_written', 'text' => 'Anything']);
        $zeroOpen = $this->question('open_written', 3, '0.000000');
        $this->answer($zeroOpen, $this->answerPayload($zeroOpen));
        $single = $this->question('single_choice', 4, '1.000000');
        $this->answer($single, $this->correctPayload($single));
        $this->freeze('8.000000');

        $this->check();

        $this->assertSame(['waiting_for_teacher_review', null, null], $this->state($open));
        $this->assertSame(['waiting_for_teacher_review', null, null], $this->state($manualShort));
        $this->assertSame(['auto_checked', '0.00000000'], array_slice($this->state($zeroOpen), 0, 2));
        $this->assertTrue($this->state($zeroOpen)[2]->equalTo(now()));
        $this->assertSame(['auto_checked', '1.00000000'], array_slice($this->state($single), 0, 2));
        $attempt = $this->attempt->fresh();
        $this->assertSame('waiting_for_teacher_review', $attempt->getRawOriginal('status'));
        $this->assertNull($attempt->earned_points);
        $this->assertNull($attempt->normalized_score);
        $this->assertNull($attempt->scoring_completed_at);
    }

    public function test_unanswered_questions_add_nothing_and_get_no_row(): void
    {
        $answered = $this->question('true_false', 1, '2.000000');
        $this->question('open_written', 2, '5.000000');
        $this->question('single_choice', 3, '1.000000');
        $this->answer($answered, $this->correctPayload($answered));
        $this->freeze('8.000000');

        $this->check();

        $this->assertDatabaseCount('attempt_answers', 1);
        $attempt = $this->attempt->fresh();
        $this->assertSame('checked', $attempt->getRawOriginal('status'));
        $this->assertSame('2.00000000', $attempt->earned_points);
        $this->assertSame('25.00000000', $attempt->normalized_score);
    }

    public function test_checking_keeps_frozen_fields_and_the_answer_save_time(): void
    {
        $question = $this->question('true_false', 1, '2.000000');
        $this->answer($question, $this->correctPayload($question));
        $this->freeze('2.000000');
        $frozen = array_intersect_key($this->attempt->fresh()->getAttributes(), array_flip([
            'submitted_at', 'finalized_at', 'locked_at', 'finalization_reason', 'official_score_eligible',
            'possible_points', 'started_at', 'attempt_number',
        ]));
        $answerUpdatedAt = AttemptAnswer::query()->sole()->getRawOriginal('updated_at');
        $this->travel(2)->hours();

        $this->check();

        $this->assertSame($frozen, array_intersect_key($this->attempt->fresh()->getAttributes(), $frozen));
        $this->assertSame($answerUpdatedAt, AttemptAnswer::query()->sole()->getRawOriginal('updated_at'));
    }

    public function test_a_second_run_and_unfrozen_attempts_are_no_ops(): void
    {
        $question = $this->question('true_false', 1, '2.000000');
        $this->answer($question, $this->correctPayload($question));
        $this->freeze('2.000000');
        $this->check();
        $checked = [$this->attempt->fresh()->getAttributes(), AttemptAnswer::query()->sole()->getAttributes()];
        $this->travel(1)->hours();

        $this->assertFalse($this->check());
        $this->assertSame($checked, [$this->attempt->fresh()->getAttributes(), AttemptAnswer::query()->sole()->getAttributes()]);

        foreach (['in_progress', 'waiting_for_teacher_review'] as $status) {
            DB::table('assessment_attempts')->where('id', $this->attempt->id)->update(['status' => $status]);
            $this->assertFalse($this->check());
        }
        $this->assertFalse(app(CheckFrozenAttempt::class)('00000000-0000-4000-8000-000000000001'));
    }

    public function test_a_corrupt_answer_throws_and_changes_nothing(): void
    {
        $first = $this->question('true_false', 1, '2.000000');
        $second = $this->question('single_choice', 2, '1.000000');
        $this->answer($first, $this->correctPayload($first));
        $this->answer($second, $this->correctPayload($second));
        $this->freeze('3.000000');
        DB::table('attempt_answers')->where('question_id', $second->id)->update(['feedback' => 'corrupt']);
        $before = [$this->attempt->fresh()->getAttributes(), AttemptAnswer::query()->orderBy('id')->get()->map->getAttributes()->all()];

        try {
            $this->check();
            $this->fail('A corrupt frozen answer must not be checked.');
        } catch (LogicException) {
        }

        $this->assertSame($before, [$this->attempt->fresh()->getAttributes(), AttemptAnswer::query()->orderBy('id')->get()->map->getAttributes()->all()]);
    }

    public function test_an_ineligible_attempt_is_checked_and_stays_ineligible(): void
    {
        $question = $this->question('true_false', 1, '2.000000');
        $this->answer($question, $this->correctPayload($question));
        $this->freeze('2.000000');
        DB::table('assessment_attempts')->where('id', $this->attempt->id)->update(['official_score_eligible' => false]);

        $this->check();

        $attempt = $this->attempt->fresh();
        $this->assertSame('checked', $attempt->getRawOriginal('status'));
        $this->assertFalse($attempt->official_score_eligible);
    }

    public function test_locks_follow_the_stage_nine_order(): void
    {
        $question = $this->question('true_false', 1, '2.000000');
        $this->answer($question, $this->correctPayload($question));
        $this->freeze('2.000000');
        $this->recordLocks();

        $this->check();

        $this->assertSame([
            'topics share', 'assessments share', 'homework_assignments share',
            'assessment_students update', 'assessment_attempts update', 'attempt_answers update',
        ], $this->locks);
    }

    /** @return array<string, array{bool}> */
    public static function blitzEligibility(): array
    {
        return ['a timed-out Blitz Attempt' => [true], 'an invalidated Blitz #1' => [false]];
    }

    #[DataProvider('blitzEligibility')]
    public function test_a_timed_out_blitz_attempt_is_checked_under_its_blitz_lock(bool $eligible): void
    {
        $blitz = BlitzTask::factory()->activeIndividual()->create();
        $this->answerQuestion($blitz, 'true_false');
        $attempt = AssessmentAttempt::factory()->create([
            'assessment_student_id' => AssessmentStudent::factory()->create(['assessment_id' => $blitz->assessment_id]),
            'status' => 'timed_out_finalized', 'started_at' => now()->subMinutes(20),
            'deadline_at' => now()->subMinutes(10), 'finalized_at' => now()->subMinutes(10),
            'locked_at' => now()->subMinutes(10), 'finalization_reason' => 'timeout_auto_submit',
            'official_score_eligible' => $eligible, 'possible_points' => '2.000000',
        ]);
        $this->recordLocks();

        $this->assertTrue(app(CheckFrozenAttempt::class)($attempt->id));

        $fresh = $attempt->fresh();
        $this->assertSame('checked', $fresh->getRawOriginal('status'));
        $this->assertSame('timeout_auto_submit', $fresh->getRawOriginal('finalization_reason'));
        $this->assertSame('0.00000000', $fresh->earned_points);
        $this->assertSame('0.00000000', $fresh->normalized_score);
        $this->assertSame($eligible, $fresh->official_score_eligible);
        $this->assertSame([
            'topics share', 'assessments share', 'blitz_tasks share',
            'assessment_students update', 'assessment_attempts update', 'attempt_answers update',
        ], $this->locks);
    }

    /** @return array<string, array{string}> */
    public static function frozenStatuses(): array
    {
        return ['Homework submitted' => ['submitted'], 'timed out' => ['timed_out_finalized']];
    }

    #[DataProvider('frozenStatuses')]
    public function test_both_frozen_statuses_are_checked(string $status): void
    {
        $question = $this->question('true_false', 1, '2.000000');
        $this->answer($question, $this->correctPayload($question));
        $this->freeze('2.000000');
        DB::table('assessment_attempts')->where('id', $this->attempt->id)->update(['status' => $status]);

        $this->assertTrue($this->check());
        $this->assertSame('checked', $this->attempt->fresh()->getRawOriginal('status'));
    }

    private function recordLocks(): void
    {
        DB::listen(function ($query): void {
            if (preg_match('/from "(\w+)".* for (share|update)$/s', $query->sql, $matches) === 1) {
                $this->locks[] = $matches[1].' '.$matches[2];
            }
        });
    }

    private function check(): bool
    {
        return app(CheckFrozenAttempt::class)($this->attempt->id);
    }

    private function question(string $type, int $position, string $points, bool $manual = false): Question
    {
        $question = $this->answerQuestion($this->homework, $type, $position);
        $question->update(['points' => $points] + ($manual ? ['checking_mode' => 'manual'] : []));
        if ($manual) {
            DB::table('question_short_accepted_answers')->where('question_id', $question->id)->delete();
        }

        return $question->fresh();
    }

    /** @param array<string, mixed> $payload */
    private function answer(Question $question, array $payload): void
    {
        $this->answerRequest($this->student, $this->attempt, $question, $payload)->assertOk();
    }

    private function freeze(string $possiblePoints): void
    {
        DB::table('assessment_attempts')->where('id', $this->attempt->id)->update([
            'status' => 'submitted',
            'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit',
            'possible_points' => $possiblePoints,
        ]);
    }

    /** @return array<string, mixed> */
    private function correctPayload(Question $question): array
    {
        return ['type' => $question->type->value] + match ($question->type) {
            QuestionType::SingleChoice => ['selected_option_ids' => [$this->optionIds($question)[0]]],
            QuestionType::MultipleChoice => ['selected_option_ids' => array_slice($this->optionIds($question), 0, 2)],
            QuestionType::TrueFalse => ['value' => true],
            QuestionType::ShortWritten => ['text' => "  PRIVATE-SHORT-ANSWER-6187\u{00A0}"],
            QuestionType::Matching => ['pairs' => QuestionMatchingItem::query()->where('question_id', $question->id)
                ->where('side', 'left')->orderBy('position')->get()
                ->map(fn ($left): array => [
                    'left_item_id' => $left->id,
                    'right_item_id' => QuestionMatchingItem::query()->where('question_id', $question->id)
                        ->where('side', 'right')->where('match_key', $left->match_key)->sole()->id,
                ])->all()],
            QuestionType::Ordering => ['items' => QuestionOrderingItem::query()->where('question_id', $question->id)
                ->orderBy('correct_position')->get()
                ->map(fn ($item): array => ['item_id' => $item->id, 'position' => $item->correct_position])->all()],
            QuestionType::FillInBlank => ['values' => QuestionFillBlank::query()->where('question_id', $question->id)
                ->orderBy('position')->get()
                ->map(fn ($blank): array => ['blank_id' => $blank->id, 'text' => 'Private-Fill-Answer-8126'])->all()],
        };
    }

    /** @return array<string, mixed> An answer in which nothing matches the key */
    private function wrongPayload(Question $question): array
    {
        $correct = $this->correctPayload($question);

        return ['type' => $question->type->value] + match ($question->type) {
            QuestionType::SingleChoice => ['selected_option_ids' => [$this->optionIds($question)[1]]],
            QuestionType::MultipleChoice => ['selected_option_ids' => array_slice($this->optionIds($question), 2)],
            QuestionType::TrueFalse => ['value' => false],
            QuestionType::ShortWritten => ['text' => 'Not an accepted answer'],
            // Every left item is paired with the next item's counterpart.
            QuestionType::Matching => ['pairs' => array_map(fn (array $pair, int $index): array => [
                'left_item_id' => $pair['left_item_id'],
                'right_item_id' => $correct['pairs'][($index + 1) % count($correct['pairs'])]['right_item_id'],
            ], $correct['pairs'], array_keys($correct['pairs']))],
            // Every item moves one place, so none keeps its correct position.
            QuestionType::Ordering => ['items' => array_map(fn (array $item): array => [
                'item_id' => $item['item_id'], 'position' => $item['position'] % count($correct['items']) + 1,
            ], $correct['items'])],
            QuestionType::FillInBlank => ['values' => array_map(
                fn (array $value): array => ['blank_id' => $value['blank_id'], 'text' => 'wrong'], $correct['values'],
            )],
        };
    }

    /** @return list<string> */
    private function optionIds(Question $question): array
    {
        return QuestionChoiceOption::query()->where('question_id', $question->id)->orderBy('position')->pluck('id')->all();
    }

    private function awarded(Question $question): ?string
    {
        return AttemptAnswer::query()->where('question_id', $question->id)->sole()->awarded_points;
    }

    /** @return array{string, ?string, mixed} */
    private function state(Question $question): array
    {
        $answer = AttemptAnswer::query()->where('question_id', $question->id)->sole();

        return [$answer->getRawOriginal('checking_status'), $answer->awarded_points, $answer->checked_at];
    }
}
