<?php

namespace App\Http\Requests\Platform;

use App\Actions\Platform\ListPlatformInstitutionAdmins;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class PlatformInstitutionAdminIndexRequest extends FormRequest
{
    private const SEARCH_MAX_LENGTH = 254;

    private const ACCEPTED_QUERY_KEYS = [
        'search',
        'status',
        'page',
        'per_page',
        'sort',
        'direction',
    ];

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
            'status' => ['sometimes', 'string', Rule::in([self::STATUS_ACTIVE, self::STATUS_INACTIVE])],
            'page' => ['sometimes', 'integer', 'min:'.ListPlatformInstitutionAdmins::DEFAULT_PAGE],
            'per_page' => [
                'sometimes',
                'integer',
                'min:1',
                'max:'.ListPlatformInstitutionAdmins::MAX_PER_PAGE,
            ],
            'sort' => ['sometimes', 'string', Rule::in(ListPlatformInstitutionAdmins::allowedSorts())],
            'direction' => ['sometimes', 'string', Rule::in(ListPlatformInstitutionAdmins::allowedDirections())],
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
        return (string) $this->validated('sort', ListPlatformInstitutionAdmins::DEFAULT_SORT);
    }

    public function direction(): string
    {
        return (string) $this->validated('direction', ListPlatformInstitutionAdmins::DEFAULT_DIRECTION);
    }

    public function page(): int
    {
        return (int) $this->validated('page', ListPlatformInstitutionAdmins::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListPlatformInstitutionAdmins::DEFAULT_PER_PAGE);
    }
}
