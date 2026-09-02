<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('questions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('assessment_id');
            $table->string('type', 40);
            $table->text('prompt');
            $table->text('instructions')->nullable();
            $table->decimal('points', 14, 6);
            $table->integer('position');
            $table->string('checking_mode', 20);
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'questions_institution_id_id_unique');
            $table->unique(['assessment_id', 'position'], 'questions_assessment_position_unique');
            $table->index(
                ['institution_id', 'assessment_id', 'type'],
                'questions_institution_assessment_type_index',
            );
        });

        DB::statement("alter table questions add constraint questions_type_check check (type in ('single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'file_based', 'matching', 'ordering', 'fill_in_blank'))");
        DB::statement("alter table questions add constraint questions_checking_mode_check check (checking_mode in ('automatic', 'manual'))");
        DB::statement("alter table questions add constraint questions_prompt_not_empty_check check (btrim(prompt) <> '')");
        DB::statement("alter table questions add constraint questions_instructions_not_empty_check check (instructions is null or btrim(instructions) <> '')");
        DB::statement('alter table questions add constraint questions_points_check check (points >= 0)');
        DB::statement('alter table questions add constraint questions_position_check check (position >= 0)');
        DB::statement(
            'alter table questions add constraint questions_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table questions add constraint questions_assessment_tenant_foreign foreign key (institution_id, assessment_id) references assessments (institution_id, id) on delete restrict'
        );

        Schema::create('question_choice_options', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('question_id');
            $table->text('option_text');
            $table->boolean('is_correct');
            $table->integer('position');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(
                ['question_id', 'position'],
                'question_choice_options_question_position_unique',
            );
            $table->index(
                ['question_id', 'is_correct'],
                'question_choice_options_question_correct_index',
            );
        });

        DB::statement("alter table question_choice_options add constraint question_choice_options_text_check check (btrim(option_text) <> '')");
        DB::statement('alter table question_choice_options add constraint question_choice_options_position_check check (position >= 0)');
        $this->addQuestionChildForeignKeys('question_choice_options');

        Schema::create('question_true_false_answers', function (Blueprint $table) {
            $table->uuid('question_id')->primary();
            $table->uuid('institution_id');
            $table->boolean('correct_value');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        $this->addQuestionChildForeignKeys('question_true_false_answers');

        Schema::create('question_short_accepted_answers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('question_id');
            $table->text('accepted_text');
            $table->integer('position');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(
                ['question_id', 'position'],
                'question_short_answers_question_position_unique',
            );
        });

        DB::statement("alter table question_short_accepted_answers add constraint question_short_answers_text_check check (btrim(accepted_text) <> '')");
        DB::statement('alter table question_short_accepted_answers add constraint question_short_answers_position_check check (position >= 0)');
        $this->addQuestionChildForeignKeys('question_short_accepted_answers', 'question_short_answers');

        Schema::create('question_matching_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('question_id');
            $table->string('side', 10);
            $table->uuid('match_key');
            $table->text('item_text');
            $table->integer('position');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(
                ['question_id', 'side', 'position'],
                'question_matching_items_question_side_position_unique',
            );
            $table->unique(
                ['question_id', 'side', 'match_key'],
                'question_matching_items_question_side_key_unique',
            );
            $table->index(
                ['question_id', 'match_key'],
                'question_matching_items_question_match_key_index',
            );
        });

        DB::statement("alter table question_matching_items add constraint question_matching_items_side_check check (side in ('left', 'right'))");
        DB::statement("alter table question_matching_items add constraint question_matching_items_text_check check (btrim(item_text) <> '')");
        DB::statement('alter table question_matching_items add constraint question_matching_items_position_check check (position >= 0)');
        $this->addQuestionChildForeignKeys('question_matching_items');

        Schema::create('question_ordering_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('question_id');
            $table->text('item_text');
            $table->integer('correct_position');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(
                ['question_id', 'correct_position'],
                'question_ordering_items_question_position_unique',
            );
        });

        DB::statement("alter table question_ordering_items add constraint question_ordering_items_text_check check (btrim(item_text) <> '')");
        DB::statement('alter table question_ordering_items add constraint question_ordering_items_position_check check (correct_position >= 0)');
        $this->addQuestionChildForeignKeys('question_ordering_items');

        Schema::create('question_fill_blanks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('question_id');
            $table->string('blank_key', 80);
            $table->integer('position');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'question_fill_blanks_institution_id_unique');
            $table->unique(['question_id', 'blank_key'], 'question_fill_blanks_question_key_unique');
            $table->unique(['question_id', 'position'], 'question_fill_blanks_question_position_unique');
        });

        DB::statement("alter table question_fill_blanks add constraint question_fill_blanks_key_check check (blank_key ~ '^[A-Za-z][A-Za-z0-9_-]{0,79}$')");
        DB::statement('alter table question_fill_blanks add constraint question_fill_blanks_position_check check (position >= 0)');
        $this->addQuestionChildForeignKeys('question_fill_blanks');

        Schema::create('question_fill_blank_accepted_answers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('blank_id');
            $table->text('accepted_text');
            $table->integer('position');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(
                ['blank_id', 'position'],
                'question_fill_answers_blank_position_unique',
            );
        });

        DB::statement("alter table question_fill_blank_accepted_answers add constraint question_fill_answers_text_check check (btrim(accepted_text) <> '')");
        DB::statement('alter table question_fill_blank_accepted_answers add constraint question_fill_answers_position_check check (position >= 0)');
        DB::statement(
            'alter table question_fill_blank_accepted_answers add constraint question_fill_answers_institution_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table question_fill_blank_accepted_answers add constraint question_fill_answers_blank_tenant_foreign foreign key (institution_id, blank_id) references question_fill_blanks (institution_id, id) on delete restrict'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('question_fill_blank_accepted_answers');
        Schema::dropIfExists('question_fill_blanks');
        Schema::dropIfExists('question_ordering_items');
        Schema::dropIfExists('question_matching_items');
        Schema::dropIfExists('question_short_accepted_answers');
        Schema::dropIfExists('question_true_false_answers');
        Schema::dropIfExists('question_choice_options');
        Schema::dropIfExists('questions');
    }

    private function addQuestionChildForeignKeys(string $table, ?string $constraintPrefix = null): void
    {
        $prefix = $constraintPrefix ?? $table;

        DB::statement(
            "alter table {$table} add constraint {$prefix}_institution_foreign foreign key (institution_id) references institutions (id) on delete restrict"
        );
        DB::statement(
            "alter table {$table} add constraint {$prefix}_question_tenant_foreign foreign key (institution_id, question_id) references questions (institution_id, id) on delete restrict"
        );
    }
};
