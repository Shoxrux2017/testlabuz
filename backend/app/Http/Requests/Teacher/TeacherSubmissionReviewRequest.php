<?php

namespace App\Http\Requests\Teacher;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

/**
 * Strict body for a review save (docs/09 §23.1 step 1): exactly `answers`, a non-empty list of
 * `{answer_id, awarded_points, feedback}` objects with unique answer ids, and no query parameters.
 * The raw JSON is read so that numbers, strings and booleans keep their JSON types.
 */
class TeacherSubmissionReviewRequest extends FormRequest
{
    public const MAX_FEEDBACK_LENGTH = 2000;

    private const ITEM_KEYS = ['answer_id', 'awarded_points', 'feedback'];

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
                if ($key !== 'answers') {
                    $validator->errors()->add((string) $key, 'This field is not allowed.');
                }
            }

            if (! property_exists($body, 'answers')) {
                $validator->errors()->add('answers', 'The answers field is required.');
            } elseif (! is_array($body->answers) || $body->answers === []) {
                $validator->errors()->add('answers', 'The answers must be a non-empty JSON array.');
            } else {
                $seenAnswerIds = [];

                foreach ($body->answers as $index => $item) {
                    $this->validateItem($validator, "answers.{$index}", $item, $seenAnswerIds);
                }
            }
        });
    }

    /** @return list<array{answer_id: string, awarded_points: int|float, feedback: ?string}> */
    public function answers(): array
    {
        return array_map(function (stdClass $item): array {
            $feedback = $item->feedback === null ? null : trim($item->feedback);

            return [
                'answer_id' => strtolower($item->answer_id),
                'awarded_points' => $item->awarded_points,
                'feedback' => $feedback === '' ? null : $feedback,
            ];
        }, $this->jsonBody()->answers);
    }

    /** @param array<string, true> $seenAnswerIds */
    private function validateItem(Validator $validator, string $path, mixed $item, array &$seenAnswerIds): void
    {
        if (! $item instanceof stdClass) {
            $validator->errors()->add($path, 'Each answer must be a JSON object.');

            return;
        }

        $fields = get_object_vars($item);

        foreach (array_keys($fields) as $key) {
            if (! in_array($key, self::ITEM_KEYS, true)) {
                $validator->errors()->add("{$path}.{$key}", 'This field is not allowed.');
            }
        }

        $answerId = $fields['answer_id'] ?? null;

        if (! is_string($answerId) || ! Str::isUuid($answerId)) {
            $validator->errors()->add("{$path}.answer_id", 'The answer_id must be a UUID string.');
        } elseif (isset($seenAnswerIds[strtolower($answerId)])) {
            $validator->errors()->add("{$path}.answer_id", 'The answer_id values must be unique.');
        } else {
            $seenAnswerIds[strtolower($answerId)] = true;
        }

        $points = $fields['awarded_points'] ?? null;

        if (! is_int($points) && ! is_float($points)) {
            $validator->errors()->add("{$path}.awarded_points", 'The awarded_points must be a JSON number.');
        }

        $feedback = $fields['feedback'] ?? null;

        if (! array_key_exists('feedback', $fields) || ($feedback !== null && ! is_string($feedback))) {
            $validator->errors()->add("{$path}.feedback", 'The feedback must be a string or null.');
        } elseif (is_string($feedback) && mb_strlen(trim($feedback)) > self::MAX_FEEDBACK_LENGTH) {
            $validator->errors()->add("{$path}.feedback", 'The feedback may not be greater than '.self::MAX_FEEDBACK_LENGTH.' characters.');
        }
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
