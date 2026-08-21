<?php

namespace App\Http\Requests\Institution;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class InstitutionGroupArchiveRequest extends FormRequest
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
        return $this->hasJsonObjectBody() ? $this->json()->all() : [];
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
        $hasBody = $this->getContent() !== '';
        $hasJsonObjectBody = $this->hasJsonObjectBody();
        $bodyKeys = array_keys($this->validationData());
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($hasBody, $hasJsonObjectBody, $bodyKeys, $queryKeys): void {
            if ($hasBody && ! $hasJsonObjectBody) {
                $validator->errors()->add('body', 'The request body must be empty or an empty application/json object.');
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
        if (! $this->hasApplicationJsonContentType()) {
            return false;
        }

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

    private function hasApplicationJsonContentType(): bool
    {
        $contentType = strtolower(trim((string) $this->headers->get('CONTENT_TYPE')));
        $mediaType = trim(explode(';', $contentType, 2)[0]);

        return $mediaType === 'application/json';
    }
}
