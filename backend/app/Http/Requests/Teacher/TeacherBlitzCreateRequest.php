<?php

namespace App\Http\Requests\Teacher;

use App\Domain\Assessment\QuestionAuthoringLimits;

class TeacherBlitzCreateRequest extends TeacherBlitzMutationRequest
{
    /** @return list<string> */
    protected function acceptedInputKeys(): array
    {
        return [...self::COMMON_INPUT_KEYS, 'scheduled_at', 'questions'];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            ...$this->commonRules(required: true),
            'scheduled_at' => ['sometimes', 'nullable', 'string', $this->scheduledAtSyntaxRule()],
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

    /** @return array<string, mixed> */
    public function blitzAttributes(): array
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
            'duration_seconds' => $validated['duration_seconds'],
            'scheduled_at' => $validated['scheduled_at'] ?? null,
            'questions' => $questions,
        ];
    }
}
