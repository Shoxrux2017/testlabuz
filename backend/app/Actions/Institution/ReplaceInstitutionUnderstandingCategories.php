<?php

namespace App\Actions\Institution;

use App\Domain\Institution\UnderstandingCategorySetValidator;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

class ReplaceInstitutionUnderstandingCategories
{
    public function __construct(
        private readonly UnderstandingCategorySetValidator $validator,
    ) {}

    /**
     * @param  list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>  $categories
     * @return Collection<int, InstitutionUnderstandingCategory>
     */
    public function __invoke(User $actor, array $categories): Collection
    {
        $institutionId = $actor->institution_id;

        if ($institutionId === null) {
            throw new RuntimeException;
        }

        return DB::transaction(function () use ($actor, $categories, $institutionId): Collection {
            $settings = InstitutionSetting::query()
                ->where('institution_id', $institutionId)
                ->lockForUpdate()
                ->first();

            if (! $settings instanceof InstitutionSetting) {
                throw new RuntimeException;
            }

            $existing = InstitutionUnderstandingCategory::query()
                ->where('institution_id', $institutionId)
                ->orderBy('sort_order')
                ->get();

            $this->requireValidStoredState($existing);
            $canonicalIncoming = $this->validator->validate($categories);

            if ($existing->isEmpty()) {
                $this->insertFirstConfiguration(
                    institutionId: $institutionId,
                    actorId: (string) $actor->getKey(),
                    categories: $canonicalIncoming,
                );
            } elseif (! $this->isExactNoOp($existing, $canonicalIncoming, (string) $actor->getKey())) {
                $this->replaceConfiguration(
                    existing: $existing,
                    institutionId: $institutionId,
                    actorId: (string) $actor->getKey(),
                    categories: $canonicalIncoming,
                );
            }

            $committed = InstitutionUnderstandingCategory::query()
                ->where('institution_id', $institutionId)
                ->orderBy('sort_order')
                ->get();

            $this->requireValidStoredState($committed, allowEmpty: false);

            return $committed;
        });
    }

    /**
     * @param  Collection<int, InstitutionUnderstandingCategory>  $categories
     */
    private function requireValidStoredState(Collection $categories, bool $allowEmpty = true): void
    {
        if ($allowEmpty && $categories->isEmpty()) {
            return;
        }

        if ($categories->count() !== 5) {
            throw new RuntimeException;
        }

        $this->validator->validate($this->normalizedEntries($categories));
    }

    /**
     * @param  list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>  $categories
     */
    private function insertFirstConfiguration(string $institutionId, string $actorId, array $categories): void
    {
        $timestamp = now();
        $rows = array_map(
            fn (array $category): array => [
                'id' => Str::uuid()->toString(),
                'institution_id' => $institutionId,
                ...$category,
                'updated_by_user_id' => $actorId,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ],
            $categories,
        );

        DB::table('institution_understanding_categories')->insert($rows);
    }

    /**
     * @param  Collection<int, InstitutionUnderstandingCategory>  $existing
     * @param  list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>  $categories
     */
    private function replaceConfiguration(
        Collection $existing,
        string $institutionId,
        string $actorId,
        array $categories,
    ): void {
        $timestamp = now();
        $existingByCode = $existing->keyBy(
            fn (InstitutionUnderstandingCategory $category): string => $category->code->value,
        );
        $rows = array_map(function (array $category) use (
            $actorId,
            $existingByCode,
            $institutionId,
            $timestamp,
        ): array {
            $stored = $existingByCode->get($category['code']);

            if (! $stored instanceof InstitutionUnderstandingCategory) {
                throw new RuntimeException;
            }

            return [
                'id' => $stored->getKey(),
                'institution_id' => $institutionId,
                ...$category,
                'updated_by_user_id' => $actorId,
                'created_at' => $stored->getRawOriginal('created_at'),
                'updated_at' => $timestamp,
            ];
        }, $categories);

        DB::table('institution_understanding_categories')->upsert(
            $rows,
            ['institution_id', 'code'],
            ['min_score', 'max_score', 'sort_order', 'updated_by_user_id', 'updated_at'],
        );
    }

    /**
     * @param  Collection<int, InstitutionUnderstandingCategory>  $existing
     * @param  list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>  $categories
     */
    private function isExactNoOp(Collection $existing, array $categories, string $actorId): bool
    {
        $existingByCode = $existing->keyBy(
            fn (InstitutionUnderstandingCategory $category): string => $category->code->value,
        );

        foreach ($categories as $category) {
            $stored = $existingByCode->get($category['code']);

            if (! $stored instanceof InstitutionUnderstandingCategory
                || $stored->min_score !== $category['min_score']
                || $stored->max_score !== $category['max_score']
                || $stored->sort_order !== $category['sort_order']
                || $stored->updated_by_user_id !== $actorId) {
                return false;
            }
        }

        return true;
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
