<?php

namespace App\Support\Idempotency;

use App\Models\IdempotencyRecord;

final readonly class IdempotencyClaim
{
    public function __construct(public IdempotencyRecord $record, public bool $new) {}
}
