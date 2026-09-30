<?php

namespace App\Support\Checking;

use App\Enums\OfficialScoreStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\OfficialTaskScore;
use LogicException;

/**
 * One Student's official task score as read now: its status and, only when ready, the
 * persisted row and the official Attempt.
 */
final readonly class OfficialScoreReading
{
    private function __construct(
        public Assessment $assessment,
        public AssessmentStudent $recipient,
        public OfficialScoreStatus $status,
        public ?OfficialTaskScore $score,
        public ?AssessmentAttempt $attempt,
    ) {}

    public static function ready(Assessment $assessment, AssessmentStudent $recipient, OfficialTaskScore $score, AssessmentAttempt $attempt): self
    {
        return new self($assessment, $recipient, OfficialScoreStatus::Ready, $score, $attempt);
    }

    public static function notReady(Assessment $assessment, AssessmentStudent $recipient, OfficialScoreStatus $status): self
    {
        if ($status === OfficialScoreStatus::Ready) {
            throw new LogicException('A ready official score needs its row and Attempt.');
        }

        return new self($assessment, $recipient, $status, null, null);
    }
}
