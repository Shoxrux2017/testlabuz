<?php

namespace App\Http\Requests\Teacher;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class TeacherTopicResultPairUpdateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = ['homework_assessment_id'];

    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return $this->hasJsonObjectBody() ? $this->json()->all() : [];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'homework_assessment_id' => ['required', 'string', 'uuid'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $requestKeys = array_keys($this->validationData());
        $unknownJsonKeys = array_values(array_diff($requestKeys, self::ACCEPTED_INPUT_KEYS));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($unknownJsonKeys, $queryKeys): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownJsonKeys as $unknownJsonKey) {
                $validator->errors()->add((string) $unknownJsonKey, 'This field is not allowed.');
            }
        });
    }

    public function homeworkAssessmentId(): string
    {
        return strtolower($this->validated('homework_assessment_id'));
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
