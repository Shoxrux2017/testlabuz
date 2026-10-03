<?php

namespace Tests\Feature\Results\Concerns;

use App\Support\Student\StudentBlitzReadSnapshot;
use Closure;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Facades\DB;

/**
 * Proves that a request reads its Topic results inside exactly one `StudentBlitzReadSnapshot` read: every
 * query of the Topic result reader (its first statement selects from `topic_result_pairs`) must run inside
 * that read. The probe delegates to the snapshot already bound by the test, so its frozen clock stays.
 */
trait AssertsTopicResultSnapshotReads
{
    protected function assertResultReadsInOneSnapshot(Closure $request): void
    {
        $snapshot = new class($this->app->make(StudentBlitzReadSnapshot::class)) extends StudentBlitzReadSnapshot
        {
            public int $reads = 0;

            public bool $reading = false;

            public function __construct(private readonly StudentBlitzReadSnapshot $bound) {}

            public function read(Closure $read): mixed
            {
                $this->reads++;
                $this->reading = true;
                try {
                    return $this->bound->read($read);
                } finally {
                    $this->reading = false;
                }
            }
        };
        $this->app->instance(StudentBlitzReadSnapshot::class, $snapshot);
        $readerQueries = ['inside' => 0, 'outside' => 0];
        DB::listen(function (QueryExecuted $query) use ($snapshot, &$readerQueries): void {
            // Only a statement whose own FROM is the pairs table; access checks use it in subqueries.
            if (preg_match('/^select [^()]* from "topic_result_pairs"/', $query->sql) === 1) {
                $readerQueries[$snapshot->reading ? 'inside' : 'outside']++;
            }
        });

        $request();

        $this->assertSame(1, $snapshot->reads, 'The request must read in exactly one snapshot.');
        $this->assertGreaterThan(0, $readerQueries['inside'], 'The Topic result reader did not run inside the snapshot.');
        $this->assertSame(0, $readerQueries['outside'], 'The Topic result reader ran outside the snapshot.');
    }
}
