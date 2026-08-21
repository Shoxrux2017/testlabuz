<?php

namespace App\Http\Requests\Institution;

use App\Actions\Institution\ListInstitutionGroups;
use App\Enums\GroupStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class InstitutionGroupIndexRequest extends FormRequest
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

    /**
     * @return array<string, mixed>
     */
    public function validationData(): array
    {
        return $this->query->all();
    }

    /**
     * @return array<string, list<mixed>>
     */
    public function rules(): array
    {
        return [
            'search' => ['sometimes', 'nullable', 'string', 'max:'.self::SEARCH_MAX_LENGTH],
            'status' => ['sometimes', 'string', Rule::in(GroupStatus::values())],
            'page' => ['sometimes', 'integer', 'min:'.ListInstitutionGroups::DEFAULT_PAGE],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.ListInstitutionGroups::MAX_PER_PAGE],
            'sort' => ['sometimes', 'string', Rule::in(ListInstitutionGroups::allowedSorts())],
            'direction' => ['sometimes', 'string', Rule::in(ListInstitutionGroups::allowedDirections())],
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

    public function status(): ?GroupStatus
    {
        $status = $this->validated('status');

        return is_string($status) ? GroupStatus::from($status) : null;
    }

    public function sort(): string
    {
        return (string) $this->validated('sort', ListInstitutionGroups::DEFAULT_SORT);
    }

    public function direction(): string
    {
        return (string) $this->validated('direction', ListInstitutionGroups::DEFAULT_DIRECTION);
    }

    public function page(): int
    {
        return (int) $this->validated('page', ListInstitutionGroups::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListInstitutionGroups::DEFAULT_PER_PAGE);
    }
}
