<?php

namespace App\Http\Resources\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use LogicException;

/** @mixin Assessment */
class StudentHomeworkResource extends StudentHomeworkSummaryResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $summary = parent::toArray($request);
        $questions = $this->relationLoaded('questions') ? $this->getRelation('questions') : null;

        if (! $questions instanceof Collection) {
            throw new LogicException('Student Homework detail requires preloaded Questions.');
        }

        $summary['attempts']['in_progress_attempt'] = $this->getAttribute('student_attempt_summary')['in_progress_attempt'];

        return [
            'id' => $summary['id'],
            'topic' => $summary['topic'],
            'title' => $summary['title'],
            'description' => $this->description,
            'student_instructions' => $this->student_instructions,
            'status' => $summary['status'],
            'deadline_at' => $summary['deadline_at'],
            'total_possible_points' => (float) $this->total_possible_points,
            'attempts' => $summary['attempts'],
            'my_status' => $summary['my_status'],
            'score_visible' => $summary['score_visible'],
            'official_score' => $summary['official_score'],
            'attempt_results' => $this->attemptResults(),
            'questions' => StudentQuestionResource::collection($questions),
        ];
    }

    /** @return list<array<string, mixed>> Every terminal Attempt in attempt-number order */
    private function attemptResults(): array
    {
        return $this->getRelation('attempts')
            ->reject(fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::InProgress)
            ->sortBy('attempt_number')
            ->map(fn (AssessmentAttempt $attempt): array => [
                'attempt_id' => $attempt->id,
                'attempt_number' => $attempt->attempt_number,
                'status' => $attempt->status->value,
                'result' => $attempt->getAttribute('student_result')
                    ?? throw new LogicException('Student Homework Attempts require their result projection.'),
            ])
            ->values()
            ->all();
    }
}
