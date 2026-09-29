<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

/**
 * A Start whose in-progress Attempt is due finalizes it after its commit and then re-reads it.
 * Stage 9 may check the frozen Attempt in between (sweep or console reconcile).
 */
class StudentBlitzTimeoutRereadAfterCheckingTest extends TestCase
{
    use BuildsStudentBlitzContext, BuildsStudentHomeworkFileAnswerContext, RefreshDatabase;

    /** @return array<string, array{int}> */
    public static function completedReplays(): array
    {
        return ['start_normal replay' => [201], 'resume replay' => [200]];
    }

    #[DataProvider('completedReplays')]
    public function test_the_timeout_reread_returns_an_attempt_checked_after_the_freeze(int $originalStatus): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, 'individual');
        $textQuestion = $this->answerQuestion($assessment->blitzTask, 'short_written');
        $key = (string) Str::uuid();
        $started = $this->startStudentBlitz($student, $assessment, $key)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $textState = $this->answerRequest($student, $attempt, $textQuestion,
            ['type' => 'short_written', 'text' => 'Frozen text'])->assertOk()->json('data');
        $intent = $originalStatus === 200 ? 'resume' : 'start_normal';
        $target = $originalStatus === 200 ? $attempt->id : null;
        if ($originalStatus === 200) {
            $key = (string) Str::uuid();
            $this->startStudentBlitz($student, $assessment, $key, $intent, $target)->assertOk();
        }
        $this->checkEveryTimeoutFreezeImmediately();
        $this->travelTo($attempt->deadline_at->copy()->addMinutes(3));

        $this->startStudentBlitz($student, $assessment, $key, $intent, $target)
            ->assertStatus($originalStatus)
            ->assertJsonPath('data.id', $attempt->id)
            ->assertJsonPath('data.status', 'checked')
            ->assertJsonPath('data.finalization_reason', 'timeout_auto_submit')
            ->assertJsonPath('data.finalized_at', $started->json('data.deadline_at'))
            ->assertJsonPath('data.timing.remaining_seconds', 0)
            ->assertJsonPath('data.answers', [$textState]);
    }

    /**
     * Simulates a Stage 9 checking run that commits right after the timeout freeze: the
     * frozen Attempt and its answers are already checked when Start re-reads them.
     */
    private function checkEveryTimeoutFreezeImmediately(): void
    {
        DB::unprepared(<<<'SQL'
            create function s09_test_check_after_timeout() returns trigger language plpgsql as $$
            begin
                if old.status = 'in_progress' and new.status = 'timed_out_finalized' then
                    update attempt_answers set checking_status = 'auto_checked', awarded_points = 1,
                        checked_at = new.finalized_at where attempt_id = new.id;
                    new.status := 'checked';
                    new.earned_points := 1;
                    new.normalized_score := 100 * 1 / new.possible_points;
                    new.scoring_completed_at := new.finalized_at;
                end if;
                return new;
            end $$;
            create trigger s09_test_check_after_timeout before update on assessment_attempts
                for each row execute function s09_test_check_after_timeout();
            SQL);
    }
}
