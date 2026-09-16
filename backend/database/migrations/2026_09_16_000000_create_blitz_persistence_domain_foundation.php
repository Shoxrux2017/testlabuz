<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('blitz_tasks', function (Blueprint $table) {
            $table->uuid('assessment_id')->primary();
            $table->uuid('institution_id');
            $table->string('status', 20);
            $table->integer('duration_seconds');
            $table->timestampTz('scheduled_at')->nullable();
            $table->string('timer_start_mode_snapshot', 24)->nullable();
            $table->timestampTz('activated_at')->nullable();
            $table->timestampTz('synchronized_ends_at')->nullable();
            $table->timestampTz('closed_at')->nullable();
            $table->timestampTz('archived_at')->nullable();
            $table->uuid('activated_by_user_id')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(
                ['institution_id', 'assessment_id'],
                'blitz_tasks_institution_assessment_unique',
            );
            $table->index(
                ['institution_id', 'status', 'scheduled_at'],
                'blitz_tasks_institution_status_scheduled_index',
            );
            $table->index(
                ['institution_id', 'activated_at'],
                'blitz_tasks_institution_activated_index',
            );
            $table->index(
                ['institution_id', 'synchronized_ends_at'],
                'blitz_tasks_institution_synchronized_ends_index',
            );
        });

        DB::statement("alter table blitz_tasks add constraint blitz_tasks_status_check check (status in ('draft', 'scheduled', 'active', 'closed', 'archived'))");
        DB::statement('alter table blitz_tasks add constraint blitz_tasks_duration_check check (duration_seconds > 0)');
        DB::statement("alter table blitz_tasks add constraint blitz_tasks_timer_mode_check check (timer_start_mode_snapshot is null or timer_start_mode_snapshot in ('synchronized', 'individual'))");
        DB::statement(
            <<<'SQL'
                alter table blitz_tasks add constraint blitz_tasks_lifecycle_check check (
                    (
                        status = 'draft'
                        and timer_start_mode_snapshot is null
                        and activated_at is null
                        and synchronized_ends_at is null
                        and closed_at is null
                        and archived_at is null
                        and activated_by_user_id is null
                    )
                    or (
                        status = 'scheduled'
                        and scheduled_at is not null
                        and timer_start_mode_snapshot is null
                        and activated_at is null
                        and synchronized_ends_at is null
                        and closed_at is null
                        and archived_at is null
                        and activated_by_user_id is null
                    )
                    or (
                        status = 'active'
                        and timer_start_mode_snapshot is not null
                        and activated_at is not null
                        and activated_by_user_id is not null
                        and closed_at is null
                        and archived_at is null
                    )
                    or (
                        status = 'closed'
                        and timer_start_mode_snapshot is not null
                        and activated_at is not null
                        and activated_by_user_id is not null
                        and closed_at is not null
                        and archived_at is null
                    )
                    or (
                        status = 'archived'
                        and archived_at is not null
                        and (
                            (
                                activated_at is null
                                and activated_by_user_id is null
                                and timer_start_mode_snapshot is null
                                and synchronized_ends_at is null
                                and closed_at is null
                            )
                            or (
                                activated_at is not null
                                and activated_by_user_id is not null
                                and timer_start_mode_snapshot is not null
                                and closed_at is not null
                            )
                        )
                    )
                )
            SQL,
        );
        DB::statement(
            <<<'SQL'
                alter table blitz_tasks add constraint blitz_tasks_timer_shape_check check (
                    (
                        timer_start_mode_snapshot is null
                        and activated_at is null
                        and activated_by_user_id is null
                        and synchronized_ends_at is null
                    )
                    or (
                        timer_start_mode_snapshot is not null
                        and timer_start_mode_snapshot = 'synchronized'
                        and activated_at is not null
                        and activated_by_user_id is not null
                        and synchronized_ends_at is not null
                        and synchronized_ends_at = activated_at + duration_seconds * interval '1 second'
                    )
                    or (
                        timer_start_mode_snapshot is not null
                        and timer_start_mode_snapshot = 'individual'
                        and activated_at is not null
                        and activated_by_user_id is not null
                        and synchronized_ends_at is null
                    )
                )
            SQL,
        );
        DB::statement(
            'alter table blitz_tasks add constraint blitz_tasks_activated_order_check check (activated_at is null or activated_at >= created_at)'
        );
        DB::statement(
            'alter table blitz_tasks add constraint blitz_tasks_closed_order_check check (closed_at is null or (activated_at is not null and closed_at >= activated_at))'
        );
        DB::statement(
            'alter table blitz_tasks add constraint blitz_tasks_archived_order_check check (archived_at is null or (archived_at >= created_at and (closed_at is null or archived_at >= closed_at)))'
        );
        DB::statement(
            'alter table blitz_tasks add constraint blitz_tasks_assessment_tenant_foreign foreign key (institution_id, assessment_id) references assessments (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table blitz_tasks add constraint blitz_tasks_activator_tenant_foreign foreign key (institution_id, activated_by_user_id) references users (institution_id, id) on delete restrict'
        );

        Schema::create('blitz_attempt_exceptions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('assessment_id');
            $table->uuid('assessment_student_id');
            $table->uuid('student_id');
            $table->uuid('invalidated_attempt_id');
            $table->uuid('replacement_attempt_id')->nullable();
            $table->string('reason_type', 24);
            $table->text('reason');
            $table->uuid('granted_by_user_id');
            $table->timestampTz('granted_at');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(
                ['assessment_id', 'student_id'],
                'blitz_attempt_exceptions_assessment_student_unique',
            );
            $table->unique('invalidated_attempt_id', 'blitz_attempt_exceptions_invalidated_attempt_unique');
            $table->unique('replacement_attempt_id', 'blitz_attempt_exceptions_replacement_attempt_unique');
            $table->index(
                ['institution_id', 'assessment_id', 'student_id'],
                'blitz_attempt_exceptions_institution_assessment_student_index',
            );
        });

        DB::statement("alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_reason_type_check check (reason_type in ('technical', 'other_valid'))");
        DB::statement("alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_reason_not_empty_check check (btrim(reason) <> '')");
        DB::statement('alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_distinct_attempts_check check (replacement_attempt_id is null or replacement_attempt_id <> invalidated_attempt_id)');
        DB::statement(
            'alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_assessment_tenant_foreign foreign key (institution_id, assessment_id) references assessments (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_recipient_tenant_foreign foreign key (institution_id, assessment_student_id) references assessment_students (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_student_tenant_foreign foreign key (institution_id, student_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_invalidated_attempt_tenant_foreign foreign key (institution_id, invalidated_attempt_id) references assessment_attempts (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_replacement_attempt_tenant_foreign foreign key (institution_id, replacement_attempt_id) references assessment_attempts (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table blitz_attempt_exceptions add constraint blitz_attempt_exceptions_grantor_tenant_foreign foreign key (institution_id, granted_by_user_id) references users (institution_id, id) on delete restrict'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('blitz_attempt_exceptions');
        Schema::dropIfExists('blitz_tasks');
    }
};
