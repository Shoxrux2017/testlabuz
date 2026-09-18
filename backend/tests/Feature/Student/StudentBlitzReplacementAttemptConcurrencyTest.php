<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use App\Models\BlitzAttemptException;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\Feature\Student\Concerns\RunsBlitzExceptionWorkers;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

class StudentBlitzReplacementAttemptConcurrencyTest extends TestCase
{
    use BuildsBlitzExceptionContext, RunsBlitzExceptionWorkers, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('startRaces')]
    public function test_replacement_start_has_one_linked_attempt_and_one_deadline(string $first, string $second, string $outcome, bool $sameKey): void
    {
        $context = $this->exceptionContext('synchronized');
        [$student, $assessment, $normal, $teacher] = $context;
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        $normalBefore = $normal->fresh()->getAttributes();
        $blitzBefore = $assessment->blitzTask->getAttributes();
        $firstInput = $this->workerInput($context, $first, ['now' => '2026-09-17 12:10:00.999999 UTC']);
        $secondInput = $this->workerInput($context, $second, ['now' => $second === 'timeout' ? '2026-09-17 12:20:00 UTC' : '2026-09-17 12:11:00 UTC']);
        if ($sameKey) {
            $secondInput['key'] = $firstInput['key'];
        }
        [$winner, $follower] = $this->exceptionRace($firstInput, $secondInput);
        $this->assertSame('ok', $winner['outcome']);
        $this->assertSame($outcome, $follower['outcome']);
        $replacement = AssessmentAttempt::query()->where('attempt_number', 2)->first();
        $this->assertSame($replacement?->id, BlitzAttemptException::query()->sole()->replacement_attempt_id);
        $this->assertDatabaseCount('assessment_attempts', $first === 'close' ? 1 : 2);
        $this->assertSame($normalBefore, $normal->fresh()->getAttributes());
        if ($replacement !== null) {
            $this->assertSame('2026-09-17 12:10:00', $replacement->started_at->format('Y-m-d H:i:s'));
            $this->assertSame('2026-09-17 12:20:00', $replacement->deadline_at->format('Y-m-d H:i:s'));
            $this->assertSame($blitzBefore['synchronized_ends_at'], $assessment->blitzTask->fresh()->getRawOriginal('synchronized_ends_at'));
            if ($second === 'start_replacement') {
                $this->assertSame($winner['id'], $follower['id']);
                $this->assertSame($sameKey ? 201 : 200, $follower['status']);
            } elseif ($second === 'timeout' || $second === 'close') {
                $this->assertSame($second === 'timeout' ? 'timeout_auto_submit' : 'task_closed_auto_finalize', $replacement->finalization_reason->value);
            }
        }
    }

    public static function startRaces(): array
    {
        return [['start_replacement', 'start_replacement', 'ok', false], ['start_replacement', 'start_replacement', 'ok', true],
            ['close', 'start_replacement', 'blitz_not_active', false], ['start_replacement', 'close', 'ok', false],
            ['start_replacement', 'timeout', 'ok', false]];
    }

    #[DataProvider('resumeRaces')]
    public function test_exact_replacement_resume_cannot_switch_after_terminalization(string $first, string $second, string $outcome): void
    {
        $context = $this->replacementContext();
        $attempt = $context[4];
        [$winner, $follower] = $this->exceptionRace(
            $this->workerInput($context, $first, ['attempt' => $attempt->id]),
            $this->workerInput($context, $second, ['attempt' => $attempt->id]),
        );
        $this->assertSame('ok', $winner['outcome']);
        $this->assertSame($outcome, $follower['outcome']);
        $this->assertDatabaseCount('assessment_attempts', 2);
        $this->assertSame('student_submit', $attempt->fresh()->finalization_reason->value);
        $this->assertSame($attempt->id, BlitzAttemptException::query()->sole()->replacement_attempt_id);
    }

    public static function resumeRaces(): array
    {
        return [['submit', 'resume', 'attempt_not_editable'], ['resume', 'submit', 'ok']];
    }
}
