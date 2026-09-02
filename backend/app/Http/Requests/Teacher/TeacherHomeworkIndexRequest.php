<?php

namespace App\Http\Requests\Teacher;

use App\Actions\Teacher\ListTeacherHomework;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\HomeworkStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class TeacherHomeworkIndexRequest extends FormRequest
{
    private const ACCEPTED_QUERY_KEYS = [
        'status',
        'assignment_mode',
        'search',
        'sort',
        'direction',
        'page',
        'per_page',
    ];

    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $search = $this->query('search');

        if (is_string($search)) {
            $this->query->set('search', trim($search));
        }
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
            'status' => ['sometimes', 'string', Rule::in(HomeworkStatus::values())],
            'assignment_mode' => ['sometimes', 'string', Rule::in(AssessmentAssignmentMode::values())],
            'search' => ['sometimes', 'nullable', 'string', 'max:160'],
            'sort' => ['sometimes', 'string', Rule::in(ListTeacherHomework::allowedSorts())],
            'direction' => ['sometimes', 'string', Rule::in(ListTeacherHomework::allowedDirections())],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.ListTeacherHomework::MAX_PER_PAGE],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownKeys = array_values(array_diff(array_keys($this->query->all()), self::ACCEPTED_QUERY_KEYS));
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

    public function status(): ?string
    {
        $status = $this->validated('status');

        return is_string($status) ? $status : null;
    }

    public function assignmentMode(): ?string
    {
        $mode = $this->validated('assignment_mode');

        return is_string($mode) ? $mode : null;
    }

    public function search(): ?string
    {
        $search = $this->validated('search');

        return is_string($search) && $search !== '' ? $search : null;
    }

    public function sort(): string
    {
        return (string) $this->validated('sort', ListTeacherHomework::DEFAULT_SORT);
    }

    public function direction(): string
    {
        return (string) $this->validated('direction', ListTeacherHomework::DEFAULT_DIRECTION);
    }

    public function page(): int
    {
        return (int) $this->validated('page', ListTeacherHomework::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListTeacherHomework::DEFAULT_PER_PAGE);
    }
}
