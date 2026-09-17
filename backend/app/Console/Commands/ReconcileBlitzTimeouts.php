<?php

namespace App\Console\Commands;

use App\Actions\Blitz\ReconcileDueBlitzTimeouts;
use Illuminate\Console\Command;

class ReconcileBlitzTimeouts extends Command
{
    protected $signature = 'blitz:reconcile-timeouts';

    protected $description = 'Reconcile due Blitz Attempts using server-authoritative deadlines';

    public function handle(ReconcileDueBlitzTimeouts $reconcile): int
    {
        $counts = $reconcile();
        $this->info("Candidates: {$counts['candidates']}; finalized attempts: {$counts['finalized_attempts']}; failures: {$counts['failures']}.");

        return $counts['failures'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
