<?php

namespace App\Support\Idempotency;

use App\Enums\IdempotencyOperation;
use App\Exceptions\Student\IdempotencyKeyReusedException;
use App\Models\IdempotencyRecord;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;

final class IdempotencyGuard
{
    public function completedReplay(User $actor, IdempotencyOperation $operation, string $key, string $fingerprint): ?IdempotencyRecord
    {
        $this->requireTransaction();
        $record = $this->scopedQuery($actor, $operation, $key)->lockForUpdate()->first();

        if ($record !== null) {
            $this->assertCompletedReplay($record, $fingerprint);
        }

        return $record;
    }

    public function claim(User $actor, IdempotencyOperation $operation, string $key, string $fingerprint): IdempotencyClaim
    {
        $this->requireTransaction();
        $claimedAt = now();
        $inserted = IdempotencyRecord::query()->insertOrIgnore([
            'id' => (string) Str::uuid(),
            'institution_id' => $actor->institution_id,
            'user_id' => $actor->id,
            'operation' => $operation->value,
            'idempotency_key' => strtolower($key),
            'request_fingerprint' => $fingerprint,
            'created_at' => $claimedAt,
            'updated_at' => $claimedAt,
        ]);
        $record = $this->scopedQuery($actor, $operation, $key)->lockForUpdate()->first();

        if ($record === null) {
            throw new LogicException('The idempotency claim must exist in its transaction.');
        }

        if ($inserted === 0) {
            $this->assertCompletedReplay($record, $fingerprint);
        }

        return new IdempotencyClaim($record, $inserted === 1);
    }

    public function complete(IdempotencyClaim $claim, string $resourceType, string $resourceId, int $responseStatus): void
    {
        $this->requireNewIncompleteClaim($claim);

        if ($responseStatus < 200 || $responseStatus > 299) {
            throw new LogicException('Idempotency completion requires a successful response status.');
        }

        $claim->record->fill([
            'result_resource_type' => $resourceType,
            'result_resource_id' => $resourceId,
            'response_status' => $responseStatus,
            'completed_at' => now(),
        ])->save();
    }

    public function abandon(IdempotencyClaim $claim): void
    {
        $this->requireNewIncompleteClaim($claim);
        $claim->record->delete();
    }

    private function requireTransaction(): void
    {
        if (DB::transactionLevel() < 1) {
            throw new LogicException('Idempotency operations require an active transaction.');
        }
    }

    private function requireNewIncompleteClaim(IdempotencyClaim $claim): void
    {
        $this->requireTransaction();

        if (! $claim->new || ! $claim->record->exists || $claim->record->completed_at !== null) {
            throw new LogicException('Only a new incomplete idempotency claim may be changed.');
        }
    }

    private function assertCompletedReplay(IdempotencyRecord $record, string $fingerprint): void
    {
        if ($record->request_fingerprint !== $fingerprint) {
            throw new IdempotencyKeyReusedException;
        }

        if ($record->completed_at === null) {
            throw new LogicException('A persisted idempotency record must be complete.');
        }
    }

    /** @return Builder<IdempotencyRecord> */
    private function scopedQuery(User $actor, IdempotencyOperation $operation, string $key): Builder
    {
        return IdempotencyRecord::query()
            ->where('institution_id', $actor->institution_id)
            ->where('user_id', $actor->id)
            ->where('operation', $operation->value)
            ->where('idempotency_key', strtolower($key));
    }
}
