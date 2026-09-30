<?php

namespace App\Http\Requests\Student;

use App\Actions\Student\ListStudentFinishedBlitz;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class StudentBlitzFinishedRequest extends FormRequest
{
    private const ACCEPTED_QUERY_KEYS = ['page', 'per_page'];

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
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.ListStudentFinishedBlitz::MAX_PER_PAGE],
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

    public function page(): int
    {
        return (int) $this->validated('page', ListStudentFinishedBlitz::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListStudentFinishedBlitz::DEFAULT_PER_PAGE);
    }
}
