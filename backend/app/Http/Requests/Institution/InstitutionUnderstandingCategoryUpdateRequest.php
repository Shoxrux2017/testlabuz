<?php

namespace App\Http\Requests\Institution;

use App\Domain\Institution\UnderstandingCategorySetValidator;
use App\Enums\UnderstandingCategoryCode;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use InvalidArgumentException;
use JsonException;
use LogicException;
use stdClass;

class InstitutionUnderstandingCategoryUpdateRequest extends FormRequest
{
    private const ROOT_KEYS = ['categories'];

    private const ITEM_KEYS = ['code', 'min_score', 'max_score', 'sort_order'];

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

        try {
            $decoded = json_decode($this->getContent(), associative: true, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return [];
        }

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * @return array<string, list<mixed>>
     */
    public function rules(): array
    {
        return [
            'categories' => ['required', 'array', 'size:5'],
            'categories.*' => ['required', 'array'],
            'categories.*.code' => ['required', 'string', Rule::in(UnderstandingCategoryCode::values())],
            'categories.*.min_score' => ['present'],
            'categories.*.max_score' => ['present'],
            'categories.*.sort_order' => ['required', 'integer:strict', 'between:1,5'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $rawJsonObject = $this->rawJsonObject();
        $rootKeys = $rawJsonObject instanceof stdClass ? array_keys((array) $rawJsonObject) : [];
        $unknownRootKeys = array_values(array_diff($rootKeys, self::ROOT_KEYS));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use (
            $rawJsonObject,
            $unknownRootKeys,
            $queryKeys,
        ): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownRootKeys as $unknownRootKey) {
                $validator->errors()->add((string) $unknownRootKey, 'This field is not allowed.');
            }

            if (! $rawJsonObject instanceof stdClass
                || ! property_exists($rawJsonObject, 'categories')
                || ! is_array($rawJsonObject->categories)) {
                return;
            }

            foreach ($rawJsonObject->categories as $index => $rawEntry) {
                if (! $rawEntry instanceof stdClass) {
                    $validator->errors()->add("categories.{$index}", 'Each category must be a JSON object.');

                    continue;
                }

                foreach (array_diff(array_keys((array) $rawEntry), self::ITEM_KEYS) as $unknownItemKey) {
                    $validator->errors()->add(
                        "categories.{$index}.{$unknownItemKey}",
                        'This field is not allowed.',
                    );
                }

                $codeValue = property_exists($rawEntry, 'code') ? $rawEntry->code : null;
                $code = is_string($codeValue) ? UnderstandingCategoryCode::tryFrom($codeValue) : null;

                if ($code === null) {
                    continue;
                }

                $sortOrder = property_exists($rawEntry, 'sort_order') ? $rawEntry->sort_order : null;

                if (is_int($sortOrder) && $sortOrder !== $code->sortOrder()) {
                    $validator->errors()->add(
                        "categories.{$index}.sort_order",
                        'The sort order does not match the category code.',
                    );
                }

                foreach (['min_score', 'max_score'] as $scoreField) {
                    if (! property_exists($rawEntry, $scoreField)) {
                        continue;
                    }

                    $score = $rawEntry->{$scoreField};

                    if ($code->isNumeric()) {
                        if (! is_int($score) || $score < 0 || $score > 100) {
                            $validator->errors()->add(
                                "categories.{$index}.{$scoreField}",
                                'Numeric category scores must be JSON integers between 0 and 100.',
                            );
                        }
                    } elseif ($score !== null) {
                        $validator->errors()->add(
                            "categories.{$index}.{$scoreField}",
                            'Not completed scores must be null.',
                        );
                    }
                }
            }

            if ($validator->errors()->isNotEmpty()) {
                return;
            }

            try {
                app(UnderstandingCategorySetValidator::class)->validate($this->normalizedCategories());
            } catch (InvalidArgumentException) {
                $validator->errors()->add(
                    'categories',
                    'The categories must form one complete non-overlapping 0 through 100 partition.',
                );
            }
        });
    }

    /**
     * @return list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>
     */
    public function categories(): array
    {
        try {
            return app(UnderstandingCategorySetValidator::class)->validate($this->normalizedCategories());
        } catch (InvalidArgumentException $exception) {
            throw new LogicException('Validated understanding categories are unavailable.', previous: $exception);
        }
    }

    /**
     * @return list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>
     */
    private function normalizedCategories(): array
    {
        $categories = $this->validationData()['categories'] ?? null;

        if (! is_array($categories)) {
            return [];
        }

        return array_values(array_map(
            static fn (array $category): array => [
                'code' => $category['code'],
                'min_score' => $category['min_score'],
                'max_score' => $category['max_score'],
                'sort_order' => $category['sort_order'],
            ],
            $categories,
        ));
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
}
