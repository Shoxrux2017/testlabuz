<?php

namespace Tests\Feature\Persistence;

use App\Enums\OfficialScoreSelectionPolicy;
use App\Models\AssessmentAttempt;
use App\Models\OfficialTaskScore;
use Closure;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class ScoringPersistenceSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_official_task_scores_has_exact_columns_types_and_nullability(): void
    {
        $expected = [
            'id' => ['uuid', 'NO'],
            'institution_id' => ['uuid', 'NO'],
            'assessment_id' => ['uuid', 'NO'],
            'student_id' => ['uuid', 'NO'],
            'official_attempt_id' => ['uuid', 'NO'],
            'normalized_score' => ['numeric', 'NO'],
            'selection_policy_code' => ['character varying', 'NO'],
            'selected_by_user_id' => ['uuid', 'YES'],
            'selected_at' => ['timestamp with time zone', 'NO'],
            'created_at' => ['timestamp with time zone', 'NO'],
            'updated_at' => ['timestamp with time zone', 'NO'],
        ];
        $columns = DB::select(
            "select column_name, data_type, is_nullable, numeric_precision, numeric_scale, character_maximum_length
             from information_schema.columns where table_schema = 'public' and table_name = 'official_task_scores'
             order by ordinal_position",
        );

        $this->assertSame(array_keys($expected), array_map(fn (object $column): string => $column->column_name, $columns));

        foreach ($columns as $column) {
            $this->assertSame($expected[$column->column_name], [$column->data_type, $column->is_nullable], $column->column_name);
        }

        $byName = array_column($columns, null, 'column_name');
        $this->assertSame([12, 8], [(int) $byName['normalized_score']->numeric_precision, (int) $byName['normalized_score']->numeric_scale]);
        $this->assertSame(64, (int) $byName['selection_policy_code']->character_maximum_length);
    }

    public function test_homework_review_due_at_is_a_nullable_timestamptz(): void
    {
        $column = DB::selectOne(
            "select data_type, is_nullable, column_default from information_schema.columns
             where table_schema = 'public' and table_name = 'homework_assignments' and column_name = 'review_due_at'",
        );

        $this->assertNotNull($column);
        $this->assertSame(['timestamp with time zone', 'YES', null], [$column->data_type, $column->is_nullable, $column->column_default]);
    }

    public function test_a_factory_official_score_persists_with_its_casts(): void
    {
        $score = OfficialTaskScore::factory()->create()->fresh();

        $this->assertSame(OfficialScoreSelectionPolicy::HighestValidCompleted, $score->selection_policy_code);
        $this->assertSame($score->officialAttempt->normalized_score, $score->normalized_score);
        $this->assertSame($score->officialAttempt->student_id, $score->student_id);
        $this->assertSame($score->officialAttempt->assessment_id, $score->assessment_id);
        $this->assertNull($score->selected_by_user_id);
        $this->assertNotNull($score->selected_at);
    }

    public function test_one_official_score_per_student_and_assessment_and_per_attempt(): void
    {
        $score = OfficialTaskScore::factory()->create();

        $this->assertPostgresRejects(fn () => DB::table('official_task_scores')->insert([
            ...$this->rowOf($score),
            'id' => Str::uuid()->toString(),
        ]), '23505', 'official_task_scores_assessment_student_unique');

        $other = OfficialTaskScore::factory()->create();
        $this->assertPostgresRejects(
            fn () => DB::table('official_task_scores')->where('id', $other->id)->update(['official_attempt_id' => $score->official_attempt_id]),
            '23505',
            'official_task_scores_official_attempt_unique',
        );
    }

    public function test_checks_reject_out_of_range_scores_unknown_policies_and_a_selecting_user(): void
    {
        $score = OfficialTaskScore::factory()->create();

        foreach ([
            ['normalized_score' => '100.00000001'],
            ['normalized_score' => '-0.00000001'],
            ['selection_policy_code' => 'teacher_choice'],
            ['selected_by_user_id' => $score->student_id],
        ] as $invalid) {
            $this->assertPostgresRejects(
                fn () => DB::table('official_task_scores')->where('id', $score->id)->update($invalid),
                '23514',
            );
        }

        foreach (OfficialScoreSelectionPolicy::values() as $policy) {
            DB::table('official_task_scores')->where('id', $score->id)->update(['selection_policy_code' => $policy]);
        }

        DB::table('official_task_scores')->where('id', $score->id)->update(['normalized_score' => '100.00000000']);
        DB::table('official_task_scores')->where('id', $score->id)->update(['normalized_score' => '0']);
        $this->assertSame('0.00000000', $score->fresh()->normalized_score);
    }

    public function test_foreign_keys_reject_every_cross_institution_reference(): void
    {
        $score = OfficialTaskScore::factory()->create();
        $foreign = OfficialTaskScore::factory()->create();
        // An Attempt of another Institution that no official score uses yet.
        $foreignAttempt = AssessmentAttempt::factory()->create();

        foreach ([
            ['assessment_id' => $foreign->assessment_id],
            ['student_id' => $foreign->student_id],
            ['official_attempt_id' => $foreignAttempt->id],
            ['institution_id' => Str::uuid()->toString()],
        ] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('official_task_scores')->where('id', $score->id)->update($foreignReference),
                '23503',
            );
        }
    }

    public function test_every_foreign_key_is_tenant_safe_and_restrictive(): void
    {
        $foreignKeys = [];

        foreach (DB::select(
            "select conname, pg_get_constraintdef(oid) as definition from pg_constraint
             where conrelid = 'official_task_scores'::regclass and contype = 'f' order by conname",
        ) as $constraint) {
            $foreignKeys[$constraint->conname] = $constraint->definition;
        }

        $this->assertSame([
            'official_task_scores_assessment_tenant_foreign' => 'FOREIGN KEY (institution_id, assessment_id) REFERENCES assessments(institution_id, id) ON DELETE RESTRICT',
            'official_task_scores_attempt_tenant_foreign' => 'FOREIGN KEY (institution_id, official_attempt_id) REFERENCES assessment_attempts(institution_id, id) ON DELETE RESTRICT',
            'official_task_scores_institution_id_foreign' => 'FOREIGN KEY (institution_id) REFERENCES institutions(id) ON DELETE RESTRICT',
            'official_task_scores_selector_tenant_foreign' => 'FOREIGN KEY (institution_id, selected_by_user_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
            'official_task_scores_student_tenant_foreign' => 'FOREIGN KEY (institution_id, student_id) REFERENCES users(institution_id, id) ON DELETE RESTRICT',
        ], $foreignKeys);
    }

    public function test_parent_deletion_is_restricted(): void
    {
        $score = OfficialTaskScore::factory()->create();

        foreach ([$score->officialAttempt, $score->assessment, $score->student, $score->institution] as $parent) {
            $this->assertPostgresRejects(fn () => $parent->delete(), '23001');
        }

        $this->assertDatabaseHas('official_task_scores', ['id' => $score->id]);
    }

    /** @return array<string, mixed> */
    private function rowOf(OfficialTaskScore $score): array
    {
        return (array) DB::table('official_task_scores')->where('id', $score->id)->first();
    }

    private function assertPostgresRejects(Closure $operation, string $sqlState, ?string $constraint = null): void
    {
        try {
            DB::transaction(fn () => $operation());
        } catch (QueryException $exception) {
            $this->assertSame($sqlState, $exception->errorInfo[0]);

            if ($constraint !== null) {
                $this->assertStringContainsString($constraint, $exception->getMessage());
            }

            return;
        }

        $this->fail('Expected PostgreSQL to reject the database operation with SQLSTATE '.$sqlState.'.');
    }
}
