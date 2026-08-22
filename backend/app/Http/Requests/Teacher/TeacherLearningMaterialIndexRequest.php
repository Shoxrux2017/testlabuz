<?php

namespace App\Http\Requests\Teacher;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class TeacherLearningMaterialIndexRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return [];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [];
    }

    public function withValidator(Validator $validator): void
    {
        $hasBody = $this->getContent() !== '';
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($hasBody, $queryKeys): void {
            if ($hasBody) {
                $validator->errors()->add('body', 'The request body is not allowed for this endpoint.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }
        });
    }
}
