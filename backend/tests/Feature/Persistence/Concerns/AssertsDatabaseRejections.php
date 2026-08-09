<?php

namespace Tests\Feature\Persistence\Concerns;

use Closure;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

trait AssertsDatabaseRejections
{
    protected function assertDatabaseRejects(Closure $operation): void
    {
        try {
            DB::transaction(fn () => $operation());
        } catch (QueryException) {
            $this->addToAssertionCount(1);

            return;
        }

        $this->fail('Expected PostgreSQL to reject the database operation.');
    }
}
