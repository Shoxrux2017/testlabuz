<?php

namespace App\Http\Resources\Teacher;

use App\Support\Results\TeacherTopicResultEntry;
use App\Support\Results\TopicResultSideView;
use DateTimeImmutable;
use DateTimeInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One Topic result for its Teacher (docs/09 §25.4): the sides, the comparison, the category, the
 * comment and the visibility state. Scores are JSON numbers of the stored 8-decimal values.
 *
 * @mixin TeacherTopicResultEntry
 */
class TeacherTopicResultResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var TeacherTopicResultEntry $entry */
        $entry = $this->resource;
        $result = $entry->result;
        $row = $result->row;

        return [
            'student' => ['id' => $result->student->id, 'full_name' => $result->student->full_name],
            'result_status' => $result->status->value,
            'closed_outcome' => $result->closedOutcome?->value,
            'closed_at' => self::timestamp($row?->closed_at),
            'missing_component' => $result->missingComponent?->value,
            'homework' => self::side($result->homework),
            'blitz' => self::side($result->blitz),
            'score_difference' => self::score($result->difference),
            'acceptable_difference' => self::score($result->threshold),
            'consistency' => $result->consistency?->value,
            'calculation_method' => $result->method?->value,
            'final_score' => self::score($result->finalScore),
            'category_score' => $result->categoryScore,
            'category' => $result->category === null ? null : ['code' => $result->category->value, 'label' => $result->category->label()],
            'teacher_comment' => $row?->teacher_comment,
            'visibility' => [
                'student_release_mode' => $entry->studentMode?->value,
                'student_visible' => $entry->visibility->studentVisible,
                'student_released_at' => self::timestamp($row?->student_released_at),
                'can_release_to_student' => $entry->visibility->canReleaseToStudent,
                'parent_release_mode' => $entry->parentMode?->value,
                'parent_visible' => $entry->visibility->parentVisible,
                'parent_released_at' => self::timestamp($row?->parent_released_at),
                'can_release_to_parent' => $entry->visibility->canReleaseToParent,
            ],
            'can_close' => $result->closable,
        ];
    }

    /** @return array{assessment_id: ?string, state: string, official_attempt_id: ?string, attempt_number: ?int, score: ?float} */
    private static function side(TopicResultSideView $side): array
    {
        return [
            'assessment_id' => $side->assessmentId,
            'state' => $side->state->value,
            'official_attempt_id' => $side->attemptId,
            'attempt_number' => $side->attemptNumber,
            'score' => self::score($side->score),
        ];
    }

    private static function score(?string $value): ?float
    {
        return $value === null ? null : (float) $value;
    }

    protected static function timestamp(?DateTimeInterface $moment): ?string
    {
        return $moment === null ? null : (new DateTimeImmutable('@'.$moment->getTimestamp()))->format('Y-m-d\TH:i:s\Z');
    }
}
