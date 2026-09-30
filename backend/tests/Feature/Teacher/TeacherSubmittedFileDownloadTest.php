<?php

namespace Tests\Feature\Teacher;

use App\Actions\Files\DownloadReviewedSubmissionFile;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\File;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

/** S09-BE-005B / S09-T5: a Teacher downloads a submitted file of a submission they may review. */
class TeacherSubmittedFileDownloadTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext;
    use RefreshDatabase;

    private const BYTES = "%PDF-1.7\nSubmitted working\n%%EOF\n";

    private User $student;

    private HomeworkAssignment $homework;

    private AssessmentAttempt $attempt;

    private User $teacher;

    private File $file;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        Storage::fake('local');
        [$this->student, $this->homework, $this->attempt] = $this->answerContext();
        [, , $this->file] = $this->savedFileAnswer($this->attempt, $this->answerQuestion($this->homework, 'file_based'), self::BYTES);
        $this->teacher = $this->homework->assessment->teacher;
        $this->teacher->update(['must_change_password' => false]);
        $this->membership($this->teacher);
    }

    /** @return array<string, array{string, string}> */
    public static function reviewableStates(): array
    {
        return [
            'submitted work of an active task' => ['submitted', 'active'],
            'work waiting for review of a closed task' => ['waiting_for_teacher_review', 'closed'],
            'checked work of an archived task' => ['checked', 'archived'],
        ];
    }

    #[DataProvider('reviewableStates')]
    public function test_a_teacher_downloads_the_file_of_a_reviewable_submission(string $status, string $taskStatus): void
    {
        $this->freeze($status);
        HomeworkAssignment::query()->whereKey($this->homework->assessment_id)->update(match ($taskStatus) {
            'active' => [],
            'closed' => ['status' => 'closed', 'closed_at' => now()],
            'archived' => ['status' => 'archived', 'closed_at' => now(), 'archived_at' => now()],
        });

        $response = $this->download($this->teacher)->assertOk()
            ->assertHeader('Content-Type', 'application/pdf')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertStreamedContent(self::BYTES);

        $this->assertStringStartsWith('attachment;', $response->headers->get('Content-Disposition'));
        $this->assertStringContainsString('private', $response->headers->get('Cache-Control'));
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
    }

    public function test_the_file_of_work_still_in_progress_stays_student_only(): void
    {
        $this->assertNotFound($this->download($this->teacher));
        $this->download($this->student)->assertOk()->assertStreamedContent(self::BYTES);
    }

    public function test_teachers_outside_the_review_rule_are_not_found(): void
    {
        $this->freeze('checked');
        $colleague = User::factory()->teacher($this->teacher->institution)->create(['must_change_password' => false]);
        $this->membership($colleague);
        $foreign = User::factory()->teacher(Institution::factory()->create())->create(['must_change_password' => false]);

        $this->assertNotFound($this->download($colleague));
        $this->assertNotFound($this->download($foreign));
        $this->download($this->teacher)->assertOk();

        GroupTeacherMembership::query()->where('teacher_id', $this->teacher->id)->update(['ended_at' => now()]);
        $this->assertNotFound($this->download($this->teacher));
    }

    /** @return array<string, array{string}> */
    public static function brokenLinks(): array
    {
        return ['removed file' => ['removed'], 'file uploaded by another Student' => ['uploader']];
    }

    #[DataProvider('brokenLinks')]
    public function test_a_file_that_is_not_the_students_live_answer_is_not_found(string $defect): void
    {
        $this->freeze('checked');
        DB::table('files')->where('id', $this->file->id)->update($defect === 'removed'
            ? ['removed_at' => now()]
            : ['uploaded_by_user_id' => User::factory()->student($this->student->institution)->create()->id]);

        $this->assertNotFound($this->download($this->teacher));
    }

    /** @return array<string, array{string}> */
    public static function teacherPathDefects(): array
    {
        return ['a learning-material file' => ['category'], 'a removed file' => ['removed'], 'another Institution' => ['institution']];
    }

    /** The download dispatcher already turns these into 404; the Teacher path must reject them on its own too. */
    #[DataProvider('teacherPathDefects')]
    public function test_the_teacher_path_itself_rejects_files_outside_a_reviewable_submission(string $defect): void
    {
        $this->freeze('checked');
        $teacher = $this->teacher;
        match ($defect) {
            'category' => DB::table('files')->where('id', $this->file->id)->update(['category' => 'learning_material']),
            'removed' => DB::table('files')->where('id', $this->file->id)->update(['removed_at' => now()]),
            'institution' => $teacher = User::factory()->teacher(Institution::factory()->create())->create(['must_change_password' => false]),
        };

        $this->expectException(NotFoundHttpException::class);
        app(DownloadReviewedSubmissionFile::class)($teacher, $this->file->id);
    }

    public function test_a_teacher_downloads_the_file_of_a_timed_out_blitz_submission(): void
    {
        $topic = $this->homework->assessment->topic;
        $blitz = Assessment::factory()->blitz()->create(['institution_id' => $topic->institution_id,
            'topic_id' => $topic->id, 'teacher_id' => $this->teacher->id]);
        $task = BlitzTask::factory()->closedIndividual()->create(['institution_id' => $topic->institution_id, 'assessment_id' => $blitz->id]);
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $blitz->id, 'student_id' => $this->student->id,
            'assigned_by_user_id' => $this->teacher->id]);
        $attempt = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id, 'status' => 'timed_out_finalized',
            'started_at' => now()->subMinutes(20), 'deadline_at' => now()->subMinutes(10), 'finalized_at' => now()->subMinutes(10),
            'locked_at' => now()->subMinutes(10), 'finalization_reason' => 'timeout_auto_submit', 'possible_points' => '1.000000']);
        [, , $file] = $this->savedFileAnswer($attempt, $this->answerQuestion($task, 'file_based'), self::BYTES);

        $this->answerHttp($this->teacher, 'GET', '/api/v1/files/'.$file->id.'/download')->assertOk()
            ->assertStreamedContent(self::BYTES);
    }

    public function test_the_student_still_downloads_the_own_submitted_file(): void
    {
        $this->freeze('checked');

        $this->download($this->student)->assertOk()->assertStreamedContent(self::BYTES);
    }

    private function freeze(string $status): void
    {
        DB::table('assessment_attempts')->where('id', $this->attempt->id)->update([
            'status' => $status, 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit',
        ] + ($status === 'checked' ? ['earned_points' => '0.00000000', 'normalized_score' => '0.00000000',
            'scoring_completed_at' => now()] : []));
    }

    private function membership(User $teacher): void
    {
        GroupTeacherMembership::factory()->create([
            'institution_id' => $teacher->institution_id, 'group_id' => $this->homework->assessment->topic->group_id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $this->teacher->id,
        ]);
    }

    private function download(User $actor): TestResponse
    {
        return $this->answerHttp($actor, 'GET', '/api/v1/files/'.$this->file->id.'/download');
    }

    private function assertNotFound(TestResponse $response): void
    {
        $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertStringNotContainsString($this->file->storage_key, $response->getContent());
    }
}
