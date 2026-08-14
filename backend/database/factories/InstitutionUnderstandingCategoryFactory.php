<?php

namespace Database\Factories;

use App\Enums\UnderstandingCategoryCode;
use App\Models\Institution;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<InstitutionUnderstandingCategory>
 */
class InstitutionUnderstandingCategoryFactory extends Factory
{
    public function definition(): array
    {
        return [
            'updated_by_user_id' => User::factory()->institutionAdmin(),
            'institution_id' => fn (array $attributes): string => (string) User::query()
                ->findOrFail($attributes['updated_by_user_id'])
                ->institution_id,
            'code' => UnderstandingCategoryCode::UnderstoodWell,
            'min_score' => 86,
            'max_score' => 100,
            'sort_order' => UnderstandingCategoryCode::UnderstoodWell->sortOrder(),
        ];
    }

    public function forInstitution(
        Institution $institution,
        User $updater,
    ): static {
        return $this->state(fn (array $attributes): array => [
            'institution_id' => $institution->getKey(),
            'updated_by_user_id' => $updater->getKey(),
        ]);
    }

    public function forCode(
        UnderstandingCategoryCode $code,
        ?int $minScore,
        ?int $maxScore,
    ): static {
        return $this->state(fn (array $attributes): array => [
            'code' => $code,
            'min_score' => $minScore,
            'max_score' => $maxScore,
            'sort_order' => $code->sortOrder(),
        ]);
    }
}
