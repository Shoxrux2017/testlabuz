<?php

namespace App\Console\Commands;

use App\Actions\Checking\CheckDueFrozenAttempts;
use Illuminate\Console\Command;

class CheckFrozenAttempts extends Command
{
    protected $signature = 'attempts:check-frozen';

    protected $description = 'Check every frozen Attempt that automatic checking has not reached yet';

    public function handle(CheckDueFrozenAttempts $check): int
    {
        $counts = $check();
        $this->info("Candidates: {$counts['candidates']}; checked attempts: {$counts['checked_attempts']}; failures: {$counts['failures']}.");

        return $counts['failures'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
