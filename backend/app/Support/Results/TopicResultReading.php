<?php

namespace App\Support\Results;

/** A Student's Topic result as the Student or a Parent reads it: the status always, the values only when visible to that reader. */
final readonly class TopicResultReading
{
    public function __construct(
        public string $topicId,
        public TopicResultView $result,
        public bool $visible,
    ) {}
}
