<?php

namespace Tests\Feature\Student;

use App\Models\AnswerTextValue;
use App\Models\Question;
use App\Support\Student\StudentHomeworkAnswerIntegrity;
use App\Support\Student\StudentHomeworkAttemptAnswerStates;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzHistoricalReplayContext;
use Tests\TestCase;

class StudentBlitzAttemptSubmitHistoricalReplayTest extends TestCase
{
    use BuildsStudentBlitzHistoricalReplayContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        Storage::fake('local');
        config(['filesystems.private_files_disk' => 'local']);
    }

    #[DataProvider('laterStatuses')]
    public function test_completed_submit_replays_checked_typed_and_file_values_without_exposing_metadata_or_changing_any_persistence(string $status): void
    {
        [$student, $assessment, $attempt, , $typed, $fileAnswer, $file] = $this->historicalReplayContext();
        $key = (string) Str::uuid();
        $original = $this->submitHistoricalReplay($student, $attempt, $key)->assertOk();
        $execution = $attempt->fresh()->only(['submitted_at', 'finalized_at', 'locked_at', 'finalization_reason']);
        $attempt->update(['status' => $status, 'earned_points' => '2.00000000', 'normalized_score' => '40.00000000', 'scoring_completed_at' => now()]);
        $this->addHistoricalCheckingMetadata($attempt, $status, $typed, $fileAnswer);
        $before = $this->historicalReplaySnapshot();
        $this->travel(1)->hours();
        $response = $this->submitHistoricalReplay($student, $attempt, $key)->assertOk()
            ->assertJsonPath('message', 'Blitz attempt submitted successfully.')
            ->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.status', $status)
            ->assertJsonPath('data.answers', $original->json('data.answers'))
            ->assertJsonPath('data.answers.1.answer.file.id', $file->id);
        $this->assertEquals($execution, $attempt->fresh()->only(array_keys($execution)));
        $this->assertSame($before, $this->historicalReplaySnapshot());
        $this->assertHistoricalReplayPrivacy($response->json());
        $this->submitHistoricalReplay($student, $attempt, (string) Str::uuid())->assertConflict()->assertJsonPath('code', 'attempt_not_editable');
        $this->assertSame($before, $this->historicalReplaySnapshot());
    }

    public static function laterStatuses(): array
    {
        return [['waiting_for_teacher_review'], ['checked']];
    }

    public function test_submitted_replay_and_new_submit_still_reject_non_pending_checking_metadata(): void
    {
        [$student, , $attempt, , $typed, $fileAnswer] = $this->historicalReplayContext();
        $key = (string) Str::uuid();
        $this->submitHistoricalReplay($student, $attempt, $key)->assertOk();
        $this->addHistoricalCheckingMetadata($attempt, 'checked', $typed, $fileAnswer);
        $before = $this->historicalReplaySnapshot();
        $this->submitHistoricalReplay($student, $attempt, $key)->assertStatus(500);
        $this->assertSame($before, $this->historicalReplaySnapshot());

        [$other, , $editable, , $otherTyped, $otherFile] = $this->historicalReplayContext();
        $this->addHistoricalCheckingMetadata($editable, 'checked', $otherTyped, $otherFile);
        $before = $this->historicalReplaySnapshot();
        $this->submitHistoricalReplay($other, $editable, (string) Str::uuid())->assertStatus(500);
        $this->assertSame($before, $this->historicalReplaySnapshot());
    }

    public function test_default_projection_new_start_resume_and_typed_file_mutations_remain_pending_only(): void
    {
        [$student, $assessment, $attempt, , $typed, $fileAnswer, , $typedQuestion, $fileQuestion] = $this->historicalReplayContext();
        $this->addHistoricalCheckingMetadata($attempt, 'checked', $typed, $fileAnswer);
        $before = $this->historicalReplaySnapshot();
        try {
            app(StudentHomeworkAttemptAnswerStates::class)($student->institution_id, $attempt, new Collection([$typedQuestion, $fileQuestion]));
            $this->fail('The default answer projection must still require pending execution metadata.');
        } catch (LogicException) {
            $this->assertSame($before, $this->historicalReplaySnapshot());
        }
        $this->startStudentBlitz($student, $assessment)->assertStatus(500);
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id)->assertStatus(500);
        $this->answerRequest($student, $attempt, $typedQuestion, ['type' => 'true_false', 'value' => false])->assertConflict();
        $blobs = Storage::disk('local')->allFiles();
        $this->fileAnswerRequest($student, $attempt, $fileQuestion, $this->fileAnswerUpload('changed.pdf', "%PDF-1.7\nRejected new bytes"))->assertConflict();
        $this->assertSame($blobs, Storage::disk('local')->allFiles());
        $this->assertSame($before, $this->historicalReplaySnapshot());
    }

    #[DataProvider('structuralCorruptions')]
    public function test_historical_canonicalization_rejects_structural_corruption_even_when_later_checking_metadata_is_allowed(string $corruption): void
    {
        [$student, , $attempt, , $typed, $fileAnswer, , $typedQuestion, $fileQuestion] = $this->historicalReplayContext();
        $this->addHistoricalCheckingMetadata($attempt, 'checked', $typed, $fileAnswer);
        $integrity = app(StudentHomeworkAnswerIntegrity::class);
        $answer = str_starts_with($corruption, 'file ') ? $fileAnswer->fresh() : $typed->fresh();
        $question = str_starts_with($corruption, 'file ') ? $fileQuestion : $typedQuestion;
        $integrity->load(new Collection([$answer]), $student->institution_id);
        $before = $this->historicalReplaySnapshot();
        // In-memory loaded-row corruption exercises invariants also protected by database constraints.
        match ($corruption) {
            'answer institution' => $answer->institution_id = (string) Str::uuid(),
            'answer attempt' => $answer->attempt_id = (string) Str::uuid(),
            'answer question' => $answer->question_id = (string) Str::uuid(),
            'question assessment' => $question->assessment_id = (string) Str::uuid(),
            'extra family' => $answer->setRelation('textValue', new AnswerTextValue(['answer_id' => $answer->id, 'institution_id' => $student->institution_id, 'text_value' => 'unexpected'])),
            'wrong family' => $answer->setRelation('booleanValue', null),
            'child institution' => $answer->booleanValue->institution_id = (string) Str::uuid(),
            'child answer' => $answer->booleanValue->answer_id = (string) Str::uuid(),
            'unknown checking status' => $answer->setRawAttributes(array_replace($answer->getAttributes(), ['checking_status' => 'unknown_stage']), true),
            'file answer link' => $answer->answerFile->file_id = (string) Str::uuid(),
            'file answer institution' => $answer->answerFile->institution_id = (string) Str::uuid(),
            'file answer owner' => $answer->answerFile->answer_id = (string) Str::uuid(),
            'file institution' => $answer->answerFile->file->institution_id = (string) Str::uuid(),
            'file student' => $answer->answerFile->file->uploaded_by_user_id = (string) Str::uuid(),
            'file category' => $answer->answerFile->file->setRawAttributes(array_replace($answer->answerFile->file->getAttributes(), ['category' => 'institution_logo']), true),
            'file removed' => $answer->answerFile->file->removed_at = now(),
            'file checksum' => $answer->answerFile->file->checksum_sha256 = 'invalid',
            'file storage' => $answer->answerFile->file->storage_key = '',
            'file size' => $answer->answerFile->file->size_bytes = 0,
            'file mime' => $answer->answerFile->file->mime_type = 'text/plain',
        };
        try {
            $integrity->canonicalForHistoricalRead($answer, $attempt, $question);
            $this->fail('Historical reading must preserve structural answer and file integrity.');
        } catch (LogicException) {
            $this->assertSame($before, $this->historicalReplaySnapshot());
        }
    }

    public static function structuralCorruptions(): array
    {
        return array_map(fn (string $case): array => [$case], ['answer institution', 'answer attempt', 'answer question', 'question assessment',
            'extra family', 'wrong family', 'child institution', 'child answer', 'unknown checking status', 'file answer link',
            'file answer institution', 'file answer owner', 'file institution', 'file student', 'file category', 'file removed',
            'file checksum', 'file storage', 'file size', 'file mime']);
    }

    public function test_historical_projection_rejects_an_answer_outside_the_authorized_question_set(): void
    {
        [$student, , $attempt, , $typed, $fileAnswer, , $typedQuestion] = $this->historicalReplayContext();
        $this->addHistoricalCheckingMetadata($attempt, 'checked', $typed, $fileAnswer);
        $otherAssessment = $this->studentBlitz($student);
        $otherQuestion = Question::factory()->trueFalse()->create(['assessment_id' => $otherAssessment->id]);
        $typed->update(['question_id' => $otherQuestion->id]);
        $before = $this->historicalReplaySnapshot();
        try {
            app(StudentHomeworkAttemptAnswerStates::class)->historicalRead($student->institution_id, $attempt, new Collection([$typedQuestion]));
            $this->fail('A historical projection must not hide an answer outside the authorized Question set.');
        } catch (LogicException) {
            $this->assertSame($before, $this->historicalReplaySnapshot());
        }
    }

    #[DataProvider('incompatibleSubmitLineages')]
    public function test_completed_submit_cannot_replay_a_timeout_or_teacher_close_history(string $status, string $reason): void
    {
        [$student, , $attempt, , $typed, $fileAnswer] = $this->historicalReplayContext();
        $key = (string) Str::uuid();
        $this->submitHistoricalReplay($student, $attempt, $key)->assertOk();
        $this->advanceHistoricalReplay($attempt, $status, $reason, $typed, $fileAnswer);
        $before = $this->historicalReplaySnapshot();
        $this->submitHistoricalReplay($student, $attempt, $key)->assertStatus(500);
        $this->assertSame($before, $this->historicalReplaySnapshot());
    }

    public static function incompatibleSubmitLineages(): array
    {
        return [['waiting_for_teacher_review', 'timeout_auto_submit'], ['checked', 'timeout_auto_submit'],
            ['waiting_for_teacher_review', 'task_closed_auto_finalize'], ['checked', 'task_closed_auto_finalize']];
    }
}
