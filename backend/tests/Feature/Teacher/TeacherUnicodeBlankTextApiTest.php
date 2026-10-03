<?php

namespace Tests\Feature\Teacher;

use App\Domain\Assessment\AssessmentActivationValidator;
use App\Enums\AssessmentAssignmentMode;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use Closure;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\Feature\Teacher\Concerns\BuildsTeacherQuestionMutationContext;
use Tests\TestCase;

/**
 * CL9-11: a Teacher text value made only of Unicode whitespace is rejected exactly like an ASCII-blank
 * one, so no client parser (which trims with Dart's whitespace set) ever receives a blank value.
 */
class TeacherUnicodeBlankTextApiTest extends TestCase
{
    use BuildsTeacherBlitzContext;
    use BuildsTeacherQuestionMutationContext;
    use RefreshDatabase;

    private const UNICODE_BLANK = "\u{00A0}\u{3000}\u{2009}";

    private const ASCII_BLANK = "  \t ";

    /** @return array<string, array{Closure(string): array<string, mixed>}> */
    public static function questionFields(): array
    {
        return [
            'prompt' => [fn (string $text): array => ['prompt' => $text]],
            'choice option text' => [fn (string $text): array => ['type' => 'single_choice', 'configuration' => ['options' => [
                ['text' => $text, 'is_correct' => true, 'position' => 1],
                ['text' => 'B', 'is_correct' => false, 'position' => 2],
            ]]]],
            'short accepted answer' => [fn (string $text): array => ['type' => 'short_written', 'configuration' => ['accepted_answers' => ['DNS', $text]]]],
            'matching left' => [fn (string $text): array => ['type' => 'matching', 'configuration' => ['pairs' => [
                ['client_key' => 'pair-1', 'left' => $text, 'right' => 'Domain Name System'],
            ]]]],
            'matching right' => [fn (string $text): array => ['type' => 'matching', 'configuration' => ['pairs' => [
                ['client_key' => 'pair-1', 'left' => 'DNS', 'right' => $text],
            ]]]],
            'ordering item' => [fn (string $text): array => ['type' => 'ordering', 'configuration' => ['items' => [
                ['text' => 'First', 'correct_position' => 1],
                ['text' => $text, 'correct_position' => 2],
            ]]]],
            'fill blank accepted answer' => [fn (string $text): array => ['type' => 'fill_in_blank', 'prompt' => 'DNS maps {{host}}.', 'configuration' => ['blanks' => [
                ['key' => 'host', 'position' => 1, 'accepted_answers' => [$text]],
            ]]]],
        ];
    }

    #[DataProvider('questionFields')]
    public function test_question_text_of_only_unicode_whitespace_is_rejected_like_ascii_blank(Closure $field): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $uri = "/api/v1/teacher/assessments/{$homework->id}/questions";

        $ascii = $this->homeworkJson($teacher, 'POST', $uri, $this->questionPayload($field(self::ASCII_BLANK)))
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->homeworkJson($teacher, 'POST', $uri, $this->questionPayload($field(self::UNICODE_BLANK)))
            ->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonPath('errors', $ascii->json('errors'));
        $this->assertDatabaseCount('questions', 0);

        $this->homeworkJson($teacher, 'POST', $uri, $this->questionPayload($field("\u{00A0}Text\u{00A0}")))->assertCreated();
    }

    #[DataProvider('taskFields')]
    public function test_task_update_rejects_blank_text_with_a_validation_error(string $task, string $field): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $assessment = $task === 'homework'
            ? $this->persistedHomework($institution, $teacher, $topic)
            : $this->persistedBlitz($institution, $teacher, $topic);
        $uri = "/api/v1/teacher/{$task}/{$assessment->id}";

        $ascii = $this->homeworkJson($teacher, 'PATCH', $uri, [$field => self::ASCII_BLANK])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonStructure(['errors' => [$field]]);
        $this->homeworkJson($teacher, 'PATCH', $uri, [$field => self::UNICODE_BLANK])
            ->assertUnprocessable()
            ->assertJsonPath('errors', $ascii->json('errors'));
        $this->homeworkJson($teacher, 'PATCH', $uri, [$field => "\u{00A0}Text\u{00A0}"])->assertOk();
    }

    public function test_inline_blitz_question_prompt_of_only_unicode_whitespace_is_rejected_like_ascii_blank(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();
        $uri = "/api/v1/teacher/topics/{$topic->id}/blitz";
        $payload = fn (string $prompt): array => $this->validBlitzPayload(['questions' => [[
            ...$this->questionPayload(['prompt' => $prompt]),
            'client_key' => 'q1',
        ]]]);

        $ascii = $this->homeworkJson($teacher, 'POST', $uri, $payload(self::ASCII_BLANK))->assertUnprocessable();
        $this->homeworkJson($teacher, 'POST', $uri, $payload(self::UNICODE_BLANK))
            ->assertUnprocessable()
            ->assertJsonPath('errors', $ascii->json('errors'));
        $this->homeworkJson($teacher, 'POST', $uri, $payload("\u{00A0}Is it true?\u{00A0}"))->assertCreated();
    }

    public function test_question_text_with_characters_inside_unicode_whitespace_is_accepted(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);

        $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/assessments/{$homework->id}/questions", $this->questionPayload([
            'prompt' => "\u{00A0}Is it true?\u{3000}",
        ]))->assertCreated();
    }

    /** @return array<string, array{string, string}> */
    public static function taskFields(): array
    {
        return [
            'homework title' => ['homework', 'title'],
            'homework student instructions' => ['homework', 'student_instructions'],
            'blitz title' => ['blitz', 'title'],
            'blitz student instructions' => ['blitz', 'student_instructions'],
        ];
    }

    #[DataProvider('taskFields')]
    public function test_task_text_of_only_unicode_whitespace_is_rejected_like_ascii_blank(string $task, string $field): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();
        $uri = "/api/v1/teacher/topics/{$topic->id}/{$task}";
        $payload = fn (string $text): array => $task === 'homework'
            ? $this->validHomeworkPayload([$field => $text])
            : $this->validBlitzPayload([$field => $text]);

        $ascii = $this->homeworkJson($teacher, 'POST', $uri, $payload(self::ASCII_BLANK))->assertUnprocessable();
        $this->homeworkJson($teacher, 'POST', $uri, $payload(self::UNICODE_BLANK))
            ->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonPath('errors', $ascii->json('errors'));
        $this->homeworkJson($teacher, 'POST', $uri, $payload("\u{00A0}Text\u{00A0}"))->assertCreated();
    }

    public function test_inline_question_prompt_of_only_unicode_whitespace_is_rejected_like_ascii_blank(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();
        $uri = "/api/v1/teacher/topics/{$topic->id}/homework";
        $payload = fn (string $prompt): array => $this->validHomeworkPayload(['questions' => [[
            ...$this->questionPayload(['prompt' => $prompt]),
            'client_key' => 'q1',
        ]]]);

        $ascii = $this->homeworkJson($teacher, 'POST', $uri, $payload(self::ASCII_BLANK))->assertUnprocessable();
        $this->homeworkJson($teacher, 'POST', $uri, $payload(self::UNICODE_BLANK))
            ->assertUnprocessable()
            ->assertJsonPath('errors', $ascii->json('errors'));
        $this->assertDatabaseCount('assessments', 0);
    }

    /** @return array<string, array{string}> */
    public static function storedMetadataFields(): array
    {
        return ['title' => ['title'], 'student instructions' => ['student_instructions']];
    }

    #[DataProvider('storedMetadataFields')]
    public function test_activation_rejects_stored_unicode_blank_metadata(string $field): void
    {
        $validator = app(AssessmentActivationValidator::class);
        $stored = fn (string $text): Assessment => (new Assessment)->setRawAttributes([
            'title' => 'Homework 1',
            'student_instructions' => 'Answer every question.',
            'assignment_mode' => 'group',
            $field => $text,
        ], true);

        $this->assertSame(AssessmentAssignmentMode::Group, $validator->validateMetadata($stored("\u{00A0}Text\u{00A0}")));

        $this->expectException(BusinessConflictException::class);
        $validator->validateMetadata($stored(self::UNICODE_BLANK));
    }
}
