<?php

namespace App\Http\Requests\Teacher;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class TeacherLearningMaterialUpdateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = ['title'];

    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $rawJson = $this->rawJsonObject();

        if ($this->hasApplicationJsonContentType() && $rawJson instanceof stdClass
            && property_exists($rawJson, 'title') && is_string($rawJson->title)) {
            $this->json()->set('title', trim($rawJson->title));
        }
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return $this->hasJsonObjectBody() ? $this->json()->all() : [];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return ['title' => ['present', 'nullable', 'string', 'min:1', 'max:255']];
    }

    public function withValidator(Validator $validator): void
    {
        $requestKeys = array_keys($this->validationData());
        $unknownKeys = array_values(array_diff($requestKeys, self::ACCEPTED_INPUT_KEYS));
        $queryKeys = array_keys($this->query->all());
        $hasBlankTitle = array_key_exists('title', $this->validationData()) && $this->validationData()['title'] === '';

        $validator->after(function (Validator $validator) use ($requestKeys, $unknownKeys, $queryKeys, $hasBlankTitle): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            }

            if ($this->hasJsonObjectBody() && $requestKeys === []) {
                $validator->errors()->add('body', 'The title field is required.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownKeys as $unknownKey) {
                $validator->errors()->add((string) $unknownKey, 'This field is not allowed.');
            }

            if ($hasBlankTitle) {
                $validator->errors()->add('title', 'The title field must not be blank.');
            }
        });
    }

    public function title(): ?string
    {
        $title = $this->validated('title');

        return is_string($title) ? $title : null;
    }

    private function hasJsonObjectBody(): bool
    {
        return $this->hasApplicationJsonContentType() && $this->rawJsonObject() instanceof stdClass;
    }

    private function hasApplicationJsonContentType(): bool
    {
        $contentType = strtolower(trim((string) $this->headers->get('CONTENT_TYPE')));
        $mediaType = trim(explode(';', $contentType, 2)[0]);

        return $mediaType === 'application/json';
    }

    private function rawJsonObject(): ?stdClass
    {
        $content = trim($this->getContent());

        if ($content === '') {
            return null;
        }

        try {
            $decoded = json_decode($content, associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return null;
        }

        return $decoded instanceof stdClass ? $decoded : null;
    }
}
