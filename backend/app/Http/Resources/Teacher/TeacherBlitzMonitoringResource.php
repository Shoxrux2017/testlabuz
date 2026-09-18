<?php

namespace App\Http\Resources\Teacher;

use App\Support\Teacher\TeacherBlitzMonitoring;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin TeacherBlitzMonitoring */
class TeacherBlitzMonitoringResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'blitz' => $this->resource->blitz,
            'summary' => $this->resource->summary,
            'students' => $this->resource->students,
        ];
    }
}
