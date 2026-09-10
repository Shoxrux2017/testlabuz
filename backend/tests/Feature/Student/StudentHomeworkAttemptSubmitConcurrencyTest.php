<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use App\Models\IdempotencyRecord;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Feature\Student\Concerns\RunsStudentHomeworkSubmitConcurrency;
use Tests\TestCase;

class StudentHomeworkAttemptSubmitConcurrencyTest extends TestCase
{
    use RunsStudentHomeworkSubmitConcurrency;

    public function test_same_key_waits_for_the_own_attempt_and_replays_one_completed_transition(): void
    {
        $key = (string) Str::uuid();
        $race = $this->race('submit', 'submit', ['key' => $key], ['key' => $key]);

        foreach (['first', 'second'] as $worker) {
            $this->assertSubmitSuccess($race[$worker]);
            $this->assertSame($race['held']['snapshot']['attempt'], $race[$worker]['snapshot']['attempt']);
            $this->assertSame($race['held']['snapshot']['records'], $race[$worker]['snapshot']['records']);
        }
        $this->assertSubmitGate($race['first']);
        $this->assertSame([], $race['second']['gate_reads']);
        $this->assertCount(1, $race['second']['snapshot']['records']);
        $record = $race['second']['snapshot']['records'][0];
        $this->assertSame($key, $record['idempotency_key']);
        $this->assertSame('student.homework.attempt.submit', $record['operation']);
        $this->assertSame(200, $record['response_status']);
        $this->assertSame('assessment_attempt', $record['result_resource_type']);
        $this->assertSame($this->ids['first_attempt'], $record['result_resource_id']);
        $this->assertNotNull($record['completed_at']);
        $this->assertSame('2026-09-09 09:30:00+00', $record['completed_at']);
    }

    public function test_different_key_waits_and_leaves_no_claim_after_losing_the_finalization(): void
    {
        $winningKey = (string) Str::uuid();
        $losingKey = (string) Str::uuid();
        $race = $this->race('submit', 'submit', ['key' => $winningKey], ['key' => $losingKey]);

        $this->assertSubmitSuccess($race['first']);
        $this->assertSubmitGate($race['first']);
        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('attempt_not_editable', $race['second']['body']['code']);
        $this->assertSame([], $race['second']['gate_reads']);
        $this->assertSame($race['held']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
        $this->assertSame($race['held']['snapshot']['records'], $race['second']['snapshot']['records']);
        $this->assertCount(1, $race['second']['snapshot']['records']);
        $this->assertSame($winningKey, $race['second']['snapshot']['records'][0]['idempotency_key']);
        $this->assertSame(0, IdempotencyRecord::query()->where('idempotency_key', $losingKey)->count());
    }

    public function test_different_students_submit_independently_with_shared_parents_and_only_their_own_attempt_locks(): void
    {
        $release = $this->signalPath();
        $firstReady = $this->signalPath();
        $secondReady = $this->signalPath();
        $first = $this->startWorker('submit', $this->arguments() + ['ready' => $firstReady, 'release' => $release]);
        $second = null;

        try {
            $firstHeld = $this->readSignal($firstReady);
            $second = $this->startWorker('submit', $this->arguments('second') + ['ready' => $secondReady, 'release' => $release]);
            $secondHeld = $this->readSignal($secondReady, 'Different Students must reach independent Submit writes before either transaction commits.');
            $this->assertSame($this->submitLocks(), $firstHeld['locks']);
            $this->assertSame($this->submitLocks(), $secondHeld['locks']);
            $this->assertNotSame($firstHeld['pid'], $secondHeld['pid']);
            foreach ([$firstHeld['pid'], $secondHeld['pid']] as $pid) {
                DB::select('select pg_stat_clear_snapshot()');
                $activity = DB::selectOne('select state, cardinality(pg_blocking_pids(pid)) as blockers from pg_stat_activity where pid = ?', [$pid]);
                $this->assertSame('idle in transaction', $activity->state);
                $this->assertSame(0, $activity->blockers);
            }
            $this->assertFileDoesNotExist($release);
        } finally {
            file_put_contents($release, 'release');
            try {
                $firstResult = $this->finishWorker($first);
            } finally {
                $secondResult = $second === null ? null : $this->finishWorker($second);
            }
        }

        $this->assertSubmitSuccess($firstResult);
        $this->assertSubmitSuccess($secondResult, 'second');
        $this->assertSubmitGate($firstResult);
        $this->assertSubmitGate($secondResult);
        $this->assertSame(2, IdempotencyRecord::query()->where('institution_id', $this->ids['institution'])->count());
        $this->assertSame(2, AssessmentAttempt::query()->where('assessment_id', $this->ids['assessment'])
            ->where('finalization_reason', 'student_submit')->count());
    }
}
