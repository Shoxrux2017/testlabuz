<?php

namespace App\Support\Platform;

use App\Models\Institution;
use Illuminate\Database\Eloquent\Builder;

final class InstitutionUserCounts
{
    public const TOTAL_ATTRIBUTE = 'user_counts_total';

    public const ACTIVE_ATTRIBUTE = 'user_counts_active';

    public static function addToQuery(Builder $query): Builder
    {
        return $query->withCount(self::countDefinitions());
    }

    public static function loadFor(Institution $institution): Institution
    {
        $institution->loadCount(self::countDefinitions());

        return $institution;
    }

    /**
     * @return array<int|string, string|\Closure(Builder): Builder>
     */
    private static function countDefinitions(): array
    {
        return [
            'users as '.self::TOTAL_ATTRIBUTE,
            'users as '.self::ACTIVE_ATTRIBUTE => fn (Builder $query): Builder => $query->where('is_active', true),
        ];
    }
}
