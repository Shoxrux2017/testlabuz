<?php

namespace Tests\Feature\Persistence;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class AssessmentHomeworkSchemaInspectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_tables_define_exact_required_columns_without_future_runtime_tables(): void
    {
        $expectedColumns = [
            'assessments' => [
                'id',
                'institution_id',
                'topic_id',
                'teacher_id',
                'type',
                'title',
                'description',
                'student_instructions',
                'assignment_mode',
                'total_possible_points',
                'created_at',
                'updated_at',
            ],
            'homework_assignments' => [
                'assessment_id',
                'institution_id',
                'status',
                'deadline_at',
                'activated_at',
                'closed_at',
                'archived_at',
                'created_at',
                'updated_at',
            ],
            'assessment_students' => [
                'id',
                'institution_id',
                'assessment_id',
                'student_id',
                'assignment_source',
                'assigned_at',
                'assigned_by_user_id',
                'created_at',
                'updated_at',
            ],
            'assessment_attempts' => [
                'id',
                'institution_id',
                'assessment_id',
                'assessment_student_id',
                'student_id',
                'attempt_number',
                'status',
                'started_at',
                'deadline_at',
                'submitted_at',
                'finalized_at',
                'finalization_reason',
                'locked_at',
                'official_score_eligible',
                'earned_points',
                'possible_points',
                'normalized_score',
                'scoring_completed_at',
                'created_at',
                'updated_at',
            ],
            'topic_result_pairs' => [
                'id',
                'institution_id',
                'topic_id',
                'homework_assessment_id',
                'blitz_assessment_id',
                'designated_by_user_id',
                'designated_at',
                'cohort_snapshotted_at',
                'locked_at',
                'created_at',
                'updated_at',
            ],
        ];

        foreach ($expectedColumns as $table => $columns) {
            $this->assertTrue(Schema::hasTable($table));
            $this->assertSame($columns, $this->columnNames($table));
        }

        $this->assertFalse(Schema::hasColumn('homework_assignments', 'attempt_limit'));

        foreach (['questions', 'blitz_tasks', 'attempt_answers', 'official_task_scores', 'topic_results'] as $table) {
            $this->assertFalse(Schema::hasTable($table), "Table {$table} is outside this persistence foundation.");
        }
    }

    public function test_columns_have_exact_types_nullability_lengths_precision_and_defaults(): void
    {
        foreach ([
            ['assessments', 'id'],
            ['assessments', 'institution_id'],
            ['assessments', 'topic_id'],
            ['assessments', 'teacher_id'],
            ['homework_assignments', 'assessment_id'],
            ['homework_assignments', 'institution_id'],
            ['assessment_students', 'id'],
            ['assessment_students', 'institution_id'],
            ['assessment_students', 'assessment_id'],
            ['assessment_students', 'student_id'],
            ['assessment_students', 'assigned_by_user_id'],
            ['assessment_attempts', 'id'],
            ['assessment_attempts', 'institution_id'],
            ['assessment_attempts', 'assessment_id'],
            ['assessment_attempts', 'assessment_student_id'],
            ['assessment_attempts', 'student_id'],
            ['topic_result_pairs', 'id'],
            ['topic_result_pairs', 'institution_id'],
            ['topic_result_pairs', 'topic_id'],
            ['topic_result_pairs', 'homework_assessment_id'],
            ['topic_result_pairs', 'designated_by_user_id'],
        ] as [$table, $column]) {
            $this->assertColumnDefinition($table, $column, 'uuid', 'NO');
        }

        $this->assertColumnDefinition('topic_result_pairs', 'blitz_assessment_id', 'uuid', 'YES');

        foreach ([
            ['assessments', 'type', 'NO', 20],
            ['assessments', 'title', 'NO', 255],
            ['assessments', 'assignment_mode', 'NO', 32],
            ['homework_assignments', 'status', 'NO', 20],
            ['assessment_students', 'assignment_source', 'NO', 20],
            ['assessment_attempts', 'status', 'NO', 40],
            ['assessment_attempts', 'finalization_reason', 'YES', 40],
        ] as [$table, $column, $nullability, $length]) {
            $definition = $this->column($table, $column);

            $this->assertSame('character varying', $definition->data_type);
            $this->assertSame($nullability, $definition->is_nullable);
            $this->assertSame($length, (int) $definition->character_maximum_length);
        }

        foreach ([
            ['assessments', 'description', 'YES'],
            ['assessments', 'student_instructions', 'NO'],
        ] as [$table, $column, $nullability]) {
            $this->assertColumnDefinition($table, $column, 'text', $nullability);
        }

        foreach ([
            ['assessments', 'total_possible_points', 'NO', 14, 6],
            ['assessment_attempts', 'earned_points', 'YES', 16, 8],
            ['assessment_attempts', 'possible_points', 'NO', 14, 6],
            ['assessment_attempts', 'normalized_score', 'YES', 12, 8],
        ] as [$table, $column, $nullability, $precision, $scale]) {
            $definition = $this->column($table, $column);

            $this->assertSame('numeric', $definition->data_type);
            $this->assertSame($nullability, $definition->is_nullable);
            $this->assertSame($precision, (int) $definition->numeric_precision);
            $this->assertSame($scale, (int) $definition->numeric_scale);
        }

        $this->assertColumnDefinition('assessment_attempts', 'attempt_number', 'smallint', 'NO');
        $this->assertColumnDefinition('assessment_attempts', 'official_score_eligible', 'boolean', 'NO');
        $this->assertSame('true', $this->column('assessment_attempts', 'official_score_eligible')->column_default);

        foreach ($this->timestampColumns() as [$table, $column, $nullability]) {
            $this->assertColumnDefinition($table, $column, 'timestamp with time zone', $nullability);
        }
    }

    public function test_named_checks_and_unique_constraints_define_the_required_structural_rules(): void
    {
        foreach ([
            'assessments_type_check',
            'assessments_assignment_mode_check',
            'assessments_title_not_empty_check',
            'assessments_instructions_not_empty_check',
            'assessments_total_points_check',
            'homework_assignments_status_check',
            'homework_assignments_lifecycle_check',
            'homework_assignments_activated_order_check',
            'homework_assignments_closed_order_check',
            'homework_assignments_archived_order_check',
            'assessment_students_source_check',
            'assessment_attempts_status_check',
            'assessment_attempts_finalization_reason_check',
            'assessment_attempts_number_check',
            'assessment_attempts_possible_points_check',
            'assessment_attempts_normalized_score_check',
            'assessment_attempts_earned_points_check',
            'assessment_attempts_submitted_order_check',
            'assessment_attempts_finalized_order_check',
            'assessment_attempts_locked_order_check',
            'assessment_attempts_scoring_order_check',
            'topic_result_pairs_distinct_assessments_check',
            'topic_result_pairs_cohort_order_check',
            'topic_result_pairs_locked_order_check',
        ] as $constraint) {
            $this->assertConstraint($constraint, 'c');
        }

        foreach ([
            'assessments_institution_id_id_unique',
            'assessments_institution_topic_id_unique',
            'homework_assignments_institution_assessment_unique',
            'assessment_students_institution_id_id_unique',
            'assessment_students_assessment_student_unique',
            'assessment_attempts_institution_id_id_unique',
            'assessment_attempts_assessment_student_number_unique',
            'topic_result_pairs_institution_id_id_unique',
            'topic_result_pairs_topic_id_unique',
        ] as $constraint) {
            $this->assertConstraint($constraint, 'u');
        }

        $assessmentType = $this->constraintDefinition('assessments_type_check');
        $this->assertStringContainsString("'homework'", $assessmentType);
        $this->assertStringContainsString("'blitz'", $assessmentType);

        $attemptStatus = $this->constraintDefinition('assessment_attempts_status_check');
        foreach (['in_progress', 'submitted', 'timed_out_finalized', 'waiting_for_teacher_review', 'checked'] as $status) {
            $this->assertStringContainsString("'{$status}'", $attemptStatus);
        }

        $finalizationReason = $this->constraintDefinition('assessment_attempts_finalization_reason_check');
        foreach (['student_submit', 'timeout_auto_submit', 'task_closed_auto_finalize', 'homework_deadline_auto_submit'] as $reason) {
            $this->assertStringContainsString("'{$reason}'", $finalizationReason);
        }
    }

    public function test_all_named_foreign_keys_are_restrictive_and_target_tenant_safe_keys(): void
    {
        $foreignKeys = [
            'assessments_institution_id_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'assessments_topic_tenant_foreign' => 'FOREIGN KEY (institution_id, topic_id) REFERENCES topics(institution_id, id) ON DELETE RESTRICT',
            'assessments_teacher_tenant_foreign' => 'FOREIGN KEY (institution_id, teacher_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
            'homework_assignments_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
            'assessment_students_institution_id_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'assessment_students_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
            'assessment_students_student_tenant_foreign' => 'FOREIGN KEY (institution_id, student_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
            'assessment_students_assigner_tenant_foreign' => 'FOREIGN KEY (institution_id, assigned_by_user_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
            'assessment_attempts_institution_id_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'assessment_attempts_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
            'assessment_attempts_recipient_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_student_id) REFERENCES assessment_students(institution_id, id) ON DELETE RESTRICT',
            'assessment_attempts_student_tenant_foreign' => 'FOREIGN KEY (institution_id, student_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
            'topic_result_pairs_institution_id_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'topic_result_pairs_topic_tenant_foreign' => 'FOREIGN KEY (institution_id, topic_id) REFERENCES topics(institution_id, id) ON DELETE RESTRICT',
            'topic_result_pairs_homework_same_topic_foreign' => 'FOREIGN KEY (institution_id, topic_id, homework_assessment_id) REFERENCES assessments(institution_id, topic_id, id) ON DELETE RESTRICT',
            'topic_result_pairs_blitz_same_topic_foreign' => 'FOREIGN KEY (institution_id, topic_id, blitz_assessment_id) REFERENCES assessments(institution_id, topic_id, id) ON DELETE RESTRICT',
            'topic_result_pairs_designator_tenant_foreign' => 'FOREIGN KEY (institution_id, designated_by_user_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
        ];

        foreach ($foreignKeys as $constraint => $expectedDefinition) {
            $definition = $this->assertConstraint($constraint, 'f');

            $this->assertSame('r', $definition->confdeltype);
            $this->assertSame($expectedDefinition, $definition->definition);
        }
    }

    public function test_required_support_business_and_query_indexes_exist(): void
    {
        foreach ([
            'assessments_institution_id_id_unique' => '(institution_id, id)',
            'assessments_institution_topic_id_unique' => '(institution_id, topic_id, id)',
            'assessments_institution_topic_type_index' => '(institution_id, topic_id, type)',
            'assessments_institution_teacher_type_index' => '(institution_id, teacher_id, type)',
            'homework_assignments_institution_assessment_unique' => '(institution_id, assessment_id)',
            'homework_assignments_institution_status_deadline_index' => '(institution_id, status, deadline_at)',
            'assessment_students_institution_id_id_unique' => '(institution_id, id)',
            'assessment_students_assessment_student_unique' => '(assessment_id, student_id)',
            'assessment_students_institution_student_assessment_index' => '(institution_id, student_id, assessment_id)',
            'assessment_students_institution_assessment_index' => '(institution_id, assessment_id)',
            'assessment_attempts_institution_id_id_unique' => '(institution_id, id)',
            'assessment_attempts_assessment_student_number_unique' => '(assessment_id, student_id, attempt_number)',
            'assessment_attempts_institution_student_assessment_index' => '(institution_id, student_id, assessment_id)',
            'assessment_attempts_institution_assessment_status_index' => '(institution_id, assessment_id, status)',
            'assessment_attempts_recipient_number_index' => '(assessment_student_id, attempt_number)',
            'assessment_attempts_status_finalized_index' => '(status, finalized_at)',
            'assessment_attempts_institution_deadline_status_index' => '(institution_id, deadline_at, status)',
            'topic_result_pairs_institution_id_id_unique' => '(institution_id, id)',
            'topic_result_pairs_topic_id_unique' => '(topic_id)',
        ] as $index => $columns) {
            $this->assertStringContainsString($columns, $this->indexDefinition($index));
        }
    }

    /** @return list<array{string, string, string}> */
    private function timestampColumns(): array
    {
        return [
            ['assessments', 'created_at', 'NO'],
            ['assessments', 'updated_at', 'NO'],
            ['homework_assignments', 'deadline_at', 'YES'],
            ['homework_assignments', 'activated_at', 'YES'],
            ['homework_assignments', 'closed_at', 'YES'],
            ['homework_assignments', 'archived_at', 'YES'],
            ['homework_assignments', 'created_at', 'NO'],
            ['homework_assignments', 'updated_at', 'NO'],
            ['assessment_students', 'assigned_at', 'NO'],
            ['assessment_students', 'created_at', 'NO'],
            ['assessment_students', 'updated_at', 'NO'],
            ['assessment_attempts', 'started_at', 'NO'],
            ['assessment_attempts', 'deadline_at', 'YES'],
            ['assessment_attempts', 'submitted_at', 'YES'],
            ['assessment_attempts', 'finalized_at', 'YES'],
            ['assessment_attempts', 'locked_at', 'YES'],
            ['assessment_attempts', 'scoring_completed_at', 'YES'],
            ['assessment_attempts', 'created_at', 'NO'],
            ['assessment_attempts', 'updated_at', 'NO'],
            ['topic_result_pairs', 'designated_at', 'NO'],
            ['topic_result_pairs', 'cohort_snapshotted_at', 'YES'],
            ['topic_result_pairs', 'locked_at', 'YES'],
            ['topic_result_pairs', 'created_at', 'NO'],
            ['topic_result_pairs', 'updated_at', 'NO'],
        ];
    }

    /** @return list<string> */
    private function columnNames(string $table): array
    {
        return array_map(
            static fn (object $column): string => $column->column_name,
            DB::select(
                <<<'SQL'
                    select column_name
                    from information_schema.columns
                    where table_schema = 'public'
                      and table_name = ?
                    order by ordinal_position
                SQL,
                [$table],
            ),
        );
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
                select
                    data_type,
                    is_nullable,
                    character_maximum_length,
                    numeric_precision,
                    numeric_scale,
                    column_default
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
                select c.conname, c.contype, c.confdeltype, pg_get_constraintdef(c.oid) as definition
                from pg_constraint c
                where c.conname = ?
            SQL,
            [$constraint],
        );

        $this->assertNotNull($definition, "Constraint {$constraint} should exist.");
        $this->assertSame($expectedType, $definition->contype);

        return $definition;
    }

    private function constraintDefinition(string $constraint): string
    {
        return $this->assertConstraint($constraint, 'c')->definition;
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
