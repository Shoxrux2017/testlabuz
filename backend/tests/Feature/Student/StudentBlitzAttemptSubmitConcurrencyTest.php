<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use App\Models\IdempotencyRecord;
use Illuminate\Support\Str;
use Tests\Feature\Student\Concerns\RunsStudentBlitzSubmitConcurrency;
use Tests\TestCase;

class StudentBlitzAttemptSubmitConcurrencyTest extends TestCase
{
    use RunsStudentBlitzSubmitConcurrency;

    public function test_same_key_waits_for_the_attempt_and_replays_one_completed_transition(): void
    {
        $key = (string) Str::uuid();
        $race = $this->race('submit', 'submit', ['key' => $key], ['key' => $key]);

        foreach (['first', 'second'] as $worker) {
            $this->assertSubmitSuccess($race[$worker]);
            $this->assertSame($race['held']['snapshot']['attempt'], $race[$worker]['snapshot']['attempt']);
            $this->assertSame($race['held']['snapshot']['records'], $race[$worker]['snapshot']['records']);
        }
        $this->assertSubmitGate($race['first']);
        $this->assertSame(1, $race['first']['attempt_writes'] + $race['second']['attempt_writes']);
        $this->assertCount(1, $race['second']['snapshot']['records']);
        $record = $race['second']['snapshot']['records'][0];
        $this->assertSame($key, $record['idempotency_key']);
        $this->assertSame('student.blitz.attempt.submit', $record['operation']);
        $this->assertSame(200, $record['response_status']);
        $this->assertSame('assessment_attempt', $record['result_resource_type']);
        $this->assertSame($this->ids['first_attempt'], $record['result_resource_id']);
        $this->assertSame('2026-09-17 09:01:00+00', $record['completed_at']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_different_keys_have_exactly_one_success_and_the_loser_leaves_no_claim(): void
    {
        $winner = (string) Str::uuid();
        $loser = (string) Str::uuid();
        $race = $this->race('submit', 'submit', ['key' => $winner], ['key' => $loser]);

        $this->assertSubmitSuccess($race['first']);
        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('attempt_not_editable', $race['second']['body']['code']);
        $this->assertSame(1, $race['first']['attempt_writes'] + $race['second']['attempt_writes']);
        $this->assertSame($race['held']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
        $this->assertSame($race['held']['snapshot']['records'], $race['second']['snapshot']['records']);
        $this->assertCount(1, $race['second']['snapshot']['records']);
        $this->assertSame($winner, $race['second']['snapshot']['records'][0]['idempotency_key']);
        $this->assertSame(0, IdempotencyRecord::query()->where('idempotency_key', $loser)->count());
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_pre_deadline_submit_wins_and_waiting_timeout_reconciliation_preserves_its_history(): void
    {
        $race = $this->race('submit', 'deadline', secondOverrides: [
            'observed_at' => '2026-09-17 09:10:00 UTC',
        ], waitTable: 'assessments');

        $this->assertSubmitSuccess($race['first']);
        $this->assertSame(1, $race['second']['finalized_count']);
        $this->assertSame(1, $race['first']['attempt_writes'] + $race['second']['attempt_writes']);
        $this->assertSame($race['held']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
        $this->assertSame($race['held']['snapshot']['records'], $race['second']['snapshot']['records']);
        $this->assertTimedOut(AssessmentAttempt::query()->findOrFail($this->ids['second_attempt'])->getAttributes());
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_timeout_wins_at_exact_deadline_and_waiting_submit_never_rewrites_it(): void
    {
        $race = $this->race('deadline', 'submit', [
            'observed_at' => '2026-09-17 09:10:00 UTC',
        ], [
            'observed_at' => '2026-09-17 09:09:59 UTC',
            'time_after_attempt_lock' => '2026-09-17 09:10:00 UTC',
        ], 'assessments');

        $this->assertSame(2, $race['first']['finalized_count']);
        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('blitz_time_expired', $race['second']['body']['code']);
        $this->assertTimedOut($race['second']['snapshot']['attempt']);
        $this->assertSame($race['first']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
        $this->assertSame([], $race['second']['snapshot']['records']);
        $this->assertSame(1, $race['first']['attempt_writes'] + $race['second']['attempt_writes']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_submit_commits_before_teacher_close_and_close_preserves_the_explicit_transition(): void
    {
        $race = $this->race('submit', 'close', waitTable: 'topics');

        $this->assertSubmitSuccess($race['first']);
        $this->assertSame('closed', $race['second']['snapshot']['blitz_status']);
        $this->assertSame($race['held']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
        $this->assertSame($race['held']['snapshot']['records'], $race['second']['snapshot']['records']);
        $this->assertSame($race['held']['snapshot']['recipients'], $race['second']['snapshot']['recipients']);
        $this->assertSame(1, $race['first']['attempt_writes'] + $race['second']['attempt_writes']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_teacher_close_wins_before_deadline_and_submit_preserves_close_lineage_without_claim(): void
    {
        $race = $this->race('close', 'submit', waitTable: 'topics');

        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('attempt_not_editable', $race['second']['body']['code']);
        $this->assertSame('closed', $race['second']['snapshot']['blitz_status']);
        $attempt = $race['second']['snapshot']['attempt'];
        $this->assertSame('submitted', $attempt['status']);
        $this->assertSame('task_closed_auto_finalize', $attempt['finalization_reason']);
        $this->assertNull($attempt['submitted_at']);
        $this->assertSame('2026-09-17 09:01:00+00', $attempt['finalized_at']);
        $this->assertSame($attempt['finalized_at'], $attempt['locked_at']);
        $this->assertSame($race['first']['snapshot']['attempt'], $attempt);
        $this->assertSame([], $race['second']['snapshot']['records']);
        $this->assertSame(1, $race['first']['attempt_writes'] + $race['second']['attempt_writes']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_teacher_close_wins_at_deadline_and_waiting_submit_keeps_timeout_precedence(): void
    {
        $race = $this->race('close', 'submit', [
            'observed_at' => '2026-09-17 09:10:00 UTC',
        ], ['observed_at' => '2026-09-17 09:11:00 UTC'], 'topics');

        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('blitz_time_expired', $race['second']['body']['code']);
        $this->assertSame('closed', $race['second']['snapshot']['blitz_status']);
        $this->assertTimedOut($race['second']['snapshot']['attempt']);
        $this->assertSame($race['first']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
        $this->assertSame([], $race['second']['snapshot']['records']);
        $this->assertSame(1, $race['first']['attempt_writes'] + $race['second']['attempt_writes']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_submit_observes_exact_deadline_only_after_its_attempt_lock_wait_and_abandons_the_claim(): void
    {
        $race = $this->race('probe', 'submit', secondOverrides: [
            'observed_at' => '2026-09-17 09:09:59 UTC',
            'time_after_attempt_lock' => '2026-09-17 09:10:00 UTC',
        ]);

        $this->assertSame('in_progress', $race['first']['probe']['status']);
        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('blitz_time_expired', $race['second']['body']['code']);
        $this->assertTimedOut($race['second']['snapshot']['attempt']);
        $this->assertSame([], $race['second']['snapshot']['records']);
        $this->assertSame(0, $race['second']['transaction_level']);
        $this->assertCount(1, $race['second']['deadline_entries']);
        $this->assertSame(0, $race['second']['deadline_entries'][0]['claims']);
        $this->assertSame([0], $race['second']['deadline_entries'][0]['preceding_transaction_ends']);
        $this->assertSame(1, $race['second']['attempt_writes']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_late_submit_releases_its_attempt_lock_and_claim_before_shared_timeout_reconciliation_waits(): void
    {
        $release = $this->signalPath();
        $blockerReady = $this->signalPath();
        $submitStarted = $this->signalPath();
        $timeoutEntry = $this->signalPath();
        $blocker = $this->startWorker('probe', $this->arguments('second') + ['ready' => $blockerReady, 'release' => $release]);
        $submit = null;
        $probe = null;

        try {
            $blockerState = $this->readSignal($blockerReady);
            $submit = $this->startWorker('submit', $this->arguments(overrides: [
                'observed_at' => '2026-09-17 09:10:00 UTC',
            ]) + ['started' => $submitStarted, 'deadline_entry' => $timeoutEntry]);
            $started = $this->readSignal($submitStarted);
            $entry = $this->readSignal($timeoutEntry, 'Late Submit must call the delivered public timeout reconciler.');
            $this->assertSame(1, $entry['transaction_level']);
            $this->assertSame([0], $entry['preceding_transaction_ends']);
            $this->assertSame(0, $entry['claims']);
            $this->waitForPostgresLock($started['pid'], $blockerState['pid'], 'assessment_attempts');

            // Reconciliation is blocked on the earlier-sorting other Attempt; the route lock must already be free.
            $probe = $this->startWorker('probe', $this->arguments());
            $runningProbe = $probe;
            $probe = null;
            $probeResult = $this->finishWorker($runningProbe);
            $this->assertSame('in_progress', $probeResult['probe']['status']);
            $this->assertNull($probeResult['probe']['submitted_at']);
            $this->assertNull($probeResult['probe']['finalized_at']);
            $this->assertSame([], $probeResult['snapshot']['records']);
            $this->assertFileDoesNotExist($release);
        } finally {
            file_put_contents($release, 'release');
            try {
                $this->finishWorker($blocker);
            } finally {
                if ($probe !== null) {
                    $this->finishWorker($probe);
                }
                $submitResult = $submit === null ? null : $this->finishWorker($submit);
            }
        }

        $this->assertSame(409, $submitResult['status']);
        $this->assertSame('blitz_time_expired', $submitResult['body']['code']);
        $this->assertSame(0, $submitResult['transaction_level']);
        $this->assertSame([], $submitResult['snapshot']['records']);
        $this->assertSame(1, $submitResult['attempt_writes']);
        $this->assertSame(0, IdempotencyRecord::query()->where('institution_id', $this->ids['institution'])->count());
        foreach (AssessmentAttempt::query()->where('assessment_id', $this->ids['assessment'])->get() as $attempt) {
            $this->assertTimedOut($attempt->getAttributes());
        }
        $this->assertFrozenAnswerGraph($probeResult['snapshot'], $submitResult['snapshot']);
    }

    private function assertTimedOut(array $attempt): void
    {
        $this->assertSame('timed_out_finalized', $attempt['status']);
        $this->assertNull($attempt['submitted_at']);
        $this->assertSame('timeout_auto_submit', $attempt['finalization_reason']);
        $this->assertSame('2026-09-17 09:10:00+00', $attempt['finalized_at']);
        $this->assertSame($attempt['deadline_at'], $attempt['finalized_at']);
        $this->assertSame($attempt['finalized_at'], $attempt['locked_at']);
    }
}
