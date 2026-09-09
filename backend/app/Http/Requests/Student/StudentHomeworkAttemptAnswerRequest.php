<?php

namespace App\Http\Requests\Student;

use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Support\Student\StudentAnswerText;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class StudentHomeworkAttemptAnswerRequest extends FormRequest
{
    private ?stdClass $rawBody = null;

    private bool $decoded = false;

    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return $this->rawObject() === null
            ? []
            : json_decode($this->getContent(), true, flags: JSON_THROW_ON_ERROR);
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        $rules = ['type' => ['required', 'string', Rule::in([
            'single_choice', 'multiple_choice', 'true_false', 'short_written',
            'open_written', 'matching', 'ordering', 'fill_in_blank',
        ])]];

        return $rules + match ($this->rawObject()?->type ?? null) {
            'single_choice', 'multiple_choice' => [
                'selected_option_ids' => ['present', 'array', 'max:'.QuestionAuthoringLimits::MAX_CHOICE_OPTIONS],
                'selected_option_ids.*' => ['required', 'string', 'uuid', 'distinct:ignore_case'],
            ],
            'true_false' => ['value' => ['present', 'boolean']],
            'short_written', 'open_written' => ['text' => ['present', 'string']],
            'matching' => [
                'pairs' => ['present', 'array', 'max:'.QuestionAuthoringLimits::MAX_MATCHING_PAIRS],
                'pairs.*' => ['array:left_item_id,right_item_id'],
                'pairs.*.left_item_id' => ['required', 'string', 'uuid', 'distinct:ignore_case'],
                'pairs.*.right_item_id' => ['required', 'string', 'uuid', 'distinct:ignore_case'],
            ],
            'ordering' => [
                'items' => ['present', 'array', 'max:'.QuestionAuthoringLimits::MAX_ORDERING_ITEMS],
                'items.*' => ['array:item_id,position'],
                'items.*.item_id' => ['required', 'string', 'uuid', 'distinct:ignore_case'],
                'items.*.position' => ['required', 'integer', 'distinct', 'min:1'],
            ],
            'fill_in_blank' => [
                'values' => ['present', 'array', 'max:'.QuestionAuthoringLimits::MAX_FILL_BLANKS],
                'values.*' => ['array:blank_id,text'],
                'values.*.blank_id' => ['required', 'string', 'uuid', 'distinct:ignore_case'],
                'values.*.text' => ['present', 'string'],
            ],
            default => [],
        };
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $raw = $this->rawObject();

            if ($raw === null) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            }

            if ($this->query->all() !== []) {
                $validator->errors()->add('query', 'Query parameters are not allowed for this endpoint.');
            }

            if ($raw === null || ! is_string($raw->type ?? null)) {
                return;
            }

            $field = match ($raw->type) {
                'single_choice', 'multiple_choice' => 'selected_option_ids',
                'true_false' => 'value',
                'short_written', 'open_written' => 'text',
                'matching' => 'pairs',
                'ordering' => 'items',
                'fill_in_blank' => 'values',
                default => null,
            };

            if ($field === null) {
                return;
            }

            if (array_diff(array_keys(get_object_vars($raw)), ['type', $field]) !== []) {
                $validator->errors()->add('body', 'The answer contains fields that are not allowed.');
            }

            $value = $raw->{$field} ?? null;

            if ($field === 'value') {
                if (! is_bool($value)) {
                    $validator->errors()->add($field, 'The value must be a JSON boolean.');
                }

                return;
            }

            if ($field === 'text') {
                $this->validateText($validator, $field, $value, $raw->type === 'short_written' ? 1000 : 20000);

                return;
            }

            if (! is_array($value)) {
                $validator->errors()->add($field, 'The value must be a JSON array.');

                return;
            }

            if ($raw->type === 'single_choice' && count($value) !== 1) {
                $validator->errors()->add($field, 'Select exactly one option.');
            }

            foreach ($value as $index => $item) {
                if ($field === 'selected_option_ids') {
                    if (! is_string($item)) {
                        $validator->errors()->add($field, 'Each option must be a UUID string.');
                    }

                    continue;
                }

                if (! $item instanceof stdClass) {
                    $validator->errors()->add($field, 'Each entry must be a JSON object.');

                    continue;
                }

                if ($field === 'items' && ! is_int($item->position ?? null)) {
                    $validator->errors()->add("items.$index.position", 'The position must be a JSON integer.');
                }

                if ($field === 'values') {
                    $this->validateText($validator, "values.$index.text", $item->text ?? null, 1000, nonEmpty: true);
                }
            }
        });
    }

    private function validateText(Validator $validator, string $field, mixed $text, int $limit, bool $nonEmpty = false): void
    {
        if (! is_string($text) || mb_strlen($text) > $limit || ($nonEmpty && StudentAnswerText::isEmpty($text))) {
            $validator->errors()->add($field, 'The answer text is invalid.');
        }
    }

    private function rawObject(): ?stdClass
    {
        if (! $this->decoded) {
            $this->decoded = true;
            $contentType = strtolower(trim(explode(';', (string) $this->header('Content-Type'), 2)[0]));

            if ($contentType !== 'application/json') {
                return null;
            }

            try {
                $raw = json_decode($this->getContent(), false, flags: JSON_THROW_ON_ERROR);
                $this->rawBody = $raw instanceof stdClass ? $raw : null;
            } catch (JsonException) {
                $this->rawBody = null;
            }
        }

        return $this->rawBody;
    }
}
