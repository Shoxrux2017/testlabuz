<?php

namespace Tests\Feature\Persistence;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\FileCategory;
use App\Enums\IdempotencyOperation;
use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Enums\UserRole;
use App\Models\AnswerBooleanValue;
use App\Models\AnswerFile;
use App\Models\AnswerFillBlankValue;
use App\Models\AnswerMatchingPair;
use App\Models\AnswerOrderingItem;
use App\Models\AnswerTextValue;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\IdempotencyRecord;
use App\Models\QuestionChoiceOption;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class StudentAnswerSubmissionFactoryModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_enums_expose_exact_contract_values(): void
    {
        $this->assertSame([
            'pending',
            'auto_checked',
            'waiting_for_teacher_review',
            'teacher_checked',
        ], AttemptAnswerCheckingStatus::values());
        $this->assertSame([
            'student.homework.attempt.start',
            'student.homework.attempt.submit',
        ], IdempotencyOperation::values());
    }

    public function test_answer_factory_defaults_and_attempt_overrides_use_the_same_assessment_and_institution(): void
    {
        $default = AttemptAnswer::factory()->create();
        $attempt = AssessmentAttempt::factory()->create();
        $first = AttemptAnswer::factory()->create(['attempt_id' => $attempt]);
        $second = AttemptAnswer::factory()->forQuestionType(QuestionType::OpenWritten)
            ->create(['attempt_id' => $attempt]);

        foreach ([$default, $first, $second] as $answer) {
            $this->assertAnswerGraph($answer);
            $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->checking_status);
            $this->assertNull($answer->awarded_points);
            $this->assertNull($answer->feedback);
            $this->assertNull($answer->checked_by_user_id);
            $this->assertNull($answer->checked_at);
            $this->assertTrue(Str::isUuid($answer->id));
            $this->assertTrue($answer->attempt->answers->contains($answer));
            $this->assertTrue($answer->question->attemptAnswers->contains($answer));
        }

        $this->assertTrue($attempt->is($first->attempt));
        $this->assertTrue($attempt->is($second->attempt));
        $this->assertNotSame($first->question_id, $second->question_id);
        $this->assertSame(QuestionType::OpenWritten, $second->question->type);
    }

    public function test_answer_casts_checker_and_choice_pivot_relationships(): void
    {
        $this->freezeTime();
        $answer = AttemptAnswer::factory()->create();
        $checker = User::factory()->teacher($answer->institution)->create();
        $answer->update([
            'checking_status' => AttemptAnswerCheckingStatus::TeacherChecked,
            'awarded_points' => '12.34567890',
            'feedback' => 'Reviewed.',
            'checked_by_user_id' => $checker->id,
            'checked_at' => now(),
        ]);
        $option = QuestionChoiceOption::factory()->create(['question_id' => $answer->question_id]);

        $answer->selectedOptions()->attach($option->id, [
            'institution_id' => $answer->institution_id,
            'created_at' => now(),
        ]);
        $answer->refresh();

        $this->assertSame(AttemptAnswerCheckingStatus::TeacherChecked, $answer->checking_status);
        $this->assertSame('12.34567890', $answer->awarded_points);
        $this->assertSame('Reviewed.', $answer->feedback);
        $this->assertInstanceOf(CarbonInterface::class, $answer->checked_at);
        $this->assertTrue($checker->is($answer->checkedBy));
        $this->assertCount(1, $answer->selectedOptions);
        $this->assertTrue($option->is($answer->selectedOptions->sole()));
        $this->assertSame($answer->institution_id, $answer->selectedOptions->sole()->pivot->institution_id);
        $this->assertNotNull($answer->selectedOptions->sole()->pivot->created_at);
        $this->assertArrayNotHasKey('updated_at', $answer->selectedOptions->sole()->pivot->getAttributes());
    }

    public function test_typed_factory_defaults_create_coherent_question_and_answer_graphs(): void
    {
        $text = AnswerTextValue::factory()->create();
        $boolean = AnswerBooleanValue::factory()->create(['boolean_value' => false]);
        $matching = AnswerMatchingPair::factory()->create();
        $ordering = AnswerOrderingItem::factory()->create(['submitted_position' => '3']);
        $fill = AnswerFillBlankValue::factory()->create();

        foreach ([
            [$text, QuestionType::ShortWritten],
            [$boolean, QuestionType::TrueFalse],
            [$matching, QuestionType::Matching],
            [$ordering, QuestionType::Ordering],
            [$fill, QuestionType::FillInBlank],
        ] as [$child, $type]) {
            $this->assertSame($child->answer->institution_id, $child->institution_id);
            $this->assertTrue($child->answer->institution->is($child->institution));
            $this->assertSame($type, $child->answer->question->type);
            $this->assertAnswerGraph($child->answer);
        }

        foreach ([$text, $boolean] as $value) {
            $this->assertSame('answer_id', $value->getKeyName());
            $this->assertSame($value->answer_id, $value->getKey());
            $this->assertFalse($value->getIncrementing());
            $this->assertSame('string', $value->getKeyType());
        }

        $this->assertTrue($text->is($text->answer->textValue));
        $this->assertSame($text->text_value, $text->answer->textValue->text_value);
        $this->assertTrue($boolean->is($boolean->answer->booleanValue));
        $this->assertFalse($boolean->boolean_value);
        $this->assertTrue($matching->answer->matchingPairs->contains($matching));
        $this->assertTrue($ordering->answer->orderingItems->contains($ordering));
        $this->assertTrue($fill->answer->fillBlankValues->contains($fill));
        $this->assertSame(3, $ordering->submitted_position);

        foreach ([$matching->leftItem, $matching->rightItem] as $item) {
            $this->assertSame($matching->answer->question_id, $item->question_id);
            $this->assertSame($matching->institution_id, $item->institution_id);
        }

        $this->assertSame(QuestionMatchingSide::Left, $matching->leftItem->side);
        $this->assertSame(QuestionMatchingSide::Right, $matching->rightItem->side);
        $this->assertSame($ordering->answer->question_id, $ordering->orderingItem->question_id);
        $this->assertSame($ordering->institution_id, $ordering->orderingItem->institution_id);
        $this->assertSame($fill->answer->question_id, $fill->blank->question_id);
        $this->assertSame($fill->institution_id, $fill->blank->institution_id);

        foreach ([$matching, $ordering, $fill] as $child) {
            $this->assertTrue(Str::isUuid($child->id));
        }

        foreach ([$matching, $ordering] as $child) {
            $this->assertInstanceOf(CarbonInterface::class, $child->created_at);
            $this->assertNull($child->getUpdatedAtColumn());
            $this->assertArrayNotHasKey('updated_at', $child->getAttributes());
        }
    }

    public function test_multiple_choice_uses_the_same_selection_pivot(): void
    {
        $answer = AttemptAnswer::factory()->forQuestionType(QuestionType::MultipleChoice)->create();
        $first = QuestionChoiceOption::factory()->create(['question_id' => $answer->question_id, 'position' => 1]);
        $second = QuestionChoiceOption::factory()->create(['question_id' => $answer->question_id, 'position' => 2]);

        foreach ([$first, $second] as $option) {
            $answer->selectedOptions()->attach($option->id, [
                'institution_id' => $answer->institution_id,
                'created_at' => now(),
            ]);
        }

        $this->assertSame(QuestionType::MultipleChoice, $answer->question->type);
        $this->assertCount(2, $answer->selectedOptions);
        $this->assertTrue($answer->selectedOptions->contains($first));
        $this->assertTrue($answer->selectedOptions->contains($second));
    }

    public function test_typed_factories_inherit_explicit_parent_answer_institution(): void
    {
        foreach ([
            [AnswerTextValue::class, QuestionType::OpenWritten],
            [AnswerBooleanValue::class, QuestionType::TrueFalse],
            [AnswerMatchingPair::class, QuestionType::Matching],
            [AnswerOrderingItem::class, QuestionType::Ordering],
            [AnswerFillBlankValue::class, QuestionType::FillInBlank],
            [AnswerFile::class, QuestionType::FileBased],
        ] as [$model, $type]) {
            $answer = AttemptAnswer::factory()->forQuestionType($type)->create();
            $child = $model::factory()->create(['answer_id' => $answer]);

            $this->assertTrue($answer->is($child->answer));
            $this->assertSame($answer->institution_id, $child->institution_id);
        }
    }

    public function test_file_factory_links_an_active_private_submission_uploaded_by_the_attempt_student_without_storage_io(): void
    {
        Storage::shouldReceive('disk')->never();

        $link = AnswerFile::factory()->create();
        $answer = $link->answer;
        $file = $link->file;

        $this->assertAnswerGraph($answer);
        $this->assertSame(QuestionType::FileBased, $answer->question->type);
        $this->assertTrue(Str::isUuid($link->id));
        $this->assertTrue($link->is($answer->answerFile));
        $this->assertTrue($link->is($file->answerFile));
        $this->assertSame($answer->institution_id, $link->institution_id);
        $this->assertTrue($answer->institution->is($link->institution));
        $this->assertSame($answer->institution_id, $file->institution_id);
        $this->assertSame(FileCategory::StudentSubmission, $file->category);
        $this->assertSame('local', $file->storage_disk);
        $this->assertNull($file->removed_at);
        $this->assertSame($answer->attempt->student_id, $file->uploaded_by_user_id);
        $this->assertTrue($answer->attempt->student->is($file->uploader));
        $this->assertSame(UserRole::Student, $file->uploader->role);
        $this->assertInstanceOf(CarbonInterface::class, $link->created_at);
        $this->assertNull($link->getUpdatedAtColumn());
        $this->assertArrayNotHasKey('updated_at', $link->getAttributes());
    }

    public function test_idempotency_factory_defaults_completion_casts_and_user_relationships(): void
    {
        $this->freezeTime();
        $pending = IdempotencyRecord::factory()->create();
        $complete = IdempotencyRecord::factory()->completed()->create([
            'user_id' => $pending->user,
            'operation' => IdempotencyOperation::StudentHomeworkAttemptSubmit,
            'response_status' => '204',
        ]);

        foreach ([$pending, $complete] as $record) {
            $this->assertTrue(Str::isUuid($record->id));
            $this->assertTrue(Str::isUuid($record->idempotency_key));
            $this->assertMatchesRegularExpression('/^[0-9a-f]{64}$/', $record->request_fingerprint);
            $this->assertSame($record->institution_id, $record->user->institution_id);
            $this->assertTrue($record->institution->is($record->user->institution));
            $this->assertTrue($record->user->idempotencyRecords->contains($record));
        }

        $this->assertSame(IdempotencyOperation::StudentHomeworkAttemptStart, $pending->operation);
        $this->assertNull($pending->result_resource_type);
        $this->assertNull($pending->result_resource_id);
        $this->assertNull($pending->response_status);
        $this->assertNull($pending->completed_at);
        $this->assertSame(IdempotencyOperation::StudentHomeworkAttemptSubmit, $complete->operation);
        $this->assertTrue($pending->user->is($complete->user));
        $this->assertSame(204, $complete->response_status);
        $this->assertNotNull($complete->result_resource_type);
        $this->assertTrue(Str::isUuid($complete->result_resource_id));
        $this->assertInstanceOf(CarbonInterface::class, $complete->completed_at);
        $this->assertTrue($complete->completed_at->greaterThanOrEqualTo($complete->created_at));
    }

    private function assertAnswerGraph(AttemptAnswer $answer): void
    {
        $this->assertSame($answer->institution_id, $answer->attempt->institution_id);
        $this->assertSame($answer->institution_id, $answer->question->institution_id);
        $this->assertSame($answer->attempt->assessment_id, $answer->question->assessment_id);
        $this->assertTrue($answer->institution->is($answer->attempt->institution));
        $this->assertTrue($answer->institution->is($answer->question->institution));
    }
}
