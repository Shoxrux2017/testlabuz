<?php

namespace Tests\Feature\Persistence;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class GroupRelationshipSchemaInspectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_group_relationship_tables_define_required_columns_types_and_nullability(): void
    {
        $requiredColumns = [
            'groups' => [
                'id',
                'institution_id',
                'name',
                'level',
                'subject_direction',
                'description',
                'status',
                'created_by_user_id',
                'archived_at',
                'created_at',
                'updated_at',
            ],
            'group_teacher_memberships' => [
                'id',
                'institution_id',
                'group_id',
                'teacher_id',
                'assigned_by_user_id',
                'started_at',
                'ended_at',
                'created_at',
                'updated_at',
            ],
            'group_student_memberships' => [
                'id',
                'institution_id',
                'group_id',
                'student_id',
                'assigned_by_user_id',
                'started_at',
                'ended_at',
                'created_at',
                'updated_at',
            ],
            'parent_student_relationships' => [
                'id',
                'institution_id',
                'parent_id',
                'student_id',
                'connected_by_user_id',
                'started_at',
                'ended_at',
                'created_at',
                'updated_at',
            ],
        ];

        foreach ($requiredColumns as $table => $columns) {
            $this->assertTrue(Schema::hasColumns($table, $columns), "Table {$table} should contain every required column.");
        }

        foreach ([
            ['groups', 'id'],
            ['groups', 'institution_id'],
            ['groups', 'created_by_user_id'],
            ['group_teacher_memberships', 'id'],
            ['group_teacher_memberships', 'institution_id'],
            ['group_teacher_memberships', 'group_id'],
            ['group_teacher_memberships', 'teacher_id'],
            ['group_teacher_memberships', 'assigned_by_user_id'],
            ['group_student_memberships', 'id'],
            ['group_student_memberships', 'institution_id'],
            ['group_student_memberships', 'group_id'],
            ['group_student_memberships', 'student_id'],
            ['group_student_memberships', 'assigned_by_user_id'],
            ['parent_student_relationships', 'id'],
            ['parent_student_relationships', 'institution_id'],
            ['parent_student_relationships', 'parent_id'],
            ['parent_student_relationships', 'student_id'],
            ['parent_student_relationships', 'connected_by_user_id'],
        ] as [$table, $column]) {
            $this->assertColumnDefinition($table, $column, 'uuid', 'NO');
        }

        foreach ([
            ['groups', 'archived_at', 'YES'],
            ['groups', 'created_at', 'NO'],
            ['groups', 'updated_at', 'NO'],
            ['group_teacher_memberships', 'started_at', 'NO'],
            ['group_teacher_memberships', 'ended_at', 'YES'],
            ['group_teacher_memberships', 'created_at', 'NO'],
            ['group_teacher_memberships', 'updated_at', 'NO'],
            ['group_student_memberships', 'started_at', 'NO'],
            ['group_student_memberships', 'ended_at', 'YES'],
            ['group_student_memberships', 'created_at', 'NO'],
            ['group_student_memberships', 'updated_at', 'NO'],
            ['parent_student_relationships', 'started_at', 'NO'],
            ['parent_student_relationships', 'ended_at', 'YES'],
            ['parent_student_relationships', 'created_at', 'NO'],
            ['parent_student_relationships', 'updated_at', 'NO'],
        ] as [$table, $column, $nullability]) {
            $this->assertColumnDefinition($table, $column, 'timestamp with time zone', $nullability);
        }

        foreach ([
            ['name', 'NO', 160],
            ['level', 'YES', 100],
            ['subject_direction', 'YES', 160],
            ['status', 'NO', 20],
        ] as [$column, $nullability, $maximumLength]) {
            $definition = $this->column('groups', $column);

            $this->assertSame('character varying', $definition->data_type);
            $this->assertSame($nullability, $definition->is_nullable);
            $this->assertSame($maximumLength, (int) $definition->character_maximum_length);
        }

        $this->assertColumnDefinition('groups', 'description', 'text', 'YES');
    }

    public function test_required_group_relationship_constraints_exist_with_restrictive_foreign_keys(): void
    {
        foreach ([
            'groups_name_not_empty_check',
            'groups_status_check',
            'groups_status_archived_at_check',
            'group_teacher_memberships_time_order_check',
            'group_student_memberships_time_order_check',
            'parent_student_relationships_time_order_check',
        ] as $constraint) {
            $this->assertConstraint($constraint, 'c');
        }

        foreach ([
            'users_institution_id_id_unique',
            'groups_institution_id_id_unique',
        ] as $constraint) {
            $this->assertConstraint($constraint, 'u');
        }

        foreach ([
            'groups_institution_id_foreign',
            'groups_institution_creator_foreign',
            'group_teacher_memberships_institution_id_foreign',
            'group_teacher_memberships_group_tenant_foreign',
            'group_teacher_memberships_teacher_tenant_foreign',
            'group_teacher_memberships_assigned_by_tenant_foreign',
            'group_student_memberships_institution_id_foreign',
            'group_student_memberships_group_tenant_foreign',
            'group_student_memberships_student_tenant_foreign',
            'group_student_memberships_assigned_by_tenant_foreign',
            'parent_student_relationships_institution_id_foreign',
            'parent_student_relationships_parent_tenant_foreign',
            'parent_student_relationships_student_tenant_foreign',
            'parent_student_relationships_connected_by_tenant_foreign',
        ] as $constraint) {
            $definition = $this->assertConstraint($constraint, 'f');

            $this->assertSame('r', $definition->confdeltype, "Foreign key {$constraint} should use ON DELETE RESTRICT.");
        }
    }

    public function test_required_group_relationship_indexes_exist_with_partial_uniqueness(): void
    {
        foreach ([
            'users_institution_id_id_unique' => '(institution_id, id)',
            'groups_institution_id_id_unique' => '(institution_id, id)',
            'groups_institution_status_index' => '(institution_id, status)',
            'groups_institution_lower_name_index' => '(institution_id, lower((name)::text))',
            'group_teacher_memberships_institution_teacher_ended_index' => '(institution_id, teacher_id, ended_at)',
            'group_teacher_memberships_institution_group_ended_index' => '(institution_id, group_id, ended_at)',
            'group_student_memberships_institution_student_ended_index' => '(institution_id, student_id, ended_at)',
            'group_student_memberships_institution_group_ended_index' => '(institution_id, group_id, ended_at)',
            'parent_student_relationships_institution_parent_ended_index' => '(institution_id, parent_id, ended_at)',
            'parent_student_relationships_institution_student_ended_index' => '(institution_id, student_id, ended_at)',
        ] as $index => $columns) {
            $this->assertStringContainsString($columns, $this->indexDefinition($index));
        }

        foreach ([
            'group_teacher_memberships_current_unique' => '(group_id, teacher_id)',
            'group_student_memberships_current_unique' => '(group_id, student_id)',
            'parent_student_relationships_current_unique' => '(parent_id, student_id)',
        ] as $index => $columns) {
            $definition = $this->indexDefinition($index);

            $this->assertStringContainsString('CREATE UNIQUE INDEX', $definition);
            $this->assertStringContainsString($columns, $definition);
            $this->assertStringContainsString('WHERE (ended_at IS NULL)', $definition);
        }
    }

    private function assertColumnDefinition(
        string $table,
        string $column,
        string $expectedType,
        string $expectedNullability,
    ): void {
        $definition = $this->column($table, $column);

        $this->assertSame($expectedType, $definition->data_type);
        $this->assertSame($expectedNullability, $definition->is_nullable);
    }

    private function column(string $table, string $column): object
    {
        $definition = DB::selectOne(
            <<<'SQL'
                select data_type, is_nullable, character_maximum_length
                from information_schema.columns
                where table_schema = 'public'
                  and table_name = ?
                  and column_name = ?
            SQL,
            [$table, $column],
        );

        $this->assertNotNull($definition, "Column {$table}.{$column} should exist.");

        return $definition;
    }

    private function assertConstraint(string $constraint, string $expectedType): object
    {
        $definition = DB::selectOne(
            <<<'SQL'
                select c.conname, c.contype, c.confdeltype
                from pg_constraint c
                join pg_class t on t.oid = c.conrelid
                join pg_namespace n on n.oid = t.relnamespace
                where n.nspname = 'public'
                  and c.conname = ?
            SQL,
            [$constraint],
        );

        $this->assertNotNull($definition, "Constraint {$constraint} should exist.");
        $this->assertSame($expectedType, $definition->contype);

        return $definition;
    }

    private function indexDefinition(string $index): string
    {
        $definition = DB::selectOne(
            <<<'SQL'
                select indexdef
                from pg_indexes
                where schemaname = 'public'
                  and indexname = ?
            SQL,
            [$index],
        );

        $this->assertNotNull($definition, "Index {$index} should exist.");

        return $definition->indexdef;
    }
}
