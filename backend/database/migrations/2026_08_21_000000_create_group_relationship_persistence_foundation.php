<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement(
            'alter table users add constraint users_institution_id_id_unique unique (institution_id, id)'
        );

        Schema::create('groups', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->string('name', 160);
            $table->string('level', 100)->nullable();
            $table->string('subject_direction', 160)->nullable();
            $table->text('description')->nullable();
            $table->string('status', 20);
            $table->uuid('created_by_user_id');
            $table->timestampTz('archived_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'groups_institution_id_id_unique');
            $table->index(['institution_id', 'status'], 'groups_institution_status_index');
        });

        DB::statement("alter table groups add constraint groups_name_not_empty_check check (btrim(name) <> '')");
        DB::statement("alter table groups add constraint groups_status_check check (status in ('active', 'archived'))");
        DB::statement(
            "alter table groups add constraint groups_status_archived_at_check check ((status = 'active' and archived_at is null) or (status = 'archived' and archived_at is not null))"
        );
        DB::statement(
            'alter table groups add constraint groups_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table groups add constraint groups_institution_creator_foreign foreign key (institution_id, created_by_user_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement('create index groups_institution_lower_name_index on groups (institution_id, lower(name))');

        Schema::create('group_teacher_memberships', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('group_id');
            $table->uuid('teacher_id');
            $table->uuid('assigned_by_user_id');
            $table->timestampTz('started_at');
            $table->timestampTz('ended_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(
                ['institution_id', 'teacher_id', 'ended_at'],
                'group_teacher_memberships_institution_teacher_ended_index',
            );
            $table->index(
                ['institution_id', 'group_id', 'ended_at'],
                'group_teacher_memberships_institution_group_ended_index',
            );
        });

        DB::statement(
            'alter table group_teacher_memberships add constraint group_teacher_memberships_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table group_teacher_memberships add constraint group_teacher_memberships_group_tenant_foreign foreign key (institution_id, group_id) references groups (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table group_teacher_memberships add constraint group_teacher_memberships_teacher_tenant_foreign foreign key (institution_id, teacher_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table group_teacher_memberships add constraint group_teacher_memberships_assigned_by_tenant_foreign foreign key (institution_id, assigned_by_user_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table group_teacher_memberships add constraint group_teacher_memberships_time_order_check check (ended_at is null or ended_at >= started_at)'
        );
        DB::statement(
            'create unique index group_teacher_memberships_current_unique on group_teacher_memberships (group_id, teacher_id) where ended_at is null'
        );

        Schema::create('group_student_memberships', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('group_id');
            $table->uuid('student_id');
            $table->uuid('assigned_by_user_id');
            $table->timestampTz('started_at');
            $table->timestampTz('ended_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(
                ['institution_id', 'student_id', 'ended_at'],
                'group_student_memberships_institution_student_ended_index',
            );
            $table->index(
                ['institution_id', 'group_id', 'ended_at'],
                'group_student_memberships_institution_group_ended_index',
            );
        });

        DB::statement(
            'alter table group_student_memberships add constraint group_student_memberships_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table group_student_memberships add constraint group_student_memberships_group_tenant_foreign foreign key (institution_id, group_id) references groups (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table group_student_memberships add constraint group_student_memberships_student_tenant_foreign foreign key (institution_id, student_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table group_student_memberships add constraint group_student_memberships_assigned_by_tenant_foreign foreign key (institution_id, assigned_by_user_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table group_student_memberships add constraint group_student_memberships_time_order_check check (ended_at is null or ended_at >= started_at)'
        );
        DB::statement(
            'create unique index group_student_memberships_current_unique on group_student_memberships (group_id, student_id) where ended_at is null'
        );

        Schema::create('parent_student_relationships', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('parent_id');
            $table->uuid('student_id');
            $table->uuid('connected_by_user_id');
            $table->timestampTz('started_at');
            $table->timestampTz('ended_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(
                ['institution_id', 'parent_id', 'ended_at'],
                'parent_student_relationships_institution_parent_ended_index',
            );
            $table->index(
                ['institution_id', 'student_id', 'ended_at'],
                'parent_student_relationships_institution_student_ended_index',
            );
        });

        DB::statement(
            'alter table parent_student_relationships add constraint parent_student_relationships_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table parent_student_relationships add constraint parent_student_relationships_parent_tenant_foreign foreign key (institution_id, parent_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table parent_student_relationships add constraint parent_student_relationships_student_tenant_foreign foreign key (institution_id, student_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table parent_student_relationships add constraint parent_student_relationships_connected_by_tenant_foreign foreign key (institution_id, connected_by_user_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table parent_student_relationships add constraint parent_student_relationships_time_order_check check (ended_at is null or ended_at >= started_at)'
        );
        DB::statement(
            'create unique index parent_student_relationships_current_unique on parent_student_relationships (parent_id, student_id) where ended_at is null'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('parent_student_relationships');
        Schema::dropIfExists('group_student_memberships');
        Schema::dropIfExists('group_teacher_memberships');
        Schema::dropIfExists('groups');

        DB::statement('alter table users drop constraint if exists users_institution_id_id_unique');
    }
};
