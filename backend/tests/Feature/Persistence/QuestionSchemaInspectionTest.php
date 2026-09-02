<?php

namespace Tests\Feature\Persistence;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class QuestionSchemaInspectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_question_tables_define_exact_normalized_columns_without_generic_configuration_or_student_answers(): void
    {
        $expectedColumns = [
            'questions' => ['id', 'institution_id', 'assessment_id', 'type', 'prompt', 'instructions', 'points', 'position', 'checking_mode', 'created_at', 'updated_at'],
            'question_choice_options' => ['id', 'institution_id', 'question_id', 'option_text', 'is_correct', 'position', 'created_at', 'updated_at'],
            'question_true_false_answers' => ['question_id', 'institution_id', 'correct_value', 'created_at', 'updated_at'],
            'question_short_accepted_answers' => ['id', 'institution_id', 'question_id', 'accepted_text', 'position', 'created_at', 'updated_at'],
            'question_matching_items' => ['id', 'institution_id', 'question_id', 'side', 'match_key', 'item_text', 'position', 'created_at', 'updated_at'],
            'question_ordering_items' => ['id', 'institution_id', 'question_id', 'item_text', 'correct_position', 'created_at', 'updated_at'],
            'question_fill_blanks' => ['id', 'institution_id', 'question_id', 'blank_key', 'position', 'created_at', 'updated_at'],
            'question_fill_blank_accepted_answers' => ['id', 'institution_id', 'blank_id', 'accepted_text', 'position', 'created_at', 'updated_at'],
        ];

        foreach ($expectedColumns as $table => $columns) {
            $this->assertTrue(Schema::hasTable($table));
            $this->assertSame($columns, $this->columnNames($table));
        }

        foreach (['configuration', 'correct_answer', 'options', 'max_selections', 'time_limit_seconds', 'negative_points'] as $column) {
            $this->assertFalse(Schema::hasColumn('questions', $column));
        }

        foreach (['question_answers', 'student_answers', 'attempt_answers', 'question_scores'] as $table) {
            $this->assertFalse(Schema::hasTable($table));
        }
    }

    public function test_columns_have_required_postgresql_types_nullability_lengths_and_precision(): void
    {
        foreach ([
            ['questions', 'id'], ['questions', 'institution_id'], ['questions', 'assessment_id'],
            ['question_choice_options', 'id'], ['question_choice_options', 'institution_id'], ['question_choice_options', 'question_id'],
            ['question_true_false_answers', 'question_id'], ['question_true_false_answers', 'institution_id'],
            ['question_short_accepted_answers', 'id'], ['question_short_accepted_answers', 'institution_id'], ['question_short_accepted_answers', 'question_id'],
            ['question_matching_items', 'id'], ['question_matching_items', 'institution_id'], ['question_matching_items', 'question_id'], ['question_matching_items', 'match_key'],
            ['question_ordering_items', 'id'], ['question_ordering_items', 'institution_id'], ['question_ordering_items', 'question_id'],
            ['question_fill_blanks', 'id'], ['question_fill_blanks', 'institution_id'], ['question_fill_blanks', 'question_id'],
            ['question_fill_blank_accepted_answers', 'id'], ['question_fill_blank_accepted_answers', 'institution_id'], ['question_fill_blank_accepted_answers', 'blank_id'],
        ] as [$table, $column]) {
            $this->assertColumnDefinition($table, $column, 'uuid', 'NO');
        }

        foreach ([
            ['questions', 'type', 40],
            ['questions', 'checking_mode', 20],
            ['question_matching_items', 'side', 10],
            ['question_fill_blanks', 'blank_key', 80],
        ] as [$table, $column, $length]) {
            $definition = $this->column($table, $column);
            $this->assertSame('character varying', $definition->data_type);
            $this->assertSame('NO', $definition->is_nullable);
            $this->assertSame($length, (int) $definition->character_maximum_length);
        }

        foreach ([
            ['questions', 'prompt', 'NO'], ['questions', 'instructions', 'YES'],
            ['question_choice_options', 'option_text', 'NO'],
            ['question_short_accepted_answers', 'accepted_text', 'NO'],
            ['question_matching_items', 'item_text', 'NO'],
            ['question_ordering_items', 'item_text', 'NO'],
            ['question_fill_blank_accepted_answers', 'accepted_text', 'NO'],
        ] as [$table, $column, $nullability]) {
            $this->assertColumnDefinition($table, $column, 'text', $nullability);
        }

        $points = $this->column('questions', 'points');
        $this->assertSame('numeric', $points->data_type);
        $this->assertSame(14, (int) $points->numeric_precision);
        $this->assertSame(6, (int) $points->numeric_scale);

        foreach ([
            ['questions', 'position'], ['question_choice_options', 'position'],
            ['question_short_accepted_answers', 'position'], ['question_matching_items', 'position'],
            ['question_ordering_items', 'correct_position'], ['question_fill_blanks', 'position'],
            ['question_fill_blank_accepted_answers', 'position'],
        ] as [$table, $column]) {
            $this->assertColumnDefinition($table, $column, 'integer', 'NO');
        }

        $this->assertColumnDefinition('question_choice_options', 'is_correct', 'boolean', 'NO');
        $this->assertColumnDefinition('question_true_false_answers', 'correct_value', 'boolean', 'NO');

        foreach (array_keys($this->tableColumns()) as $table) {
            $this->assertColumnDefinition($table, 'created_at', 'timestamp with time zone', 'NO');
            $this->assertColumnDefinition($table, 'updated_at', 'timestamp with time zone', 'NO');
        }
    }

    public function test_named_checks_and_unique_constraints_encode_required_structural_rules(): void
    {
        foreach ([
            'questions_type_check', 'questions_checking_mode_check', 'questions_prompt_not_empty_check',
            'questions_instructions_not_empty_check', 'questions_points_check', 'questions_position_check',
            'question_choice_options_text_check', 'question_choice_options_position_check',
            'question_short_answers_text_check', 'question_short_answers_position_check',
            'question_matching_items_side_check', 'question_matching_items_text_check', 'question_matching_items_position_check',
            'question_ordering_items_text_check', 'question_ordering_items_position_check',
            'question_fill_blanks_key_check', 'question_fill_blanks_position_check',
            'question_fill_answers_text_check', 'question_fill_answers_position_check',
        ] as $constraint) {
            $this->assertConstraint($constraint, 'c');
        }

        foreach ([
            'questions_institution_id_id_unique', 'questions_assessment_position_unique',
            'question_choice_options_question_position_unique',
            'question_short_answers_question_position_unique',
            'question_matching_items_question_side_position_unique',
            'question_matching_items_question_side_key_unique',
            'question_ordering_items_question_position_unique',
            'question_fill_blanks_institution_id_unique',
            'question_fill_blanks_question_key_unique',
            'question_fill_blanks_question_position_unique',
            'question_fill_answers_blank_position_unique',
        ] as $constraint) {
            $this->assertConstraint($constraint, 'u');
        }

        $types = $this->constraintDefinition('questions_type_check');
        foreach (['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'file_based', 'matching', 'ordering', 'fill_in_blank'] as $type) {
            $this->assertStringContainsString("'{$type}'", $types);
        }

        $modes = $this->constraintDefinition('questions_checking_mode_check');
        $this->assertStringContainsString("'automatic'", $modes);
        $this->assertStringContainsString("'manual'", $modes);
        $this->assertStringContainsString('^[A-Za-z][A-Za-z0-9_-]{0,79}$', $this->constraintDefinition('question_fill_blanks_key_check'));
    }

    public function test_all_question_foreign_keys_are_restrictive_and_tenant_safe(): void
    {
        $foreignKeys = [
            'questions_institution_id_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'questions_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
            'question_choice_options_institution_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'question_choice_options_question_tenant_foreign' => 'FOREIGN KEY (institution_id, question_id) REFERENCES questions(institution_id, id) ON DELETE RESTRICT',
            'question_true_false_answers_institution_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'question_true_false_answers_question_tenant_foreign' => 'FOREIGN KEY (institution_id, question_id) REFERENCES questions(institution_id, id) ON DELETE RESTRICT',
            'question_short_answers_institution_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'question_short_answers_question_tenant_foreign' => 'FOREIGN KEY (institution_id, question_id) REFERENCES questions(institution_id, id) ON DELETE RESTRICT',
            'question_matching_items_institution_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'question_matching_items_question_tenant_foreign' => 'FOREIGN KEY (institution_id, question_id) REFERENCES questions(institution_id, id) ON DELETE RESTRICT',
            'question_ordering_items_institution_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'question_ordering_items_question_tenant_foreign' => 'FOREIGN KEY (institution_id, question_id) REFERENCES questions(institution_id, id) ON DELETE RESTRICT',
            'question_fill_blanks_institution_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'question_fill_blanks_question_tenant_foreign' => 'FOREIGN KEY (institution_id, question_id) REFERENCES questions(institution_id, id) ON DELETE RESTRICT',
            'question_fill_answers_institution_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'question_fill_answers_blank_tenant_foreign' => 'FOREIGN KEY (institution_id, blank_id) REFERENCES question_fill_blanks(institution_id, id) ON DELETE RESTRICT',
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
            'questions_institution_id_id_unique' => '(institution_id, id)',
            'questions_assessment_position_unique' => '(assessment_id, "position")',
            'questions_institution_assessment_type_index' => '(institution_id, assessment_id, type)',
            'question_choice_options_question_position_unique' => '(question_id, "position")',
            'question_choice_options_question_correct_index' => '(question_id, is_correct)',
            'question_matching_items_question_side_position_unique' => '(question_id, side, "position")',
            'question_matching_items_question_side_key_unique' => '(question_id, side, match_key)',
            'question_matching_items_question_match_key_index' => '(question_id, match_key)',
            'question_fill_blanks_institution_id_unique' => '(institution_id, id)',
        ] as $index => $columns) {
            $this->assertStringContainsString($columns, $this->indexDefinition($index));
        }
    }

    /** @return array<string, list<string>> */
    private function tableColumns(): array
    {
        return [
            'questions' => [], 'question_choice_options' => [], 'question_true_false_answers' => [],
            'question_short_accepted_answers' => [], 'question_matching_items' => [],
            'question_ordering_items' => [], 'question_fill_blanks' => [],
            'question_fill_blank_accepted_answers' => [],
        ];
    }

    /** @return list<string> */
    private function columnNames(string $table): array
    {
        return array_map(
            static fn (object $column): string => $column->column_name,
            DB::select("select column_name from information_schema.columns where table_schema = 'public' and table_name = ? order by ordinal_position", [$table]),
        );
    }

    private function assertColumnDefinition(string $table, string $column, string $type, string $nullability): void
    {
        $definition = $this->column($table, $column);
        $this->assertSame($type, $definition->data_type);
        $this->assertSame($nullability, $definition->is_nullable);
    }

    private function column(string $table, string $column): object
    {
        $definition = DB::selectOne(
            "select data_type, is_nullable, character_maximum_length, numeric_precision, numeric_scale from information_schema.columns where table_schema = 'public' and table_name = ? and column_name = ?",
            [$table, $column],
        );
        $this->assertNotNull($definition, "Column {$table}.{$column} should exist.");

        return $definition;
    }

    private function assertConstraint(string $constraint, string $type): object
    {
        $definition = DB::selectOne('select contype, confdeltype, pg_get_constraintdef(oid) as definition from pg_constraint where conname = ?', [$constraint]);
        $this->assertNotNull($definition, "Constraint {$constraint} should exist.");
        $this->assertSame($type, $definition->contype);

        return $definition;
    }

    private function constraintDefinition(string $constraint): string
    {
        return $this->assertConstraint($constraint, 'c')->definition;
    }

    private function indexDefinition(string $index): string
    {
        $definition = DB::selectOne("select indexdef from pg_indexes where schemaname = 'public' and indexname = ?", [$index]);
        $this->assertNotNull($definition, "Index {$index} should exist.");

        return $definition->indexdef;
    }
}
