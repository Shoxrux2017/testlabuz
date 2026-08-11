<?php

namespace App\Http\Resources\Platform;

use App\Models\Institution;
use App\Support\Platform\InstitutionUserCounts;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Institution
 */
abstract class PlatformInstitutionResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    protected function platformFields(bool $includeDetailFields): array
    {
        $fields = [
            'id' => $this->id,
            'name' => $this->name,
            'type' => $this->type->value,
            'status' => $this->status->value,
            'contact_email' => $this->contact_email,
            'contact_phone' => $this->contact_phone,
        ];

        if ($includeDetailFields) {
            $fields['address'] = $this->address;
            $fields['description'] = $this->description;
        }

        return array_merge($fields, [
            'created_at' => $this->timestamp($this->created_at),
            'updated_at' => $this->timestamp($this->updated_at),
            'user_counts' => [
                'total' => (int) $this->resource->getAttribute(InstitutionUserCounts::TOTAL_ATTRIBUTE),
                'active' => (int) $this->resource->getAttribute(InstitutionUserCounts::ACTIVE_ATTRIBUTE),
            ],
        ]);
    }

    protected function timestamp(?DateTimeInterface $timestamp): ?string
    {
        if ($timestamp === null) {
            return null;
        }

        return (new DateTimeImmutable('@'.$timestamp->getTimestamp()))
            ->setTimezone(new DateTimeZone('UTC'))
            ->format('Y-m-d\TH:i:s\Z');
    }
}
