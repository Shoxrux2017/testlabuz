<?php

namespace App\Domain\Results;

use App\Enums\TopicResultSideState;
use LogicException;

/** One side (Homework or Blitz) of a Topic result: its state and, only when ready, its official score. */
final class TopicResultSide
{
    public function __construct(
        public readonly TopicResultSideState $state,
        public readonly ?string $score = null,
    ) {
        if (($state === TopicResultSideState::Ready) !== ($score !== null)) {
            throw new LogicException('A Topic result side has an official score exactly when it is ready.');
        }
    }
}
