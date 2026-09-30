<?php

namespace App\Support\Checking;

use App\Actions\Checking\CheckFrozenAttempt;
use Illuminate\Contracts\Foundation\Application;
use Throwable;

/**
 * Collects the Attempts a request or command froze and checks them after the freeze
 * commits: at the end of an HTTP request (after the response) or when a console
 * reconciler drains it. Not a queued job: with the sync queue it would run inside the
 * freeze response.
 */
final class FrozenAttemptCheckQueue
{
    /** @var array<string, true> */
    private array $attemptIds = [];

    private bool $drainsOnTerminate = false;

    public function __construct(
        private readonly Application $app,
        private readonly CheckFrozenAttempt $checkFrozenAttempt,
    ) {}

    public function add(string $attemptId): void
    {
        $this->attemptIds[$attemptId] = true;

        if (! $this->drainsOnTerminate) {
            // Laravel keeps terminating callbacks for the application's lifetime, so one
            // registration per instance drains whatever is recorded at each termination.
            $this->drainsOnTerminate = true;
            $this->app->terminating(fn () => $this->drain());
        }
    }

    public function drain(): void
    {
        while ($this->attemptIds !== []) {
            $attemptIds = array_keys($this->attemptIds);
            $this->attemptIds = [];

            foreach ($attemptIds as $attemptId) {
                try {
                    ($this->checkFrozenAttempt)($attemptId);
                } catch (Throwable $exception) {
                    // Checking never alters the freeze or its response; the sweep retries.
                    report($exception);
                }
            }
        }
    }
}
