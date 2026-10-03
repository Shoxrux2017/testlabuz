<?php

namespace App\Support\Results;

use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Models\User;

/** One Topic result as the Teacher sees it: the live or closed result, its visibility now and, for the detail, its actors. */
final readonly class TeacherTopicResultEntry
{
    /** @param array<string, User> $actors The comment, release and closure actors by id (detail only) */
    public function __construct(
        public TopicResultView $result,
        public TopicResultVisibilityState $visibility,
        public ?StudentResultReleaseMode $studentMode,
        public ?ParentResultReleaseMode $parentMode,
        public array $actors = [],
    ) {}
}
