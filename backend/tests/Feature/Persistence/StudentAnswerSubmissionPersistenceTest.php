<?php

namespace Tests\Feature\Persistence;

use App\Enums\AssessmentAttemptStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\User;
use Closure;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class StudentAnswerSubmissionPersistenceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
        $this->assertSame('pgsql', DB::connection()->getDriverName());
    }

    public function test_answer_persists_defaults_and_rejects_duplicate_question_invalid_checking_and_foreign_references(): void
    {
        $answer = $this->answerForType('singleChoice');

        $this->assertDatabaseHas('attempt_answers', [
            'id' => $answer->id,
            'institution_id' => $answer->attempt->institution_id,
            'question_id' => $answer->question_id,
            'checking_status' => 'pending',
            'awarded_points' => null,
            'feedback' => null,
            'checked_by_user_id' => null,
            'checked_at' => null,
        ]);

        $this->assertPostgresRejects(fn () => DB::table('attempt_answers')->insert(array_replace(
            $answer->getAttributes(),
            ['id' => Str::uuid()->toString()],
        )), '23505');

        $foreignAnswer = $this->answerForType('singleChoice');

        foreach ([
            ['attempt_id' => $foreignAnswer->attempt_id],
            ['question_id' => $foreignAnswer->question_id],
            ['checked_by_user_id' => $foreignAnswer->attempt->student_id],
        ] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('attempt_answers')->where('id', $answer->id)->update($foreignReference),
                '23503',
            );
        }

        foreach ([
            ['checking_status' => 'checked'],
            ['awarded_points' => '-0.00000001'],
        ] as $invalidAttributes) {
            $this->assertPostgresRejects(
                fn () => DB::table('attempt_answers')->where('id', $answer->id)->update($invalidAttributes),
                '23514',
            );
        }

        foreach (['pending', 'auto_checked', 'waiting_for_teacher_review', 'teacher_checked'] as $status) {
            DB::table('attempt_answers')->where('id', $answer->id)->update([
                'checking_status' => $status,
                'awarded_points' => '0.00000000',
            ]);
            $this->assertDatabaseHas('attempt_answers', ['id' => $answer->id, 'checking_status' => $status]);
        }
    }

    #[DataProvider('assessmentTypes')]
    public function test_one_in_progress_attempt_is_enforced_for_homework_and_blitz_while_terminal_history_remains_valid(string $type): void
    {
        $assessment = Assessment::factory()->{$type}()->create();
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $assessment]);
        $first = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient]);
        $next = [
            'assessment_student_id' => $recipient,
            'attempt_number' => 2,
        ];

        $this->assertDatabaseHas('assessment_attempts', ['id' => $first->id, 'status' => 'in_progress']);
        $this->assertPostgresRejects(fn () => AssessmentAttempt::factory()->create($next), '23505');

        $first->update([
            'status' => AssessmentAttemptStatus::Submitted,
            'submitted_at' => now(),
            'finalized_at' => now(),
            'finalization_reason' => 'student_submit',
        ]);
        $second = AssessmentAttempt::factory()->create($next);

        $this->assertDatabaseHas('assessment_attempts', ['id' => $first->id, 'status' => 'submitted']);
        $this->assertDatabaseHas('assessment_attempts', ['id' => $second->id, 'status' => 'in_progress']);
        $this->assertSame(2, DB::table('assessment_attempts')
            ->where('assessment_id', $assessment->id)
            ->where('student_id', $recipient->student_id)
            ->count());

        $this->assertPostgresRejects(fn () => $first->update(['status' => AssessmentAttemptStatus::InProgress]), '23505');

        $anotherStudent = AssessmentStudent::factory()->create(['assessment_id' => $assessment]);
        AssessmentAttempt::factory()->create(['assessment_student_id' => $anotherStudent]);
        $anotherAssessment = Assessment::factory()->{$type}()->create(['institution_id' => $assessment->institution_id]);
        $anotherRecipient = AssessmentStudent::factory()->create([
            'assessment_id' => $anotherAssessment,
            'student_id' => $recipient->student_id,
        ]);
        AssessmentAttempt::factory()->create(['assessment_student_id' => $anotherRecipient]);

        $this->assertDatabaseCount('assessment_attempts', 4);
    }

    public static function assessmentTypes(): array
    {
        return [['homework'], ['blitz']];
    }

    public function test_choice_selection_rejects_duplicates_and_foreign_option_or_answer(): void
    {
        $answer = $this->answerForType('singleChoice');
        $option = QuestionChoiceOption::factory()->create(['question_id' => $answer->question_id]);
        $selection = [
            'answer_id' => $answer->id,
            'option_id' => $option->id,
            'institution_id' => $answer->institution_id,
            'created_at' => now(),
        ];
        DB::table('answer_choice_selections')->insert($selection);
        $this->assertDatabaseHas('answer_choice_selections', ['answer_id' => $answer->id, 'option_id' => $option->id]);
        $this->assertPostgresRejects(fn () => DB::table('answer_choice_selections')->insert($selection), '23505');

        $foreignOption = QuestionChoiceOption::factory()->create();
        $foreignAnswer = $this->answerForType('singleChoice');

        foreach ([['option_id' => $foreignOption->id], ['answer_id' => $foreignAnswer->id]] as $foreignReference) {
            $this->assertPostgresRejects(fn () => DB::table('answer_choice_selections')->insert(array_replace(
                $selection,
                $foreignReference,
            )), '23503');
        }
    }

    public function test_text_and_boolean_values_persist_one_value_and_reject_foreign_parent_answers(): void
    {
        $foreignAnswer = $this->answerForType('singleChoice');

        foreach ([
            ['answer_text_values', 'openWritten', ['text_value' => 'Student response']],
            ['answer_boolean_values', 'trueFalse', ['boolean_value' => false]],
        ] as [$table, $questionType, $value]) {
            $answer = $this->answerForType($questionType);
            $attributes = array_merge([
                'answer_id' => $answer->id,
                'institution_id' => $answer->institution_id,
                'created_at' => now(),
                'updated_at' => now(),
            ], $value);
            DB::table($table)->insert($attributes);
            $this->assertDatabaseHas($table, array_merge(['answer_id' => $answer->id], $value));
            $this->assertPostgresRejects(fn () => DB::table($table)->insert($attributes), '23505');
            $this->assertPostgresRejects(fn () => DB::table($table)->insert(array_replace(
                $attributes,
                ['answer_id' => $foreignAnswer->id],
            )), '23503');
            $this->assertPostgresRejects(fn () => $answer->delete(), '23001');
        }
    }

    public function test_matching_pairs_reject_duplicate_left_or_right_and_foreign_items_or_parent(): void
    {
        $answer = $this->answerForType('matching');
        $left = QuestionMatchingItem::factory()->left()->create(['question_id' => $answer->question_id, 'position' => 0]);
        $otherLeft = QuestionMatchingItem::factory()->left()->create(['question_id' => $answer->question_id, 'position' => 1]);
        $right = QuestionMatchingItem::factory()->right()->create(['question_id' => $answer->question_id, 'position' => 0]);
        $otherRight = QuestionMatchingItem::factory()->right()->create(['question_id' => $answer->question_id, 'position' => 1]);
        $pair = $this->childAttributes($answer, ['left_item_id' => $left->id, 'right_item_id' => $right->id]);
        DB::table('answer_matching_pairs')->insert($pair);

        foreach ([['right_item_id' => $otherRight->id], ['left_item_id' => $otherLeft->id]] as $duplicateSide) {
            $this->assertPostgresRejects(fn () => DB::table('answer_matching_pairs')->insert(array_replace(
                $pair,
                ['id' => Str::uuid()->toString()],
                $duplicateSide,
            )), '23505');
        }

        $foreignItem = QuestionMatchingItem::factory()->create();
        $foreignAnswer = $this->answerForType('matching');

        foreach ([
            ['left_item_id' => $foreignItem->id],
            ['right_item_id' => $foreignItem->id],
            ['answer_id' => $foreignAnswer->id],
        ] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('answer_matching_pairs')->where('id', $pair['id'])->update($foreignReference),
                '23503',
            );
        }

        $this->assertDatabaseHas('answer_matching_pairs', ['id' => $pair['id'], 'left_item_id' => $left->id, 'right_item_id' => $right->id]);
        $this->assertPostgresRejects(fn () => $left->delete(), '23001');
        $this->assertPostgresRejects(fn () => $right->delete(), '23001');
    }

    public function test_ordering_items_reject_duplicate_item_or_position_negative_position_and_foreign_links(): void
    {
        $answer = $this->answerForType('ordering');
        $item = QuestionOrderingItem::factory()->create(['question_id' => $answer->question_id, 'correct_position' => 0]);
        $otherItem = QuestionOrderingItem::factory()->create(['question_id' => $answer->question_id, 'correct_position' => 1]);
        $submission = $this->childAttributes($answer, ['ordering_item_id' => $item->id, 'submitted_position' => 0]);
        DB::table('answer_ordering_items')->insert($submission);

        foreach ([['submitted_position' => 1], ['ordering_item_id' => $otherItem->id]] as $duplicate) {
            $this->assertPostgresRejects(fn () => DB::table('answer_ordering_items')->insert(array_replace(
                $submission,
                ['id' => Str::uuid()->toString()],
                $duplicate,
            )), '23505');
        }

        $this->assertPostgresRejects(
            fn () => DB::table('answer_ordering_items')->where('id', $submission['id'])->update(['submitted_position' => -1]),
            '23514',
        );
        $foreignItem = QuestionOrderingItem::factory()->create();
        $foreignAnswer = $this->answerForType('ordering');

        foreach ([['ordering_item_id' => $foreignItem->id], ['answer_id' => $foreignAnswer->id]] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('answer_ordering_items')->where('id', $submission['id'])->update($foreignReference),
                '23503',
            );
        }

        $this->assertDatabaseHas('answer_ordering_items', ['id' => $submission['id'], 'submitted_position' => 0]);
        $this->assertPostgresRejects(fn () => $item->delete(), '23001');
    }

    public function test_fill_blank_values_reject_duplicate_blank_and_foreign_blank_or_parent(): void
    {
        $answer = $this->answerForType('fillInBlank');
        $blank = QuestionFillBlank::factory()->create(['question_id' => $answer->question_id]);
        $value = $this->childAttributes($answer, [
            'blank_id' => $blank->id,
            'text_value' => 'Student blank value',
            'updated_at' => now(),
        ]);
        DB::table('answer_fill_blank_values')->insert($value);
        $this->assertPostgresRejects(fn () => DB::table('answer_fill_blank_values')->insert(array_replace(
            $value,
            ['id' => Str::uuid()->toString()],
        )), '23505');

        $foreignBlank = QuestionFillBlank::factory()->create();
        $foreignAnswer = $this->answerForType('fillInBlank');

        foreach ([['blank_id' => $foreignBlank->id], ['answer_id' => $foreignAnswer->id]] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('answer_fill_blank_values')->where('id', $value['id'])->update($foreignReference),
                '23503',
            );
        }

        $this->assertDatabaseHas('answer_fill_blank_values', ['id' => $value['id'], 'text_value' => 'Student blank value']);
        $this->assertPostgresRejects(fn () => $blank->delete(), '23001');
    }

    public function test_answer_files_reject_multiple_files_file_reuse_and_foreign_file_or_parent(): void
    {
        $answer = $this->answerForType('fileBased');
        $file = $this->submissionFile($answer);
        $link = $this->childAttributes($answer, ['file_id' => $file->id]);
        DB::table('answer_files')->insert($link);

        $otherFile = $this->submissionFile($answer);
        $this->assertPostgresRejects(fn () => DB::table('answer_files')->insert(array_replace(
            $link,
            ['id' => Str::uuid()->toString(), 'file_id' => $otherFile->id],
        )), '23505');

        $otherAnswer = $this->answerForType('fileBased', $answer->institution_id);
        $this->assertPostgresRejects(fn () => DB::table('answer_files')->insert(array_replace(
            $link,
            ['id' => Str::uuid()->toString(), 'answer_id' => $otherAnswer->id],
        )), '23505');

        $foreignAnswer = $this->answerForType('fileBased');
        $foreignFile = $this->submissionFile($foreignAnswer);

        foreach ([['file_id' => $foreignFile->id], ['answer_id' => $foreignAnswer->id]] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('answer_files')->where('id', $link['id'])->update($foreignReference),
                '23503',
            );
        }

        $this->assertDatabaseHas('answer_files', ['id' => $link['id'], 'file_id' => $file->id]);

        foreach ([$answer, $file, $answer->attempt, $answer->question] as $referencedModel) {
            $this->assertPostgresRejects(fn () => $referencedModel->delete(), '23001');
        }
    }

    public function test_idempotency_scope_allows_same_key_for_another_user_institution_or_extensible_operation(): void
    {
        $user = User::factory()->student()->create();
        $record = $this->idempotencyAttributes($user, [
            'result_resource_type' => 'assessment_attempt',
            'result_resource_id' => Str::uuid()->toString(),
            'response_status' => 201,
            'completed_at' => now(),
        ]);
        DB::table('idempotency_records')->insert($record);
        $this->assertDatabaseHas('idempotency_records', [
            'id' => $record['id'],
            'response_status' => 201,
            'result_resource_id' => $record['result_resource_id'],
        ]);

        $sameTenantUser = User::factory()->student()->create(['institution_id' => $user->institution_id]);
        $foreignUser = User::factory()->student()->create();

        foreach ([
            ['user_id' => $sameTenantUser->id],
            ['institution_id' => $foreignUser->institution_id, 'user_id' => $foreignUser->id],
            ['operation' => 'student.blitz.attempt.start'],
        ] as $differentScope) {
            DB::table('idempotency_records')->insert(array_replace(
                $record,
                ['id' => Str::uuid()->toString()],
                $differentScope,
            ));
        }

        $this->assertSame(4, DB::table('idempotency_records')->where('idempotency_key', $record['idempotency_key'])->count());
        $this->assertPostgresRejects(fn () => DB::table('idempotency_records')->insert(array_replace(
            $record,
            ['id' => Str::uuid()->toString()],
        )), '23505');
        $this->assertPostgresRejects(
            fn () => DB::table('idempotency_records')->where('id', $record['id'])->update(['user_id' => $foreignUser->id]),
            '23503',
        );
        $this->assertPostgresRejects(fn () => $user->delete(), '23001');
    }

    public function test_idempotency_rejects_invalid_fingerprints_blank_labels_non_success_status_and_completion_order(): void
    {
        $user = User::factory()->student()->create();
        $record = $this->idempotencyAttributes($user, [
            'result_resource_type' => 'assessment_attempt',
            'result_resource_id' => Str::uuid()->toString(),
            'response_status' => 200,
            'completed_at' => now(),
        ]);
        DB::table('idempotency_records')->insert($record);

        foreach ([
            ['request_fingerprint' => str_repeat('a', 63)],
            ['request_fingerprint' => str_repeat('A', 64)],
            ['request_fingerprint' => str_repeat('g', 64)],
            ['operation' => '   '],
            ['result_resource_type' => '   '],
            ['response_status' => 199],
            ['response_status' => 300],
            ['completed_at' => now()->subSecond()],
        ] as $invalidAttributes) {
            $this->assertPostgresRejects(
                fn () => DB::table('idempotency_records')->where('id', $record['id'])->update($invalidAttributes),
                '23514',
            );
        }

        DB::table('idempotency_records')->where('id', $record['id'])->update(['response_status' => 299]);
        $this->assertDatabaseHas('idempotency_records', ['id' => $record['id'], 'response_status' => 299]);
    }

    public function test_idempotency_completion_metadata_must_be_all_absent_or_all_present(): void
    {
        $record = $this->idempotencyAttributes(User::factory()->student()->create());
        DB::table('idempotency_records')->insert($record);
        $completion = [
            'result_resource_type' => 'assessment_attempt',
            'result_resource_id' => Str::uuid()->toString(),
            'response_status' => 200,
            'completed_at' => now(),
        ];

        for ($mask = 1; $mask < 15; $mask++) {
            $partialCompletion = [];

            foreach (array_keys($completion) as $bit => $column) {
                $partialCompletion[$column] = ($mask & (1 << $bit)) !== 0 ? $completion[$column] : null;
            }

            $this->assertPostgresRejects(
                fn () => DB::table('idempotency_records')->where('id', $record['id'])->update($partialCompletion),
                '23514',
            );
        }

        $this->assertDatabaseHas('idempotency_records', [
            'id' => $record['id'],
            'result_resource_type' => null,
            'result_resource_id' => null,
            'response_status' => null,
            'completed_at' => null,
        ]);
        DB::table('idempotency_records')->where('id', $record['id'])->update($completion);
        $this->assertDatabaseHas('idempotency_records', ['id' => $record['id'], 'response_status' => 200]);
    }

    public function test_transaction_rollback_leaves_no_durable_idempotency_claim_and_key_can_be_reused(): void
    {
        $record = $this->idempotencyAttributes(User::factory()->student()->create());
        $failure = new RuntimeException('Abort the persistence transaction.');

        try {
            DB::transaction(function () use ($record, $failure): void {
                DB::table('idempotency_records')->insert($record);
                $this->assertDatabaseHas('idempotency_records', ['id' => $record['id']]);

                throw $failure;
            });
        } catch (RuntimeException $exception) {
            $this->assertSame($failure, $exception);
        }

        $this->assertDatabaseMissing('idempotency_records', ['id' => $record['id']]);
        DB::table('idempotency_records')->insert($record);
        $this->assertDatabaseHas('idempotency_records', ['id' => $record['id'], 'completed_at' => null]);
    }

    private function answerForType(string $questionType, ?string $institutionId = null): AttemptAnswer
    {
        $assessment = Assessment::factory()->create($institutionId === null ? [] : ['institution_id' => $institutionId]);
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $assessment]);
        $attempt = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient]);
        $question = Question::factory()->{$questionType}()->create(['assessment_id' => $assessment]);

        return AttemptAnswer::factory()->create(['attempt_id' => $attempt, 'question_id' => $question]);
    }

    /** @param array<string, mixed> $attributes */
    private function childAttributes(AttemptAnswer $answer, array $attributes): array
    {
        return array_merge([
            'id' => Str::uuid()->toString(),
            'institution_id' => $answer->institution_id,
            'answer_id' => $answer->id,
            'created_at' => now(),
        ], $attributes);
    }

    private function submissionFile(AttemptAnswer $answer): File
    {
        return File::factory()->studentSubmission()->create([
            'institution_id' => $answer->institution_id,
            'uploaded_by_user_id' => $answer->attempt->student_id,
        ]);
    }

    /** @param array<string, mixed> $attributes */
    private function idempotencyAttributes(User $user, array $attributes = []): array
    {
        return array_merge([
            'id' => Str::uuid()->toString(),
            'institution_id' => $user->institution_id,
            'user_id' => $user->id,
            'operation' => 'student.homework.attempt.start',
            'idempotency_key' => Str::uuid()->toString(),
            'request_fingerprint' => hash('sha256', 'deterministic-request'),
            'result_resource_type' => null,
            'result_resource_id' => null,
            'response_status' => null,
            'completed_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $attributes);
    }

    private function assertPostgresRejects(Closure $operation, string $sqlState): void
    {
        try {
            DB::transaction(fn () => $operation());
        } catch (QueryException $exception) {
            $this->assertSame($sqlState, $exception->errorInfo[0]);

            return;
        }

        $this->fail('Expected PostgreSQL to reject the database operation with SQLSTATE '.$sqlState.'.');
    }
}
