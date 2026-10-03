<?php

namespace App\Http\Resources\Teacher;

use App\Models\User;
use App\Support\Results\TeacherTopicResultEntry;
use Illuminate\Http\Request;

/** One Topic result with who wrote the comment, released and closed it (docs/09 §25.6). */
class TeacherTopicResultDetailResource extends TeacherTopicResultResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var TeacherTopicResultEntry $entry */
        $entry = $this->resource;
        $row = $entry->result->row;
        $actor = function (?string $id) use ($entry): ?array {
            if ($id === null) {
                return null;
            }

            $user = $entry->actors[$id] ?? null;

            return $user instanceof User ? ['id' => $user->id, 'full_name' => $user->full_name] : null;
        };

        return [
            ...parent::toArray($request),
            'teacher_comment_updated_at' => self::timestamp($row?->teacher_comment_updated_at),
            'teacher_comment_updated_by' => $actor($row?->teacher_comment_updated_by_user_id),
            'student_released_by' => $actor($row?->student_released_by_user_id),
            'parent_released_by' => $actor($row?->parent_released_by_user_id),
            'closed_by' => $actor($row?->closed_by_user_id),
            'closure_reason' => $row?->closure_reason?->value,
        ];
    }
}
