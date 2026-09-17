<?php

namespace Tests\Feature\Student;

use App\Enums\BlitzStatus;
use App\Models\AssessmentStudent;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentBlitzSubmissionFileDownloadTest extends TestCase
{
    use BuildsStudentBlitzContext, BuildsStudentHomeworkFileAnswerContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        Storage::fake('local');
    }

    public function test_student_downloads_own_active_and_historical_closed_archived_blitz_file_with_private_headers(): void
    {
        [$student, $assessment, $attempt, , , , $file] = $this->submission();
        $file->update(['original_name' => 'Мой ответ.PDF']);
        $bytes = Storage::disk('local')->get($file->storage_key);

        foreach (['active', 'closed', 'archived'] as $status) {
            if ($status === 'closed') {
                $this->terminateStudentBlitzAttempt($attempt);
                $this->travelTo($attempt->deadline_at->copy()->addDay());
                $assessment->topic->update(['status' => 'closed', 'closed_at' => now()]);
            }
            $assessment->blitzTask->update([
                'status' => $status, 'closed_at' => $status === 'active' ? null : now(),
                'archived_at' => $status === 'archived' ? now() : null,
            ]);
            $snapshot = $this->fileAnswerSnapshot();
            $response = $this->answerHttp($student, 'GET', '/api/v1/files/'.$file->id.'/download')
                ->assertOk()->assertHeader('Content-Type', 'application/pdf')
                ->assertHeader('X-Content-Type-Options', 'nosniff')->assertStreamedContent($bytes);
            $this->assertStringContainsString('private', $response->headers->get('Cache-Control'));
            $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
            $this->assertStringStartsWith('attachment;', $response->headers->get('Content-Disposition'));
            $this->assertStringContainsString("filename*=utf-8''", $response->headers->get('Content-Disposition'));
            $this->assertStringNotContainsString($file->storage_key, json_encode($response->headers->all(), JSON_THROW_ON_ERROR));
            $this->assertSame($snapshot, $this->fileAnswerSnapshot());
        }
    }

    public function test_other_student_other_institution_and_teacher_cannot_download_blitz_submission(): void
    {
        [$student, $assessment, , , , , $file] = $this->submission();
        $otherStudent = $this->studentBlitzActor($student->institution);
        $foreignStudent = $this->studentBlitzActor();
        $teacher = $assessment->teacher;
        $teacher->update(['must_change_password' => false]);

        foreach ([$otherStudent, $foreignStudent, $teacher] as $actor) {
            $response = $this->answerHttp($actor, 'GET', '/api/v1/files/'.$file->id.'/download')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertStringNotContainsString($file->id, $response->getContent());
            $this->assertStringNotContainsString($file->storage_key, $response->getContent());
        }
    }

    #[DataProvider('unavailableStatuses')]
    public function test_draft_and_scheduled_blitz_cannot_authorize_submission_download(BlitzStatus $status): void
    {
        [$student, $assessment, , , , , $file] = $this->submission();
        $assessment->blitzTask->update([
            'status' => $status, 'activated_at' => null, 'activated_by_user_id' => null,
            'timer_start_mode_snapshot' => null, 'synchronized_ends_at' => null,
            'scheduled_at' => $status === BlitzStatus::Scheduled ? now()->addHour() : null,
        ]);

        $this->answerHttp($student, 'GET', '/api/v1/files/'.$file->id.'/download')
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
    }

    public static function unavailableStatuses(): array
    {
        return [[BlitzStatus::Draft], [BlitzStatus::Scheduled]];
    }

    #[DataProvider('brokenGraphs')]
    public function test_wrong_question_recipient_or_assessment_graph_cannot_authorize_blitz_submission(string $corruption): void
    {
        [$student, $assessment, $attempt, $question, $answer, , $file] = $this->submission();
        DB::beginTransaction();

        try {
            if ($corruption === 'non_file_question') {
                $question->update(['type' => 'open_written']);
            } elseif ($corruption === 'wrong_question') {
                $otherAssessment = $this->studentBlitz($student);
                [, $otherQuestion] = $this->studentBlitzQuestions($otherAssessment);
                $answer->update(['question_id' => $otherQuestion->id]);
            } elseif ($corruption === 'recipient_student') {
                $otherStudent = $this->studentBlitzActor($student->institution);
                AssessmentStudent::query()->whereKey($attempt->assessment_student_id)->update(['student_id' => $otherStudent->id]);
            } elseif ($corruption === 'recipient_assessment') {
                $otherAssessment = $this->studentBlitz($student, assigned: false);
                AssessmentStudent::query()->whereKey($attempt->assessment_student_id)->update(['assessment_id' => $otherAssessment->id]);
            } elseif (in_array($corruption, ['foreign_recipient', 'missing_recipient'], true)) {
                $recipientId = (string) Str::uuid();
                if ($corruption === 'foreign_recipient') {
                    $foreignStudent = $this->studentBlitzActor();
                    $foreignAssessment = $this->studentBlitz($foreignStudent);
                    $recipientId = AssessmentStudent::query()->where('assessment_id', $foreignAssessment->id)->sole()->id;
                }
                // Savepoint rollback restores the constraint after exercising a corrupt persisted graph.
                DB::statement('alter table assessment_attempts drop constraint assessment_attempts_recipient_tenant_foreign');
                $attempt->update(['assessment_student_id' => $recipientId]);
            } elseif ($corruption === 'wrong_assessment_type') {
                $assessment->update(['type' => 'homework']);
            } elseif ($corruption === 'wrong_uploader') {
                $file->update(['uploaded_by_user_id' => $this->studentBlitzActor($student->institution)->id]);
            } else {
                $file->update(['removed_at' => now()]);
            }
            $snapshot = $this->fileAnswerSnapshot();

            $this->answerHttp($student, 'GET', '/api/v1/files/'.$file->id.'/download')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertSame($snapshot, $this->fileAnswerSnapshot());
            Storage::disk('local')->assertExists($file->storage_key);
        } finally {
            DB::rollBack();
        }
    }

    public static function brokenGraphs(): array
    {
        return array_map(fn (string $case): array => [$case], [
            'non_file_question', 'wrong_question', 'recipient_student', 'recipient_assessment',
            'foreign_recipient', 'missing_recipient', 'wrong_assessment_type', 'wrong_uploader', 'removed_file',
        ]);
    }

    public function test_homework_submission_download_still_uses_its_own_detail_branch(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);

        $this->answerHttp($student, 'GET', '/api/v1/files/'.$file->id.'/download')
            ->assertOk()->assertStreamedContent(Storage::disk('local')->get($file->storage_key));
    }

    private function submission(): array
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        [, $question] = $this->studentBlitzQuestions($assessment);
        $attempt = $this->studentBlitzAttempt($assessment, $student);
        [$answer, $answerFile, $file] = $this->savedFileAnswer($attempt, $question);

        return [$student, $assessment, $attempt, $question, $answer, $answerFile, $file];
    }
}
