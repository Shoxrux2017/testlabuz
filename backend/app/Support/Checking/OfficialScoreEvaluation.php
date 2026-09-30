<?php

namespace App\Support\Checking;

use App\Enums\OfficialScoreSelectionPolicy;
use App\Models\AssessmentAttempt;

/**
 * The live evaluation of one Student's official task score: the official Attempt when
 * the score is ready, otherwise the Attempts that still hold it back.
 */
final readonly class OfficialScoreEvaluation
{
    /** @param list<AssessmentAttempt> $blocking */
    private function __construct(
        public ?AssessmentAttempt $official,
        public ?OfficialScoreSelectionPolicy $policy,
        public array $blocking,
    ) {}

    public static function ready(AssessmentAttempt $official, OfficialScoreSelectionPolicy $policy): self
    {
        return new self($official, $policy, []);
    }

    /** @param list<AssessmentAttempt> $blocking Ordered by attempt number */
    public static function notReady(array $blocking): self
    {
        return new self(null, null, $blocking);
    }
}
