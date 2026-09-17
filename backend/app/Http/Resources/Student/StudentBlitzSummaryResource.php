<?php

namespace App\Http\Resources\Student;

use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\Topic;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Assessment */
class StudentBlitzSummaryResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $topic = $this->relationLoaded('topic') ? $this->getRelation('topic') : null;
        $blitz = $this->relationLoaded('blitzTask') ? $this->getRelation('blitzTask') : null;
        $timing = $this->getAttribute('student_blitz_timing');
        $attempts = $this->getAttribute('student_blitz_attempt_summary');

        if (! $topic instanceof Topic || ! $blitz instanceof BlitzTask || ! is_array($timing) || ! is_array($attempts)) {
            throw new LogicException('Student Blitz resources require preloaded read projections.');
        }

        return [
            'id' => $this->id,
            'topic' => ['id' => $topic->id, 'title' => $topic->title],
            'title' => $this->title,
            'status' => $blitz->status->value,
            'duration_seconds' => $blitz->duration_seconds,
            'timing' => $timing,
            'attempts' => $attempts,
        ];
    }
}
