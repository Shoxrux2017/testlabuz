<?php

namespace App\Http\Requests\Teacher;

use App\Actions\Teacher\ListTeacherTopics;
use App\Enums\TopicStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class TeacherTopicIndexRequest extends FormRequest
{
    private const ACCEPTED_QUERY_KEYS = [
        'group_id',
        'status',
        'search',
        'page',
        'per_page',
        'sort',
        'direction',
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
            'group_id' => ['sometimes', 'string', 'uuid'],
            'status' => ['sometimes', 'string', Rule::in(TopicStatus::values())],
            'search' => ['sometimes', 'nullable', 'string', 'max:254'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.ListTeacherTopics::MAX_PER_PAGE],
            'sort' => ['sometimes', 'string', Rule::in(ListTeacherTopics::allowedSorts())],
            'direction' => ['sometimes', 'string', Rule::in(ListTeacherTopics::allowedDirections())],
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

    public function groupId(): ?string
    {
        $groupId = $this->validated('group_id');

        return is_string($groupId) ? $groupId : null;
    }

    public function status(): ?string
    {
        $status = $this->validated('status');

        return is_string($status) ? $status : null;
    }

    public function search(): ?string
    {
        $search = $this->validated('search');

        return is_string($search) && $search !== '' ? $search : null;
    }

    public function sort(): string
    {
        return (string) $this->validated('sort', ListTeacherTopics::DEFAULT_SORT);
    }

    public function direction(): string
    {
        return (string) $this->validated('direction', ListTeacherTopics::DEFAULT_DIRECTION);
    }

    public function page(): int
    {
        return (int) $this->validated('page', ListTeacherTopics::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListTeacherTopics::DEFAULT_PER_PAGE);
    }
}
