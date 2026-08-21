<?php

namespace App\Http\Requests\Institution;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class InstitutionGroupStudentMembershipAssignRequest extends FormRequest
{
    private const ACCEPTED_BODY_KEY = 'student_ids';

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
            self::ACCEPTED_BODY_KEY => ['required', 'array', 'list', 'min:1', 'max:100'],
            self::ACCEPTED_BODY_KEY.'.*' => ['required', 'string', 'uuid', 'distinct:strict'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $hasJsonObjectBody = $this->hasJsonObjectBody();
        $validationData = $this->validationData();
        $unknownBodyKeys = array_values(array_diff(array_keys($validationData), [self::ACCEPTED_BODY_KEY]));
        $studentIds = $validationData[self::ACCEPTED_BODY_KEY] ?? null;
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($hasJsonObjectBody, $unknownBodyKeys, $studentIds, $queryKeys): void {
            if (! $hasJsonObjectBody) {
                $validator->errors()->add('body', 'A valid application/json object body is required.');
            }

            if ($this->containsCanonicalDuplicate($studentIds)) {
                $validator->errors()->add(self::ACCEPTED_BODY_KEY, 'The student ids must not contain duplicates.');
            }

            foreach ($unknownBodyKeys as $unknownBodyKey) {
                $validator->errors()->add((string) $unknownBodyKey, 'This field is not allowed.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }
        });
    }

    /** @return list<string> */
    public function studentIds(): array
    {
        /** @var list<string> $studentIds */
        $studentIds = $this->validated(self::ACCEPTED_BODY_KEY);

        return array_values($studentIds);
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

    private function containsCanonicalDuplicate(mixed $studentIds): bool
    {
        if (! is_array($studentIds)) {
            return false;
        }

        $canonicalIds = array_map(
            static fn (mixed $studentId): mixed => is_string($studentId) ? strtolower($studentId) : $studentId,
            $studentIds,
        );

        return count($canonicalIds) !== count(array_unique($canonicalIds, SORT_REGULAR));
    }

    private function hasApplicationJsonContentType(): bool
    {
        $contentType = strtolower(trim((string) $this->headers->get('CONTENT_TYPE')));
        $mediaType = trim(explode(';', $contentType, 2)[0]);

        return $mediaType === 'application/json';
    }
}
