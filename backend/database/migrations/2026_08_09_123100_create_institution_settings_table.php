<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const BLITZ_TIMER_MODES = [
        'synchronized',
        'individual',
    ];

    private const STUDENT_RELEASE_MODES = [
        'automatic',
        'manual_teacher',
    ];

    private const PARENT_RELEASE_MODES = [
        'with_student',
        'manual_teacher',
        'hidden',
    ];

    public function up(): void
    {
        Schema::create('institution_settings', function (Blueprint $table) {
            $table->uuid('institution_id')->primary();
            $table->decimal('acceptable_score_difference', 12, 8)->nullable();
            $table->string('blitz_timer_start_mode', 24)->nullable();
            $table->string('student_result_release_mode', 30)->nullable();
            $table->string('parent_result_release_mode', 30)->nullable();
            $table->string('timezone', 64)->default('Asia/Tashkent');
            $table->smallInteger('learning_material_max_mb')->default(25);
            $table->smallInteger('student_submission_max_mb')->default(15);
            $table->uuid('updated_by_user_id')->nullable();
            $table->timestampsTz();
        });

        DB::statement(
            'alter table institution_settings add constraint institution_settings_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table institution_settings add constraint institution_settings_updated_by_user_id_foreign foreign key (updated_by_user_id) references users (id) on delete restrict'
        );
        DB::statement(
            'alter table institution_settings add constraint institution_settings_score_difference_check check (acceptable_score_difference is null or acceptable_score_difference between 0 and 100)'
        );
        DB::statement(sprintf(
            'alter table institution_settings add constraint institution_settings_blitz_timer_mode_check check (blitz_timer_start_mode is null or blitz_timer_start_mode in (%s))',
            $this->quotedValues(self::BLITZ_TIMER_MODES),
        ));
        DB::statement(sprintf(
            'alter table institution_settings add constraint institution_settings_student_release_mode_check check (student_result_release_mode is null or student_result_release_mode in (%s))',
            $this->quotedValues(self::STUDENT_RELEASE_MODES),
        ));
        DB::statement(sprintf(
            'alter table institution_settings add constraint institution_settings_parent_release_mode_check check (parent_result_release_mode is null or parent_result_release_mode in (%s))',
            $this->quotedValues(self::PARENT_RELEASE_MODES),
        ));
        DB::statement(
            'alter table institution_settings add constraint institution_settings_learning_material_limit_check check (learning_material_max_mb between 1 and 25)'
        );
        DB::statement(
            'alter table institution_settings add constraint institution_settings_student_submission_limit_check check (student_submission_max_mb between 1 and 15)'
        );
        DB::statement(
            "alter table institution_settings add constraint institution_settings_timezone_not_empty_check check (timezone <> '')"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('institution_settings');
    }

    /**
     * @param  list<string>  $values
     */
    private function quotedValues(array $values): string
    {
        return collect($values)
            ->map(fn (string $value): string => DB::getPdo()->quote($value))
            ->implode(', ');
    }
};
