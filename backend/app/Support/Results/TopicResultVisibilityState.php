<?php

namespace App\Support\Results;

/** Who sees a Topic result's values now and which Teacher release would change state now. */
final readonly class TopicResultVisibilityState
{
    public function __construct(
        public bool $studentVisible,
        public bool $parentVisible,
        public bool $canReleaseToStudent,
        public bool $canReleaseToParent,
    ) {}
}
