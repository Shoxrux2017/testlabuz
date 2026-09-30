<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

/**
 * Stage 9 checks frozen Homework Attempts. Student reads and Submit replays must read
 * the answers in any checking state and keep the Stage 7 response unchanged.
 */
class StudentHomeworkCheckedAttemptReadTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext;
    use RefreshDatabase;

    /** @return array<string, array{string}> */
    public static function checkedStatuses(): array
    {
        return [
            'waiting for Teacher review' => ['waiting_for_teacher_review'],
            'checked' => ['checked'],
        ];
    }

    #[DataProvider('checkedStatuses')]
    public function test_a_checked_attempt_reads_its_answers_like_before_checking(string $status): void
    {
        [$student, $attempt, $key] = $this->submittedAttempt();
        $before = $this->read($student, $attempt)->assertOk()->json('data');

        $this->check($attempt, $status);

        $after = $this->read($student, $attempt)->assertOk()->assertJsonPath('data.status', $status)->json('data');
        $this->assertSame($before['answers'], $after['answers']);
        $this->assertNoCheckingFields($after);
        $this->assertSame(
            array_diff_key($before, ['status' => true]),
            array_diff_key($after, ['status' => true]),
        );

        $this->submit($student, $attempt, $key)->assertOk()
            ->assertJsonPath('data.status', $status)
            ->assertJsonPath('data.finalization_reason', 'student_submit')
            ->assertJsonPath('data.submitted_at', $before['submitted_at'])
            ->assertJsonPath('data.finalized_at', $before['finalized_at'])
            ->assertJsonPath('data.answers', $before['answers']);
    }

    /** @return array<string, array{string, string}> */
    public static function pendingMetadata(): array
    {
        return [
            'awarded points on a submitted Attempt' => ['submitted', 'awarded_points'],
            'feedback on a submitted Attempt' => ['submitted', 'feedback'],
            'a reviewer on a checked Attempt' => ['checked', 'checked_by_user_id'],
            'a checking time on a checked Attempt' => ['checked', 'checked_at'],
        ];
    }

    #[DataProvider('pendingMetadata')]
    public function test_a_pending_answer_with_checking_metadata_fails_a_terminal_read(string $status, string $field): void
    {
        [$student, $attempt] = $this->submittedAttempt();
        $value = match ($field) {
            'awarded_points' => '1.00000000',
            'feedback' => 'Leaked feedback.',
            'checked_by_user_id' => $attempt->assessment->teacher_id,
            'checked_at' => now(),
        };
        DB::table('attempt_answers')->where('attempt_id', $attempt->id)->limit(1)
            ->update([$field => $value]);
        DB::table('assessment_attempts')->where('id', $attempt->id)->update(['status' => $status]);

        $this->read($student, $attempt)->assertStatus(500);
    }

    public function test_an_in_progress_attempt_with_a_checked_answer_still_fails_its_integrity(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $written = $this->answerQuestion($homework, 'open_written');
        $this->answerRequest($student, $attempt, $written, $this->answerPayload($written))->assertOk();
        DB::table('attempt_answers')->where('attempt_id', $attempt->id)->update([
            'checking_status' => 'auto_checked',
            'awarded_points' => '1.00000000',
            'checked_at' => now(),
        ]);

        $this->read($student, $attempt)->assertStatus(500);
    }

    /** @return array{User, AssessmentAttempt, string} */
    private function submittedAttempt(): array
    {
        [$student, $homework, $attempt] = $this->answerContext();
        foreach (['open_written' => 1, 'single_choice' => 2, 'matching' => 3] as $type => $position) {
            $question = $this->answerQuestion($homework, $type, $position);
            $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk();
        }
        $this->savedFileAnswer($attempt, $this->answerQuestion($homework, 'file_based', 4));
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk()->assertJsonPath('data.status', 'submitted');
        $this->uncheckFrozenAttempt($attempt);

        return [$student, $attempt->fresh(), $key];
    }

    /** Moves the frozen answers and the Attempt into Stage 9 checking states. */
    private function check(AssessmentAttempt $attempt, string $status): void
    {
        $reviewer = $attempt->assessment->teacher_id;
        $answers = AttemptAnswer::query()->where('attempt_id', $attempt->id)->orderBy('id')->get();
        $states = $status === 'checked'
            ? ['auto_checked', 'teacher_checked', 'auto_checked', 'teacher_checked']
            : ['auto_checked', 'waiting_for_teacher_review', 'auto_checked', 'teacher_checked'];

        foreach ($answers->values() as $index => $answer) {
            $state = $states[$index % count($states)];
            DB::table('attempt_answers')->where('id', $answer->id)->update([
                'checking_status' => $state,
                'awarded_points' => $state === 'waiting_for_teacher_review' ? null : '1.50000000',
                'feedback' => $state === 'teacher_checked' ? 'Clear reasoning.' : null,
                'checked_by_user_id' => $state === 'teacher_checked' ? $reviewer : null,
                'checked_at' => $state === 'waiting_for_teacher_review' ? null : now(),
            ]);
        }

        DB::table('assessment_attempts')->where('id', $attempt->id)->update($status === 'checked'
            ? ['status' => 'checked', 'earned_points' => '6.00000000', 'normalized_score' => '75.00000000', 'scoring_completed_at' => now()]
            : ['status' => 'waiting_for_teacher_review']);
    }

    /** @param array<string, mixed> $data */
    private function assertNoCheckingFields(array $data): void
    {
        // Stage 9: results are not released here, so the result is hidden and every feedback is null.
        $this->assertSame(['visible' => false, 'normalized_score' => null], $data['result']);
        $this->assertSame(array_fill(0, count($data['answers']), null), array_column($data['answers'], 'feedback'));
        unset($data['result']);
        $data['answers'] = array_map(fn (array $answer): array => array_diff_key($answer, ['feedback' => true]), $data['answers']);
        $json = json_encode($data, JSON_THROW_ON_ERROR);

        foreach (['checking_status', 'awarded_points', 'feedback', 'checked_by', 'checked_at', 'Clear reasoning.', 'earned_points', 'normalized_score'] as $secret) {
            $this->assertStringNotContainsString($secret, $json);
        }
    }

    private function read(User $student, AssessmentAttempt $attempt): TestResponse
    {
        return $this->answerHttp($student, 'GET', '/api/v1/student/attempts/'.$attempt->id);
    }

    private function submit(User $student, AssessmentAttempt $attempt, string $key): TestResponse
    {
        return $this->answerHttp($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', headers: [
            'HTTP_IDEMPOTENCY_KEY' => $key,
        ]);
    }
}
