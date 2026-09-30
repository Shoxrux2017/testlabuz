<?php

namespace App\Console\Commands;

use App\Actions\Checking\CheckDueFrozenAttempts;
use App\Actions\Checking\RepairOfficialTaskScores;
use Illuminate\Console\Command;

class CheckFrozenAttempts extends Command
{
    protected $signature = 'attempts:check-frozen';

    protected $description = 'Check every frozen Attempt that automatic checking has not reached yet and repair stale official scores';

    public function handle(CheckDueFrozenAttempts $check, RepairOfficialTaskScores $repair): int
    {
        $checks = $check();
        $this->info("Candidates: {$checks['candidates']}; checked attempts: {$checks['checked_attempts']}; failures: {$checks['failures']}.");
        $repairs = $repair();
        $this->info("Official scores repaired: {$repairs['repaired']}; failures: {$repairs['failures']}.");

        return $checks['failures'] === 0 && $repairs['failures'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
