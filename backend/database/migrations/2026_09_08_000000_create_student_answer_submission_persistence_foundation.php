<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        foreach (['question_choice_options', 'question_matching_items', 'question_ordering_items'] as $table) {
            Schema::table($table, function (Blueprint $blueprint) use ($table) {
                $blueprint->unique(['institution_id', 'id'], "{$table}_institution_id_unique");
            });
        }

        DB::statement("create unique index assessment_attempts_one_in_progress_per_student_unique on assessment_attempts (assessment_id, student_id) where status = 'in_progress'");

        Schema::create('attempt_answers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('attempt_id');
            $table->uuid('question_id');
            $table->string('checking_status', 30)->default('pending');
            $table->decimal('awarded_points', 16, 8)->nullable();
            $table->text('feedback')->nullable();
            $table->uuid('checked_by_user_id')->nullable();
            $table->timestampTz('checked_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'attempt_answers_institution_id_unique');
            $table->unique(['attempt_id', 'question_id'], 'attempt_answers_attempt_question_unique');
            $table->index(['institution_id', 'checking_status', 'checked_at'], 'attempt_answers_institution_checking_checked_index');
        });

        DB::statement("alter table attempt_answers add constraint attempt_answers_checking_status_check check (checking_status in ('pending', 'auto_checked', 'waiting_for_teacher_review', 'teacher_checked'))");
        DB::statement('alter table attempt_answers add constraint attempt_answers_awarded_points_check check (awarded_points is null or awarded_points >= 0)');
        $this->addInstitutionForeignKey('attempt_answers');
        $this->addTenantForeignKey('attempt_answers', 'attempt_id', 'assessment_attempts', 'attempt_answers_attempt_tenant_foreign');
        $this->addTenantForeignKey('attempt_answers', 'question_id', 'questions', 'attempt_answers_question_tenant_foreign');
        $this->addTenantForeignKey('attempt_answers', 'checked_by_user_id', 'users', 'attempt_answers_checker_tenant_foreign');

        Schema::create('answer_choice_selections', function (Blueprint $table) {
            $table->uuid('answer_id');
            $table->uuid('option_id');
            $table->uuid('institution_id');
            $table->timestampTz('created_at');

            $table->primary(['answer_id', 'option_id']);
        });

        $this->addAnswerChildForeignKeys('answer_choice_selections');
        $this->addTenantForeignKey('answer_choice_selections', 'option_id', 'question_choice_options', 'answer_choice_selections_option_tenant_foreign');

        Schema::create('answer_text_values', function (Blueprint $table) {
            $table->uuid('answer_id')->primary();
            $table->uuid('institution_id');
            $table->text('text_value');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        $this->addAnswerChildForeignKeys('answer_text_values');

        Schema::create('answer_boolean_values', function (Blueprint $table) {
            $table->uuid('answer_id')->primary();
            $table->uuid('institution_id');
            $table->boolean('boolean_value');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        $this->addAnswerChildForeignKeys('answer_boolean_values');

        Schema::create('answer_matching_pairs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('answer_id');
            $table->uuid('left_item_id');
            $table->uuid('right_item_id');
            $table->timestampTz('created_at');

            $table->unique(['institution_id', 'id'], 'answer_matching_pairs_institution_id_unique');
            $table->unique(['answer_id', 'left_item_id'], 'answer_matching_pairs_answer_left_unique');
            $table->unique(['answer_id', 'right_item_id'], 'answer_matching_pairs_answer_right_unique');
        });

        $this->addAnswerChildForeignKeys('answer_matching_pairs');
        $this->addTenantForeignKey('answer_matching_pairs', 'left_item_id', 'question_matching_items', 'answer_matching_pairs_left_tenant_foreign');
        $this->addTenantForeignKey('answer_matching_pairs', 'right_item_id', 'question_matching_items', 'answer_matching_pairs_right_tenant_foreign');

        Schema::create('answer_ordering_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('answer_id');
            $table->uuid('ordering_item_id');
            $table->integer('submitted_position');
            $table->timestampTz('created_at');

            $table->unique(['institution_id', 'id'], 'answer_ordering_items_institution_id_unique');
            $table->unique(['answer_id', 'ordering_item_id'], 'answer_ordering_items_answer_item_unique');
            $table->unique(['answer_id', 'submitted_position'], 'answer_ordering_items_answer_position_unique');
        });

        DB::statement('alter table answer_ordering_items add constraint answer_ordering_items_position_check check (submitted_position >= 0)');
        $this->addAnswerChildForeignKeys('answer_ordering_items');
        $this->addTenantForeignKey('answer_ordering_items', 'ordering_item_id', 'question_ordering_items', 'answer_ordering_items_item_tenant_foreign');

        Schema::create('answer_fill_blank_values', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('answer_id');
            $table->uuid('blank_id');
            $table->text('text_value');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'answer_fill_blank_values_institution_id_unique');
            $table->unique(['answer_id', 'blank_id'], 'answer_fill_blank_values_answer_blank_unique');
        });

        $this->addAnswerChildForeignKeys('answer_fill_blank_values');
        $this->addTenantForeignKey('answer_fill_blank_values', 'blank_id', 'question_fill_blanks', 'answer_fill_blank_values_blank_tenant_foreign');

        Schema::create('answer_files', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('answer_id');
            $table->uuid('file_id');
            $table->timestampTz('created_at');

            $table->unique(['institution_id', 'id'], 'answer_files_institution_id_unique');
            $table->unique('answer_id', 'answer_files_answer_unique');
            $table->unique('file_id', 'answer_files_file_unique');
        });

        $this->addAnswerChildForeignKeys('answer_files');
        $this->addTenantForeignKey('answer_files', 'file_id', 'files', 'answer_files_file_tenant_foreign');

        Schema::create('idempotency_records', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('user_id');
            $table->string('operation', 80);
            $table->uuid('idempotency_key');
            $table->char('request_fingerprint', 64);
            $table->string('result_resource_type', 80)->nullable();
            $table->uuid('result_resource_id')->nullable();
            $table->smallInteger('response_status')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'idempotency_records_institution_id_unique');
            $table->unique(['institution_id', 'user_id', 'operation', 'idempotency_key'], 'idempotency_records_scope_key_unique');
            $table->index(['institution_id', 'user_id', 'operation', 'created_at'], 'idempotency_records_lookup_index');
        });

        DB::statement("alter table idempotency_records add constraint idempotency_records_operation_check check (btrim(operation) <> '')");
        DB::statement("alter table idempotency_records add constraint idempotency_records_fingerprint_check check (request_fingerprint ~ '^[0-9a-f]{64}$')");
        DB::statement("alter table idempotency_records add constraint idempotency_records_resource_type_check check (result_resource_type is null or btrim(result_resource_type) <> '')");
        DB::statement('alter table idempotency_records add constraint idempotency_records_response_status_check check (response_status is null or response_status between 200 and 299)');
        DB::statement(<<<'SQL'
            alter table idempotency_records
            add constraint idempotency_records_completion_shape_check check (
                (
                    completed_at is null
                    and result_resource_type is null
                    and result_resource_id is null
                    and response_status is null
                )
                or (
                    completed_at is not null
                    and result_resource_type is not null
                    and result_resource_id is not null
                    and response_status is not null
                )
            )
        SQL);
        DB::statement('alter table idempotency_records add constraint idempotency_records_completed_at_check check (completed_at is null or completed_at >= created_at)');
        $this->addInstitutionForeignKey('idempotency_records');
        $this->addTenantForeignKey('idempotency_records', 'user_id', 'users', 'idempotency_records_user_tenant_foreign');
    }

    public function down(): void
    {
        Schema::dropIfExists('idempotency_records');
        Schema::dropIfExists('answer_files');
        Schema::dropIfExists('answer_fill_blank_values');
        Schema::dropIfExists('answer_ordering_items');
        Schema::dropIfExists('answer_matching_pairs');
        Schema::dropIfExists('answer_boolean_values');
        Schema::dropIfExists('answer_text_values');
        Schema::dropIfExists('answer_choice_selections');
        Schema::dropIfExists('attempt_answers');

        DB::statement('drop index assessment_attempts_one_in_progress_per_student_unique');

        foreach (['question_ordering_items', 'question_matching_items', 'question_choice_options'] as $table) {
            Schema::table($table, function (Blueprint $blueprint) use ($table) {
                $blueprint->dropUnique("{$table}_institution_id_unique");
            });
        }
    }

    private function addInstitutionForeignKey(string $table): void
    {
        DB::statement("alter table {$table} add constraint {$table}_institution_foreign foreign key (institution_id) references institutions (id) on delete restrict");
    }

    private function addAnswerChildForeignKeys(string $table): void
    {
        $this->addInstitutionForeignKey($table);
        $this->addTenantForeignKey($table, 'answer_id', 'attempt_answers', "{$table}_answer_tenant_foreign");
    }

    private function addTenantForeignKey(string $table, string $column, string $parent, string $constraint): void
    {
        DB::statement("alter table {$table} add constraint {$constraint} foreign key (institution_id, {$column}) references {$parent} (institution_id, id) on delete restrict");
    }
};
