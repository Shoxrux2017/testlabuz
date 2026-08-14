<?php

namespace App\Actions\Institution;

use App\Domain\Institution\UnderstandingCategorySetValidator;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use RuntimeException;

class ListInstitutionUnderstandingCategories
{
    public function __construct(
        private readonly UnderstandingCategorySetValidator $validator,
    ) {}

    /**
     * @return Collection<int, InstitutionUnderstandingCategory>
     */
    public function __invoke(User $actor): Collection
    {
        $institutionId = $actor->institution_id;

        if ($institutionId === null) {
            throw new RuntimeException;
        }

        $settingsExist = InstitutionSetting::query()
            ->where('institution_id', $institutionId)
            ->exists();

        if (! $settingsExist) {
            throw new RuntimeException;
        }

        $categories = InstitutionUnderstandingCategory::query()
            ->where('institution_id', $institutionId)
            ->orderBy('sort_order')
            ->get();

        if ($categories->isEmpty()) {
            return $categories;
        }

        if ($categories->count() !== 5) {
            throw new RuntimeException;
        }

        $canonical = $this->validator->validate($this->normalizedEntries($categories));
        $categoriesByCode = $categories->keyBy(
            fn (InstitutionUnderstandingCategory $category): string => $category->code->value,
        );

        return new Collection(array_map(
            fn (array $entry): InstitutionUnderstandingCategory => $categoriesByCode
                ->get($entry['code']) ?? throw new RuntimeException,
            $canonical,
        ));
    }

    /**
     * @param  Collection<int, InstitutionUnderstandingCategory>  $categories
     * @return list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>
     */
    private function normalizedEntries(Collection $categories): array
    {
        return $categories->map(
            fn (InstitutionUnderstandingCategory $category): array => [
                'code' => $category->code->value,
                'min_score' => $category->min_score,
                'max_score' => $category->max_score,
                'sort_order' => $category->sort_order,
            ],
        )->all();
    }
}
