<?php

namespace App\Http\Requests\Teacher;

use App\Enums\BlitzStatus;
use Illuminate\Contracts\Validation\Validator as ValidatorContract;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class TeacherBlitzIndexRequest extends FormRequest
{
    private const ACCEPTED_QUERY_KEYS = ['topic_id', 'group_id', 'status', 'page', 'per_page'];

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
            'topic_id' => ['sometimes', 'required', 'string', 'uuid'],
            'group_id' => ['sometimes', 'required', 'string', 'uuid'],
            'status' => ['sometimes', 'required', 'string', Rule::in(BlitzStatus::values())],
            'page' => ['sometimes', 'required', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'required', 'integer', 'min:1', 'max:100'],
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

    protected function failedValidation(ValidatorContract $validator): void
    {
        if ($validator->errors()->has('topic_id') || $validator->errors()->has('group_id')) {
            throw new NotFoundHttpException;
        }

        parent::failedValidation($validator);
    }

    /** @return array<string, mixed> */
    public function filters(): array
    {
        return [
            ...$this->validated(),
            'page' => (int) $this->validated('page', 1),
            'per_page' => (int) $this->validated('per_page', 20),
        ];
    }
}
