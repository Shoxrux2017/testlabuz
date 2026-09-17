<?php

namespace App\Http\Resources\Teacher;

use App\Enums\AssessmentType;
use App\Models\Assessment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Assessment */
class TeacherAssessmentAuthoringResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $resource = match ($this->type) {
            AssessmentType::Homework => new TeacherHomeworkResource($this->resource),
            AssessmentType::Blitz => new TeacherBlitzResource($this->resource),
            default => throw new LogicException('Unsupported Assessment authoring resource type.'),
        };

        return $resource->toArray($request);
    }
}
