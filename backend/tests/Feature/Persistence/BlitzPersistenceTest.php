<?php

namespace Tests\Feature\Persistence;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\User;
use Closure;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class BlitzPersistenceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-16 09:00:00 UTC'));
        $this->assertSame('pgsql', DB::connection()->getDriverName());
    }

    #[DataProvider('validLifecycleFamilies')]
    public function test_valid_blitz_lifecycle_history_persists(string $family): void
    {
        $assessment = Assessment::factory()->blitz()->create();
        $attributes = $this->blitzAttributes($assessment, $family);

        DB::table('blitz_tasks')->insert($attributes);

        $this->assertDatabaseHas('blitz_tasks', $attributes);
    }

    public static function validLifecycleFamilies(): array
    {
        return [
            'draft' => ['draft'],
            'draft with prepared schedule' => ['preparedDraft'],
            'scheduled' => ['scheduled'],
            'active synchronized' => ['activeSynchronized'],
            'active individual' => ['activeIndividual'],
            'closed synchronized' => ['closedSynchronized'],
            'closed individual' => ['closedIndividual'],
            'archive from draft' => ['archivedFromDraft'],
            'archive from prepared draft or schedule' => ['archivedFromScheduled'],
            'archive after synchronized close' => ['archivedAfterCloseSynchronized'],
            'archive after individual close' => ['archivedAfterCloseIndividual'],
        ];
    }

    #[DataProvider('invalidLifecycleShapes')]
    public function test_database_rejects_invalid_blitz_values_lifecycle_and_timestamp_order(
        string $family,
        array $invalidAttributes,
    ): void {
        $assessment = Assessment::factory()->blitz()->create();
        $attributes = $this->blitzAttributes($assessment, $family);
        DB::table('blitz_tasks')->insert($attributes);

        $this->assertPostgresRejects(
            fn () => DB::table('blitz_tasks')->where('assessment_id', $assessment->id)->update($invalidAttributes),
            '23514',
        );
        $this->assertDatabaseHas('blitz_tasks', $attributes);
    }

    public static function invalidLifecycleShapes(): array
    {
        return [
            'unknown status' => ['draft', ['status' => 'disabled']],
            'zero duration' => ['draft', ['duration_seconds' => 0]],
            'negative duration' => ['draft', ['duration_seconds' => -1]],
            'unknown timer mode' => ['activeIndividual', ['timer_start_mode_snapshot' => 'per_question']],
            'draft activation timestamp' => ['draft', ['activated_at' => '2026-09-16 09:01:00+00']],
            'draft timer snapshot' => ['draft', ['timer_start_mode_snapshot' => 'individual']],
            'draft common end' => ['draft', ['synchronized_ends_at' => '2026-09-16 09:11:00+00']],
            'draft close timestamp' => ['draft', ['closed_at' => '2026-09-16 09:12:00+00']],
            'draft archive timestamp' => ['draft', ['archived_at' => '2026-09-16 09:15:00+00']],
            'scheduled missing schedule' => ['scheduled', ['scheduled_at' => null]],
            'scheduled activation timestamp' => ['scheduled', ['activated_at' => '2026-09-16 09:01:00+00']],
            'scheduled timer snapshot' => ['scheduled', ['timer_start_mode_snapshot' => 'individual']],
            'scheduled common end' => ['scheduled', ['synchronized_ends_at' => '2026-09-16 09:11:00+00']],
            'scheduled close timestamp' => ['scheduled', ['closed_at' => '2026-09-16 09:12:00+00']],
            'scheduled archive timestamp' => ['scheduled', ['archived_at' => '2026-09-16 09:15:00+00']],
            'active missing activation actor' => ['activeSynchronized', ['activated_by_user_id' => null]],
            'active missing timer snapshot' => ['activeSynchronized', ['timer_start_mode_snapshot' => null]],
            'active missing activation timestamp' => ['activeSynchronized', ['activated_at' => null]],
            'active with close timestamp' => ['activeSynchronized', ['closed_at' => '2026-09-16 09:12:00+00']],
            'active with archive timestamp' => ['activeSynchronized', ['archived_at' => '2026-09-16 09:15:00+00']],
            'synchronized active missing common end' => ['activeSynchronized', ['synchronized_ends_at' => null]],
            'synchronized active wrong common end' => ['activeSynchronized', ['synchronized_ends_at' => '2026-09-16 09:10:59+00']],
            'individual active with common end' => ['activeIndividual', ['synchronized_ends_at' => '2026-09-16 09:11:00+00']],
            'closed missing activation' => ['closedIndividual', ['activated_at' => null]],
            'closed missing activation actor' => ['closedIndividual', ['activated_by_user_id' => null]],
            'closed missing timer snapshot' => ['closedIndividual', ['timer_start_mode_snapshot' => null]],
            'closed missing close timestamp' => ['closedIndividual', ['closed_at' => null]],
            'closed with archive timestamp' => ['closedIndividual', ['archived_at' => '2026-09-16 09:15:00+00']],
            'closed synchronized missing common end' => ['closedSynchronized', ['synchronized_ends_at' => null]],
            'archived synchronized missing common end' => ['archivedAfterCloseSynchronized', ['synchronized_ends_at' => null]],
            'archived individual with common end' => ['archivedAfterCloseIndividual', ['synchronized_ends_at' => '2026-09-16 09:11:00+00']],
            'archive missing archive timestamp' => ['archivedFromDraft', ['archived_at' => null]],
            'archive before activation with stray timer snapshot' => ['archivedFromDraft', ['timer_start_mode_snapshot' => 'individual']],
            'archive before activation with stray common end' => ['archivedFromDraft', ['synchronized_ends_at' => '2026-09-16 09:11:00+00']],
            'archive after activation missing close' => ['archivedAfterCloseIndividual', ['closed_at' => null]],
            'direct active to archive' => ['activeIndividual', [
                'status' => 'archived',
                'archived_at' => '2026-09-16 09:15:00+00',
            ]],
            'activation before creation' => ['activeIndividual', ['activated_at' => '2026-09-16 08:59:59+00']],
            'close before activation' => ['closedIndividual', ['closed_at' => '2026-09-16 09:00:59+00']],
            'archive before creation' => ['archivedFromDraft', ['archived_at' => '2026-09-16 08:59:59+00']],
            'archive before close' => ['archivedAfterCloseIndividual', ['archived_at' => '2026-09-16 09:11:59+00']],
        ];
    }

    public function test_pre_activation_actor_fields_and_cross_institution_blitz_references_are_rejected(): void
    {
        $assessment = Assessment::factory()->blitz()->create();

        foreach (['draft', 'scheduled', 'archivedFromDraft'] as $family) {
            $this->assertPostgresRejects(
                fn () => DB::table('blitz_tasks')->insert(array_replace(
                    $this->blitzAttributes($assessment, $family),
                    ['activated_by_user_id' => $assessment->teacher_id],
                )),
                '23514',
            );
        }

        $foreignAssessment = Assessment::factory()->blitz()->create();
        $attributes = $this->blitzAttributes($assessment, 'activeSynchronized');
        DB::table('blitz_tasks')->insert($attributes);

        foreach ([
            ['assessment_id' => $foreignAssessment->id],
            ['activated_by_user_id' => $foreignAssessment->teacher_id],
        ] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('blitz_tasks')->where('assessment_id', $assessment->id)->update($foreignReference),
                '23503',
            );
        }

        $this->assertDatabaseHas('blitz_tasks', $attributes);
    }

    public function test_restrictive_blitz_parent_deletion_preserves_task_history(): void
    {
        $assessment = Assessment::factory()->blitz()->create();
        $activator = User::factory()->teacher()->create(['institution_id' => $assessment->institution_id]);
        $attributes = array_replace($this->blitzAttributes($assessment, 'closedSynchronized'), [
            'activated_by_user_id' => $activator->id,
        ]);
        DB::table('blitz_tasks')->insert($attributes);

        foreach ([$assessment, $activator, $assessment->institution] as $parent) {
            $this->assertPostgresRejects(fn () => $parent->delete(), '23001');
        }

        $this->assertDatabaseHas('blitz_tasks', $attributes);
    }

    public function test_exception_reason_categories_and_nullable_replacements_persist(): void
    {
        foreach (['technical', 'other_valid'] as $reasonType) {
            $exception = BlitzAttemptException::factory()->create(['reason_type' => $reasonType]);

            $this->assertDatabaseHas('blitz_attempt_exceptions', [
                'id' => $exception->id,
                'reason_type' => $reasonType,
                'replacement_attempt_id' => null,
            ]);
        }

        $this->assertDatabaseCount('blitz_attempt_exceptions', 2);
    }

    public function test_exception_rejects_blank_reasons_invalid_reason_types_and_identical_attempts(): void
    {
        $exception = BlitzAttemptException::factory()->create();

        foreach ([
            ['reason' => ''],
            ['reason' => '   '],
            ['reason_type' => 'unsupported'],
            ['replacement_attempt_id' => $exception->invalidated_attempt_id],
        ] as $invalidAttributes) {
            $this->assertPostgresRejects(
                fn () => DB::table('blitz_attempt_exceptions')->where('id', $exception->id)->update($invalidAttributes),
                '23514',
            );
        }
    }

    public function test_exception_uniqueness_prevents_duplicate_student_blitz_and_attempt_reuse(): void
    {
        $first = BlitzAttemptException::factory()->create();
        $replacement = $this->replacementAttemptFor($first);
        DB::table('blitz_attempt_exceptions')->where('id', $first->id)->update([
            'replacement_attempt_id' => $replacement->id,
        ]);

        $this->assertDatabaseHas('blitz_attempt_exceptions', [
            'id' => $first->id,
            'replacement_attempt_id' => $replacement->id,
        ]);

        $this->assertPostgresRejects(
            fn () => DB::table('blitz_attempt_exceptions')->insert(array_replace($first->getAttributes(), [
                'id' => Str::uuid()->toString(),
                'invalidated_attempt_id' => $replacement->id,
                'replacement_attempt_id' => null,
            ])),
            '23505',
            'blitz_attempt_exceptions_assessment_student_unique',
        );

        $otherRecipient = AssessmentStudent::factory()->create(['assessment_id' => $first->assessment_id]);
        $second = BlitzAttemptException::factory()->create([
            'assessment_id' => $first->assessment_id,
            'assessment_student_id' => $otherRecipient,
        ]);

        foreach ([
            'invalidated_attempt_id' => [
                $first->invalidated_attempt_id,
                'blitz_attempt_exceptions_invalidated_attempt_unique',
            ],
            'replacement_attempt_id' => [
                $replacement->id,
                'blitz_attempt_exceptions_replacement_attempt_unique',
            ],
        ] as $column => [$attemptId, $constraint]) {
            $this->assertPostgresRejects(
                fn () => DB::table('blitz_attempt_exceptions')->where('id', $second->id)->update([$column => $attemptId]),
                '23505',
                $constraint,
            );
        }
    }

    public function test_exception_foreign_keys_reject_every_cross_institution_reference(): void
    {
        $exception = BlitzAttemptException::factory()->create();
        $foreignException = BlitzAttemptException::factory()->create();
        $foreignAttempt = $this->replacementAttemptFor($foreignException);

        foreach ([
            ['assessment_id' => $foreignException->assessment_id],
            ['assessment_student_id' => $foreignException->assessment_student_id],
            ['student_id' => $foreignException->student_id],
            ['invalidated_attempt_id' => $foreignAttempt->id],
            ['replacement_attempt_id' => $foreignAttempt->id],
            ['granted_by_user_id' => $foreignException->granted_by_user_id],
            ['institution_id' => Str::uuid()->toString()],
        ] as $foreignReference) {
            $this->assertPostgresRejects(
                fn () => DB::table('blitz_attempt_exceptions')->where('id', $exception->id)->update($foreignReference),
                '23503',
            );
        }
    }

    public function test_restrictive_exception_parent_deletion_preserves_history(): void
    {
        $exception = BlitzAttemptException::factory()->create();
        $replacement = $this->replacementAttemptFor($exception);
        DB::table('blitz_attempt_exceptions')->where('id', $exception->id)->update([
            'replacement_attempt_id' => $replacement->id,
        ]);

        foreach ([
            $exception->assessment,
            $exception->assessmentStudent,
            $exception->student,
            $exception->invalidatedAttempt,
            $replacement,
            $exception->grantedBy,
            $exception->institution,
        ] as $parent) {
            $this->assertPostgresRejects(fn () => $parent->delete(), '23001');
        }

        $this->assertDatabaseHas('blitz_attempt_exceptions', [
            'id' => $exception->id,
            'replacement_attempt_id' => $replacement->id,
        ]);
    }

    /** @return array<string, mixed> */
    private function blitzAttributes(Assessment $assessment, string $family): array
    {
        $draft = [
            'assessment_id' => $assessment->id,
            'institution_id' => $assessment->institution_id,
            'status' => 'draft',
            'duration_seconds' => 600,
            'scheduled_at' => null,
            'timer_start_mode_snapshot' => null,
            'activated_at' => null,
            'synchronized_ends_at' => null,
            'closed_at' => null,
            'archived_at' => null,
            'activated_by_user_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ];
        $active = [
            'status' => 'active',
            'timer_start_mode_snapshot' => 'synchronized',
            'activated_at' => now()->addMinute(),
            'synchronized_ends_at' => now()->addMinutes(11),
            'activated_by_user_id' => $assessment->teacher_id,
        ];
        $individual = ['timer_start_mode_snapshot' => 'individual', 'synchronized_ends_at' => null];
        $closed = ['status' => 'closed', 'closed_at' => now()->addMinutes(12)];
        $archived = ['status' => 'archived', 'archived_at' => now()->addMinutes(15)];

        return match ($family) {
            'draft' => $draft,
            'preparedDraft' => array_replace($draft, ['scheduled_at' => now()->subDay()]),
            'scheduled' => array_replace($draft, ['status' => 'scheduled', 'scheduled_at' => now()->subDay()]),
            'activeSynchronized' => array_replace($draft, $active),
            'activeIndividual' => array_replace($draft, $active, $individual),
            'closedSynchronized' => array_replace($draft, $active, $closed),
            'closedIndividual' => array_replace($draft, $active, $individual, $closed),
            'archivedFromDraft' => array_replace($draft, $archived),
            'archivedFromScheduled' => array_replace($draft, $archived, ['scheduled_at' => now()->subDay()]),
            'archivedAfterCloseSynchronized' => array_replace($draft, $active, $closed, $archived),
            'archivedAfterCloseIndividual' => array_replace($draft, $active, $individual, $closed, $archived),
        };
    }

    private function replacementAttemptFor(BlitzAttemptException $exception): AssessmentAttempt
    {
        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $exception->assessment_student_id,
            'attempt_number' => 2,
        ]);
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
