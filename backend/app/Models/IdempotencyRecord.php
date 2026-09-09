<?php

namespace App\Models;

use App\Enums\IdempotencyOperation;
use Database\Factories\IdempotencyRecordFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'user_id',
    'operation',
    'idempotency_key',
    'request_fingerprint',
    'result_resource_type',
    'result_resource_id',
    'response_status',
    'completed_at',
])]
class IdempotencyRecord extends Model
{
    /** @use HasFactory<IdempotencyRecordFactory> */
    use HasFactory, HasUuids;

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'operation' => IdempotencyOperation::class,
            'response_status' => 'integer',
            'completed_at' => 'datetime',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
