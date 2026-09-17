<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\TopicStatus;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;
use Tests\TestCase;

class StudentBlitzAnswerLifecycleTest extends TestCase
{
    use BuildsStudentBlitzAnswerContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('timerModes')]
    public function test_active_own_attempt_uses_its_persisted_deadline_in_each_timer_mode(string $timerMode): void
    {
        [$student, $blitz, $attempt] = $this->answerContext($timerMode);
        $question = $this->answerQuestion($blitz, 'short_written');
        $this->travelTo($attempt->deadline_at->copy()->subSecond());
        $before = $attempt->getAttributes();
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'At the final eligible second'])
            ->assertOk()->assertJsonPath('data.answer.text', 'At the final eligible second');
        $this->assertSame($before, $attempt->fresh()->getAttributes());
    }

    public static function timerModes(): array
    {
        return [['individual'], ['synchronized']];
    }

    #[DataProvider('inactiveStates')]
    public function test_inactive_topic_or_blitz_precedes_attempt_and_deadline_conflicts(string $state): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($blitz, 'short_written');
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'Saved'])->assertOk();
        if ($state === 'topic') {
            $blitz->assessment->topic->update(['status' => TopicStatus::Closed, 'closed_at' => now()]);
        } else {
            $attributes = match ($state) {
                'closed' => ['status' => 'closed', 'closed_at' => now()],
                'archived' => ['status' => 'archived', 'closed_at' => now(), 'archived_at' => now()],
                'draft', 'scheduled' => ['status' => $state, 'activated_at' => null, 'activated_by_user_id' => null,
                    'timer_start_mode_snapshot' => null, 'synchronized_ends_at' => null,
                    'scheduled_at' => $state === 'scheduled' ? now()->addHour() : null],
            };
            $blitz->update($attributes);
        }
        $this->terminateStudentBlitzAttempt($attempt);
        $this->travelTo($attempt->deadline_at);
        $answersBefore = $this->answerSnapshot();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'Rejected'])
            ->assertConflict()->assertJsonPath('code', 'blitz_not_active');
        $this->assertSame($answersBefore, $this->answerSnapshot());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function inactiveStates(): array
    {
        return array_map(fn (string $state): array => [$state], ['topic', 'draft', 'scheduled', 'closed', 'archived']);
    }

    #[DataProvider('terminalStatuses')]
    public function test_terminal_attempt_is_not_editable_even_after_its_deadline(string $status, bool $expired): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($blitz, 'short_written');
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'Saved'])->assertOk();
        $this->terminateStudentBlitzAttempt($attempt);
        $attempt->update(['status' => $status] + ($status === 'timed_out_finalized'
            ? ['submitted_at' => null, 'finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit] : []));
        if ($expired) {
            $this->travelTo($attempt->deadline_at->copy()->addSecond());
        }
        $before = $this->answerSnapshot();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'Rejected'])
            ->assertConflict()->assertJsonPath('code', 'attempt_not_editable');
        $this->assertSame($before, $this->answerSnapshot());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function terminalStatuses(): array
    {
        $cases = [];
        foreach (['submitted', 'timed_out_finalized', 'waiting_for_teacher_review', 'checked'] as $status) {
            foreach ([false, true] as $expired) {
                $cases[$status.($expired ? ' expired' : ' before deadline')] = [$status, $expired];
            }
        }

        return $cases;
    }

    #[DataProvider('expiredMutations')]
    public function test_expired_write_never_mutates_answers_or_finalizes_any_attempt(string $timerMode, int $offset, string $mutation): void
    {
        [$student, $blitz, $attempt] = $this->answerContext($timerMode);
        $question = $this->answerQuestion($blitz, 'short_written');
        if ($mutation !== 'create') {
            $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'Saved'])->assertOk();
        }
        $otherStudent = $this->studentBlitzActor($student->institution);
        $this->studentBlitzAttempt($blitz->assessment, $otherStudent);
        $this->travelTo($attempt->deadline_at->copy()->addSeconds($offset));
        $answersBefore = $this->answerSnapshot();
        $attemptsBefore = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $blitzBefore = $blitz->getAttributes();
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $this->answerHttp($student, 'PUT', '/api/v1/student/attempts/'.$attempt->id.'/answers/'.$question->id,
                json_encode(['type' => 'short_written', 'text' => match ($mutation) {
                    'clear' => '', 'noop' => 'Saved', default => 'Late answer',
                }], JSON_THROW_ON_ERROR), headers: ['HTTP_X_CLIENT_TIME' => '2026-09-17T11:59:00Z'])
                ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
            foreach (DB::getQueryLog() as $query) {
                if (preg_match('/^\s*(insert|update|delete)\b/i', $query['query']) === 1) {
                    $this->assertDoesNotMatchRegularExpression('/"(?:attempt_answers|answer_[a-z_]+|assessment_attempts|blitz_tasks)"/', $query['query']);
                }
            }
        } finally {
            DB::disableQueryLog();
        }
        $this->assertSame($answersBefore, $this->answerSnapshot());
        $this->assertSame($attemptsBefore, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
        $this->assertSame($blitzBefore, $blitz->fresh()->getAttributes());
        $this->assertSame(AssessmentAttemptStatus::InProgress, $attempt->fresh()->status);
    }

    public static function expiredMutations(): array
    {
        $cases = [];
        foreach (['individual', 'synchronized'] as $timerMode) {
            foreach ([0, 1] as $offset) {
                foreach (['create', 'replace', 'clear', 'noop'] as $mutation) {
                    $cases[$timerMode.' '.$offset.' '.$mutation] = [$timerMode, $offset, $mutation];
                }
            }
        }

        return $cases;
    }

    public function test_other_students_foreign_tenants_wrong_questions_and_broken_recipient_ownership_are_private(): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($blitz, 'short_written');
        $otherStudent = $this->studentBlitzActor($student->institution);
        $otherAssessment = $this->studentBlitz($otherStudent);
        $otherAttempt = $this->studentBlitzAttempt($otherAssessment, $otherStudent);
        $otherQuestion = $this->answerQuestion(BlitzTask::query()->findOrFail($otherAssessment->id), 'short_written');
        [, $foreignBlitz, $foreignAttempt] = $this->answerContext();
        $foreignQuestion = $this->answerQuestion($foreignBlitz, 'short_written');
        foreach ([[$otherAttempt->id, $otherQuestion->id], [$foreignAttempt->id, $foreignQuestion->id],
            [$attempt->id, $otherQuestion->id], [$attempt->id, $foreignQuestion->id],
            ['malformed-attempt', $question->id], [(string) Str::uuid(), $question->id]] as [$attemptId, $questionId]) {
            $this->answerHttp($student, 'PUT', '/api/v1/student/attempts/'.$attemptId.'/answers/'.$questionId,
                '{"type":"short_written","text":"Private"}')->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $attempt->update(['assessment_student_id' => $otherAttempt->assessment_student_id]);
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'Private'])
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertDatabaseCount('attempt_answers', 0);
    }
}
