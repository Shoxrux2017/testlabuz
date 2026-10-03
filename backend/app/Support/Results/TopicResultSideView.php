<?php

namespace App\Support\Results;

use App\Enums\TopicResultSideState;

/** One side (Homework or Blitz) of a Topic result as read: its state and, when ready, its official Attempt and score. */
final readonly class TopicResultSideView
{
    public function __construct(
        public TopicResultSideState $state,
        public ?string $assessmentId,
        public ?string $attemptId = null,
        public ?int $attemptNumber = null,
        public ?string $score = null,
    ) {}
}
