<?php

namespace App\Http\Resources\Teacher;

use App\Models\File;
use App\Models\LearningMaterial;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin LearningMaterial */
class TeacherLearningMaterialResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $file = $this->relationLoaded('file') ? $this->getRelation('file') : null;

        if (! $file instanceof File) {
            throw new LogicException('Teacher Learning Material resources require a preloaded File projection.');
        }

        return [
            'id' => $this->id,
            'topic_id' => $this->topic_id,
            'title' => $this->title,
            'file' => [
                'id' => $file->id,
                'original_name' => $file->original_name,
                'mime_type' => $file->mime_type,
                'extension' => $file->extension->value,
                'size_bytes' => $file->size_bytes,
            ],
            'created_at' => $this->timestamp($this->created_at),
            'updated_at' => $this->timestamp($this->updated_at),
        ];
    }

    private function timestamp(DateTimeInterface $timestamp): string
    {
        return (new DateTimeImmutable('@'.$timestamp->getTimestamp()))
            ->setTimezone(new DateTimeZone('UTC'))
            ->format('Y-m-d\TH:i:s\Z');
    }
}
