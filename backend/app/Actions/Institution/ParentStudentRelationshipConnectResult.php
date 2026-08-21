<?php

namespace App\Actions\Institution;

use App\Models\ParentStudentRelationship;

final readonly class ParentStudentRelationshipConnectResult
{
    public function __construct(
        public ParentStudentRelationship $relationship,
        public bool $created,
    ) {}
}
