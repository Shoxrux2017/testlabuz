<?php

namespace App\Support\Results;

/** The counts a bulk Teacher result action reports (docs/09 §27.5). */
final readonly class TopicResultBulkOutcome
{
    public function __construct(
        public int $processed,
        public int $alreadyDone,
        public int $notReady,
    ) {}

    /** @param list<TopicResultActionOutcome> $outcomes */
    public static function of(array $outcomes): self
    {
        $count = fn (TopicResultActionOutcome $outcome): int => count(array_filter(
            $outcomes,
            fn (TopicResultActionOutcome $each): bool => $each === $outcome,
        ));

        return new self(
            $count(TopicResultActionOutcome::Done),
            $count(TopicResultActionOutcome::AlreadyDone),
            $count(TopicResultActionOutcome::NotReady),
        );
    }
}
