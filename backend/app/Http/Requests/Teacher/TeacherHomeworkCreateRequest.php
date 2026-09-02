<?php

namespace App\Http\Requests\Teacher;

use App\Domain\Assessment\QuestionAuthoringLimits;

class TeacherHomeworkCreateRequest extends TeacherHomeworkMutationRequest
{
    /** @return list<string> */
    protected function acceptedInputKeys(): array
    {
        return [...self::COMMON_INPUT_KEYS, 'questions'];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            ...$this->commonRules(required: true),
            'questions' => ['sometimes', 'array', 'max:'.QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT],
        ];
    }

    protected function validatesQuestions(): bool
    {
        return true;
    }

    protected function validatesCreateAssignmentRules(): bool
    {
        return true;
    }

    /**
     * @return array{
     *     title: string,
     *     description: ?string,
     *     student_instructions: string,
     *     assignment_mode: string,
     *     student_ids: list<string>,
     *     deadline_at: ?string,
     *     questions: list<array<string, mixed>>
     * }
     */
    public function homeworkAttributes(): array
    {
        $validated = $this->validated();
        $questions = array_map(static function (array $question): array {
            $question['instructions'] ??= null;

            return $question;
        }, $validated['questions'] ?? []);

        return [
            'title' => $validated['title'],
            'description' => $validated['description'] ?? null,
            'student_instructions' => $validated['student_instructions'],
            'assignment_mode' => $validated['assignment_mode'],
            'student_ids' => array_map(strtolower(...), $validated['student_ids']),
            'deadline_at' => $validated['deadline_at'] ?? null,
            'questions' => $questions,
        ];
    }
}
