<?php

namespace App\Http\Requests\Platform;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class PlatformInstitutionLifecycleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function validationData(): array
    {
        if (! $this->hasJsonObjectBody()) {
            return [];
        }

        return $this->json()->all();
    }

    /**
     * @return array<string, list<mixed>>
     */
    public function rules(): array
    {
        return [];
    }

    public function withValidator(Validator $validator): void
    {
        $hasBody = trim($this->getContent()) !== '';
        $hasJsonObjectBody = $this->hasJsonObjectBody();
        $bodyKeys = array_keys($this->validationData());
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($hasBody, $hasJsonObjectBody, $bodyKeys, $queryKeys): void {
            if ($hasBody && ! $hasJsonObjectBody) {
                $validator->errors()->add('body', 'The request body must be empty or an empty JSON object.');
            }

            foreach ($bodyKeys as $bodyKey) {
                $validator->errors()->add((string) $bodyKey, 'This field is not allowed.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }
        });
    }

    private function hasJsonObjectBody(): bool
    {
        $content = trim($this->getContent());

        if ($content === '') {
            return false;
        }

        try {
            $decoded = json_decode($content, associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return false;
        }

        return $decoded instanceof stdClass;
    }
}
