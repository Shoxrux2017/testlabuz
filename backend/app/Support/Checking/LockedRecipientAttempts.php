<?php

namespace App\Support\Checking;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use Illuminate\Database\Eloquent\Collection;

/** One Student's scoring graph of one task, locked by RecipientScoringLock. */
final readonly class LockedRecipientAttempts
{
    /** @param Collection<int, AssessmentAttempt> $attempts Ordered by id */
    public function __construct(
        public Assessment $assessment,
        public AssessmentStudent $recipient,
        public Collection $attempts,
    ) {}
}
