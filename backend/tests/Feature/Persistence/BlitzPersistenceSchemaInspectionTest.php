<?php

namespace Tests\Feature\Persistence;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class BlitzPersistenceSchemaInspectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_tables_define_exact_columns_without_duplicate_attempt_or_answer_storage(): void
    {
        foreach ($this->tableColumns() as $table => $columns) {
            $this->assertTrue(Schema::hasTable($table), "Table {$table} should exist.");
            $this->assertSame($columns, array_map(
                static fn (object $column): string => $column->column_name,
                DB::select(
                    "select column_name from information_schema.columns where table_schema = 'public' and table_name = ? order by ordinal_position",
                    [$table],
                ),
            ));
        }

        foreach (['blitz_attempts', 'blitz_answers', 'official_task_scores', 'topic_results'] as $table) {
            $this->assertFalse(Schema::hasTable($table), "Table {$table} is outside this persistence foundation.");
        }
    }

    public function test_columns_have_exact_postgresql_types_nullability_and_lengths(): void
    {
        $columnTypes = [
            'id' => 'uuid',
            'assessment_id' => 'uuid',
            'institution_id' => 'uuid',
            'assessment_student_id' => 'uuid',
            'student_id' => 'uuid',
            'invalidated_attempt_id' => 'uuid',
            'replacement_attempt_id' => 'uuid',
            'activated_by_user_id' => 'uuid',
            'granted_by_user_id' => 'uuid',
            'status' => 'character varying',
            'duration_seconds' => 'integer',
            'timer_start_mode_snapshot' => 'character varying',
            'reason_type' => 'character varying',
            'reason' => 'text',
            'scheduled_at' => 'timestamp with time zone',
            'activated_at' => 'timestamp with time zone',
            'synchronized_ends_at' => 'timestamp with time zone',
            'closed_at' => 'timestamp with time zone',
            'archived_at' => 'timestamp with time zone',
            'granted_at' => 'timestamp with time zone',
            'created_at' => 'timestamp with time zone',
            'updated_at' => 'timestamp with time zone',
        ];
        $nullableColumns = [
            'scheduled_at', 'timer_start_mode_snapshot', 'activated_at', 'synchronized_ends_at',
            'closed_at', 'archived_at', 'activated_by_user_id', 'replacement_attempt_id',
        ];

        foreach ($this->tableColumns() as $table => $columns) {
            foreach ($columns as $column) {
                $definition = $this->column($table, $column);
                $this->assertSame($columnTypes[$column], $definition->data_type, "Type of {$table}.{$column}");
                $this->assertSame(in_array($column, $nullableColumns, true) ? 'YES' : 'NO', $definition->is_nullable, "Nullability of {$table}.{$column}");
            }
        }

        foreach ([
            ['blitz_tasks', 'status', 20],
            ['blitz_tasks', 'timer_start_mode_snapshot', 24],
            ['blitz_attempt_exceptions', 'reason_type', 24],
        ] as [$table, $column, $length]) {
            $this->assertSame($length, (int) $this->column($table, $column)->character_maximum_length);
        }

        $this->assertNull($this->column('blitz_tasks', 'duration_seconds')->column_default);
    }

    public function test_primary_and_unique_keys_preserve_shared_identity_and_exception_cardinality(): void
    {
        foreach (['blitz_tasks' => 'assessment_id', 'blitz_attempt_exceptions' => 'id'] as $table => $primaryColumn) {
            $primary = DB::selectOne(
                <<<'SQL'
                    select pg_get_constraintdef(c.oid) as definition
                    from pg_constraint c
                    join pg_class t on t.oid = c.conrelid
                    join pg_namespace n on n.oid = t.relnamespace
                    where n.nspname = 'public' and t.relname = ? and c.contype = 'p'
                SQL,
                [$table],
            );
            $this->assertNotNull($primary, "Primary key for {$table} should exist.");
            $this->assertSame("PRIMARY KEY ({$primaryColumn})", $primary->definition);
        }

        foreach ([
            'blitz_tasks_institution_assessment_unique' => 'institution_id, assessment_id',
            'blitz_attempt_exceptions_assessment_student_unique' => 'assessment_id, student_id',
            'blitz_attempt_exceptions_invalidated_attempt_unique' => 'invalidated_attempt_id',
            'blitz_attempt_exceptions_replacement_attempt_unique' => 'replacement_attempt_id',
        ] as $constraint => $columns) {
            $this->assertSame("UNIQUE ({$columns})", $this->constraint($constraint, 'u')->definition);
        }
    }

    public function test_named_checks_define_exact_values_and_required_structural_rules(): void
    {
        foreach ([
            'blitz_tasks_status_check' => ['draft', 'scheduled', 'active', 'closed', 'archived'],
            'blitz_tasks_timer_mode_check' => ['synchronized', 'individual'],
            'blitz_attempt_exceptions_reason_type_check' => ['technical', 'other_valid'],
        ] as $constraint => $expectedValues) {
            preg_match_all("/'([^']*)'/", $this->constraint($constraint, 'c')->definition, $values);
            $this->assertSame($expectedValues, $values[1], "Values of {$constraint}");
        }

        foreach ([
            'blitz_tasks_duration_check' => ['duration_seconds > 0'],
            'blitz_tasks_timer_mode_check' => ['timer_start_mode_snapshot IS NULL'],
            'blitz_tasks_lifecycle_check' => [
                "'draft'", "'scheduled'", "'active'", "'closed'", "'archived'",
                'scheduled_at IS NOT NULL',
                'timer_start_mode_snapshot IS NULL', 'timer_start_mode_snapshot IS NOT NULL',
                'activated_at IS NULL', 'activated_at IS NOT NULL',
                'activated_by_user_id IS NULL', 'activated_by_user_id IS NOT NULL',
                'synchronized_ends_at IS NULL',
                'closed_at IS NULL', 'closed_at IS NOT NULL',
                'archived_at IS NULL', 'archived_at IS NOT NULL',
            ],
            'blitz_tasks_timer_shape_check' => [
                'timer_start_mode_snapshot IS NULL', "'synchronized'", "'individual'",
                'activated_at IS NULL', 'activated_at IS NOT NULL',
                'activated_by_user_id IS NULL', 'activated_by_user_id IS NOT NULL',
                'synchronized_ends_at IS NULL', 'synchronized_ends_at IS NOT NULL',
                'synchronized_ends_at = (activated_at +', 'duration_seconds', '::interval',
            ],
            'blitz_tasks_activated_order_check' => ['activated_at IS NULL', 'activated_at >= created_at'],
            'blitz_tasks_closed_order_check' => ['closed_at IS NULL', 'activated_at IS NOT NULL', 'closed_at >= activated_at'],
            'blitz_tasks_archived_order_check' => ['archived_at IS NULL', 'archived_at >= created_at', 'closed_at IS NULL', 'archived_at >= closed_at'],
            'blitz_attempt_exceptions_reason_not_empty_check' => ["btrim(reason) <> ''::text"],
            'blitz_attempt_exceptions_distinct_attempts_check' => ['replacement_attempt_id IS NULL', 'replacement_attempt_id <> invalidated_attempt_id'],
        ] as $constraint => $fragments) {
            $definition = $this->constraint($constraint, 'c')->definition;

            foreach ($fragments as $fragment) {
                $this->assertStringContainsString($fragment, $definition, "Definition of {$constraint}");
            }
        }
    }

    public function test_all_named_foreign_keys_are_exact_tenant_safe_and_restrictive(): void
    {
        $foreignKeys = [
            'blitz_tasks' => [
                'blitz_tasks_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
                'blitz_tasks_activator_tenant_foreign' => 'FOREIGN KEY (institution_id, activated_by_user_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
            ],
            'blitz_attempt_exceptions' => [
                'blitz_attempt_exceptions_institution_id_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
                'blitz_attempt_exceptions_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
                'blitz_attempt_exceptions_recipient_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_student_id) REFERENCES assessment_students(institution_id, id) ON DELETE RESTRICT',
                'blitz_attempt_exceptions_student_tenant_foreign' => 'FOREIGN KEY (institution_id, student_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
                'blitz_attempt_exceptions_invalidated_attempt_tenant_foreign' => 'FOREIGN KEY (institution_id, invalidated_attempt_id) REFERENCES assessment_attempts(institution_id, id) ON DELETE RESTRICT',
                'blitz_attempt_exceptions_replacement_attempt_tenant_foreign' => 'FOREIGN KEY (institution_id, replacement_attempt_id) REFERENCES assessment_attempts(institution_id, id) ON DELETE RESTRICT',
                'blitz_attempt_exceptions_grantor_tenant_foreign' => 'FOREIGN KEY (institution_id, granted_by_user_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
            ],
        ];

        foreach ($foreignKeys as $table => $expectedForeignKeys) {
            $actualForeignKeys = DB::select(
                <<<'SQL'
                    select c.conname, c.confdeltype, pg_get_constraintdef(c.oid) as definition
                    from pg_constraint c
                    join pg_class t on t.oid = c.conrelid
                    join pg_namespace n on n.oid = t.relnamespace
                    where n.nspname = 'public' and t.relname = ? and c.contype = 'f'
                SQL,
                [$table],
            );
            $this->assertCount(count($expectedForeignKeys), $actualForeignKeys, "Exact foreign keys for {$table}");

            foreach ($actualForeignKeys as $foreignKey) {
                $this->assertArrayHasKey($foreignKey->conname, $expectedForeignKeys);
                $this->assertSame('r', $foreignKey->confdeltype);
                $this->assertSame($expectedForeignKeys[$foreignKey->conname], $foreignKey->definition);
            }
        }
    }

    public function test_named_query_indexes_and_existing_one_in_progress_guard_are_preserved(): void
    {
        foreach ([
            'blitz_tasks_institution_status_scheduled_index' => ['blitz_tasks', 'institution_id, status, scheduled_at'],
            'blitz_tasks_institution_activated_index' => ['blitz_tasks', 'institution_id, activated_at'],
            'blitz_tasks_institution_synchronized_ends_index' => ['blitz_tasks', 'institution_id, synchronized_ends_at'],
            'blitz_attempt_exceptions_institution_assessment_student_index' => ['blitz_attempt_exceptions', 'institution_id, assessment_id, student_id'],
        ] as $index => [$table, $columns]) {
            $definition = $this->index($index);
            $this->assertSame($table, $definition->table_name);
            $this->assertFalse($definition->indisunique);
            $this->assertNull($definition->predicate);
            $this->assertSame("CREATE INDEX {$index} ON public.{$table} USING btree ({$columns})", $definition->definition);
        }

        $partial = $this->index('assessment_attempts_one_in_progress_per_student_unique');
        $this->assertSame('assessment_attempts', $partial->table_name);
        $this->assertTrue($partial->indisunique);
        $this->assertStringContainsString('(assessment_id, student_id)', $partial->definition);
        $this->assertSame("((status)::text = 'in_progress'::text)", $partial->predicate);
    }

    /** @return array<string, list<string>> */
    private function tableColumns(): array
    {
        return [
            'blitz_tasks' => [
                'assessment_id', 'institution_id', 'status', 'duration_seconds', 'scheduled_at',
                'timer_start_mode_snapshot', 'activated_at', 'synchronized_ends_at', 'closed_at',
                'archived_at', 'activated_by_user_id', 'created_at', 'updated_at',
            ],
            'blitz_attempt_exceptions' => [
                'id', 'institution_id', 'assessment_id', 'assessment_student_id', 'student_id',
                'invalidated_attempt_id', 'replacement_attempt_id', 'reason_type', 'reason',
                'granted_by_user_id', 'granted_at', 'created_at', 'updated_at',
            ],
        ];
    }

    private function column(string $table, string $column): object
    {
        $definition = DB::selectOne(
            <<<'SQL'
                select data_type, is_nullable, character_maximum_length, column_default
                from information_schema.columns
                where table_schema = 'public' and table_name = ? and column_name = ?
            SQL,
            [$table, $column],
        );
        $this->assertNotNull($definition, "Column {$table}.{$column} should exist.");

        return $definition;
    }

    private function constraint(string $constraint, string $expectedType): object
    {
        $definition = DB::selectOne(
            <<<'SQL'
                select c.contype, pg_get_constraintdef(c.oid) as definition
                from pg_constraint c
                join pg_class t on t.oid = c.conrelid
                join pg_namespace n on n.oid = t.relnamespace
                where n.nspname = 'public' and c.conname = ?
            SQL,
            [$constraint],
        );
        $this->assertNotNull($definition, "Constraint {$constraint} should exist.");
        $this->assertSame($expectedType, $definition->contype);

        return $definition;
    }

    private function index(string $index): object
    {
        $definition = DB::selectOne(
            <<<'SQL'
                select t.relname as table_name, i.indisunique, pg_get_expr(i.indpred, i.indrelid) as predicate,
                       pg_get_indexdef(i.indexrelid) as definition
                from pg_index i
                join pg_class x on x.oid = i.indexrelid
                join pg_class t on t.oid = i.indrelid
                join pg_namespace n on n.oid = t.relnamespace
                where n.nspname = 'public' and x.relname = ?
            SQL,
            [$index],
        );
        $this->assertNotNull($definition, "Index {$index} should exist.");

        return $definition;
    }
}
