<?php

namespace Tests\Feature\Student\Concerns;

use App\Support\Student\StudentBlitzReadSnapshot;
use Carbon\CarbonImmutable;
use Illuminate\Database\Connection;
use Illuminate\Foundation\Testing\DatabaseTruncation;

trait UsesBlitzReadSnapshot
{
    use DatabaseTruncation;

    protected function setUpUsesBlitzReadSnapshot(): void
    {
        // Committed fixtures let the production reader own a real top-level RR READ ONLY transaction.
        $this->beforeApplicationDestroyed(fn () => $this->truncateDatabaseTables());
        $this->app->instance(StudentBlitzReadSnapshot::class, new class extends StudentBlitzReadSnapshot
        {
            protected function captureSnapshotAt(Connection $connection): CarbonImmutable
            {
                // Freeze only the SQL clock expression; retain the production transaction and first SELECT.
                return CarbonImmutable::parse($connection->selectOne(
                    "SELECT date_trunc('second', CAST(? AS timestamptz)) AS snapshot_at",
                    [now()->format('Y-m-d H:i:s.uP')],
                )->snapshot_at)->utc();
            }
        });
    }
}
