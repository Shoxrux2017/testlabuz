<?php

namespace App\Http\Resources\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Models\Group;
use App\Models\HomeworkAssignment;
use App\Models\Topic;
use App\Models\User;
use DateTimeImmutable;
use DateTimeInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/**
 * One Teacher review queue item (docs/09 §21.1).
 *
 * @mixin AssessmentAttempt
 */
class TeacherSubmissionResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $assessment = $this->relationLoaded('assessment') ? $this->getRelation('assessment') : null;
        $topic = $assessment?->relationLoaded('topic') ? $assessment->getRelation('topic') : null;
        $group = $topic?->relationLoaded('group') ? $topic->getRelation('group') : null;
        $student = $this->relationLoaded('student') ? $this->getRelation('student') : null;

        if (! $topic instanceof Topic || ! $group instanceof Group || ! $student instanceof User
            || $this->getAttribute('waiting_answers_count') === null || $this->getAttribute('submission_official') === null) {
            throw new LogicException('Teacher submission resources require the review projection.');
        }

        $homework = $assessment->getRelation('homeworkAssignment');
        $checked = $this->status === AssessmentAttemptStatus::Checked;

        if ($checked && ($this->earned_points === null || $this->normalized_score === null)) {
            throw new LogicException('A checked submission has no score.');
        }

        return [
            'id' => $this->id,
            'assessment' => ['id' => $assessment->id, 'type' => $assessment->type->value, 'title' => $assessment->title],
            'official' => (bool) $this->getAttribute('submission_official'),
            'topic' => ['id' => $topic->id, 'title' => $topic->title],
            'group' => ['id' => $group->id, 'name' => $group->name],
            'student' => ['id' => $student->id, 'full_name' => $student->full_name],
            'attempt_number' => $this->attempt_number,
            'status' => $this->status->value,
            'official_score_eligible' => $this->official_score_eligible,
            'finalization_reason' => $this->finalization_reason?->value,
            'finalized_at' => self::timestamp($this->finalized_at),
            'review' => [
                'waiting_answers' => (int) $this->getAttribute('waiting_answers_count'),
                'reviewed_answers' => (int) $this->getAttribute('reviewed_answers_count'),
            ],
            'review_due_at' => $homework instanceof HomeworkAssignment ? self::timestamp($homework->review_due_at) : null,
            'review_overdue' => (bool) $this->getAttribute('submission_overdue'),
            'score' => [
                'earned_points' => $checked ? (float) $this->earned_points : null,
                'possible_points' => (float) $this->possible_points,
                'normalized_score' => $checked ? (float) $this->normalized_score : null,
            ],
        ];
    }

    public static function timestamp(?DateTimeInterface $timestamp): ?string
    {
        return $timestamp === null ? null
            : (new DateTimeImmutable('@'.$timestamp->getTimestamp()))->format('Y-m-d\TH:i:s\Z');
    }
}
