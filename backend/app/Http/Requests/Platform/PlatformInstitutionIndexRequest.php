<?php

namespace App\Http\Requests\Platform;

use App\Actions\Platform\ListPlatformInstitutions;
use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class PlatformInstitutionIndexRequest extends FormRequest
{
    private const SEARCH_MAX_LENGTH = 200;

    private const ACCEPTED_QUERY_KEYS = [
        'search',
        'status',
        'type',
        'page',
        'per_page',
        'sort',
        'direction',
    ];

    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $search = $this->query('search');

        if (is_string($search)) {
            $this->merge([
                'search' => trim($search),
            ]);
        }
    }

    /**
     * @return array<string, list<mixed>>
     */
    public function rules(): array
    {
        return [
            'search' => ['sometimes', 'nullable', 'string', 'max:'.self::SEARCH_MAX_LENGTH],
            'status' => ['sometimes', 'string', Rule::in(InstitutionStatus::values())],
            'type' => ['sometimes', 'string', Rule::in(InstitutionType::values())],
            'page' => ['sometimes', 'integer', 'min:'.ListPlatformInstitutions::DEFAULT_PAGE],
            'per_page' => [
                'sometimes',
                'integer',
                'min:1',
                'max:'.ListPlatformInstitutions::MAX_PER_PAGE,
            ],
            'sort' => ['sometimes', 'string', Rule::in(ListPlatformInstitutions::allowedSorts())],
            'direction' => ['sometimes', 'string', Rule::in(ListPlatformInstitutions::allowedDirections())],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownKeys = array_values(array_diff(array_keys($this->query()), self::ACCEPTED_QUERY_KEYS));

        $validator->after(function (Validator $validator) use ($unknownKeys): void {
            foreach ($unknownKeys as $unknownKey) {
                $validator->errors()->add($unknownKey, 'This query parameter is not allowed.');
            }
        });
    }

    public function search(): ?string
    {
        $search = $this->validated('search');

        return is_string($search) && $search !== '' ? $search : null;
    }

    public function status(): ?InstitutionStatus
    {
        $status = $this->validated('status');

        return is_string($status) ? InstitutionStatus::from($status) : null;
    }

    public function type(): ?InstitutionType
    {
        $type = $this->validated('type');

        return is_string($type) ? InstitutionType::from($type) : null;
    }

    public function sort(): string
    {
        return (string) $this->validated('sort', ListPlatformInstitutions::DEFAULT_SORT);
    }

    public function direction(): string
    {
        return (string) $this->validated('direction', ListPlatformInstitutions::DEFAULT_DIRECTION);
    }

    public function page(): int
    {
        return (int) $this->validated('page', ListPlatformInstitutions::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListPlatformInstitutions::DEFAULT_PER_PAGE);
    }
}
