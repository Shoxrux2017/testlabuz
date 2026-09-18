<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\IdempotencyRecord;
use App\Support\Student\StudentBlitzAttemptAccess;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

class StudentBlitzReplacementAttemptStartTest extends TestCase
{
    use BuildsBlitzExceptionContext, BuildsStudentHomeworkFileAnswerContext, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        Storage::fake('local');
        config(['filesystems.private_files_disk' => 'local']);
    }

    public function test_only_explicit_replacement_start_creates_a_clean_linked_eligible_attempt(): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext(terminal: false);
        [$question, $fileQuestion] = $this->studentBlitzQuestions($assessment);
        $normalKey = (string) Str::uuid();
        $this->startStudentBlitz($student, $assessment, $normalKey)->assertOk()->assertJsonPath('data.id', $normal->id);
        $this->studentBlitzRequest($student, 'PUT', '/api/v1/student/attempts/'.$normal->id.'/answers/'.$question->id,
            json_encode(['type' => 'single_choice', 'selected_option_ids' => [$question->choiceOptions()->first()->id]]))->assertOk();
        [, , $originalFile] = $this->savedFileAnswer($normal, $fileQuestion);
        $originalBytes = Storage::disk('local')->get($originalFile->storage_key);
        $this->terminateStudentBlitzAttempt($normal);
        $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertConflict()->assertJsonPath('code', 'attempts_exhausted');
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        $this->startStudentBlitz($student, $assessment)->assertConflict()->assertJsonPath('code', 'attempts_exhausted');
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $normal->id)->assertConflict()->assertJsonPath('code', 'attempt_not_editable');
        $this->startStudentBlitz($student, $assessment, $normalKey)->assertOk()->assertJsonPath('data.id', $normal->id);
        $this->startStudentBlitz($student, $assessment, $normalKey, 'start_replacement')->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $this->assertDatabaseCount('assessment_attempts', 1);

        $key = (string) Str::uuid();
        $response = $this->startStudentBlitz($student, $assessment, $key, 'start_replacement')->assertCreated();
        $replacement = AssessmentAttempt::query()->findOrFail($response->json('data.id'));
        $this->assertSame(2, $replacement->attempt_number);
        $this->assertSame($normal->assessment_student_id, $replacement->assessment_student_id);
        $this->assertSame($student->id, $replacement->student_id);
        $this->assertSame($assessment->total_possible_points, $replacement->possible_points);
        $this->assertTrue($replacement->official_score_eligible);
        $this->assertFalse($normal->fresh()->official_score_eligible);
        $this->assertSame($replacement->id, BlitzAttemptException::query()->sole()->replacement_attempt_id);
        $this->assertSame(0, $replacement->answers()->count());
        $this->assertSame(2, $normal->answers()->count());
        foreach ($response->json('data.answers') as $row) {
            $this->assertNull($row['answer']);
        }
        $before = $replacement->getAttributes();
        $this->startStudentBlitz($student, $assessment, $key, 'start_replacement')->assertCreated()->assertJsonPath('data.id', $replacement->id);
        $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertOk()->assertJsonPath('data.id', $replacement->id);
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $replacement->id)->assertOk()->assertJsonPath('data.id', $replacement->id);
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $normal->id)->assertConflict()->assertJsonPath('code', 'attempt_not_editable');
        $this->assertSame($before, $replacement->fresh()->getAttributes());
        $this->startStudentBlitz($student, $assessment, $normalKey)->assertOk()->assertJsonPath('data.id', $normal->id);
        $this->studentBlitzRequest($student, 'PUT', '/api/v1/student/attempts/'.$replacement->id.'/answers/'.$question->id,
            json_encode(['type' => 'single_choice', 'selected_option_ids' => [$question->choiceOptions()->first()->id]]))->assertOk();
        $this->fileAnswerRequest($student, $replacement, $fileQuestion, $this->fileAnswerUpload('replacement.pdf'))->assertOk();
        $this->assertSame(2, $replacement->answers()->count());
        $this->assertSame(2, $normal->answers()->count());
        $this->assertSame($originalBytes, Storage::disk('local')->get($originalFile->storage_key));
        $this->terminateStudentBlitzAttempt($replacement);
        $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertConflict()->assertJsonPath('code', 'attempts_exhausted');
        $this->assertDatabaseCount('assessment_attempts', 2);
    }

    public function test_replacement_preserves_the_locked_official_pair_and_frozen_cohort(): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $assessment->update(['assignment_mode' => 'group']);
        $assessment->recipients()->update(['assignment_source' => 'group']);
        $pair = $this->officialBlitzPair($assessment, $teacher, true)->fresh();
        $pairBefore = $pair->getAttributes();
        $recipients = $assessment->recipients()->get()->map->getAttributes()->all();
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertCreated()->assertJsonPath('data.attempt_number', 2);
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertSame($recipients, $assessment->recipients()->get()->map->getAttributes()->all());
    }

    public function test_official_replacement_start_resume_and_completed_replay_accept_reverse_uuid_history(): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        $normal = $this->studentBlitzAttempt($assessment, $student, [
            'id' => '00000000-0000-4000-8000-000000000002',
            'official_score_eligible' => false,
        ]);
        $this->terminateStudentBlitzAttempt($normal);
        $pair->update(['locked_at' => $normal->started_at]);
        $replacement = $this->studentBlitzAttempt($assessment, $student, [
            'id' => '00000000-0000-4000-8000-000000000001',
            'attempt_number' => 2,
            'started_at' => now(),
            'deadline_at' => now()->addSeconds($assessment->blitzTask->duration_seconds),
        ]);
        $exception = BlitzAttemptException::factory()->create([
            'assessment_id' => $assessment->id,
            'assessment_student_id' => $normal->assessment_student_id,
            'invalidated_attempt_id' => $normal->id,
            'replacement_attempt_id' => $replacement->id,
        ]);
        $this->assertDatabaseCount('assessment_attempts', 2);
        $this->assertSame([$replacement->id, $normal->id], DB::transaction(fn () => app(StudentBlitzAttemptAccess::class)
            ->lockAttempts($student, $assessment, $pair)->modelKeys()));
        $pairBefore = $pair->fresh()->getAttributes();
        $cohort = AssessmentStudent::query()->whereIn('assessment_id', [$pair->homework_assessment_id, $pair->blitz_assessment_id]);
        $cohortBefore = $cohort->orderBy('id')->get()->map->getAttributes()->all();
        $normalBefore = $normal->fresh()->getAttributes();
        $replacementBefore = $replacement->getAttributes();
        $exceptionBefore = $exception->fresh()->getAttributes();

        $key = (string) Str::uuid();
        $this->startStudentBlitz($student, $assessment, $key, 'start_replacement')
            ->assertOk()->assertJsonPath('data.id', $replacement->id)
            ->assertJsonPath('data.attempt_number', 2)->assertJsonPath('data.status', 'in_progress');
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $replacement->id)
            ->assertOk()->assertJsonPath('data.id', $replacement->id)
            ->assertJsonPath('data.attempt_number', 2)->assertJsonPath('data.status', 'in_progress');
        $this->assertSame($replacementBefore, $replacement->fresh()->getAttributes());

        $this->terminateStudentBlitzAttempt($replacement);
        $terminalBefore = $replacement->fresh()->getAttributes();
        $this->startStudentBlitz($student, $assessment, $key, 'start_replacement')
            ->assertOk()->assertJsonPath('data.id', $replacement->id)
            ->assertJsonPath('data.attempt_number', 2)->assertJsonPath('data.status', 'submitted');
        $this->assertSame($terminalBefore, $replacement->fresh()->getAttributes());
        $this->assertSame($normalBefore, $normal->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 2);
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => $assessment->id, 'attempt_number' => 3]);
        $this->assertDatabaseCount('idempotency_records', 2);
        $this->assertSame($exceptionBefore, $exception->fresh()->getAttributes());
        $this->assertSame($normal->id, $exception->fresh()->invalidated_attempt_id);
        $this->assertSame($replacement->id, $exception->fresh()->replacement_attempt_id);
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertSame($cohortBefore, $cohort->get()->map->getAttributes()->all());
    }

    public function test_replacement_input_and_exact_resume_target_cannot_be_reinterpreted(): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext();
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        foreach (['{}', '{"intent":"replacement"}', '{"intent":"start_replacement","attempt_id":null}',
            '{"intent":"start_replacement","attempt_id":"'.$normal->id.'"}', '{"intent":"resume"}'] as $body) {
            $this->studentBlitzRequest($student, 'POST', '/api/v1/student/blitz/'.$assessment->id.'/attempts', $body)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: (string) Str::uuid())->assertNotFound();
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public function test_start_completion_failure_rolls_back_replacement_and_exception_link(): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        $before = BlitzAttemptException::query()->sole()->getAttributes();
        $dispatcher = IdempotencyRecord::getEventDispatcher();
        IdempotencyRecord::setEventDispatcher(clone $dispatcher);
        IdempotencyRecord::updating(fn () => throw new RuntimeException('Injected Start completion failure.'));
        $this->withoutExceptionHandling();
        try {
            $this->startStudentBlitz($student, $assessment, intent: 'start_replacement');
            $this->fail('Completion failure must roll back.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected Start completion failure.', $exception->getMessage());
            $this->assertSame($before, BlitzAttemptException::query()->sole()->getAttributes());
            $this->assertDatabaseCount('assessment_attempts', 1);
            $this->assertDatabaseCount('idempotency_records', 1);
        } finally {
            IdempotencyRecord::setEventDispatcher($dispatcher);
        }
    }

    #[DataProvider('corruptGraphs')]
    public function test_impossible_committed_graph_is_not_repaired(string $corruption): void
    {
        [$student, $assessment, $normal, , $replacement, $exception] = $this->replacementContext();
        match ($corruption) {
            'unlinked' => $exception->update(['replacement_attempt_id' => null]),
            'eligible normal' => $normal->update(['official_score_eligible' => true]),
            'ineligible replacement' => $replacement->update(['official_score_eligible' => false]),
            'third' => $replacement->update(['attempt_number' => 3]),
            'no exception' => $exception->delete(),
        };
        $before = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $this->withoutExceptionHandling();
        foreach (['start', 'detail', 'list'] as $path) {
            try {
                $path === 'start'
                    ? $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')
                    : $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.($path === 'list' ? 'active' : $assessment->id));
                $this->fail('Impossible graph must fail.');
            } catch (LogicException) {
                $this->assertSame($before, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
            }
        }
    }

    public static function corruptGraphs(): array
    {
        return [['unlinked'], ['eligible normal'], ['ineligible replacement'], ['third'], ['no exception']];
    }
}
