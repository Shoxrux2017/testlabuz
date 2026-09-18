<?php

namespace App\Support\Teacher;

final readonly class TeacherBlitzMonitoring
{
    /**
     * @param  array<string, mixed>  $blitz
     * @param  array<string, int>  $summary
     * @param  list<array<string, mixed>>  $students  Fully materialized scalar-only rows.
     */
    public function __construct(
        public array $blitz,
        public array $summary,
        public array $students,
    ) {}
}
