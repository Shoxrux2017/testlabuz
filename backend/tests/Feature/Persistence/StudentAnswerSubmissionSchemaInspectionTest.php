<?php

namespace Tests\Feature\Persistence;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class StudentAnswerSubmissionSchemaInspectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_nine_tables_define_exact_typed_columns_without_generic_answer_payloads(): void
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
    }

    public function test_columns_have_exact_postgresql_types_nullability_lengths_precision_and_default(): void
    {
        $columnTypes = [
            'id' => 'uuid',
            'institution_id' => 'uuid',
            'attempt_id' => 'uuid',
            'question_id' => 'uuid',
            'checking_status' => 'character varying',
            'awarded_points' => 'numeric',
            'feedback' => 'text',
            'checked_by_user_id' => 'uuid',
            'checked_at' => 'timestamp with time zone',
            'created_at' => 'timestamp with time zone',
            'updated_at' => 'timestamp with time zone',
            'answer_id' => 'uuid',
            'option_id' => 'uuid',
            'text_value' => 'text',
            'boolean_value' => 'boolean',
            'left_item_id' => 'uuid',
            'right_item_id' => 'uuid',
            'ordering_item_id' => 'uuid',
            'submitted_position' => 'integer',
            'blank_id' => 'uuid',
            'file_id' => 'uuid',
            'user_id' => 'uuid',
            'operation' => 'character varying',
            'idempotency_key' => 'uuid',
            'request_fingerprint' => 'character',
            'result_resource_type' => 'character varying',
            'result_resource_id' => 'uuid',
            'response_status' => 'smallint',
            'completed_at' => 'timestamp with time zone',
        ];
        $nullableColumns = [
            'awarded_points', 'feedback', 'checked_by_user_id', 'checked_at',
            'result_resource_type', 'result_resource_id', 'response_status', 'completed_at',
        ];

        foreach ($this->tableColumns() as $table => $columns) {
            foreach ($columns as $column) {
                $definition = $this->column($table, $column);
                $this->assertSame($columnTypes[$column], $definition->data_type, "Type of {$table}.{$column}");
                $this->assertSame(in_array($column, $nullableColumns, true) ? 'YES' : 'NO', $definition->is_nullable, "Nullability of {$table}.{$column}");
            }
        }

        foreach ([
            ['attempt_answers', 'checking_status', 30],
            ['idempotency_records', 'operation', 80],
            ['idempotency_records', 'request_fingerprint', 64],
            ['idempotency_records', 'result_resource_type', 80],
        ] as [$table, $column, $length]) {
            $this->assertSame($length, (int) $this->column($table, $column)->character_maximum_length);
        }

        $points = $this->column('attempt_answers', 'awarded_points');
        $this->assertSame(16, (int) $points->numeric_precision);
        $this->assertSame(8, (int) $points->numeric_scale);
        $this->assertSame("'pending'::character varying", $this->column('attempt_answers', 'checking_status')->column_default);

        foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $column) {
            $this->assertNull($this->column('attempt_answers', $column)->column_default);
        }
    }

    public function test_primary_and_unique_keys_encode_answer_cardinality_and_tenant_reference_rules(): void
    {
        foreach (array_keys($this->tableColumns()) as $table) {
            $primaryColumns = match ($table) {
                'answer_choice_selections' => 'answer_id, option_id',
                'answer_text_values', 'answer_boolean_values' => 'answer_id',
                default => 'id',
            };

            $primary = DB::selectOne(
                "select pg_get_constraintdef(c.oid) as definition from pg_constraint c join pg_class t on t.oid = c.conrelid join pg_namespace n on n.oid = t.relnamespace where n.nspname = 'public' and t.relname = ? and c.contype = 'p'",
                [$table],
            );
            $this->assertNotNull($primary);
            $this->assertSame("PRIMARY KEY ({$primaryColumns})", $primary->definition);
        }

        foreach ([
            'attempt_answers_institution_id_unique' => 'institution_id, id',
            'attempt_answers_attempt_question_unique' => 'attempt_id, question_id',
            'answer_matching_pairs_institution_id_unique' => 'institution_id, id',
            'answer_matching_pairs_answer_left_unique' => 'answer_id, left_item_id',
            'answer_matching_pairs_answer_right_unique' => 'answer_id, right_item_id',
            'answer_ordering_items_institution_id_unique' => 'institution_id, id',
            'answer_ordering_items_answer_item_unique' => 'answer_id, ordering_item_id',
            'answer_ordering_items_answer_position_unique' => 'answer_id, submitted_position',
            'answer_fill_blank_values_institution_id_unique' => 'institution_id, id',
            'answer_fill_blank_values_answer_blank_unique' => 'answer_id, blank_id',
            'answer_files_institution_id_unique' => 'institution_id, id',
            'answer_files_answer_unique' => 'answer_id',
            'answer_files_file_unique' => 'file_id',
            'idempotency_records_institution_id_unique' => 'institution_id, id',
            'idempotency_records_scope_key_unique' => 'institution_id, user_id, operation, idempotency_key',
            'question_choice_options_institution_id_unique' => 'institution_id, id',
            'question_matching_items_institution_id_unique' => 'institution_id, id',
            'question_ordering_items_institution_id_unique' => 'institution_id, id',
            'question_fill_blanks_institution_id_unique' => 'institution_id, id',
            'assessment_attempts_assessment_student_number_unique' => 'assessment_id, student_id, attempt_number',
        ] as $constraint => $columns) {
            $this->assertSame("UNIQUE ({$columns})", $this->constraint($constraint, 'u')->definition);
        }
    }

    public function test_check_constraints_encode_specified_status_score_position_and_idempotency_rules(): void
    {
        $status = $this->constraint('attempt_answers_checking_status_check', 'c')->definition;
        preg_match_all("/'([^']*)'/", $status, $values);
        $this->assertSame(['pending', 'auto_checked', 'waiting_for_teacher_review', 'teacher_checked'], $values[1]);
        $this->assertMatchesRegularExpression('/awarded_points >= \(?0\)?(?:::numeric)?/', $this->constraint('attempt_answers_awarded_points_check', 'c')->definition);

        foreach ([
            'attempt_answers_awarded_points_check' => ['awarded_points IS NULL', 'awarded_points >='],
            'answer_ordering_items_position_check' => ['submitted_position >= 0'],
            'idempotency_records_operation_check' => ["btrim((operation)::text) <> ''::text"],
            'idempotency_records_fingerprint_check' => ["~ '^[0-9a-f]{64}$'::text"],
            'idempotency_records_resource_type_check' => ['result_resource_type IS NULL', "btrim((result_resource_type)::text) <> ''::text"],
            'idempotency_records_response_status_check' => ['response_status IS NULL', 'response_status >= 200', 'response_status <= 299'],
            'idempotency_records_completion_shape_check' => [
                '(completed_at IS NULL) AND (result_resource_type IS NULL) AND (result_resource_id IS NULL) AND (response_status IS NULL)',
                ' OR ',
                '(completed_at IS NOT NULL) AND (result_resource_type IS NOT NULL) AND (result_resource_id IS NOT NULL) AND (response_status IS NOT NULL)',
            ],
            'idempotency_records_completed_at_check' => ['completed_at IS NULL', 'completed_at >= created_at'],
        ] as $constraint => $fragments) {
            $definition = $this->constraint($constraint, 'c')->definition;

            foreach ($fragments as $fragment) {
                $this->assertStringContainsString($fragment, $definition);
            }
        }
    }

    public function test_all_domain_foreign_keys_are_exact_tenant_preserving_and_restrictive(): void
    {
        $tenantReferences = [
            'attempt_answers' => [
                'attempt_id' => 'assessment_attempts',
                'question_id' => 'questions',
                'checked_by_user_id' => 'users',
            ],
            'answer_choice_selections' => ['answer_id' => 'attempt_answers', 'option_id' => 'question_choice_options'],
            'answer_text_values' => ['answer_id' => 'attempt_answers'],
            'answer_boolean_values' => ['answer_id' => 'attempt_answers'],
            'answer_matching_pairs' => ['answer_id' => 'attempt_answers', 'left_item_id' => 'question_matching_items', 'right_item_id' => 'question_matching_items'],
            'answer_ordering_items' => ['answer_id' => 'attempt_answers', 'ordering_item_id' => 'question_ordering_items'],
            'answer_fill_blank_values' => ['answer_id' => 'attempt_answers', 'blank_id' => 'question_fill_blanks'],
            'answer_files' => ['answer_id' => 'attempt_answers', 'file_id' => 'files'],
            'idempotency_records' => ['user_id' => 'users'],
        ];

        foreach ($tenantReferences as $table => $references) {
            $expected = ['FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT'];

            foreach ($references as $column => $parent) {
                $expected[] = "FOREIGN KEY (institution_id, {$column}) REFERENCES {$parent}(institution_id, id) ON DELETE RESTRICT";
            }

            $foreignKeys = DB::select(
                <<<'SQL'
                    select c.confdeltype, pg_get_constraintdef(c.oid) as definition
                    from pg_constraint c
                    join pg_class t on t.oid = c.conrelid
                    join pg_namespace n on n.oid = t.relnamespace
                    where n.nspname = 'public' and t.relname = ? and c.contype = 'f'
                SQL,
                [$table],
            );
            $this->assertCount(count($expected), $foreignKeys, "Exact foreign keys for {$table}; no polymorphic result resource FK.");

            foreach ($foreignKeys as $foreignKey) {
                $this->assertSame('r', $foreignKey->confdeltype);
            }

            $this->assertEqualsCanonicalizing($expected, array_column($foreignKeys, 'definition'));
        }
    }

    public function test_partial_unique_guard_covers_every_assessment_type_and_required_lookup_indexes_exist(): void
    {
        $partial = DB::selectOne(
            <<<'SQL'
                select t.relname as table_name, i.indisunique, pg_get_expr(i.indpred, i.indrelid) as predicate,
                       pg_get_indexdef(i.indexrelid) as definition
                from pg_index i
                join pg_class x on x.oid = i.indexrelid
                join pg_class t on t.oid = i.indrelid
                join pg_namespace n on n.oid = t.relnamespace
                where n.nspname = 'public' and x.relname = ?
            SQL,
            ['assessment_attempts_one_in_progress_per_student_unique'],
        );
        $this->assertNotNull($partial);
        $this->assertSame('assessment_attempts', $partial->table_name);
        $this->assertTrue($partial->indisunique);
        $this->assertStringContainsString('(assessment_id, student_id)', $partial->definition);
        $this->assertSame("((status)::text = 'in_progress'::text)", $partial->predicate);

        foreach ([
            'attempt_answers_institution_checking_checked_index' => '(institution_id, checking_status, checked_at)',
            'idempotency_records_scope_key_unique' => '(institution_id, user_id, operation, idempotency_key)',
            'idempotency_records_lookup_index' => '(institution_id, user_id, operation, created_at)',
        ] as $index => $columns) {
            $definition = DB::selectOne(
                "select indexdef from pg_indexes where schemaname = 'public' and indexname = ?",
                [$index],
            );
            $this->assertNotNull($definition, "Index {$index} should exist.");
            $this->assertStringContainsString($columns, $definition->indexdef);
        }
    }

    /** @return array<string, list<string>> */
    private function tableColumns(): array
    {
        return [
            'attempt_answers' => ['id', 'institution_id', 'attempt_id', 'question_id', 'checking_status', 'awarded_points', 'feedback', 'checked_by_user_id', 'checked_at', 'created_at', 'updated_at'],
            'answer_choice_selections' => ['answer_id', 'option_id', 'institution_id', 'created_at'],
            'answer_text_values' => ['answer_id', 'institution_id', 'text_value', 'created_at', 'updated_at'],
            'answer_boolean_values' => ['answer_id', 'institution_id', 'boolean_value', 'created_at', 'updated_at'],
            'answer_matching_pairs' => ['id', 'institution_id', 'answer_id', 'left_item_id', 'right_item_id', 'created_at'],
            'answer_ordering_items' => ['id', 'institution_id', 'answer_id', 'ordering_item_id', 'submitted_position', 'created_at'],
            'answer_fill_blank_values' => ['id', 'institution_id', 'answer_id', 'blank_id', 'text_value', 'created_at', 'updated_at'],
            'answer_files' => ['id', 'institution_id', 'answer_id', 'file_id', 'created_at'],
            'idempotency_records' => ['id', 'institution_id', 'user_id', 'operation', 'idempotency_key', 'request_fingerprint', 'result_resource_type', 'result_resource_id', 'response_status', 'completed_at', 'created_at', 'updated_at'],
        ];
    }

    private function column(string $table, string $column): object
    {
        $definition = DB::selectOne(
            <<<'SQL'
                select data_type, is_nullable, character_maximum_length, numeric_precision, numeric_scale, column_default
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
}
