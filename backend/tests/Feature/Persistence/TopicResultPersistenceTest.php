<?php

namespace Tests\Feature\Persistence;

use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Topic;
use App\Models\TopicResult;
use App\Models\User;
use Closure;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class TopicResultPersistenceTest extends TestCase
{
    use RefreshDatabase;

    public function test_topic_results_has_exact_columns_types_and_nullability(): void
    {
        $uuid = ['uuid', 'YES'];
        $time = ['timestamp with time zone', 'YES'];
        $varchar = ['character varying', 'YES'];
        $score = ['numeric', 'YES'];
        $expected = [
            'id' => ['uuid', 'NO'], 'institution_id' => ['uuid', 'NO'], 'topic_id' => ['uuid', 'NO'], 'student_id' => ['uuid', 'NO'],
            'teacher_comment' => ['text', 'YES'], 'teacher_comment_updated_by_user_id' => $uuid, 'teacher_comment_updated_at' => $time,
            'student_released_at' => $time, 'student_released_by_user_id' => $uuid,
            'parent_released_at' => $time, 'parent_released_by_user_id' => $uuid,
            'closed_at' => $time, 'closed_by_user_id' => $uuid, 'closure_reason' => $varchar, 'closed_outcome' => $varchar,
            'missing_component' => $varchar, 'homework_assessment_id' => $uuid, 'blitz_assessment_id' => $uuid,
            'homework_state' => $varchar, 'blitz_state' => $varchar,
            'homework_attempt_id' => $uuid, 'homework_score' => $score, 'blitz_attempt_id' => $uuid, 'blitz_score' => $score,
            'score_difference' => $score, 'acceptable_difference_used' => $score,
            'calculation_method' => $varchar, 'consistency' => $varchar, 'final_score' => $score,
            'category_score' => ['smallint', 'YES'], 'category_code' => $varchar,
            'category_min_score_used' => ['smallint', 'YES'], 'category_max_score_used' => ['smallint', 'YES'],
            'created_at' => ['timestamp with time zone', 'NO'], 'updated_at' => ['timestamp with time zone', 'NO'],
        ];
        $columns = DB::select(
            "select column_name, data_type, is_nullable, numeric_precision, numeric_scale, character_maximum_length
             from information_schema.columns where table_schema = 'public' and table_name = 'topic_results'
             order by ordinal_position",
        );

        $this->assertSame(array_keys($expected), array_map(fn (object $column): string => $column->column_name, $columns));

        foreach ($columns as $column) {
            $this->assertSame($expected[$column->column_name], [$column->data_type, $column->is_nullable], $column->column_name);

            if ($column->data_type === 'numeric') {
                $this->assertSame([12, 8], [(int) $column->numeric_precision, (int) $column->numeric_scale], $column->column_name);
            }
        }

        $lengths = array_column($columns, 'character_maximum_length', 'column_name');
        $this->assertSame([20, 20, 20, 30, 30, 20, 20, 40], array_map('intval', [
            $lengths['closure_reason'], $lengths['closed_outcome'], $lengths['missing_component'], $lengths['homework_state'],
            $lengths['blitz_state'], $lengths['calculation_method'], $lengths['consistency'], $lengths['category_code'],
        ]));
    }

    public function test_every_factory_state_is_a_valid_row(): void
    {
        TopicResult::factory()->create();
        TopicResult::factory()->withComment()->releasedToStudent()->releasedToParent()->create();
        $calculated = TopicResult::factory()->closedCalculated()->create();
        $notCompleted = TopicResult::factory()->closedNotCompleted()->create();

        $this->assertSame(4, TopicResult::query()->count());
        $this->assertSame('86.00000000', $calculated->fresh()->final_score);
        $this->assertNull($notCompleted->fresh()->final_score);
    }

    public function test_a_student_has_one_result_per_topic(): void
    {
        $result = TopicResult::factory()->create();

        $this->assertPostgresRejects(fn () => TopicResult::factory()->create([
            'institution_id' => $result->institution_id, 'topic_id' => $result->topic_id, 'student_id' => $result->student_id,
        ]), '23505', 'topic_results_topic_student_unique');
    }

    /** @return array<string, array{string, array<string, mixed>, string}> */
    public static function inconsistentRows(): array
    {
        return [
            'empty comment' => ['withComment', ['teacher_comment' => ''], 'topic_results_teacher_comment_check'],
            'comment above 2000 characters' => ['withComment', ['teacher_comment' => str_repeat('a', 2001)], 'topic_results_teacher_comment_check'],
            'comment without its actor' => ['withComment', ['teacher_comment_updated_by_user_id' => null], 'topic_results_comment_actor_check'],
            'student release without its actor' => ['releasedToStudent', ['student_released_by_user_id' => null], 'topic_results_student_release_check'],
            'parent release without its time' => ['releasedToParent', ['parent_released_at' => null], 'topic_results_parent_release_check'],
            'open row with a closure reason' => ['default', ['closure_reason' => 'teacher'], 'topic_results_open_row_check'],
            'open row with a homework score' => ['default', ['homework_score' => '80'], 'topic_results_open_row_check'],
            'closed row without an outcome' => ['closedCalculated', ['closed_outcome' => null], 'topic_results_closed_row_check'],
            'unknown closure reason' => ['closedCalculated', ['closure_reason' => 'admin'], 'topic_results_closure_reason_check'],
            'unknown outcome' => ['closedCalculated', ['closed_outcome' => 'closed'], 'topic_results_closed_outcome_check'],
            'unknown missing component' => ['closedNotCompleted', ['missing_component' => 'teacher'], 'topic_results_missing_component_check'],
            'homework not designated' => ['closedNotCompleted', ['homework_state' => 'not_designated'], 'topic_results_homework_state_check'],
            'unknown blitz state' => ['closedNotCompleted', ['blitz_state' => 'closed'], 'topic_results_blitz_state_check'],
            'unknown method' => ['closedCalculated', ['calculation_method' => 'homework'], 'topic_results_calculation_method_check'],
            'unknown consistency' => ['closedCalculated', ['consistency' => 'unknown'], 'topic_results_consistency_check'],
            'unknown category' => ['closedNotCompleted', ['category_code' => 'excellent'], 'topic_results_category_code_check'],
            'ready side without its score' => ['closedCalculated', ['homework_score' => null], 'topic_results_side_score_check'],
            'missing side with an attempt' => ['closedNotCompleted', ['blitz_attempt_id' => null, 'blitz_state' => 'missing', 'blitz_score' => '50'], 'topic_results_side_score_check'],
            'not designated blitz with an assessment' => ['closedNotCompleted', ['blitz_state' => 'not_designated', 'missing_component' => 'homework'], 'topic_results_blitz_designation_check'],
            'calculated without a final score' => ['closedCalculated', ['final_score' => null], 'topic_results_calculated_outcome_check'],
            'calculated with the not completed category' => ['closedCalculated', ['category_code' => 'not_completed'], 'topic_results_calculated_outcome_check'],
            'not completed with a final score' => ['closedNotCompleted', ['final_score' => '80'], 'topic_results_not_completed_outcome_check'],
            'not completed naming the wrong missing side' => ['closedNotCompleted', ['missing_component' => 'homework'], 'topic_results_not_completed_outcome_check'],
            'calculated without a category' => ['closedCalculated', ['category_code' => null], 'topic_results_calculated_outcome_check'],
            'not completed without a category' => ['closedNotCompleted', ['category_code' => null], 'topic_results_not_completed_outcome_check'],
            'not completed without a missing component' => ['closedNotCompleted', ['missing_component' => null], 'topic_results_not_completed_outcome_check'],
            'average that is inconsistent' => ['closedCalculated', ['consistency' => 'inconsistent'], 'topic_results_method_consistency_check'],
            'consistency without a method' => ['closedNotCompleted', ['consistency' => 'consistent'], 'topic_results_method_consistency_check'],
            'final score above one hundred' => ['closedCalculated', ['final_score' => '100.00000001'], 'topic_results_score_range_check'],
            'category score above one hundred' => ['closedCalculated', ['category_score' => 101], 'topic_results_score_range_check'],
            'inverted category range' => ['closedCalculated', ['category_min_score_used' => 100, 'category_max_score_used' => 86], 'topic_results_score_range_check'],
        ];
    }

    #[DataProvider('inconsistentRows')]
    public function test_checks_reject_an_inconsistent_row(string $state, array $change, string $constraint): void
    {
        $factory = TopicResult::factory();
        $result = ($state === 'default' ? $factory : $factory->{$state}())->create();

        $this->assertPostgresRejects(
            fn () => DB::table('topic_results')->where('id', $result->id)->update($change),
            '23514',
            $constraint,
        );
    }

    public function test_every_foreign_key_is_tenant_safe_and_restrictive(): void
    {
        $foreignKeys = [];

        foreach (DB::select(
            "select conname, pg_get_constraintdef(oid) as definition from pg_constraint
             where conrelid = 'topic_results'::regclass and contype = 'f' order by conname",
        ) as $constraint) {
            $foreignKeys[$constraint->conname] = $constraint->definition;
        }

        $users = fn (string $column): string => "FOREIGN KEY (institution_id, {$column}) REFERENCES users(institution_id, id) ON DELETE RESTRICT";
        $this->assertSame([
            'topic_results_blitz_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, blitz_assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
            'topic_results_blitz_attempt_tenant_foreign' => 'FOREIGN KEY (institution_id, blitz_attempt_id) REFERENCES assessment_attempts(institution_id, id) ON DELETE RESTRICT',
            'topic_results_closer_tenant_foreign' => $users('closed_by_user_id'),
            'topic_results_comment_author_tenant_foreign' => $users('teacher_comment_updated_by_user_id'),
            'topic_results_homework_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, homework_assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
            'topic_results_homework_attempt_tenant_foreign' => 'FOREIGN KEY (institution_id, homework_attempt_id) REFERENCES assessment_attempts(institution_id, id) ON DELETE RESTRICT',
            'topic_results_institution_id_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'topic_results_parent_releaser_tenant_foreign' => $users('parent_released_by_user_id'),
            'topic_results_student_releaser_tenant_foreign' => $users('student_released_by_user_id'),
            'topic_results_student_tenant_foreign' => $users('student_id'),
            'topic_results_topic_tenant_foreign' => 'FOREIGN KEY (institution_id, topic_id) REFERENCES topics(institution_id, id) ON DELETE RESTRICT',
        ], $foreignKeys);
    }

    public function test_foreign_keys_reject_every_cross_institution_reference(): void
    {
        $result = TopicResult::factory()->closedCalculated()->create();
        $foreign = TopicResult::factory()->closedCalculated()->create();

        foreach ([
            ['topic_id' => $foreign->topic_id],
            ['student_id' => $foreign->student_id],
            ['homework_assessment_id' => $foreign->homework_assessment_id],
            ['homework_attempt_id' => $foreign->homework_attempt_id],
            ['closed_by_user_id' => $foreign->closed_by_user_id],
        ] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('topic_results')->where('id', $result->id)->update($foreignReference),
                '23503',
            );
        }
    }

    public function test_parent_deletion_is_restricted_by_the_topic_result(): void
    {
        $open = TopicResult::factory()->create();
        $closed = TopicResult::factory()->closedCalculated()->create();

        $this->assertPostgresRejects(fn () => Topic::query()->findOrFail($open->topic_id)->delete(), '23001', 'topic_results_topic_tenant_foreign');
        $this->assertPostgresRejects(fn () => User::query()->findOrFail($open->student_id)->delete(), '23001', 'topic_results_student_tenant_foreign');
        $this->assertPostgresRejects(
            fn () => AssessmentAttempt::query()->findOrFail($closed->homework_attempt_id)->delete(),
            '23001',
            'topic_results_homework_attempt_tenant_foreign',
        );
        $this->assertSame(2, TopicResult::query()->count());
    }

    public function test_the_institution_and_id_pair_is_unique_for_tenant_references(): void
    {
        $definition = DB::selectOne(
            "select pg_get_constraintdef(oid) as definition from pg_constraint
             where conrelid = 'topic_results'::regclass and conname = 'topic_results_institution_id_id_unique'",
        );

        $this->assertSame('UNIQUE (institution_id, id)', $definition?->definition);
    }

    public function test_valid_edge_rows_are_accepted(): void
    {
        $notDesignated = TopicResult::factory()->closedNotCompleted()->create();
        DB::table('topic_results')->where('id', $notDesignated->id)->update([
            'blitz_assessment_id' => null, 'blitz_state' => 'not_designated',
            'homework_state' => 'missing', 'homework_attempt_id' => null, 'homework_score' => null, 'missing_component' => 'homework',
        ]);
        $both = TopicResult::factory()->closedNotCompleted()->create();
        DB::table('topic_results')->where('id', $both->id)->update([
            'homework_state' => 'missing', 'homework_attempt_id' => null, 'homework_score' => null, 'missing_component' => 'both',
        ]);
        $archived = TopicResult::factory()->closedCalculated()->create(['closure_reason' => 'topic_archived']);
        $cleared = TopicResult::factory()->withComment()->create();
        DB::table('topic_results')->where('id', $cleared->id)->update(['teacher_comment' => null]);

        $this->assertSame('not_designated', $notDesignated->fresh()->blitz_state->value);
        $this->assertSame('both', $both->fresh()->missing_component->value);
        $this->assertSame('topic_archived', $archived->fresh()->closure_reason->value);
        $this->assertNotNull($cleared->fresh()->teacher_comment_updated_by_user_id);
    }

    public function test_stored_answer_feedback_is_null_or_non_empty(): void
    {
        $answer = AttemptAnswer::factory()->create();

        DB::table('attempt_answers')->where('id', $answer->id)->update(['feedback' => 'Well argued.']);
        DB::table('attempt_answers')->where('id', $answer->id)->update(['feedback' => null]);

        $this->assertPostgresRejects(
            fn () => DB::table('attempt_answers')->where('id', $answer->id)->update(['feedback' => '']),
            '23514',
            'attempt_answers_feedback_not_empty_check',
        );
    }

    private function assertPostgresRejects(Closure $operation, string $sqlState, ?string $constraint = null): void
    {
        try {
            DB::transaction(fn () => $operation());
        } catch (QueryException $exception) {
            $this->assertSame($sqlState, $exception->errorInfo[0], $exception->getMessage());

            if ($constraint !== null) {
                $this->assertStringContainsString($constraint, $exception->getMessage());
            }

            return;
        }

        $this->fail('Expected PostgreSQL to reject the database operation with SQLSTATE '.$sqlState.'.');
    }
}
