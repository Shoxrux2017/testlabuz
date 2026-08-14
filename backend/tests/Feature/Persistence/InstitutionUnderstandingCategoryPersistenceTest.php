<?php

namespace Tests\Feature\Persistence;

use App\Enums\UnderstandingCategoryCode;
use App\Models\Institution;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\Feature\Persistence\Concerns\AssertsDatabaseRejections;
use Tests\TestCase;

class InstitutionUnderstandingCategoryPersistenceTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    public function test_schema_has_exact_columns_types_nullability_and_named_constraints(): void
    {
        $expectedColumns = [
            'id' => ['uuid', 'NO'],
            'institution_id' => ['uuid', 'NO'],
            'code' => ['character varying', 'NO'],
            'min_score' => ['smallint', 'YES'],
            'max_score' => ['smallint', 'YES'],
            'sort_order' => ['smallint', 'NO'],
            'updated_by_user_id' => ['uuid', 'NO'],
            'created_at' => ['timestamp with time zone', 'NO'],
            'updated_at' => ['timestamp with time zone', 'NO'],
        ];
        $columns = collect(DB::select(<<<'SQL'
            select column_name, data_type, is_nullable, character_maximum_length
            from information_schema.columns
            where table_schema = 'public'
              and table_name = 'institution_understanding_categories'
            order by ordinal_position
            SQL))->keyBy('column_name');

        $this->assertSame(array_keys($expectedColumns), $columns->keys()->all());

        foreach ($expectedColumns as $column => [$type, $nullable]) {
            $this->assertSame($type, $columns[$column]->data_type, $column);
            $this->assertSame($nullable, $columns[$column]->is_nullable, $column);
        }

        $this->assertSame(40, (int) $columns['code']->character_maximum_length);

        foreach ([
            'institution_understanding_categories_pkey' => 'p',
            'institution_categories_institution_code_unique' => 'u',
            'institution_categories_institution_id_foreign' => 'f',
            'institution_categories_updated_by_user_id_foreign' => 'f',
            'institution_categories_code_check' => 'c',
            'institution_categories_sort_order_check' => 'c',
            'institution_categories_range_shape_check' => 'c',
        ] as $constraintName => $constraintType) {
            $constraint = DB::selectOne(
                'select contype, confdeltype from pg_constraint where conname = ?',
                [$constraintName],
            );
            $this->assertNotNull($constraint, $constraintName);
            $this->assertSame($constraintType, $constraint->contype, $constraintName);

            if ($constraintType === 'f') {
                $this->assertSame('r', $constraint->confdeltype, $constraintName);
            }
        }
    }

    public function test_database_constraints_accept_fixed_rows_and_reject_every_invalid_row_shape(): void
    {
        $institution = Institution::factory()->create();
        $updater = User::factory()->institutionAdmin($institution)->create();

        foreach ($this->validSet() as $entry) {
            InstitutionUnderstandingCategory::factory()
                ->forInstitution($institution, $updater)
                ->forCode(
                    UnderstandingCategoryCode::from($entry['code']),
                    $entry['min_score'],
                    $entry['max_score'],
                )->create();
        }

        $this->assertSame(5, InstitutionUnderstandingCategory::query()
            ->where('institution_id', $institution->id)
            ->count());

        $invalidRows = [
            ['code' => 'unknown'],
            ['code' => 'understood_well', 'sort_order' => 2],
            ['code' => 'partially_understood', 'min_score' => null],
            ['code' => 'needs_revision', 'max_score' => null],
            ['code' => 'needs_teacher_support', 'min_score' => -1],
            ['code' => 'understood_well', 'max_score' => 101],
            ['code' => 'partially_understood', 'min_score' => 90, 'max_score' => 80],
            ['code' => 'not_completed', 'min_score' => 0],
            ['code' => 'not_completed', 'max_score' => 0],
        ];

        foreach ($invalidRows as $invalidRow) {
            $invalidInstitution = Institution::factory()->create();
            $invalidUpdater = User::factory()->institutionAdmin($invalidInstitution)->create();
            $this->assertDatabaseRejects(fn () => DB::table('institution_understanding_categories')->insert(
                $this->rowPayload($invalidInstitution->id, $invalidUpdater->id, array_merge([
                    'code' => 'understood_well',
                    'min_score' => 86,
                    'max_score' => 100,
                    'sort_order' => 1,
                ], $invalidRow, ['id' => Str::uuid()->toString()])),
            ));
        }
    }

    public function test_unique_foreign_keys_restrict_deletion_and_allow_same_code_for_two_institutions(): void
    {
        $firstInstitution = Institution::factory()->create();
        $secondInstitution = Institution::factory()->create();
        $firstUpdater = User::factory()->institutionAdmin($firstInstitution)->create();
        $secondUpdater = User::factory()->institutionAdmin($secondInstitution)->create();

        $first = InstitutionUnderstandingCategory::factory()
            ->forInstitution($firstInstitution, $firstUpdater)
            ->create();
        InstitutionUnderstandingCategory::factory()
            ->forInstitution($secondInstitution, $secondUpdater)
            ->create();

        $this->assertSame(2, InstitutionUnderstandingCategory::query()
            ->where('code', UnderstandingCategoryCode::UnderstoodWell)
            ->count());

        $this->assertDatabaseRejects(fn () => InstitutionUnderstandingCategory::factory()
            ->forInstitution($firstInstitution, $firstUpdater)
            ->create());
        $this->assertDatabaseRejects(fn () => DB::table('institution_understanding_categories')->insert(
            $this->rowPayload(Str::uuid()->toString(), $firstUpdater->id),
        ));
        $this->assertDatabaseRejects(fn () => DB::table('institution_understanding_categories')->insert(
            $this->rowPayload($firstInstitution->id, Str::uuid()->toString()),
        ));
        $this->assertDatabaseRejects(fn () => $firstInstitution->delete());
        $this->assertDatabaseRejects(fn () => $firstUpdater->delete());

        $this->assertTrue($first->fresh()->exists);
    }

    public function test_model_factory_uuid_casts_fillable_and_relations_are_focused(): void
    {
        $defaultCategory = InstitutionUnderstandingCategory::factory()->create();
        $institution = Institution::factory()->create();
        $updater = User::factory()->institutionAdmin($institution)->create();
        $category = InstitutionUnderstandingCategory::factory()
            ->forInstitution($institution, $updater)
            ->forCode(UnderstandingCategoryCode::NeedsRevision, 51, 70)
            ->create();

        $this->assertTrue(Str::isUuid($category->id));
        $this->assertSame(UnderstandingCategoryCode::NeedsRevision, $category->code);
        $this->assertSame(51, $category->min_score);
        $this->assertSame(70, $category->max_score);
        $this->assertSame(3, $category->sort_order);
        $this->assertTrue($institution->is($category->institution));
        $this->assertTrue($updater->is($category->updater));
        $this->assertSame($defaultCategory->institution_id, $defaultCategory->updater->institution_id);
        $this->assertSame([
            'institution_id',
            'code',
            'min_score',
            'max_score',
            'sort_order',
            'updated_by_user_id',
        ], $category->getFillable());
        $this->assertNotContains('id', $category->getFillable());
        $this->assertNotContains('created_at', $category->getFillable());
        $this->assertNotContains('updated_at', $category->getFillable());
    }

    public function test_migration_rollback_removes_only_new_table_and_remigrate_restores_it(): void
    {
        $institution = Institution::factory()->create();
        $updater = User::factory()->institutionAdmin($institution)->create();
        $migration = require database_path(
            'migrations/2026_08_14_000000_create_institution_understanding_categories_table.php',
        );

        $migration->down();

        $this->assertFalse(Schema::hasTable('institution_understanding_categories'));
        $this->assertTrue(Schema::hasTable('institutions'));
        $this->assertTrue(Schema::hasTable('users'));
        $this->assertTrue(Schema::hasTable('institution_settings'));
        $this->assertDatabaseHas('institutions', ['id' => $institution->id]);
        $this->assertDatabaseHas('users', ['id' => $updater->id]);

        $migration->up();

        $this->assertTrue(Schema::hasTable('institution_understanding_categories'));
        InstitutionUnderstandingCategory::factory()
            ->forInstitution($institution, $updater)
            ->create();
        $this->assertDatabaseCount('institution_understanding_categories', 1);
    }

    /**
     * @return list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>
     */
    private function validSet(): array
    {
        return [
            ['code' => 'understood_well', 'min_score' => 86, 'max_score' => 100, 'sort_order' => 1],
            ['code' => 'partially_understood', 'min_score' => 71, 'max_score' => 85, 'sort_order' => 2],
            ['code' => 'needs_revision', 'min_score' => 51, 'max_score' => 70, 'sort_order' => 3],
            ['code' => 'needs_teacher_support', 'min_score' => 0, 'max_score' => 50, 'sort_order' => 4],
            ['code' => 'not_completed', 'min_score' => null, 'max_score' => null, 'sort_order' => 5],
        ];
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function rowPayload(string $institutionId, string $updaterId, array $overrides = []): array
    {
        return array_merge([
            'id' => Str::uuid()->toString(),
            'institution_id' => $institutionId,
            'code' => 'understood_well',
            'min_score' => 86,
            'max_score' => 100,
            'sort_order' => 1,
            'updated_by_user_id' => $updaterId,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }
}
