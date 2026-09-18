<?php

namespace App\Support\Student;

use Carbon\CarbonImmutable;
use Closure;
use Illuminate\Database\Connection;
use Illuminate\Support\Facades\DB;
use LogicException;

class StudentBlitzReadSnapshot
{
    public function read(Closure $read): mixed
    {
        $connection = DB::connection();
        if ($connection->getDriverName() !== 'pgsql' || $connection->transactionLevel() !== 0) {
            throw new LogicException('Student Blitz final reads require a new PostgreSQL snapshot transaction.');
        }

        return $connection->transaction(function () use ($connection, $read): mixed {
            // A prepared SET can establish an early PostgreSQL snapshot before the clock SELECT.
            $connection->unprepared('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY');
            // The first SELECT establishes the snapshot and its one authoritative clock instant.
            $snapshotAt = $this->captureSnapshotAt($connection);

            return $read($snapshotAt);
        });
    }

    protected function captureSnapshotAt(Connection $connection): CarbonImmutable
    {
        return CarbonImmutable::parse($connection->selectOne(
            "SELECT date_trunc('second', clock_timestamp()) AS snapshot_at",
        )->snapshot_at)->utc();
    }
}
