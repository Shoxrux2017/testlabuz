<?php

namespace Tests\Feature\Persistence;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class IdentitySchemaInspectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_identity_primary_keys_and_timestamps_use_locked_postgresql_types(): void
    {
        $this->assertColumnType('institutions', 'id', 'uuid');
        $this->assertColumnType('users', 'id', 'uuid');
        $this->assertColumnType('institution_settings', 'institution_id', 'uuid');
        $this->assertColumnType('personal_access_tokens', 'tokenable_id', 'uuid');

        foreach ([
            ['institutions', 'created_at'],
            ['institutions', 'updated_at'],
            ['institutions', 'deactivated_at'],
            ['users', 'created_at'],
            ['users', 'updated_at'],
            ['users', 'last_login_at'],
            ['users', 'deactivated_at'],
            ['institution_settings', 'created_at'],
            ['institution_settings', 'updated_at'],
            ['personal_access_tokens', 'created_at'],
            ['personal_access_tokens', 'updated_at'],
            ['personal_access_tokens', 'last_used_at'],
            ['personal_access_tokens', 'expires_at'],
        ] as [$table, $column]) {
            $this->assertColumnType($table, $column, 'timestamp with time zone');
        }

        foreach ([
            ['institutions', 'created_at'],
            ['institutions', 'updated_at'],
            ['users', 'created_at'],
            ['users', 'updated_at'],
            ['institution_settings', 'created_at'],
            ['institution_settings', 'updated_at'],
        ] as [$table, $column]) {
            $this->assertColumnNullability($table, $column, 'NO');
        }

        foreach ([
            ['institutions', 'deactivated_at'],
            ['users', 'last_login_at'],
            ['users', 'deactivated_at'],
        ] as [$table, $column]) {
            $this->assertColumnNullability($table, $column, 'YES');
        }

        $scoreDifference = $this->column('institution_settings', 'acceptable_score_difference');

        $this->assertSame('numeric', $scoreDifference->data_type);
        $this->assertSame(12, (int) $scoreDifference->numeric_precision);
        $this->assertSame(8, (int) $scoreDifference->numeric_scale);
    }

    public function test_required_identity_constraints_and_indexes_exist(): void
    {
        foreach ([
            'institutions_name_not_empty_check',
            'institutions_type_check',
            'institutions_status_check',
            'users_role_check',
            'users_role_institution_check',
            'institution_settings_score_difference_check',
            'institution_settings_blitz_timer_mode_check',
            'institution_settings_student_release_mode_check',
            'institution_settings_parent_release_mode_check',
            'institution_settings_learning_material_limit_check',
            'institution_settings_student_submission_limit_check',
            'institution_settings_timezone_not_empty_check',
        ] as $constraint) {
            $this->assertConstraintExists($constraint);
        }

        foreach ([
            'users_institution_id_foreign',
            'institution_settings_institution_id_foreign',
            'institution_settings_updated_by_user_id_foreign',
            'institutions_created_by_user_id_foreign',
        ] as $constraint) {
            $this->assertConstraintExists($constraint, 'f');
        }

        foreach ([
            'institutions_status_index',
            'institutions_type_index',
            'institutions_lower_name_index',
            'users_login_name_unique',
            'users_institution_role_active_index',
            'users_institution_lower_full_name_index',
            'users_role_index',
            'personal_access_tokens_tokenable_index',
            'personal_access_tokens_token_unique',
            'personal_access_tokens_expires_at_index',
        ] as $index) {
            $this->assertIndexExists($index);
        }
    }

    private function assertColumnType(string $table, string $column, string $expectedType): void
    {
        $this->assertSame($expectedType, $this->column($table, $column)->data_type);
    }

    private function assertColumnNullability(string $table, string $column, string $expectedNullability): void
    {
        $this->assertSame($expectedNullability, $this->column($table, $column)->is_nullable);
    }

    private function column(string $table, string $column): object
    {
        $columnDefinition = DB::selectOne(
            <<<'SQL'
                select data_type, is_nullable, numeric_precision, numeric_scale
                from information_schema.columns
                where table_schema = 'public'
                  and table_name = ?
                  and column_name = ?
            SQL,
            [$table, $column],
        );

        $this->assertNotNull($columnDefinition, "Column {$table}.{$column} should exist.");

        return $columnDefinition;
    }

    private function assertConstraintExists(string $constraint, ?string $type = null): void
    {
        $found = DB::selectOne(
            <<<'SQL'
                select c.conname, c.contype
                from pg_constraint c
                join pg_class t on t.oid = c.conrelid
                join pg_namespace n on n.oid = t.relnamespace
                where n.nspname = 'public'
                  and c.conname = ?
            SQL,
            [$constraint],
        );

        $this->assertNotNull($found, "Constraint {$constraint} should exist.");

        if ($type !== null) {
            $this->assertSame($type, $found->contype);
        }
    }

    private function assertIndexExists(string $index): void
    {
        $found = DB::selectOne(
            <<<'SQL'
                select indexname
                from pg_indexes
                where schemaname = 'public'
                  and indexname = ?
            SQL,
            [$index],
        );

        $this->assertNotNull($found, "Index {$index} should exist.");
    }
}
