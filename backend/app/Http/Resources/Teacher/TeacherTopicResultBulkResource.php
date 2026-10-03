<?php

namespace App\Http\Resources\Teacher;

use App\Support\Results\TopicResultBulkOutcome;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** The counts of a bulk Teacher result action (docs/09 §27.5). */
class TeacherTopicResultBulkResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        /** @var TopicResultBulkOutcome $outcome */
        $outcome = $this->resource;

        return [
            'processed' => $outcome->processed,
            'skipped' => [
                'already_done' => $outcome->alreadyDone,
                'not_ready' => $outcome->notReady,
            ],
        ];
    }
}
