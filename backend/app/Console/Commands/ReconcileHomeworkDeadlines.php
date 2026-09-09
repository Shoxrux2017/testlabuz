<?php

namespace App\Console\Commands;

use App\Actions\Homework\ReconcileDueHomeworkDeadlines;
use Illuminate\Console\Command;

class ReconcileHomeworkDeadlines extends Command
{
    protected $signature = 'homework:reconcile-deadlines';

    protected $description = 'Reconcile due Homework Attempts using server-authoritative deadlines';

    public function handle(ReconcileDueHomeworkDeadlines $reconcile): int
    {
        $counts = $reconcile();
        $this->info("Candidates: {$counts['candidates']}; finalized attempts: {$counts['finalized_attempts']}; failures: {$counts['failures']}.");

        return $counts['failures'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
