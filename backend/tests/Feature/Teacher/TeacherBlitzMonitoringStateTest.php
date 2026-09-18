<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzMonitoringContext;
use Tests\TestCase;

class TeacherBlitzMonitoringStateTest extends TestCase
{
    use BuildsTeacherBlitzMonitoringContext, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_all_operational_statuses_partition_rows_and_score_is_always_null(): void
    {
        [$neverStarted, $assessment, $teacher] = $this->monitoringContext();
        $expected = [$neverStarted->id => ['status' => 'not_started', 'attempt_number' => null,
            'started_at' => null, 'deadline_at' => null, 'remaining_seconds' => null, 'finalization_reason' => null]];
        foreach (['in_progress', 'submitted', 'timed_out_finalized', 'closed', 'waiting_for_teacher_review', 'checked'] as $state) {
            $student = $this->studentBlitzActor($neverStarted->institution);
            $attempt = $this->studentBlitzAttempt($assessment, $student);
            if ($state !== 'in_progress') {
                $this->terminateStudentBlitzAttempt($attempt);
                if ($state === 'timed_out_finalized') {
                    $attempt->update(['status' => $state, 'submitted_at' => null, 'finalized_at' => $attempt->deadline_at,
                        'locked_at' => $attempt->deadline_at, 'finalization_reason' => 'timeout_auto_submit']);
                } elseif ($state === 'closed') {
                    $attempt->update(['submitted_at' => null, 'finalization_reason' => 'task_closed_auto_finalize']);
                } else {
                    $attempt->update(['status' => $state, 'earned_points' => '4.00000000', 'normalized_score' => '80.00000000']);
                }
            }
            $expected[$student->id] = [
                'status' => match ($state) {
                    'in_progress', 'waiting_for_teacher_review' => $state, default => 'finalized'
                },
                'attempt_number' => 1, 'started_at' => '2026-09-17T11:59:00Z', 'deadline_at' => '2026-09-17T12:09:00Z',
                'remaining_seconds' => $state === 'in_progress' ? 540 : 0,
                'finalization_reason' => $attempt->fresh()->finalization_reason?->value,
            ];
        }
        $response = $this->monitor($teacher, $assessment)->assertOk();
        $this->assertMonitoringPartition($response);
        $response->assertJsonPath('data.summary', ['assigned' => 7, 'not_started' => 1, 'in_progress' => 1,
            'finalized' => 4, 'waiting_for_teacher_review' => 1, 'attempt_exceptions_granted' => 0]);
        foreach ($response->json('data.students') as $row) {
            $identity = $row['student'];
            $this->assertSame(['student' => $identity] + $expected[$identity['id']] + ['score' => null, 'attempt_exception' => null], $row);
        }
    }

    #[DataProvider('replacementStates')]
    public function test_exception_projects_current_replacement_path_and_its_own_timer(string $mode, string $state): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext($mode);
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        // Synchronized common end never limits unused or started replacement capacity.
        $this->travelTo(Carbon::parse('2026-09-17 12:06:00 UTC'));
        $replacement = null;
        if ($state !== 'unused') {
            $id = $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertCreated()->json('data.id');
            $replacement = AssessmentAttempt::query()->findOrFail($id);
            if ($state === 'submitted') {
                $this->terminateStudentBlitzAttempt($replacement);
            } elseif ($state === 'timeout') {
                $this->travelTo($replacement->deadline_at);
            }
        }
        $response = $this->monitor($teacher, $assessment)->assertOk();
        $this->assertMonitoringPartition($response);
        $response->assertJsonPath('data.summary.attempt_exceptions_granted', 1);
        $exception = DB::table('blitz_attempt_exceptions')->sole();
        $this->assertSame([
            'student' => ['id' => $student->id, 'full_name' => $student->full_name],
            'status' => match ($state) {
                'unused' => 'not_started', 'in_progress' => 'in_progress', default => 'finalized'
            },
            'attempt_number' => $state === 'unused' ? null : 2,
            'started_at' => $state === 'unused' ? null : '2026-09-17T12:06:00Z',
            'deadline_at' => $state === 'unused' ? null : '2026-09-17T12:16:00Z',
            'remaining_seconds' => match ($state) {
                'unused' => null, 'in_progress' => 600, default => 0
            },
            'finalization_reason' => match ($state) {
                'submitted' => 'student_submit', 'timeout' => 'timeout_auto_submit', default => null
            },
            'score' => null,
            'attempt_exception' => ['id' => $exception->id, 'invalidated_attempt_id' => $normal->id,
                'replacement_attempt_id' => $replacement?->id, 'reason_type' => 'technical', 'reason' => 'Device interruption.',
                'granted_at' => '2026-09-17T12:00:00Z', 'replacement_attempt_available' => $state === 'unused'],
        ], $response->json('data.students.0'));
    }

    public static function replacementStates(): array
    {
        $cases = [];
        foreach (['individual', 'synchronized'] as $mode) {
            foreach (['unused', 'in_progress', 'submitted', 'timeout'] as $state) {
                $cases[] = [$mode, $state];
            }
        }

        return $cases;
    }

    #[DataProvider('corruptHistories')]
    public function test_invalid_same_snapshot_history_is_not_repaired(string $corruption): void
    {
        [$student, $assessment, $normal, $teacher, $replacement, $exception] = $this->replacementContext();
        match ($corruption) {
            'unlinked' => $exception->update(['replacement_attempt_id' => null]),
            'eligible normal' => $normal->update(['official_score_eligible' => true]),
            'ineligible replacement' => $replacement->update(['official_score_eligible' => false]),
            'third' => $replacement->update(['attempt_number' => 3]),
            'no exception' => $exception->delete(),
            'wrong points' => $replacement->update(['possible_points' => 4]),
            'wrong deadline' => $replacement->update(['deadline_at' => $replacement->deadline_at->addSecond()]),
            'homework reason' => $normal->update(['finalization_reason' => AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit]),
            'missing finalization' => $normal->update(['finalized_at' => null]),
        };
        $before = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $this->withoutExceptionHandling();
        try {
            $this->monitor($teacher, $assessment);
            $this->fail('Invalid committed history must fail.');
        } catch (LogicException) {
            $this->assertSame($before, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
        }
    }

    public static function corruptHistories(): array
    {
        return array_map(fn ($case) => [$case], ['unlinked', 'eligible normal', 'ineligible replacement', 'third',
            'no exception', 'wrong points', 'wrong deadline', 'homework reason', 'missing finalization']);
    }

    #[DataProvider('invalidRecipients')]
    public function test_missing_foreign_or_wrong_role_recipient_user_is_an_invariant_failure(string $case): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext();
        // Exercise defensive reads of corrupt legacy state without weakening production constraints.
        DB::statement('SET session_replication_role = replica');
        try {
            match ($case) {
                'missing' => DB::table('users')->where('id', $student->id)->delete(),
                'foreign' => DB::table('users')->where('id', $student->id)->update(['institution_id' => $this->studentBlitzActor()->institution_id]),
                'role' => $student->update(['role' => 'teacher']),
            };
        } finally {
            DB::statement('SET session_replication_role = origin');
        }
        $this->withoutExceptionHandling();
        $this->expectException(LogicException::class);
        $this->expectExceptionMessage('Every Blitz recipient requires a same-Institution Student.');
        $this->monitor($teacher, $assessment);
    }

    public static function invalidRecipients(): array
    {
        return [['missing'], ['foreign'], ['role']];
    }

    #[DataProvider('invalidTimers')]
    public function test_invalid_active_task_timing_is_an_invariant_failure(array $attributes): void
    {
        [, $assessment, $teacher] = $this->monitoringContext();
        // PostgreSQL prevents persisting these shapes; inject damaged hydration to test the read guard.
        $dispatcher = BlitzTask::getEventDispatcher();
        BlitzTask::setEventDispatcher(clone $dispatcher);
        BlitzTask::retrieved(fn (BlitzTask $task) => $task->forceFill($attributes));
        $this->withoutExceptionHandling();
        $this->expectException(LogicException::class);
        try {
            $this->monitor($teacher, $assessment);
        } finally {
            BlitzTask::setEventDispatcher($dispatcher);
        }
    }

    public static function invalidTimers(): array
    {
        return [[['activated_at' => null]], [['timer_start_mode_snapshot' => null]],
            [['synchronized_ends_at' => '2026-09-17 12:05:00']], [['timer_start_mode_snapshot' => 'synchronized']]];
    }

    public function test_normal_terminal_attempt_also_rejects_homework_reason(): void
    {
        [, $assessment, $normal, $teacher] = $this->exceptionContext();
        $normal->update(['finalization_reason' => AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit]);
        $this->withoutExceptionHandling();
        $this->expectException(LogicException::class);
        $this->monitor($teacher, $assessment);
    }
}
