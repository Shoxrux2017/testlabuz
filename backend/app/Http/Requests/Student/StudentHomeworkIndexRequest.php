<?php

namespace App\Http\Requests\Student;

use App\Actions\Student\ListStudentHomework;
use App\Enums\HomeworkStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class StudentHomeworkIndexRequest extends FormRequest
{
    private const ACCEPTED_QUERY_KEYS = ['topic_id', 'status', 'page', 'per_page', 'sort', 'direction'];

    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return $this->query->all();
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'topic_id' => ['sometimes', 'string', 'uuid'],
            'status' => ['sometimes', 'string', Rule::in([
                HomeworkStatus::Active->value,
                HomeworkStatus::Closed->value,
                HomeworkStatus::Archived->value,
            ])],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.ListStudentHomework::MAX_PER_PAGE],
            'sort' => ['sometimes', 'string', Rule::in(['created_at', 'title', 'deadline_at', 'status'])],
            'direction' => ['sometimes', 'string', Rule::in(['asc', 'desc'])],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownKeys = array_diff(array_keys($this->query->all()), self::ACCEPTED_QUERY_KEYS);
        $hasRequestBody = $this->getContent() !== '';

        $validator->after(function (Validator $validator) use ($unknownKeys, $hasRequestBody): void {
            if ($hasRequestBody) {
                $validator->errors()->add('body', 'The request body is not allowed for this endpoint.');
            }

            foreach ($unknownKeys as $unknownKey) {
                $validator->errors()->add((string) $unknownKey, 'This query parameter is not allowed.');
            }
        });
    }

    public function topicId(): ?string
    {
        return $this->validated('topic_id');
    }

    public function status(): ?string
    {
        return $this->validated('status');
    }

    public function page(): int
    {
        return (int) $this->validated('page', ListStudentHomework::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListStudentHomework::DEFAULT_PER_PAGE);
    }

    public function sort(): string
    {
        return $this->validated('sort', 'created_at');
    }

    public function direction(): string
    {
        return $this->validated('direction', 'desc');
    }
}
