<?php

namespace App\Http\Requests\Teacher;

use App\Actions\Teacher\ListTeacherTopicResults;
use App\Enums\TopicResultStatus;
use App\Enums\UnderstandingCategoryCode;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/** The Topic results list query (docs/09 §25.5): status and category filters and paging only; no body. */
class TeacherTopicResultIndexRequest extends FormRequest
{
    private const ACCEPTED_QUERY_KEYS = ['result_status', 'category', 'page', 'per_page'];

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
            'result_status' => ['sometimes', 'string', Rule::in(TopicResultStatus::values())],
            'category' => ['sometimes', 'string', Rule::in(UnderstandingCategoryCode::values())],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.ListTeacherTopicResults::MAX_PER_PAGE],
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

    /** @return array{result_status?: string, category?: string} */
    public function filters(): array
    {
        return array_intersect_key($this->validated(), array_flip(['result_status', 'category']));
    }

    public function page(): int
    {
        return (int) ($this->validated()['page'] ?? 1);
    }

    public function perPage(): int
    {
        return (int) ($this->validated()['per_page'] ?? ListTeacherTopicResults::DEFAULT_PER_PAGE);
    }
}
