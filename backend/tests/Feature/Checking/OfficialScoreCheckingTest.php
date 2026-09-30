<?php

namespace Tests\Feature\Checking;

use App\Actions\Checking\CheckFrozenAttempt;
use App\Models\AssessmentAttempt;
use App\Models\HomeworkAssignment;
use App\Models\OfficialTaskScore;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

/**
 * S09-BE-004: every automatic checking run re-resolves the Student's official Homework score.
 */
class OfficialScoreCheckingTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext;
    use RefreshDatabase;

    private User $student;

    private HomeworkAssignment $homework;

    private AssessmentAttempt $first;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        [$this->student, $this->homework, $this->first] = $this->answerContext();
    }

    public function test_checking_an_official_homework_attempt_stores_its_official_score(): void
    {
        $this->designate();
        $this->answerTrueFalse($this->first, $this->question('true_false', 1));
        $this->freeze($this->first);

        $this->check($this->first);

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$this->first->id, '12.50000000', 'highest_valid_completed', $this->student->id],
            [$row->official_attempt_id, $row->normalized_score, $row->getRawOriginal('selection_policy_code'), $row->student_id]);
        $this->assertTrue($row->selected_at->equalTo(now()));
    }

    public function test_a_later_attempt_that_could_overtake_withdraws_the_score_while_it_waits_for_review(): void
    {
        $this->designate();
        $trueFalse = $this->question('true_false', 1);
        $written = $this->question('open_written', 2);
        $written->update(['points' => '5.000000']);
        $this->answerTrueFalse($this->first, $trueFalse);
        $this->freeze($this->first);
        $this->check($this->first);
        $this->assertDatabaseCount('official_task_scores', 1);
        $second = $this->nextAttempt();
        $this->answerRequest($this->student, $second, $written, $this->answerPayload($written))->assertOk();
        $this->freeze($second);

        $this->check($second);

        // Its bound (5 of 8 points = 62.5) could overtake the checked 12.5.
        $this->assertSame('waiting_for_teacher_review', $second->fresh()->getRawOriginal('status'));
        $this->assertDatabaseCount('official_task_scores', 0);
    }

    public function test_a_better_later_attempt_moves_the_official_score(): void
    {
        $this->designate();
        $trueFalse = $this->question('true_false', 1);
        $choice = $this->question('single_choice', 2);
        $this->answerTrueFalse($this->first, $trueFalse);
        $this->freeze($this->first);
        $this->check($this->first);
        $second = $this->nextAttempt();
        $this->answerTrueFalse($second, $trueFalse);
        $this->answerRequest($this->student, $second, $choice, ['type' => 'single_choice', 'selected_option_ids' => [
            QuestionChoiceOption::query()->where('question_id', $choice->id)->where('is_correct', true)->sole()->id,
        ]])->assertOk();
        $this->freeze($second);
        $this->travel(1)->hours();

        $this->check($second);

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$second->id, '25.00000000'], [$row->official_attempt_id, $row->normalized_score]);
        $this->assertTrue($row->selected_at->equalTo(now()));
    }

    public function test_checking_a_practice_homework_attempt_stores_no_official_score(): void
    {
        $this->answerTrueFalse($this->first, $this->question('true_false', 1));
        $this->freeze($this->first);

        $this->check($this->first);

        $this->assertSame('checked', $this->first->fresh()->getRawOriginal('status'));
        $this->assertDatabaseCount('official_task_scores', 0);
    }

    public function test_an_official_check_takes_the_official_row_lock_last(): void
    {
        $this->designate();
        $this->answerTrueFalse($this->first, $this->question('true_false', 1));
        $this->freeze($this->first);
        $locks = [];
        DB::listen(function ($query) use (&$locks): void {
            if (preg_match('/from "(\w+)".* for (share|update)$/s', $query->sql, $matches) === 1) {
                $locks[] = $matches[1].' '.$matches[2];
            }
        });

        $this->check($this->first);

        $this->assertSame([
            'topics share', 'assessments share', 'homework_assignments share', 'assessment_students update',
            'assessment_attempts update', 'attempt_answers update', 'official_task_scores update',
        ], $locks);
    }

    private function designate(): void
    {
        TopicResultPair::factory()->create(['homework_assessment_id' => $this->homework->assessment_id]);
    }

    private function question(string $type, int $position): Question
    {
        return $this->answerQuestion($this->homework, $type, $position);
    }

    private function answerTrueFalse(AssessmentAttempt $attempt, Question $question): void
    {
        $this->answerRequest($this->student, $attempt, $question, ['type' => 'true_false', 'value' => true])->assertOk();
    }

    private function nextAttempt(): AssessmentAttempt
    {
        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $this->first->assessment_student_id, 'attempt_number' => 2,
            'possible_points' => '8.000000', 'started_at' => now(),
        ])->fresh();
    }

    private function freeze(AssessmentAttempt $attempt): void
    {
        DB::table('assessment_attempts')->where('id', $attempt->id)->update([
            'status' => 'submitted', 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit',
        ]);
    }

    private function check(AssessmentAttempt $attempt): void
    {
        $this->assertTrue(app(CheckFrozenAttempt::class)($attempt->id));
    }
}
