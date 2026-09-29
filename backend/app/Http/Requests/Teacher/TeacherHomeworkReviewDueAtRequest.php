<?php

namespace App\Http\Requests\Teacher;

/**
 * Strict body for the Homework review deadline: exactly the key `review_due_at`,
 * a numeric-offset RFC 3339 string or null, and no query parameters.
 */
class TeacherHomeworkReviewDueAtRequest extends TeacherHomeworkMutationRequest
{
    /** @return list<string> */
    protected function acceptedInputKeys(): array
    {
        return ['review_due_at'];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'review_due_at' => ['present', 'nullable', 'string', $this->dateTimeSyntaxRule('review_due_at')],
        ];
    }

    public function reviewDueAt(): ?string
    {
        return $this->validated()['review_due_at'];
    }
}
