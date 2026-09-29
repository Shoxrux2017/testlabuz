<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('official_task_scores', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('assessment_id');
            $table->uuid('student_id');
            $table->uuid('official_attempt_id');
            $table->decimal('normalized_score', 12, 8);
            $table->string('selection_policy_code', 64);
            $table->uuid('selected_by_user_id')->nullable();
            $table->timestampTz('selected_at');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['assessment_id', 'student_id'], 'official_task_scores_assessment_student_unique');
            $table->unique('official_attempt_id', 'official_task_scores_official_attempt_unique');
        });

        DB::statement('alter table official_task_scores add constraint official_task_scores_normalized_score_check check (normalized_score >= 0 and normalized_score <= 100)');
        DB::statement("alter table official_task_scores add constraint official_task_scores_selection_policy_check check (selection_policy_code in ('highest_valid_completed', 'valid_normal_blitz', 'approved_blitz_exception_replacement'))");
        // The resolver selects deterministically; a Teacher never chooses the official Attempt.
        DB::statement('alter table official_task_scores add constraint official_task_scores_no_selecting_user_check check (selected_by_user_id is null)');
        DB::statement(
            'alter table official_task_scores add constraint official_task_scores_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table official_task_scores add constraint official_task_scores_assessment_tenant_foreign foreign key (institution_id, assessment_id) references assessments (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table official_task_scores add constraint official_task_scores_student_tenant_foreign foreign key (institution_id, student_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table official_task_scores add constraint official_task_scores_attempt_tenant_foreign foreign key (institution_id, official_attempt_id) references assessment_attempts (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table official_task_scores add constraint official_task_scores_selector_tenant_foreign foreign key (institution_id, selected_by_user_id) references users (institution_id, id) on delete restrict'
        );

        Schema::table('homework_assignments', function (Blueprint $table) {
            $table->timestampTz('review_due_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('homework_assignments', function (Blueprint $table) {
            $table->dropColumn('review_due_at');
        });

        Schema::dropIfExists('official_task_scores');
    }
};
