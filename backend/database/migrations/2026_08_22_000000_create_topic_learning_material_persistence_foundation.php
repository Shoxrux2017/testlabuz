<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('topics', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('group_id');
            $table->uuid('teacher_id');
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('subject', 160);
            $table->text('student_instructions');
            $table->timestampTz('lesson_at')->nullable();
            $table->string('status', 20);
            $table->timestampTz('activated_at')->nullable();
            $table->timestampTz('closed_at')->nullable();
            $table->timestampTz('archived_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'topics_institution_id_id_unique');
            $table->index(['institution_id', 'group_id', 'status'], 'topics_institution_group_status_index');
            $table->index(['institution_id', 'teacher_id', 'status'], 'topics_institution_teacher_status_index');
            $table->index(['institution_id', 'status', 'created_at'], 'topics_institution_status_created_index');
        });

        DB::statement("alter table topics add constraint topics_title_not_empty_check check (btrim(title) <> '')");
        DB::statement("alter table topics add constraint topics_subject_not_empty_check check (btrim(subject) <> '')");
        DB::statement("alter table topics add constraint topics_student_instructions_not_empty_check check (btrim(student_instructions) <> '')");
        DB::statement("alter table topics add constraint topics_status_check check (status in ('draft', 'active', 'closed', 'archived'))");
        DB::statement(
            <<<'SQL'
                alter table topics add constraint topics_lifecycle_consistency_check check (
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
            'alter table topics add constraint topics_activated_at_order_check check (activated_at is null or activated_at >= created_at)'
        );
        DB::statement(
            'alter table topics add constraint topics_closed_at_order_check check (closed_at is null or (activated_at is not null and closed_at >= activated_at))'
        );
        DB::statement(
            'alter table topics add constraint topics_archived_at_order_check check (archived_at is null or (archived_at >= created_at and (closed_at is null or archived_at >= closed_at)))'
        );
        DB::statement(
            'alter table topics add constraint topics_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table topics add constraint topics_group_tenant_foreign foreign key (institution_id, group_id) references groups (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table topics add constraint topics_teacher_tenant_foreign foreign key (institution_id, teacher_id) references users (institution_id, id) on delete restrict'
        );
        DB::statement('create index topics_institution_lower_title_index on topics (institution_id, lower(title))');

        Schema::create('files', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('uploaded_by_user_id');
            $table->string('category', 32);
            $table->string('original_name', 500);
            $table->string('storage_disk', 100);
            $table->text('storage_key');
            $table->string('mime_type', 160);
            $table->string('extension', 20);
            $table->bigInteger('size_bytes');
            $table->char('checksum_sha256', 64)->nullable();
            $table->timestampTz('removed_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'files_institution_id_id_unique');
            $table->unique(['storage_disk', 'storage_key'], 'files_storage_disk_storage_key_unique');
            $table->index(['institution_id', 'category', 'created_at'], 'files_institution_category_created_index');
            $table->index('uploaded_by_user_id', 'files_uploaded_by_user_id_index');
        });

        DB::statement("alter table files add constraint files_category_check check (category in ('learning_material', 'student_submission'))");
        DB::statement("alter table files add constraint files_extension_check check (extension in ('pdf', 'docx', 'ppt', 'pptx'))");
        DB::statement("alter table files add constraint files_original_name_not_empty_check check (btrim(original_name) <> '')");
        DB::statement("alter table files add constraint files_storage_disk_not_empty_check check (btrim(storage_disk) <> '')");
        DB::statement("alter table files add constraint files_storage_key_not_empty_check check (btrim(storage_key) <> '')");
        DB::statement("alter table files add constraint files_mime_type_not_empty_check check (btrim(mime_type) <> '')");
        DB::statement('alter table files add constraint files_size_positive_check check (size_bytes > 0)');
        DB::statement(
            <<<'SQL'
                alter table files add constraint files_category_size_limit_check check (
                    (category = 'learning_material' and size_bytes <= 26214400)
                    or (category = 'student_submission' and size_bytes <= 15728640)
                )
            SQL,
        );
        DB::statement(
            "alter table files add constraint files_checksum_sha256_check check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9A-Fa-f]{64}$')"
        );
        DB::statement(
            'alter table files add constraint files_removed_at_order_check check (removed_at is null or removed_at >= created_at)'
        );
        DB::statement(
            'alter table files add constraint files_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table files add constraint files_uploader_tenant_foreign foreign key (institution_id, uploaded_by_user_id) references users (institution_id, id) on delete restrict'
        );

        Schema::create('learning_materials', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('topic_id');
            $table->uuid('file_id');
            $table->uuid('teacher_id');
            $table->string('title')->nullable();
            $table->integer('position')->default(0);
            $table->timestampTz('removed_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['institution_id', 'id'], 'learning_materials_institution_id_id_unique');
            $table->unique('file_id', 'learning_materials_file_id_unique');
            $table->index(
                ['institution_id', 'topic_id', 'removed_at'],
                'learning_materials_institution_topic_removed_index',
            );
        });

        DB::statement(
            "alter table learning_materials add constraint learning_materials_title_not_empty_check check (title is null or btrim(title) <> '')"
        );
        DB::statement(
            'alter table learning_materials add constraint learning_materials_position_check check (position >= 0)'
        );
        DB::statement(
            'alter table learning_materials add constraint learning_materials_removed_at_order_check check (removed_at is null or removed_at >= created_at)'
        );
        DB::statement(
            'alter table learning_materials add constraint learning_materials_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table learning_materials add constraint learning_materials_topic_tenant_foreign foreign key (institution_id, topic_id) references topics (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table learning_materials add constraint learning_materials_file_tenant_foreign foreign key (institution_id, file_id) references files (institution_id, id) on delete restrict'
        );
        DB::statement(
            'alter table learning_materials add constraint learning_materials_teacher_tenant_foreign foreign key (institution_id, teacher_id) references users (institution_id, id) on delete restrict'
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('learning_materials');
        Schema::dropIfExists('files');
        Schema::dropIfExists('topics');
    }
};
