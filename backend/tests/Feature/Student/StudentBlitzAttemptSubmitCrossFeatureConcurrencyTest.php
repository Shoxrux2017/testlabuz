<?php

namespace Tests\Feature\Student;

use Illuminate\Support\Facades\Storage;
use Tests\Feature\Student\Concerns\RunsStudentBlitzSubmitConcurrency;
use Tests\TestCase;

class StudentBlitzAttemptSubmitCrossFeatureConcurrencyTest extends TestCase
{
    use RunsStudentBlitzSubmitConcurrency;

    public function test_answer_replacement_commits_first_and_submit_integrity_freezes_its_committed_text(): void
    {
        $race = $this->race('answer', 'submit');

        $this->assertSame(200, $race['first']['status'], json_encode($race['first']['body']));
        $this->assertSubmitSuccess($race['second']);
        $this->assertSubmitGate($race['second']);
        $this->assertSame('replacement', $race['second']['snapshot']['text']['text_value']);
        $this->assertSame('replacement', $this->answerInResponse($race['second'], $this->ids['text_question'])['text']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
    }

    public function test_submit_commits_first_and_waiting_answer_replacement_cannot_mutate_frozen_answers(): void
    {
        $race = $this->race('submit', 'answer');

        $this->assertSubmitSuccess($race['first']);
        $this->assertSubmitGate($race['first']);
        $this->assertSame(409, $race['second']['status']);
        $this->assertSame('attempt_not_editable', $race['second']['body']['code']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
        $this->assertSame('initial-first', $race['second']['snapshot']['text']['text_value']);
        $this->assertSame($race['held']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
    }

    public function test_file_replacement_commits_first_and_submit_freezes_the_new_stable_file_graph(): void
    {
        $race = $this->race('file', 'submit');

        $this->assertSame(200, $race['first']['status'], json_encode($race['first']['body']));
        $this->assertSubmitSuccess($race['second']);
        $this->assertSubmitGate($race['second']);
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
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
        $disk = Storage::disk('blitz_submit_concurrency');
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
        $this->assertFrozenAnswerGraph($race['held']['snapshot'], $race['second']['snapshot']);
        $this->assertSame($race['held']['snapshot']['attempt'], $race['second']['snapshot']['attempt']);
        $this->assertCount(1, $race['second']['stored']);
        $newKey = $race['second']['stored'][0]['key'];
        $this->assertSame([[
            'key' => $newKey, 'operation' => 'student_submission_compensation',
            'deleted' => true, 'transaction_level' => 0,
        ]], $race['second']['cleanups']);
        $disk = Storage::disk('blitz_submit_concurrency');
        $disk->assertMissing($newKey);
        $this->assertSame("%PDF-1.7\ninitial-first\n%%EOF\n", $disk->get($this->ids['first_key']));
        $this->assertCount(2, $disk->allFiles());
    }

    private function answerInResponse(array $result, string $questionId): array
    {
        $answers = array_column($result['body']['data']['answers'], null, 'question_id');
        $this->assertArrayHasKey($questionId, $answers);

        return $answers[$questionId]['answer'];
    }
}
