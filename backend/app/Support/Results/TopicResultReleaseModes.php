<?php

namespace App\Support\Results;

use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Models\InstitutionSetting;

/** An Institution's current Student and Parent result release modes; null is unconfigured (docs/09 §27). */
final readonly class TopicResultReleaseModes
{
    public function __construct(
        public ?StudentResultReleaseMode $student,
        public ?ParentResultReleaseMode $parent,
    ) {}

    public static function current(string $institutionId): self
    {
        $settings = InstitutionSetting::query()
            ->select(['institution_id', 'student_result_release_mode', 'parent_result_release_mode'])
            ->where('institution_id', $institutionId)
            ->first();

        return new self($settings?->student_result_release_mode, $settings?->parent_result_release_mode);
    }
}
