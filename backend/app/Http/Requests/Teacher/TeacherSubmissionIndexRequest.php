<?php

namespace App\Http\Requests\Teacher;

use App\Actions\Teacher\ListTeacherSubmissions;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class TeacherSubmissionIndexRequest extends FormRequest
{
    private const ID_FILTERS = ['assessment_id', 'topic_id', 'group_id', 'student_id'];

    private const ACCEPTED_QUERY_KEYS = [...self::ID_FILTERS, 'checking_status', 'type', 'official', 'overdue',
        'sort', 'direction', 'page', 'per_page'];

    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return $this->query->all();
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return array_fill_keys(self::ID_FILTERS, ['sometimes', 'string', 'uuid']) + [
            'checking_status' => ['sometimes', 'string', Rule::in(ListTeacherSubmissions::CHECKING_STATUSES)],
            'type' => ['sometimes', 'string', Rule::in(['homework', 'blitz'])],
            'official' => ['sometimes', 'string', Rule::in(['true', 'false'])],
            'overdue' => ['sometimes', 'string', Rule::in(['true'])],
            'sort' => ['sometimes', 'string', Rule::in(ListTeacherSubmissions::SORTS)],
            'direction' => ['sometimes', 'string', Rule::in(ListTeacherSubmissions::DIRECTIONS)],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.ListTeacherSubmissions::MAX_PER_PAGE],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownKeys = array_values(array_diff(array_keys($this->query->all()), self::ACCEPTED_QUERY_KEYS));
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

    /** @return array{assessment_id?: string, topic_id?: string, group_id?: string, student_id?: string, checking_status?: string, type?: string, official?: bool, overdue?: bool} */
    public function filters(): array
    {
        $validated = $this->validated();
        $filters = array_intersect_key($validated, array_flip([...self::ID_FILTERS, 'checking_status', 'type']));

        foreach (self::ID_FILTERS as $key) {
            if (isset($filters[$key])) {
                $filters[$key] = strtolower($filters[$key]);
            }
        }

        if (isset($validated['official'])) {
            $filters['official'] = $validated['official'] === 'true';
        }

        if (isset($validated['overdue'])) {
            $filters['overdue'] = true;
        }

        return $filters;
    }

    public function sort(): string
    {
        return (string) $this->validated('sort', ListTeacherSubmissions::DEFAULT_SORT);
    }

    public function direction(): string
    {
        return (string) $this->validated('direction', ListTeacherSubmissions::DEFAULT_DIRECTION);
    }

    public function page(): int
    {
        return (int) $this->validated('page', ListTeacherSubmissions::DEFAULT_PAGE);
    }

    public function perPage(): int
    {
        return (int) $this->validated('per_page', ListTeacherSubmissions::DEFAULT_PER_PAGE);
    }
}
