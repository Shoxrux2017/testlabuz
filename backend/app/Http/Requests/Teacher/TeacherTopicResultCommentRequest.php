<?php

namespace App\Http\Requests\Teacher;

use App\Domain\Text\UnicodeWhitespace;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

/**
 * Strict body for the Topic-result comment (docs/09 §25.7): exactly `teacher_comment`, a string or
 * null, at most 2000 characters after trimming the Unicode whitespace set; no query parameters.
 */
class TeacherTopicResultCommentRequest extends FormRequest
{
    public const MAX_COMMENT_LENGTH = 2000;

    private bool $bodyDecoded = false;

    private mixed $body = null;

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
        $validator->after(function (Validator $validator): void {
            foreach (array_keys($this->query->all()) as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            $body = $this->jsonBody();

            if (! $body instanceof stdClass) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');

                return;
            }

            foreach (array_keys(get_object_vars($body)) as $key) {
                if ($key !== 'teacher_comment') {
                    $validator->errors()->add((string) $key, 'This field is not allowed.');
                }
            }

            if (! property_exists($body, 'teacher_comment')) {
                $validator->errors()->add('teacher_comment', 'The teacher comment field is required.');
            } elseif ($body->teacher_comment !== null && ! is_string($body->teacher_comment)) {
                $validator->errors()->add('teacher_comment', 'The teacher comment must be a string or null.');
            } elseif (mb_strlen($this->normalized($body->teacher_comment) ?? '') > self::MAX_COMMENT_LENGTH) {
                $validator->errors()->add('teacher_comment', 'The teacher comment may not be greater than 2000 characters.');
            }
        });
    }

    /** The comment to store: trimmed, and null when empty. */
    public function comment(): ?string
    {
        $body = $this->jsonBody();

        return $body instanceof stdClass ? $this->normalized($body->teacher_comment) : null;
    }

    private function normalized(?string $comment): ?string
    {
        $trimmed = $comment === null ? '' : UnicodeWhitespace::trim($comment);

        return $trimmed === '' ? null : $trimmed;
    }

    private function jsonBody(): mixed
    {
        if ($this->bodyDecoded) {
            return $this->body;
        }

        $this->bodyDecoded = true;
        $mediaType = trim(explode(';', strtolower((string) $this->headers->get('CONTENT_TYPE')), 2)[0]);

        if ($mediaType !== 'application/json') {
            return null;
        }

        try {
            return $this->body = json_decode($this->getContent(), associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return null;
        }
    }
}
