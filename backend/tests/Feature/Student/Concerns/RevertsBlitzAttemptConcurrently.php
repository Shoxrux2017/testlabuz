<?php

namespace Tests\Feature\Student\Concerns;

use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use Illuminate\Support\Facades\DB;

/**
 * Forces the "impossible" no-progress condition for read-path progress guards: a separate,
 * autocommitting connection puts a just-finalized Attempt back to in_progress before the next
 * snapshot is established. Requires committed fixtures (DatabaseTruncation).
 */
trait RevertsBlitzAttemptConcurrently
{
    protected function revertAttemptToInProgressConcurrently(AssessmentAttempt $attempt): void
    {
        config(['database.connections.pgsql_concurrent_revert' => config('database.connections.pgsql')]);
        try {
            DB::connection('pgsql_concurrent_revert')->table('assessment_attempts')->where('id', $attempt->id)->update([
                'status' => AssessmentAttemptStatus::InProgress->value,
                'submitted_at' => null,
                'finalized_at' => null,
                'locked_at' => null,
                'finalization_reason' => null,
            ]);
        } finally {
            DB::purge('pgsql_concurrent_revert');
        }
    }
}
