<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const SIDE_STATES = "'ready', 'waiting_for_teacher_review', 'checking', 'not_activated', 'open', 'missing'";

    private const CLOSURE_COLUMNS = [
        'closed_by_user_id', 'closure_reason', 'closed_outcome', 'missing_component', 'homework_assessment_id',
        'blitz_assessment_id', 'homework_state', 'blitz_state', 'homework_attempt_id', 'homework_score', 'blitz_attempt_id',
        'blitz_score', 'score_difference', 'acceptable_difference_used', 'calculation_method', 'consistency', 'final_score',
        'category_score', 'category_code', 'category_min_score_used', 'category_max_score_used',
    ];

    private const CALCULATION_COLUMNS = [
        'score_difference', 'acceptable_difference_used', 'calculation_method', 'consistency', 'final_score', 'category_score',
        'category_min_score_used', 'category_max_score_used',
    ];

    public function up(): void
    {
        // Open Topic results are computed live (S10-T1); a row holds only the Teacher comment, Teacher
        // releases and the closure snapshot, which never references the deletable official score rows.
        Schema::create('topic_results', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->uuid('topic_id');
            $table->uuid('student_id');
            $table->text('teacher_comment')->nullable();
            $table->uuid('teacher_comment_updated_by_user_id')->nullable();
            $table->timestampTz('teacher_comment_updated_at')->nullable();
            $table->timestampTz('student_released_at')->nullable();
            $table->uuid('student_released_by_user_id')->nullable();
            $table->timestampTz('parent_released_at')->nullable();
            $table->uuid('parent_released_by_user_id')->nullable();
            $table->timestampTz('closed_at')->nullable();
            $table->uuid('closed_by_user_id')->nullable();
            $table->string('closure_reason', 20)->nullable();
            $table->string('closed_outcome', 20)->nullable();
            $table->string('missing_component', 20)->nullable();
            $table->uuid('homework_assessment_id')->nullable();
            $table->uuid('blitz_assessment_id')->nullable();
            $table->string('homework_state', 30)->nullable();
            $table->string('blitz_state', 30)->nullable();
            $table->uuid('homework_attempt_id')->nullable();
            $table->decimal('homework_score', 12, 8)->nullable();
            $table->uuid('blitz_attempt_id')->nullable();
            $table->decimal('blitz_score', 12, 8)->nullable();
            $table->decimal('score_difference', 12, 8)->nullable();
            $table->decimal('acceptable_difference_used', 12, 8)->nullable();
            $table->string('calculation_method', 20)->nullable();
            $table->string('consistency', 20)->nullable();
            $table->decimal('final_score', 12, 8)->nullable();
            $table->smallInteger('category_score')->nullable();
            $table->string('category_code', 40)->nullable();
            $table->smallInteger('category_min_score_used')->nullable();
            $table->smallInteger('category_max_score_used')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['topic_id', 'student_id'], 'topic_results_topic_student_unique');
            $table->unique(['institution_id', 'id'], 'topic_results_institution_id_id_unique');
        });

        $this->check('teacher_comment', "teacher_comment is null or (teacher_comment <> '' and char_length(teacher_comment) <= 2000)");
        $this->check('comment_actor', '(teacher_comment_updated_by_user_id is null) = (teacher_comment_updated_at is null)
            and (teacher_comment is null or teacher_comment_updated_by_user_id is not null)');
        $this->check('student_release', '(student_released_at is null) = (student_released_by_user_id is null)');
        $this->check('parent_release', '(parent_released_at is null) = (parent_released_by_user_id is null)');

        $this->check('closure_reason', "closure_reason is null or closure_reason in ('teacher', 'topic_archived')");
        $this->check('closed_outcome', "closed_outcome is null or closed_outcome in ('calculated', 'not_completed')");
        $this->check('missing_component', "missing_component is null or missing_component in ('homework', 'blitz', 'both')");
        $this->check('homework_state', 'homework_state is null or homework_state in ('.self::SIDE_STATES.')');
        $this->check('blitz_state', 'blitz_state is null or blitz_state in ('.self::SIDE_STATES.", 'not_designated')");
        $this->check('calculation_method', "calculation_method is null or calculation_method in ('average', 'blitz')");
        $this->check('consistency', "consistency is null or consistency in ('consistent', 'inconsistent')");
        $this->check('category_code', "category_code is null or category_code in ('understood_well', 'partially_understood', 'needs_revision', 'needs_teacher_support', 'not_completed')");

        $this->check('open_row', 'closed_at is not null or ('.$this->allNull(self::CLOSURE_COLUMNS).')');
        $this->check('closed_row', 'closed_at is null or (closed_by_user_id is not null and closure_reason is not null
            and closed_outcome is not null and homework_assessment_id is not null and homework_state is not null and blitz_state is not null)');
        $this->check('blitz_designation', "closed_at is null or ((blitz_assessment_id is null) = (blitz_state = 'not_designated'))");
        $this->check('side_score', "(homework_state is null or ((homework_state = 'ready') = (homework_attempt_id is not null)
            and (homework_state = 'ready') = (homework_score is not null)))
            and (blitz_state is null or ((blitz_state = 'ready') = (blitz_attempt_id is not null)
            and (blitz_state = 'ready') = (blitz_score is not null)))");
        // A CHECK passes when its expression is NULL, so these conditions are forced to true or false.
        $this->check('calculated_outcome', "closed_outcome is distinct from 'calculated' or coalesce(homework_state = 'ready'
            and blitz_state = 'ready' and missing_component is null
            and category_code in ('understood_well', 'partially_understood', 'needs_revision', 'needs_teacher_support')
            and ".$this->allNotNull(self::CALCULATION_COLUMNS).', false)');
        $this->check('not_completed_outcome', "closed_outcome is distinct from 'not_completed' or coalesce(category_code = 'not_completed'
            and ".$this->allNull(self::CALCULATION_COLUMNS)."
            and missing_component = case
                when homework_state = 'missing' and blitz_state = 'missing' then 'both'
                when homework_state = 'missing' then 'homework'
                when blitz_state = 'missing' then 'blitz'
            end, false)");
        $this->check('method_consistency', "(calculation_method is null and consistency is null)
            or (calculation_method is not distinct from 'average' and consistency is not distinct from 'consistent')
            or (calculation_method is not distinct from 'blitz' and consistency is not distinct from 'inconsistent')");
        $this->check('score_range', implode(' and ', array_map(
            fn (string $column): string => "({$column} is null or {$column} between 0 and 100)",
            ['homework_score', 'blitz_score', 'score_difference', 'acceptable_difference_used', 'final_score', 'category_score',
                'category_min_score_used', 'category_max_score_used'],
        )).' and (category_min_score_used is null or category_max_score_used is null or category_min_score_used <= category_max_score_used)');

        DB::statement('alter table topic_results add constraint topic_results_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict');

        foreach ([
            'topic' => ['topic_id', 'topics'],
            'student' => ['student_id', 'users'],
            'comment_author' => ['teacher_comment_updated_by_user_id', 'users'],
            'student_releaser' => ['student_released_by_user_id', 'users'],
            'parent_releaser' => ['parent_released_by_user_id', 'users'],
            'closer' => ['closed_by_user_id', 'users'],
            'homework_assessment' => ['homework_assessment_id', 'assessments'],
            'blitz_assessment' => ['blitz_assessment_id', 'assessments'],
            'homework_attempt' => ['homework_attempt_id', 'assessment_attempts'],
            'blitz_attempt' => ['blitz_attempt_id', 'assessment_attempts'],
        ] as $name => [$column, $parent]) {
            DB::statement("alter table topic_results add constraint topic_results_{$name}_tenant_foreign foreign key (institution_id, {$column}) references {$parent} (institution_id, id) on delete restrict");
        }

        // CL9-11: a stored empty feedback string would fail the strict client parsers.
        DB::statement("alter table attempt_answers add constraint attempt_answers_feedback_not_empty_check check (feedback is null or feedback <> '')");
    }

    public function down(): void
    {
        DB::statement('alter table attempt_answers drop constraint attempt_answers_feedback_not_empty_check');
        Schema::dropIfExists('topic_results');
    }

    private function check(string $name, string $condition): void
    {
        DB::statement("alter table topic_results add constraint topic_results_{$name}_check check ({$condition})");
    }

    /** @param list<string> $columns */
    private function allNull(array $columns): string
    {
        return implode(' and ', array_map(fn (string $column): string => "{$column} is null", $columns));
    }

    /** @param list<string> $columns */
    private function allNotNull(array $columns): string
    {
        return implode(' and ', array_map(fn (string $column): string => "{$column} is not null", $columns));
    }
};
