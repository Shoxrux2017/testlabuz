<?php

namespace App\Http\Requests\Institution;

use App\Actions\Platform\CreatePlatformInstitution;
use App\Enums\BlitzTimerStartMode;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use JsonException;
use LogicException;
use stdClass;

class InstitutionAssessmentSettingsUpdateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = [
        'acceptable_score_difference',
        'blitz_timer_start_mode',
        'student_result_release_mode',
        'parent_result_release_mode',
        'timezone',
        'learning_material_max_mb',
        'student_submission_max_mb',
    ];

    private const TIMEZONE_MAX_LENGTH = 64;

    private const MAXIMUM_SCORE_DECIMAL_PLACES = 8;

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function validationData(): array
    {
        $rawJsonObject = $this->rawJsonObject();

        if (! $this->hasApplicationJsonContentType() || ! $rawJsonObject instanceof stdClass) {
            return [];
        }

        return (array) $rawJsonObject;
    }

    /**
     * @return array<string, list<mixed>>
     */
    public function rules(): array
    {
        return [
            'acceptable_score_difference' => ['required', 'numeric:strict', 'min:0', 'max:100'],
            'blitz_timer_start_mode' => ['required', 'string', Rule::in(BlitzTimerStartMode::values())],
            'student_result_release_mode' => ['required', 'string', Rule::in(StudentResultReleaseMode::values())],
            'parent_result_release_mode' => ['required', 'string', Rule::in(ParentResultReleaseMode::values())],
            'timezone' => ['required', 'string', 'max:'.self::TIMEZONE_MAX_LENGTH, 'timezone'],
            'learning_material_max_mb' => [
                'required',
                'integer:strict',
                'between:1,'.CreatePlatformInstitution::DEFAULT_LEARNING_MATERIAL_MAX_MB,
            ],
            'student_submission_max_mb' => [
                'required',
                'integer:strict',
                'between:1,'.CreatePlatformInstitution::DEFAULT_STUDENT_SUBMISSION_MAX_MB,
            ],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownJsonKeys = array_values(array_diff(array_keys($this->validationData()), self::ACCEPTED_INPUT_KEYS));
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

            $scoreDifference = $this->rawJsonObject()?->acceptable_score_difference ?? null;

            if ((is_int($scoreDifference) || is_float($scoreDifference)) && ! $this->scoreDifferenceHasValidScale()) {
                $validator->errors()->add(
                    'acceptable_score_difference',
                    'The acceptable score difference may have at most 8 decimal places.',
                );
            }
        });
    }

    public function acceptableScoreDifference(): string
    {
        $literal = $this->scoreDifferenceLiteral();

        if ($literal === null) {
            throw new LogicException('Validated score difference is unavailable.');
        }

        return $this->normalizeJsonNumber($literal);
    }

    public function blitzTimerStartMode(): BlitzTimerStartMode
    {
        return BlitzTimerStartMode::from((string) $this->validated('blitz_timer_start_mode'));
    }

    public function studentResultReleaseMode(): StudentResultReleaseMode
    {
        return StudentResultReleaseMode::from((string) $this->validated('student_result_release_mode'));
    }

    public function parentResultReleaseMode(): ParentResultReleaseMode
    {
        return ParentResultReleaseMode::from((string) $this->validated('parent_result_release_mode'));
    }

    public function timezone(): string
    {
        return (string) $this->validated('timezone');
    }

    public function learningMaterialMaxMb(): int
    {
        return (int) $this->validated('learning_material_max_mb');
    }

    public function studentSubmissionMaxMb(): int
    {
        return (int) $this->validated('student_submission_max_mb');
    }

    private function hasJsonObjectBody(): bool
    {
        return $this->hasApplicationJsonContentType() && $this->rawJsonObject() instanceof stdClass;
    }

    private function hasApplicationJsonContentType(): bool
    {
        $parts = array_map('trim', explode(';', strtolower(trim((string) $this->headers->get('CONTENT_TYPE')))));

        if (array_shift($parts) !== 'application/json') {
            return false;
        }

        if ($parts === []) {
            return true;
        }

        return count($parts) === 1
            && preg_match('/^charset\s*=\s*(?:"[^"]+"|[^\s]+)$/', $parts[0]) === 1;
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

    private function scoreDifferenceHasValidScale(): bool
    {
        $literal = $this->scoreDifferenceLiteral();

        if ($literal === null || preg_match(
            '/^-?(?<integer>0|[1-9]\d*)(?:\.(?<fraction>\d+))?(?:[eE](?<exponent>[+-]?\d+))?$/',
            $literal,
            $matches,
        ) !== 1) {
            return false;
        }

        $fractionLength = strlen($matches['fraction'] ?? '');
        $exponent = (int) ($matches['exponent'] ?? 0);

        return max(0, $fractionLength - $exponent) <= self::MAXIMUM_SCORE_DECIMAL_PLACES;
    }

    private function scoreDifferenceLiteral(): ?string
    {
        if (preg_match(
            '/"acceptable_score_difference"\s*:\s*(?<number>-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)(?=\s*[,}])/',
            $this->getContent(),
            $matches,
        ) !== 1) {
            return null;
        }

        return $matches['number'];
    }

    private function normalizeJsonNumber(string $literal): string
    {
        preg_match(
            '/^(?<sign>-?)(?<integer>0|[1-9]\d*)(?:\.(?<fraction>\d+))?(?:[eE](?<exponent>[+-]?\d+))?$/',
            $literal,
            $matches,
        );

        $sign = $matches['sign'] ?? '';
        $integer = $matches['integer'] ?? '0';
        $fraction = $matches['fraction'] ?? '';
        $exponent = (int) ($matches['exponent'] ?? 0);
        $digits = $integer.$fraction;
        $decimalPosition = strlen($integer) + $exponent;

        if ($decimalPosition <= 0) {
            $normalized = '0.'.str_repeat('0', -$decimalPosition).$digits;
        } elseif ($decimalPosition >= strlen($digits)) {
            $normalized = $digits.str_repeat('0', $decimalPosition - strlen($digits));
        } else {
            $normalized = substr($digits, 0, $decimalPosition).'.'.substr($digits, $decimalPosition);
        }

        $normalized = ltrim($normalized, '0');

        if ($normalized === '' || str_starts_with($normalized, '.')) {
            $normalized = '0'.$normalized;
        }

        return $sign.$normalized;
    }
}
