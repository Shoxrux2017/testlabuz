<?php

namespace App\Actions\Institution;

use App\Models\User;
use Illuminate\Support\Collection;

final readonly class GroupMembershipAssignmentResult
{
    /**
     * @param  Collection<int, User>  $members
     */
    public function __construct(
        public Collection $members,
        public int $createdCount,
    ) {}
}
