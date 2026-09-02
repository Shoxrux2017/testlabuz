<?php

namespace App\Http\Requests\Teacher;

use App\Domain\Assessment\AssessmentPointMath;
use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Domain\Assessment\QuestionConfigurationValidator;
use App\Domain\Assessment\QuestionPositionSetValidator;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use App\Support\Teacher\InstitutionHomeworkDeadlineAt;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use InvalidArgumentException;
use JsonException;
use stdClass;

abstract class TeacherHomeworkMutationRequest extends FormRequest
{
    protected const COMMON_INPUT_KEYS = [
        'title',
        'description',
        'student_instructions',
        'assignment_mode',
        'student_ids',
        'deadline_at',
    ];

    private bool $rawBodyDecoded = false;

    private mixed $rawBody = null;

    public function authorize(): bool
    {
        return true;
    }

    /** @return list<string> */
    abstract protected function acceptedInputKeys(): array;

    /** @return array<string, list<mixed>> */
    abstract public function rules(): array;

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        $rawBody = $this->rawJsonObject();

        if (! $this->hasApplicationJsonContentType() || ! $rawBody instanceof stdClass) {
            return [];
        }

        /** @var array<string, mixed> $payload */
        $payload = json_decode($this->getContent(), true, flags: JSON_THROW_ON_ERROR);

        foreach (['title', 'student_instructions'] as $field) {
            if (isset($payload[$field]) && is_string($payload[$field])) {
                $payload[$field] = trim($payload[$field]);
            }
        }

        if (isset($payload['questions']) && is_array($payload['questions'])) {
            foreach ($payload['questions'] as $index => $question) {
                if (is_array($question) && isset($question['prompt']) && is_string($question['prompt'])) {
                    $payload['questions'][$index]['prompt'] = trim($question['prompt']);
                }
            }
        }

        return $payload;
    }

    public function withValidator(Validator $validator): void
    {
        $requestKeys = array_keys($this->validationData());
        $acceptedInputKeys = $this->acceptedInputKeys();
        $unknownJsonKeys = array_values(array_diff($requestKeys, $acceptedInputKeys));
        $acceptedJsonKeys = array_values(array_intersect($requestKeys, $acceptedInputKeys));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($unknownJsonKeys, $acceptedJsonKeys, $queryKeys): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            }

            if ($this->requiresAtLeastOneField() && $this->hasJsonObjectBody() && $acceptedJsonKeys === []) {
                $validator->errors()->add('body', 'At least one Homework field is required.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownJsonKeys as $unknownJsonKey) {
                $validator->errors()->add((string) $unknownJsonKey, 'This field is not allowed.');
            }

            $this->validateRawArrayFields($validator);
            $this->validateStudentIdSet($validator);
            $this->validateQuestions($validator);
            $this->validateCreateAssignmentRules($validator);
        });
    }

    protected function commonRules(bool $required): array
    {
        $presence = $required ? 'required' : 'sometimes';

        return [
            'title' => [$presence, 'string', 'min:1', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string', 'max:10000'],
            'student_instructions' => [$presence, 'string', 'min:1', 'max:10000'],
            'assignment_mode' => [$presence, 'string', Rule::in(AssessmentAssignmentMode::values())],
            'student_ids' => [$required ? 'present' : 'sometimes', 'array'],
            'student_ids.*' => ['string', 'uuid'],
            'deadline_at' => ['sometimes', 'nullable', 'string', $this->deadlineSyntaxRule()],
        ];
    }

    protected function requiresAtLeastOneField(): bool
    {
        return false;
    }

    protected function validatesQuestions(): bool
    {
        return false;
    }

    protected function validatesCreateAssignmentRules(): bool
    {
        return false;
    }

    /** @return array<string, mixed> */
    protected function validatedCommonAttributes(): array
    {
        $validated = $this->validated();
        $attributes = [];

        foreach (self::COMMON_INPUT_KEYS as $field) {
            if (array_key_exists($field, $validated)) {
                $attributes[$field] = $validated[$field];
            }
        }

        return $attributes;
    }

    private function deadlineSyntaxRule(): Closure
    {
        return static function (string $attribute, mixed $value, Closure $fail): void {
            if (is_string($value) && ! InstitutionHomeworkDeadlineAt::hasValidSyntax($value)) {
                $fail('The deadline_at must be an RFC 3339 date-time with an explicit numeric offset.');
            }
        };
    }

    private function validateStudentIdSet(Validator $validator): void
    {
        $studentIds = $this->validationData()['student_ids'] ?? null;

        if (! is_array($studentIds) || ! array_is_list($studentIds)) {
            return;
        }

        $normalized = [];

        foreach ($studentIds as $studentId) {
            if (! is_string($studentId)) {
                return;
            }

            $canonical = strtolower($studentId);

            if (isset($normalized[$canonical])) {
                $validator->errors()->add('student_ids', 'The student_ids must not contain duplicates.');

                return;
            }

            $normalized[$canonical] = true;
        }
    }

    private function validateRawArrayFields(Validator $validator): void
    {
        $rawBody = $this->rawJsonObject();

        if (! $rawBody instanceof stdClass) {
            return;
        }

        if (property_exists($rawBody, 'student_ids') && ! is_array($rawBody->student_ids)) {
            $validator->errors()->add('student_ids', 'The student_ids must be a JSON array.');
        }

        if ($this->validatesQuestions()
            && property_exists($rawBody, 'questions')
            && ! is_array($rawBody->questions)) {
            $validator->errors()->add('questions', 'The questions must be a JSON array.');
        }
    }

    private function validateCreateAssignmentRules(Validator $validator): void
    {
        if (! $this->validatesCreateAssignmentRules()) {
            return;
        }

        $payload = $this->validationData();
        $mode = $payload['assignment_mode'] ?? null;
        $studentIds = $payload['student_ids'] ?? null;

        if ($mode === AssessmentAssignmentMode::Group->value && $studentIds !== []) {
            $validator->errors()->add('student_ids', 'Group Homework requires an empty student_ids array.');
        }

        if ($mode === AssessmentAssignmentMode::SelectedStudents->value
            && (! is_array($studentIds) || $studentIds === [])) {
            $validator->errors()->add('student_ids', 'Selected-student Homework requires at least one student ID.');
        }
    }

    private function validateQuestions(Validator $validator): void
    {
        if (! $this->validatesQuestions()) {
            return;
        }

        $rawBody = $this->rawJsonObject();

        if (! $rawBody instanceof stdClass || ! property_exists($rawBody, 'questions')) {
            return;
        }

        if (! is_array($rawBody->questions)) {
            return;
        }

        $positions = [];
        $clientKeys = [];
        $configurationValidator = new QuestionConfigurationValidator;

        foreach ($rawBody->questions as $index => $rawQuestion) {
            $path = 'questions.'.$index;

            if (! $rawQuestion instanceof stdClass || ! $this->hasValidQuestionKeys($rawQuestion)) {
                $validator->errors()->add($path, 'Each Question must be an object with exactly the allowed fields.');

                continue;
            }

            if (! is_string($rawQuestion->client_key)
                || preg_match('/\A[A-Za-z][A-Za-z0-9_-]{0,79}\z/D', $rawQuestion->client_key) !== 1
                || isset($clientKeys[$rawQuestion->client_key])) {
                $validator->errors()->add($path.'.client_key', 'The client_key is invalid or duplicated.');
            } else {
                $clientKeys[$rawQuestion->client_key] = true;
            }

            $type = is_string($rawQuestion->type) ? QuestionType::tryFrom($rawQuestion->type) : null;
            $checkingMode = is_string($rawQuestion->checking_mode)
                ? QuestionCheckingMode::tryFrom($rawQuestion->checking_mode)
                : null;
            $prompt = is_string($rawQuestion->prompt) ? trim($rawQuestion->prompt) : null;

            if (! $type instanceof QuestionType) {
                $validator->errors()->add($path.'.type', 'The Question type is invalid.');
            }

            if (! $checkingMode instanceof QuestionCheckingMode) {
                $validator->errors()->add($path.'.checking_mode', 'The Question checking_mode is invalid.');
            }

            if (! is_string($prompt) || $prompt === '' || mb_strlen($prompt) > QuestionAuthoringLimits::MAX_PROMPT_LENGTH) {
                $validator->errors()->add($path.'.prompt', 'The Question prompt is invalid.');
            }

            $instructions = property_exists($rawQuestion, 'instructions') ? $rawQuestion->instructions : null;

            if ($instructions !== null
                && (! is_string($instructions)
                    || trim($instructions) === ''
                    || mb_strlen($instructions) > QuestionAuthoringLimits::MAX_INSTRUCTIONS_LENGTH)) {
                $validator->errors()->add($path.'.instructions', 'The Question instructions are invalid.');
            }

            if ((! is_int($rawQuestion->points) && ! is_float($rawQuestion->points))
                || ! $this->hasValidPointScale($rawQuestion->points)) {
                $validator->errors()->add($path.'.points', 'The Question points must be a valid JSON number with at most six fractional digits.');
            }

            if (! is_int($rawQuestion->position)) {
                $validator->errors()->add($path.'.position', 'The Question position must be a JSON integer.');
            } else {
                $positions[] = $rawQuestion->position;
            }

            if (! $rawQuestion->configuration instanceof stdClass) {
                $validator->errors()->add($path.'.configuration', 'The Question configuration must be a JSON object.');

                continue;
            }

            if ($this->containsArrayLikeJsonObject($rawQuestion->configuration)) {
                $validator->errors()->add($path.'.configuration', 'JSON arrays and objects must use their required distinct shapes.');

                continue;
            }

            if ($type instanceof QuestionType && $checkingMode instanceof QuestionCheckingMode && is_string($prompt)) {
                /** @var array<string, mixed> $configuration */
                $configuration = json_decode(json_encode($rawQuestion->configuration, JSON_THROW_ON_ERROR), true, flags: JSON_THROW_ON_ERROR);

                try {
                    $configurationValidator->validate($type, $checkingMode, $prompt, $configuration);
                } catch (InvalidArgumentException) {
                    $validator->errors()->add($path.'.configuration', 'The Question configuration is invalid.');
                }
            }
        }

        try {
            (new QuestionPositionSetValidator)->validate(
                $positions,
                QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT,
                allowEmpty: true,
            );
        } catch (InvalidArgumentException) {
            $validator->errors()->add('questions', 'Question positions must be the exact contiguous set 1..N.');
        }
    }

    private function hasValidPointScale(int|float $points): bool
    {
        try {
            AssessmentPointMath::normalize($points);

            return true;
        } catch (InvalidArgumentException) {
            return false;
        }
    }

    private function hasValidQuestionKeys(stdClass $question): bool
    {
        $actualKeys = array_keys(get_object_vars($question));
        $requiredKeys = ['client_key', 'type', 'prompt', 'points', 'position', 'checking_mode', 'configuration'];
        $allowedKeys = [...$requiredKeys, 'instructions'];
        sort($actualKeys);
        sort($allowedKeys);

        return array_diff($actualKeys, $allowedKeys) === []
            && array_diff($requiredKeys, $actualKeys) === [];
    }

    private function containsArrayLikeJsonObject(mixed $value): bool
    {
        if (is_array($value)) {
            foreach ($value as $item) {
                if ($this->containsArrayLikeJsonObject($item)) {
                    return true;
                }
            }

            return false;
        }

        if (! $value instanceof stdClass) {
            return false;
        }

        $properties = get_object_vars($value);
        $keys = array_keys($properties);

        if ($keys !== [] && array_filter($keys, static fn (string|int $key): bool => ! ctype_digit((string) $key)) === []) {
            return true;
        }

        foreach ($properties as $property) {
            if ($this->containsArrayLikeJsonObject($property)) {
                return true;
            }
        }

        return false;
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

    private function rawJsonObject(): mixed
    {
        if ($this->rawBodyDecoded) {
            return $this->rawBody;
        }

        $this->rawBodyDecoded = true;
        $content = trim($this->getContent());

        if ($content === '') {
            return null;
        }

        try {
            return $this->rawBody = json_decode($content, associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return null;
        }
    }
}
