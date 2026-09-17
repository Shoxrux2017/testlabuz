<?php

namespace Tests\Feature\Student;

use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;

class StudentBlitzAnswerValidationTest extends StudentHomeworkAnswerValidationTest
{
    use BuildsStudentBlitzAnswerContext;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_inaccessible_direct_question_is_not_reclassified_as_a_type_or_child_validation_error(): void
    {
        [$student, , $attempt] = $this->answerContext();
        [, $foreignBlitz] = $this->answerContext();
        $foreignQuestion = $this->answerQuestion($foreignBlitz, 'single_choice');
        $payload = json_encode(['type' => 'multiple_choice', 'selected_option_ids' => [(string) Str::uuid()]], JSON_THROW_ON_ERROR);
        $before = $this->answerSnapshot();
        foreach ([$foreignQuestion->id, (string) Str::uuid(), 'malformed-question'] as $questionId) {
            $response = $this->answerHttp($student, 'PUT', '/api/v1/student/attempts/'.$attempt->id.'/answers/'.$questionId, $payload)
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertStringNotContainsString($questionId, $response->getContent());
        }
        $this->assertSame($before, $this->answerSnapshot());
    }
}
