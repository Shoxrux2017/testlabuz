<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\IdempotencyRecord;
use Illuminate\Support\Facades\Storage;
use Tests\Feature\Student\Concerns\RunsStudentHomeworkSubmitConcurrency;
use Tests\TestCase;

class StudentHomeworkAttemptSubmitCrossFeatureConcurrencyTest extends TestCase
{
    use RunsStudentHomeworkSubmitConcurrency;

    public function test_answer_replacement_commits_first_and_submit_integrity_freezes_its_committed_text(): void
    {
        $race = $this->race('answer', 'submit');

        $this->assertSame(200, $race['first']['status'], json_encode($race['first']['body']));
        $this->assertSubmitSuccess($race['second']);
        $this->assertSubmitGate($race['second']);
        $this->assertSame('replacement', $race['second']['snapshot']['text']['text_value']);
        $this->assertSame('replacement', $this->answerInResponse($race['second'], $this->ids['text_question'])['text']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot'], 'waiting_for_teacher_review');
    }

    public function test_submit_commits_first_and_waiting_answer_replacement_cannot_mutate_frozen_answers(): void
    {
        $race = $this->race('submit', 'answer');

        $this->assertSubmitSuccess($race['first']);
        $this->assertSubmitGate($race['first']);
        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('attempt_not_editable', $race['second']['body']['code']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot'], 'waiting_for_teacher_review');
        $this->assertSame('initial-first', $race['second']['snapshot']['text']['text_value']);
        $this->assertSame($this->frozenAttempt($race['held']['snapshot']['attempt']), $this->frozenAttempt($race['second']['snapshot']['attempt']));
        $this->assertAttemptStatus('first', 'waiting_for_teacher_review');
    }

    public function test_file_replacement_commits_first_and_submit_freezes_the_new_stable_file_graph(): void
    {
        $race = $this->race('file', 'submit');

        $this->assertSame(200, $race['first']['status'], json_encode($race['first']['body']));
        $this->assertSubmitSuccess($race['second']);
        $this->assertSubmitGate($race['second']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot'], 'waiting_for_teacher_review');
        $file = $race['second']['snapshot']['file'];
        $this->assertSame($this->ids['first_file'], $file['id']);
        $this->assertSame($this->ids['first_answer_file'], $race['second']['snapshot']['answer_file']['id']);
        $this->assertSame('replacement.pdf', $file['original_name']);
        $this->assertSame('replacement.pdf', $this->answerInResponse($race['second'], $this->ids['file_question'])['file']['original_name']);
        $this->assertSame($race['first']['stored'][0]['key'], $file['storage_key']);
        $this->assertSame([[
            'key' => $this->ids['first_key'], 'operation' => 'student_submission_replace_old_blob_cleanup',
            'deleted' => true, 'transaction_level' => 0,
        ]], $race['first']['cleanups']);
        $disk = Storage::disk('homework_submit_concurrency');
        $disk->assertMissing($this->ids['first_key']);
        $this->assertSame("%PDF-1.7\nreplacement\n%%EOF\n", $disk->get($file['storage_key']));
        $this->assertCount(2, $disk->allFiles());
    }

    public function test_submit_commits_first_and_waiting_file_replacement_compensates_its_new_private_blob(): void
    {
        $race = $this->race('submit', 'file');

        $this->assertSubmitSuccess($race['first']);
        $this->assertSubmitGate($race['first']);
        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('attempt_not_editable', $race['second']['body']['code']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot'], 'waiting_for_teacher_review');
        $this->assertSame($this->frozenAttempt($race['held']['snapshot']['attempt']), $this->frozenAttempt($race['second']['snapshot']['attempt']));
        $this->assertAttemptStatus('first', 'waiting_for_teacher_review');
        $this->assertCount(1, $race['second']['stored']);
        $newKey = $race['second']['stored'][0]['key'];
        $this->assertSame([[
            'key' => $newKey, 'operation' => 'student_submission_compensation',
            'deleted' => true, 'transaction_level' => 0,
        ]], $race['second']['cleanups']);
        $disk = Storage::disk('homework_submit_concurrency');
        $disk->assertMissing($newKey);
        $this->assertSame("%PDF-1.7\ninitial-first\n%%EOF\n", $disk->get($this->ids['first_key']));
        $this->assertCount(2, $disk->allFiles());
    }

    public function test_submit_wins_before_teacher_close_and_close_preserves_the_explicit_transition(): void
    {
        $race = $this->race('submit', 'close', waitTable: 'topics');

        $this->assertSubmitSuccess($race['first']);
        $this->assertSubmitGate($race['first']);
        $this->assertSame('closed', $race['second']['snapshot']['homework_status']);
        $this->assertSame($this->frozenAttempt($race['held']['snapshot']['attempt']), $this->frozenAttempt($race['second']['snapshot']['attempt']));
        $this->assertSame($race['held']['snapshot']['records'], $race['second']['snapshot']['records']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot'], 'waiting_for_teacher_review');
        $this->assertAttemptStatus('first', 'waiting_for_teacher_review');
    }

    public function test_teacher_close_wins_before_deadline_and_waiting_submit_leaves_no_claim(): void
    {
        $race = $this->race('close', 'submit', waitTable: 'topics');

        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('task_closed', $race['second']['body']['code']);
        $this->assertSame('closed', $race['second']['snapshot']['homework_status']);
        $attempt = $race['second']['snapshot']['attempt'];
        $this->assertSame('submitted', $attempt['status']);
        $this->assertSame('task_closed_auto_finalize', $attempt['finalization_reason']);
        $this->assertNull($attempt['submitted_at']);
        $this->assertSame('2026-09-09 09:30:00+00', $attempt['finalized_at']);
        $this->assertSame($attempt['finalized_at'], $attempt['locked_at']);
        $this->assertSame($race['first']['snapshot']['attempt'], $attempt);
        $this->assertSame([], $race['second']['snapshot']['records']);
        $this->assertSame([], $race['second']['gate_reads']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_pre_deadline_submit_wins_and_waiting_public_deadline_reconciliation_preserves_it(): void
    {
        $race = $this->race('submit', 'deadline', secondOverrides: [
            'observed_at' => '2026-09-09 10:00:00 UTC',
        ], waitTable: 'assessments');

        $this->assertSubmitSuccess($race['first']);
        $this->assertSubmitGate($race['first']);
        $this->assertSame($this->frozenAttempt($race['held']['snapshot']['attempt']), $this->frozenAttempt($race['second']['snapshot']['attempt']));
        $this->assertSame($race['held']['snapshot']['records'], $race['second']['snapshot']['records']);
        $this->assertSame(1, $race['second']['finalized_count']);
        $this->assertSame('homework_deadline_auto_submit', AssessmentAttempt::query()
            ->whereKey($this->ids['second_attempt'])->firstOrFail()->getRawOriginal('finalization_reason'));
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot'], 'waiting_for_teacher_review');
        // The reconciler runs without an HTTP request here, so only the Submit is checked.
        $this->assertAttemptStatus('first', 'waiting_for_teacher_review');
        $this->assertAttemptStatus('second', 'submitted');
    }

    public function test_deadline_wins_and_a_request_started_before_deadline_uses_time_after_its_lock_wait(): void
    {
        $race = $this->race('deadline', 'submit', [
            'observed_at' => '2026-09-09 10:00:00 UTC',
        ], [
            'observed_at' => '2026-09-09 09:59:59 UTC',
            'time_after_attempt_lock' => '2026-09-09 10:00:00 UTC',
        ], 'assessments');

        $this->assertSame(2, $race['first']['finalized_count']);
        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('deadline_passed', $race['second']['body']['code']);
        $this->assertDeadlineAttempt($race['second']['snapshot']['attempt']);
        $this->assertSame($race['first']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
        $this->assertSame([], $race['second']['snapshot']['records']);
        $this->assertSame([], $race['second']['gate_reads']);
        $this->assertSame([['transaction_level' => 1, 'preceding_commits' => [0]]], $race['second']['deadline_entries']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_late_submit_releases_its_own_transaction_before_public_all_attempt_reconciliation_waits(): void
    {
        $release = $this->signalPath();
        $blockerReady = $this->signalPath();
        $submitStarted = $this->signalPath();
        $deadlineEntry = $this->signalPath();
        $blocker = $this->startWorker('probe', $this->arguments('second') + ['ready' => $blockerReady, 'release' => $release]);
        $submit = null;
        $probe = null;

        try {
            $blockerState = $this->readSignal($blockerReady);
            $submit = $this->startWorker('submit', $this->arguments(overrides: [
                'observed_at' => '2026-09-09 10:00:00 UTC',
            ]) + ['started' => $submitStarted, 'deadline_entry' => $deadlineEntry]);
            $started = $this->readSignal($submitStarted);
            $entry = $this->readSignal($deadlineEntry, 'Late Submit must call the delivered public deadline reconciler.');
            $this->assertSame(['transaction_level' => 1, 'preceding_commits' => [0]], $entry);
            $this->waitForPostgresLock($started['pid'], $blockerState['pid'], 'assessment_attempts');

            // Public reconciliation is blocked on the earlier-sorting other Attempt; the route lock must already be free.
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
        $this->assertSame('deadline_passed', $submitResult['body']['code']);
        $this->assertSame(0, $submitResult['transaction_level']);
        $this->assertSame([], $submitResult['snapshot']['records']);
        $this->assertSame([], $submitResult['gate_reads']);
        $this->assertSame([['transaction_level' => 1, 'preceding_commits' => [0]]], $submitResult['deadline_entries']);
        $this->assertSame(0, IdempotencyRecord::query()->where('institution_id', $this->ids['institution'])->count());
        // The rejected Submit reconciles both deadlines and checks them when its request terminates.
        foreach (AssessmentAttempt::query()->where('assessment_id', $this->ids['assessment'])->get() as $attempt) {
            $this->assertDeadlineAttempt($attempt->getAttributes(), 'waiting_for_teacher_review');
        }
        $this->assertFrozenAnswerGraph($probeResult['snapshot'], $submitResult['snapshot'], 'waiting_for_teacher_review');
    }

    private function answerInResponse(array $result, string $questionId): array
    {
        $answers = array_column($result['body']['data']['answers'], null, 'question_id');
        $this->assertArrayHasKey($questionId, $answers);

        return $answers[$questionId]['answer'];
    }

    /**
     * Checking runs right after an HTTP freeze commits (S09-T1) and may interleave with the other
     * worker's snapshot, so the checking state is read once both workers have finished.
     */
    private function assertFrozenAnswerGraph(array $before, array $after, string $checkingStatus = 'pending'): void
    {
        foreach (['text', 'answer_file', 'file'] as $field) {
            $this->assertSame($before[$field], $after[$field], 'Submit must preserve '.$field);
        }
        $withoutStatus = fn (array $answers): array => array_map(fn (array $answer): array => array_diff_key($answer, ['checking_status' => true]), $answers);
        $this->assertSame($withoutStatus($before['answers']), $withoutStatus($after['answers']), 'Submit must preserve answers');
        $answers = AttemptAnswer::query()->where('attempt_id', $after['attempt']['id'])->orderBy('id')->get();
        $this->assertCount(count($after['answers']), $answers);
        // Both Questions are manual, so checking leaves every answer waiting without points.
        foreach ($answers as $answer) {
            $this->assertSame($checkingStatus, $answer->getRawOriginal('checking_status'));
            foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
                $this->assertNull($answer->getAttribute($field));
            }
        }
    }

    private function assertDeadlineAttempt(array $attempt, string $status = 'submitted'): void
    {
        $this->assertSame($status, $attempt['status']);
        $this->assertNull($attempt['submitted_at']);
        $this->assertSame('homework_deadline_auto_submit', $attempt['finalization_reason']);
        $this->assertSame('2026-09-09 10:00:00+00', $attempt['finalized_at']);
        $this->assertSame($attempt['finalized_at'], $attempt['locked_at']);
    }
}
