<?php

namespace Tests\Feature\Teacher;

use App\Models\AssessmentAttempt;
use App\Models\BlitzAttemptException;
use App\Models\IdempotencyRecord;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\Feature\Student\Concerns\RunsBlitzExceptionWorkers;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

class TeacherBlitzAttemptExceptionConcurrencyTest extends TestCase
{
    use BuildsBlitzExceptionContext, RunsBlitzExceptionWorkers, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('grantRaces')]
    public function test_grant_serializes_with_execution_and_lifecycle(string $first, string $second, string $expected, bool $due, bool $sameKey): void
    {
        $context = $this->exceptionContext(terminal: ! $due);
        [$student, $assessment, $normal] = $context;
        if ($due) {
            $this->travelTo($normal->deadline_at);
        }
        $firstInput = $this->workerInput($context, $first);
        $secondInput = $this->workerInput($context, $second);
        if ($sameKey) {
            $secondInput['key'] = $firstInput['key'];
        }
        [$winner, $follower] = $this->exceptionRace($firstInput, $secondInput);
        $this->assertSame('ok', $winner['outcome']);
        $this->assertSame($expected, $follower['outcome']);
        $exceptions = BlitzAttemptException::query()->get();
        $this->assertCount($first === 'close' ? 0 : 1, $exceptions);
        $this->assertDatabaseCount('assessment_attempts', $second === 'start_replacement' ? 2 : 1);
        $this->assertSame($first === 'close', $normal->fresh()->official_score_eligible);
        $this->assertSame(0, IdempotencyRecord::query()->whereNull('completed_at')->count());
        if ($sameKey) {
            $this->assertSame(201, $winner['status']);
            $this->assertSame(201, $follower['status']);
            $this->assertSame($winner['id'], $follower['id']);
            $this->assertDatabaseCount('idempotency_records', 1);
        }
        if ($due && $first !== 'close') {
            $this->assertSame('timeout_auto_submit', $normal->fresh()->finalization_reason->value);
            $this->assertTrue($normal->deadline_at->equalTo($normal->fresh()->finalized_at));
        }
        if ($second === 'start_replacement') {
            $this->assertSame(AssessmentAttempt::query()->where('attempt_number', 2)->sole()->id, $exceptions->sole()->replacement_attempt_id);
        }
    }

    public static function grantRaces(): array
    {
        return [
            ['grant', 'grant', 'ok', false, true], ['grant', 'grant', 'already_granted', false, false],
            ['timeout', 'grant', 'ok', true, false], ['grant', 'timeout', 'ok', true, false],
            ['close', 'grant', 'not_allowed', false, false], ['grant', 'close', 'ok', false, false],
            ['grant', 'start_normal', 'attempts_exhausted', false, false],
            ['grant', 'resume', 'blitz_time_expired', true, false],
            ['grant', 'start_replacement', 'ok', false, false],
        ];
    }

    public function test_live_resume_wins_without_allowing_fake_early_timeout(): void
    {
        $context = $this->exceptionContext(terminal: false);
        $before = $context[2]->getAttributes();
        [, $grant] = $this->exceptionRace($this->workerInput($context, 'resume'), $this->workerInput($context, 'grant'));
        $this->assertSame('not_allowed', $grant['outcome']);
        $this->assertSame($before, $context[2]->fresh()->getAttributes());
        $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
    }
}
