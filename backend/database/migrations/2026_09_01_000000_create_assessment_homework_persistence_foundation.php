<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('assessments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('topic_id');
            $table->uuid('teacher_id');
            $table->string('type', 20);
            $table->string('title');
            $table->text('description')->nullable();
            $table->text('student_instructions');
            $table->string('assignment_mode', 32);
            $table->decimal('total_possible_points', 14, 6);
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'assessments_institution_id_id_unique');
            $table->unique(
                ['institution_id', 'topic_id', 'id'],
                'assessments_institution_topic_id_unique',
            );
            $table->index(
                ['institution_id', 'topic_id', 'type'],
                'assessments_institution_topic_type_index',
            );
            $table->index(
                ['institution_id', 'teacher_id', 'type'],
                'assessments_institution_teacher_type_index',
            );
        });

        DB::statement("alter table assessments add constraint assessments_type_check check (type in ('homework', 'blitz'))");
        DB::statement("alter table assessments add constraint assessments_assignment_mode_check check (assignment_mode in ('group', 'selected_students'))");
        DB::statement("alter table assessments add constraint assessments_title_not_empty_check check (btrim(title) <> '')");
        DB::statement("alter table assessments add constraint assessments_instructions_not_empty_check check (btrim(student_instructions) <> '')");
        DB::statement('alter table assessments add constraint assessments_total_points_check check (total_possible_points >= 0)');
        DB::statement(
            'alter table assessments add constraint assessments_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table assessments add constraint assessments_topic_tenant_foreign foreign key (institution_id, topic_id) references topics (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table assessments add constraint assessments_teacher_tenant_foreign foreign key (institution_id, teacher_id) references users (institution_id, id) on delete restrict'
        );

        Schema::create('homework_assignments', function (Blueprint $table) {
            $table->uuid('assessment_id')->primary();
            $table->uuid('institution_id');
            $table->string('status', 20);
            $table->timestampTz('deadline_at')->nullable();
            $table->timestampTz('activated_at')->nullable();
            $table->timestampTz('closed_at')->nullable();
            $table->timestampTz('archived_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(
                ['institution_id', 'assessment_id'],
                'homework_assignments_institution_assessment_unique',
            );
            $table->index(
                ['institution_id', 'status', 'deadline_at'],
                'homework_assignments_institution_status_deadline_index',
            );
        });

        DB::statement("alter table homework_assignments add constraint homework_assignments_status_check check (status in ('draft', 'active', 'closed', 'archived'))");
        DB::statement(
            <<<'SQL'
                alter table homework_assignments add constraint homework_assignments_lifecycle_check check (
                    (status = 'draft' and activated_at is null and closed_at is null and archived_at is null)
                    or (status = 'active' and activated_at is not null and closed_at is null and archived_at is null)
                    or (status = 'closed' and activated_at is not null and closed_at is not null and archived_at is null)
                    or (
                        status = 'archived'
                        and archived_at is not null
                        and (
                            (activated_at is null and closed_at is null)
                            or (activated_at is not null and closed_at is not null)
                        )
                    )
                )
            SQL,
        );
        DB::statement(
            'alter table homework_assignments add constraint homework_assignments_activated_order_check check (activated_at is null or activated_at >= created_at)'
        );
        DB::statement(
            'alter table homework_assignments add constraint homework_assignments_closed_order_check check (closed_at is null or (activated_at is not null and closed_at >= activated_at))'
        );
        DB::statement(
            'alter table homework_assignments add constraint homework_assignments_archived_order_check check (archived_at is null or (archived_at >= created_at and (closed_at is null or archived_at >= closed_at)))'
        );
        DB::statement(
            'alter table homework_assignments add constraint homework_assignments_assessment_tenant_foreign foreign key (institution_id, assessment_id) references assessments (institution_id, id) on delete restrict'
        );

        Schema::create('assessment_students', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('assessment_id');
            $table->uuid('student_id');
            $table->string('assignment_source', 20);
            $table->timestampTz('assigned_at');
            $table->uuid('assigned_by_user_id');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'assessment_students_institution_id_id_unique');
            $table->unique(
                ['assessment_id', 'student_id'],
                'assessment_students_assessment_student_unique',
            );
            $table->index(
                ['institution_id', 'student_id', 'assessment_id'],
                'assessment_students_institution_student_assessment_index',
            );
            $table->index(
                ['institution_id', 'assessment_id'],
                'assessment_students_institution_assessment_index',
            );
        });

        DB::statement("alter table assessment_students add constraint assessment_students_source_check check (assignment_source in ('group', 'direct'))");
        DB::statement(
            'alter table assessment_students add constraint assessment_students_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table assessment_students add constraint assessment_students_assessment_tenant_foreign foreign key (institution_id, assessment_id) references assessments (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table assessment_students add constraint assessment_students_student_tenant_foreign foreign key (institution_id, student_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table assessment_students add constraint assessment_students_assigner_tenant_foreign foreign key (institution_id, assigned_by_user_id) references users (institution_id, id) on delete restrict'
        );

        Schema::create('assessment_attempts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('assessment_id');
            $table->uuid('assessment_student_id');
            $table->uuid('student_id');
            $table->smallInteger('attempt_number');
            $table->string('status', 40);
            $table->timestampTz('started_at');
            $table->timestampTz('deadline_at')->nullable();
            $table->timestampTz('submitted_at')->nullable();
            $table->timestampTz('finalized_at')->nullable();
            $table->string('finalization_reason', 40)->nullable();
            $table->timestampTz('locked_at')->nullable();
            $table->boolean('official_score_eligible')->default(true);
            $table->decimal('earned_points', 16, 8)->nullable();
            $table->decimal('possible_points', 14, 6);
            $table->decimal('normalized_score', 12, 8)->nullable();
            $table->timestampTz('scoring_completed_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'assessment_attempts_institution_id_id_unique');
            $table->unique(
                ['assessment_id', 'student_id', 'attempt_number'],
                'assessment_attempts_assessment_student_number_unique',
            );
            $table->index(
                ['institution_id', 'student_id', 'assessment_id'],
                'assessment_attempts_institution_student_assessment_index',
            );
            $table->index(
                ['institution_id', 'assessment_id', 'status'],
                'assessment_attempts_institution_assessment_status_index',
            );
            $table->index(
                ['assessment_student_id', 'attempt_number'],
                'assessment_attempts_recipient_number_index',
            );
            $table->index(
                ['status', 'finalized_at'],
                'assessment_attempts_status_finalized_index',
            );
            $table->index(
                ['institution_id', 'deadline_at', 'status'],
                'assessment_attempts_institution_deadline_status_index',
            );
        });

        DB::statement("alter table assessment_attempts add constraint assessment_attempts_status_check check (status in ('in_progress', 'submitted', 'timed_out_finalized', 'waiting_for_teacher_review', 'checked'))");
        DB::statement("alter table assessment_attempts add constraint assessment_attempts_finalization_reason_check check (finalization_reason is null or finalization_reason in ('student_submit', 'timeout_auto_submit', 'task_closed_auto_finalize', 'homework_deadline_auto_submit'))");
        DB::statement('alter table assessment_attempts add constraint assessment_attempts_number_check check (attempt_number >= 1 and attempt_number <= 3)');
        DB::statement('alter table assessment_attempts add constraint assessment_attempts_possible_points_check check (possible_points >= 0)');
        DB::statement('alter table assessment_attempts add constraint assessment_attempts_normalized_score_check check (normalized_score is null or (normalized_score >= 0 and normalized_score <= 100))');
        DB::statement('alter table assessment_attempts add constraint assessment_attempts_earned_points_check check (earned_points is null or (earned_points >= 0 and earned_points <= possible_points))');
        DB::statement('alter table assessment_attempts add constraint assessment_attempts_submitted_order_check check (submitted_at is null or submitted_at >= started_at)');
        DB::statement('alter table assessment_attempts add constraint assessment_attempts_finalized_order_check check (finalized_at is null or finalized_at >= started_at)');
        DB::statement('alter table assessment_attempts add constraint assessment_attempts_locked_order_check check (locked_at is null or locked_at >= started_at)');
        DB::statement('alter table assessment_attempts add constraint assessment_attempts_scoring_order_check check (scoring_completed_at is null or scoring_completed_at >= started_at)');
        DB::statement(
            'alter table assessment_attempts add constraint assessment_attempts_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table assessment_attempts add constraint assessment_attempts_assessment_tenant_foreign foreign key (institution_id, assessment_id) references assessments (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table assessment_attempts add constraint assessment_attempts_recipient_tenant_foreign foreign key (institution_id, assessment_student_id) references assessment_students (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table assessment_attempts add constraint assessment_attempts_student_tenant_foreign foreign key (institution_id, student_id) references users (institution_id, id) on delete restrict'
        );

        Schema::create('topic_result_pairs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('topic_id');
            $table->uuid('homework_assessment_id');
            $table->uuid('blitz_assessment_id')->nullable();
            $table->uuid('designated_by_user_id');
            $table->timestampTz('designated_at');
            $table->timestampTz('cohort_snapshotted_at')->nullable();
            $table->timestampTz('locked_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'topic_result_pairs_institution_id_id_unique');
            $table->unique('topic_id', 'topic_result_pairs_topic_id_unique');
        });

        DB::statement('alter table topic_result_pairs add constraint topic_result_pairs_distinct_assessments_check check (blitz_assessment_id is null or blitz_assessment_id <> homework_assessment_id)');
        DB::statement('alter table topic_result_pairs add constraint topic_result_pairs_cohort_order_check check (cohort_snapshotted_at is null or cohort_snapshotted_at >= designated_at)');
        DB::statement('alter table topic_result_pairs add constraint topic_result_pairs_locked_order_check check (locked_at is null or (cohort_snapshotted_at is not null and locked_at >= cohort_snapshotted_at))');
        DB::statement(
            'alter table topic_result_pairs add constraint topic_result_pairs_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table topic_result_pairs add constraint topic_result_pairs_topic_tenant_foreign foreign key (institution_id, topic_id) references topics (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table topic_result_pairs add constraint topic_result_pairs_homework_same_topic_foreign foreign key (institution_id, topic_id, homework_assessment_id) references assessments (institution_id, topic_id, id) on delete restrict'
        );
        DB::statement(
            'alter table topic_result_pairs add constraint topic_result_pairs_blitz_same_topic_foreign foreign key (institution_id, topic_id, blitz_assessment_id) references assessments (institution_id, topic_id, id) on delete restrict'
        );
        DB::statement(
            'alter table topic_result_pairs add constraint topic_result_pairs_designator_tenant_foreign foreign key (institution_id, designated_by_user_id) references users (institution_id, id) on delete restrict'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('topic_result_pairs');
        Schema::dropIfExists('assessment_attempts');
        Schema::dropIfExists('assessment_students');
        Schema::dropIfExists('homework_assignments');
        Schema::dropIfExists('assessments');
    }
};
