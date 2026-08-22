<?php

namespace Tests\Feature\Persistence;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class TopicLearningMaterialSchemaInspectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_topic_file_and_learning_material_tables_define_required_columns(): void
    {
        $requiredColumns = [
            'topics' => [
                'id',
                'institution_id',
                'group_id',
                'teacher_id',
                'title',
                'description',
                'subject',
                'student_instructions',
                'lesson_at',
                'status',
                'activated_at',
                'closed_at',
                'archived_at',
                'created_at',
                'updated_at',
            ],
            'files' => [
                'id',
                'institution_id',
                'uploaded_by_user_id',
                'category',
                'original_name',
                'storage_disk',
                'storage_key',
                'mime_type',
                'extension',
                'size_bytes',
                'checksum_sha256',
                'removed_at',
                'created_at',
                'updated_at',
            ],
            'learning_materials' => [
                'id',
                'institution_id',
                'topic_id',
                'file_id',
                'teacher_id',
                'title',
                'position',
                'removed_at',
                'created_at',
                'updated_at',
            ],
        ];

        foreach ($requiredColumns as $table => $columns) {
            $this->assertTrue(Schema::hasTable($table), "Table {$table} should exist.");
            $this->assertTrue(Schema::hasColumns($table, $columns), "Table {$table} should contain every required column.");
        }
    }

    public function test_topic_file_and_learning_material_columns_have_exact_types_nullability_and_lengths(): void
    {
        foreach ([
            ['topics', 'id'],
            ['topics', 'institution_id'],
            ['topics', 'group_id'],
            ['topics', 'teacher_id'],
            ['files', 'id'],
            ['files', 'institution_id'],
            ['files', 'uploaded_by_user_id'],
            ['learning_materials', 'id'],
            ['learning_materials', 'institution_id'],
            ['learning_materials', 'topic_id'],
            ['learning_materials', 'file_id'],
            ['learning_materials', 'teacher_id'],
        ] as [$table, $column]) {
            $this->assertColumnDefinition($table, $column, 'uuid', 'NO');
        }

        foreach ([
            ['topics', 'lesson_at', 'YES'],
            ['topics', 'activated_at', 'YES'],
            ['topics', 'closed_at', 'YES'],
            ['topics', 'archived_at', 'YES'],
            ['topics', 'created_at', 'NO'],
            ['topics', 'updated_at', 'NO'],
            ['files', 'removed_at', 'YES'],
            ['files', 'created_at', 'NO'],
            ['files', 'updated_at', 'NO'],
            ['learning_materials', 'removed_at', 'YES'],
            ['learning_materials', 'created_at', 'NO'],
            ['learning_materials', 'updated_at', 'NO'],
        ] as [$table, $column, $nullability]) {
            $this->assertColumnDefinition($table, $column, 'timestamp with time zone', $nullability);
        }

        foreach ([
            ['topics', 'title', 'NO', 255],
            ['topics', 'subject', 'NO', 160],
            ['topics', 'status', 'NO', 20],
            ['files', 'category', 'NO', 32],
            ['files', 'original_name', 'NO', 500],
            ['files', 'storage_disk', 'NO', 100],
            ['files', 'mime_type', 'NO', 160],
            ['files', 'extension', 'NO', 20],
            ['learning_materials', 'title', 'YES', 255],
        ] as [$table, $column, $nullability, $maximumLength]) {
            $definition = $this->column($table, $column);

            $this->assertSame('character varying', $definition->data_type);
            $this->assertSame($nullability, $definition->is_nullable);
            $this->assertSame($maximumLength, (int) $definition->character_maximum_length);
        }

        foreach ([
            ['topics', 'description', 'YES'],
            ['topics', 'student_instructions', 'NO'],
            ['files', 'storage_key', 'NO'],
        ] as [$table, $column, $nullability]) {
            $this->assertColumnDefinition($table, $column, 'text', $nullability);
        }

        $checksum = $this->column('files', 'checksum_sha256');
        $this->assertSame('character', $checksum->data_type);
        $this->assertSame('YES', $checksum->is_nullable);
        $this->assertSame(64, (int) $checksum->character_maximum_length);

        $this->assertColumnDefinition('files', 'size_bytes', 'bigint', 'NO');
        $this->assertColumnDefinition('learning_materials', 'position', 'integer', 'NO');
        $this->assertSame('0', $this->column('learning_materials', 'position')->column_default);
    }

    public function test_required_named_constraints_exist_and_all_foreign_keys_are_restrictive(): void
    {
        foreach ([
            'topics_title_not_empty_check',
            'topics_subject_not_empty_check',
            'topics_student_instructions_not_empty_check',
            'topics_status_check',
            'topics_lifecycle_consistency_check',
            'topics_activated_at_order_check',
            'topics_closed_at_order_check',
            'topics_archived_at_order_check',
            'files_category_check',
            'files_extension_check',
            'files_original_name_not_empty_check',
            'files_storage_disk_not_empty_check',
            'files_storage_key_not_empty_check',
            'files_mime_type_not_empty_check',
            'files_size_positive_check',
            'files_category_size_limit_check',
            'files_checksum_sha256_check',
            'files_removed_at_order_check',
            'learning_materials_title_not_empty_check',
            'learning_materials_position_check',
            'learning_materials_removed_at_order_check',
        ] as $constraint) {
            $this->assertConstraint($constraint, 'c');
        }

        foreach ([
            'topics_institution_id_id_unique',
            'files_institution_id_id_unique',
            'files_storage_disk_storage_key_unique',
            'learning_materials_institution_id_id_unique',
            'learning_materials_file_id_unique',
        ] as $constraint) {
            $this->assertConstraint($constraint, 'u');
        }

        foreach ([
            'topics_institution_id_foreign',
            'topics_group_tenant_foreign',
            'topics_teacher_tenant_foreign',
            'files_institution_id_foreign',
            'files_uploader_tenant_foreign',
            'learning_materials_institution_id_foreign',
            'learning_materials_topic_tenant_foreign',
            'learning_materials_file_tenant_foreign',
            'learning_materials_teacher_tenant_foreign',
        ] as $constraint) {
            $definition = $this->assertConstraint($constraint, 'f');

            $this->assertSame('r', $definition->confdeltype, "Foreign key {$constraint} should use ON DELETE RESTRICT.");
        }
    }

    public function test_required_support_unique_and_query_indexes_exist(): void
    {
        foreach ([
            'topics_institution_id_id_unique' => '(institution_id, id)',
            'topics_institution_group_status_index' => '(institution_id, group_id, status)',
            'topics_institution_teacher_status_index' => '(institution_id, teacher_id, status)',
            'topics_institution_status_created_index' => '(institution_id, status, created_at)',
            'topics_institution_lower_title_index' => '(institution_id, lower((title)::text))',
            'files_institution_id_id_unique' => '(institution_id, id)',
            'files_storage_disk_storage_key_unique' => '(storage_disk, storage_key)',
            'files_institution_category_created_index' => '(institution_id, category, created_at)',
            'files_uploaded_by_user_id_index' => '(uploaded_by_user_id)',
            'learning_materials_institution_id_id_unique' => '(institution_id, id)',
            'learning_materials_file_id_unique' => '(file_id)',
            'learning_materials_institution_topic_removed_index' => '(institution_id, topic_id, removed_at)',
        ] as $index => $columns) {
            $this->assertStringContainsString($columns, $this->indexDefinition($index));
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
                select data_type, is_nullable, character_maximum_length, column_default
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
