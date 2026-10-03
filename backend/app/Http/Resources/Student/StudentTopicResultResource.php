<?php

namespace App\Http\Resources\Student;

use App\Enums\TopicResultSideState;
use App\Support\Results\TopicResultReading;
use App\Support\Results\TopicResultSideView;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A Student's Topic result for the Student or a Parent (docs/09 §29.5, §30.5): the status always,
 * every value null unless visible to the reader. Never the consistency, the difference, the
 * threshold or the category score (S10-D2). Scores are JSON numbers of the stored values.
 *
 * @mixin TopicResultReading
 */
class StudentTopicResultResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var TopicResultReading $reading */
        $reading = $this->resource;
        $result = $reading->result;
        $visible = $reading->visible;

        return [
            'topic_id' => $reading->topicId,
            'result_status' => $result->status->value,
            'closed_outcome' => $result->closedOutcome?->value,
            'missing_component' => $result->missingComponent?->value,
            'visible' => $visible,
            'homework_score' => $visible ? self::sideScore($result->homework) : null,
            'blitz_score' => $visible ? self::sideScore($result->blitz) : null,
            'final_score' => $visible && $result->finalScore !== null ? (float) $result->finalScore : null,
            'calculation_method' => $visible ? $result->method?->value : null,
            'category' => $visible && $result->category !== null
                ? ['code' => $result->category->value, 'label' => $result->category->label()]
                : null,
            'teacher_comment' => $visible ? $result->row?->teacher_comment : null,
        ];
    }

    private static function sideScore(TopicResultSideView $side): ?float
    {
        return $side->state === TopicResultSideState::Ready && $side->score !== null ? (float) $side->score : null;
    }
}
