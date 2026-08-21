<?php

namespace App\Http\Requests\Institution;

use App\Actions\Institution\ListInstitutionParentStudents;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class InstitutionParentStudentsIndexRequest extends FormRequest
{
    private const ACCEPTED_QUERY_KEYS = [
        'search',
        'status',
        'page',
        'per_page',
        'sort',
        'direction',
    ];

    private const SEARCH_MAX_LENGTH = 254;

    private const STATUS_ACTIVE = 'active';

    private const STATUS_INACTIVE = 'inactive';

    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $search = $this->query('search');

        if (is_string($search)) {
            $this->query->set('search', trim($search));
        }
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return $this->query->all();
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'search' => ['sometimes', 'nullable', 'string', 'max:'.self::SEARCH_MAX_LENGTH],
            'status' => ['sometimes', 'string', Rule::in([self::STATUS_ACTIVE, self::STATUS_INACTIVE])],
            'page' => ['sometimes', 'integer', 'min:'.ListInstitutionParentStudents::DEFAULT_PAGE],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.ListInstitutionParentStudents::MAX_PER_PAGE],
            'sort' => ['sometimes', 'string', Rule::in(ListInstitutionParentStudents::allowedSorts())],
            'direction' => ['sometimes', 'string', Rule::in(ListInstitutionParentStudents::allowedDirections())],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownKeys = array_values(array_diff(array_keys($this->query()), self::ACCEPTED_QUERY_KEYS));
        $hasRequestBody = $this->getContent() !== '';

        $validator->after(function (Validator $validator) use ($unknownKeys, $hasRequestBody): void {
            if ($hasRequestBody) {
                $validator->errors()->add('body', 'The request body is not allowed for this endpoint.');
            }

            foreach ($unknownKeys as $unknownKey) {
                $validator->errors()->add((string) $unknownKey, 'This query parameter is not allowed.');
            }
        });
    }

    public function search(): ?string
    {
        $search = $this->validated('search');

        return is_string($search) && $search !== '' ? $search : null;
    }

    public function status(): ?bool
    {
        return match ($this->validated('status')) {
            self::STATUS_ACTIVE => true,
            self::STATUS_INACTIVE => false,
            default => null,
        };
    }

    public function sort(): string
    {
        return (string) $this->validated('sort', ListInstitutionParentStudents::DEFAULT_SORT);
    }

    public function direction(): string
    {
        return (string) $this->validated('direction', ListInstitutionParentStudents::DEFAULT_DIRECTION);
    }

    public function page(): int
    {
        return (int) $this->validated('page', ListInstitutionParentStudents::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListInstitutionParentStudents::DEFAULT_PER_PAGE);
    }
}
