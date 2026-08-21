<?php

namespace App\Actions\Institution;

use App\Enums\GroupStatus;
use App\Models\Group;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class CreateInstitutionGroup
{
    /**
     * @param  array{name: string, level: ?string, subject_direction: ?string, description: ?string}  $attributes
     */
    public function __invoke(User $actor, array $attributes): Group
    {
        $group = DB::transaction(fn (): Group => Group::query()->create([
            ...$attributes,
            'institution_id' => $actor->institution_id,
            'status' => GroupStatus::Active,
            'created_by_user_id' => $actor->getKey(),
            'archived_at' => null,
        ])->refresh());

        $group->setAttribute('teachers_count', 0);
        $group->setAttribute('students_count', 0);

        return $group;
    }
}
