<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\BlitzStatus;
use App\Models\HomeworkAssignment;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Teacher\Concerns\BuildsTeacherSubmissionContext;
use Tests\TestCase;

/** S09-BE-005B: Teacher Homework and Blitz resources count the task's work waiting for review. */
class TeacherTaskReviewSummaryTest extends TestCase
{
    use BuildsTeacherSubmissionContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        $this->submissionContext();
    }

    public function test_the_homework_detail_counts_waiting_submissions_and_the_overdue_ones(): void
    {
        $homework = $this->homeworkTask(['review_due_at' => now()]);
        foreach (['waiting_for_teacher_review', 'waiting_for_teacher_review', 'checked', 'submitted', 'in_progress'] as $index => $status) {
            $this->submission($homework, $this->studentNamed('Student '.$index), $status);
        }

        $this->homeworkDetail($homework->id)->assertJsonPath('data.review_summary',
            ['waiting_for_teacher_review' => 2, 'overdue' => 2]);

        HomeworkAssignment::query()->whereKey($homework->id)->update(['review_due_at' => now()->addSecond()]);
        $this->homeworkDetail($homework->id)->assertJsonPath('data.review_summary',
            ['waiting_for_teacher_review' => 2, 'overdue' => 0]);

        HomeworkAssignment::query()->whereKey($homework->id)->update(['review_due_at' => null]);
        $this->homeworkDetail($homework->id)->assertJsonPath('data.review_summary',
            ['waiting_for_teacher_review' => 2, 'overdue' => 0]);
    }

    public function test_the_waiting_count_equals_the_review_queue_total(): void
    {
        $homework = $this->homeworkTask();
        foreach (range(1, 3) as $index) {
            $this->submission($homework, $this->studentNamed('Student '.$index), 'waiting_for_teacher_review');
        }
        $this->submission($this->homeworkTask(), $this->studentNamed('Elsewhere'), 'waiting_for_teacher_review');
        // Outside the review rule: its recipient row belongs to another Student.
        $otherRecipient = $this->blitzRecipient($homework, $this->studentNamed('Other'), $this->teacher);
        $this->submission($homework, $this->studentNamed('Mismatched'), 'waiting_for_teacher_review',
            ['assessment_student_id' => $otherRecipient->id]);

        $queueTotal = $this->submissionsRequest($this->teacher, ['assessment_id' => $homework->id,
            'checking_status' => 'waiting_for_teacher_review'])->assertOk()->json('meta.pagination.total');

        $this->assertSame(3, $queueTotal);
        $this->homeworkDetail($homework->id)->assertJsonPath('data.review_summary.waiting_for_teacher_review', $queueTotal);
    }

    public function test_a_homework_mutation_response_carries_the_summary(): void
    {
        $homework = $this->homeworkTask();
        $this->submission($homework, $this->studentNamed('Student'), 'waiting_for_teacher_review');

        $this->homeworkJson($this->teacher, 'PUT', '/api/v1/teacher/homework/'.$homework->id.'/review-due-at',
            ['review_due_at' => '2026-09-30T14:00:00+05:00'])->assertOk()
            ->assertJsonPath('data.review_summary', ['waiting_for_teacher_review' => 1, 'overdue' => 1]);
    }

    public function test_blitz_resources_count_waiting_submissions_and_are_never_overdue(): void
    {
        $blitz = $this->persistedBlitz($this->institution, $this->teacher, $this->topic,
            AssessmentAssignmentMode::Group, BlitzStatus::Active);
        $this->submission($blitz, $this->studentNamed('Waiting'), 'waiting_for_teacher_review');
        $this->submission($blitz, $this->studentNamed('Checked'), 'checked');

        $this->blitzRaw($this->teacher, 'GET', '/api/v1/teacher/blitz/'.$blitz->id)->assertOk()
            ->assertJsonPath('data.review_summary', ['waiting_for_teacher_review' => 1, 'overdue' => 0]);
        $this->blitzRaw($this->teacher, 'POST', '/api/v1/teacher/blitz/'.$blitz->id.'/close', '{}')->assertOk()
            ->assertJsonPath('data.review_summary', ['waiting_for_teacher_review' => 1, 'overdue' => 0]);
    }

    private function homeworkDetail(string $homeworkId): TestResponse
    {
        return $this->homeworkRaw($this->teacher, 'GET', '/api/v1/teacher/homework/'.$homeworkId, '')->assertOk();
    }
}
