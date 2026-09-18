<?php

namespace Tests\Feature\Student\Concerns;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Models\AnswerBooleanValue;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;

trait BuildsStudentBlitzHistoricalReplayContext
{
    use BuildsStudentBlitzAnswerContext, BuildsStudentHomeworkFileAnswerContext {
        BuildsStudentBlitzAnswerContext::answerContext insteadof BuildsStudentHomeworkFileAnswerContext;
    }

    protected function historicalReplayContext(): array
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $key = (string) Str::uuid();
        $id = $this->startStudentBlitz($student, $assessment, $key)->assertCreated()->json('data.id');
        $attempt = AssessmentAttempt::query()->findOrFail($id);
        $answers = $this->historicalReplayAnswers($attempt, $assessment);

        return [$student, $assessment, $attempt, $key, ...$answers];
    }

    protected function historicalReplayAnswers(AssessmentAttempt $attempt, Assessment $assessment): array
    {
        $blitz = BlitzTask::query()->findOrFail($assessment->id);
        $typedQuestion = $this->answerQuestion($blitz, 'true_false', 1);
        $fileQuestion = $this->answerQuestion($blitz, 'file_based', 2);
        $typedAnswer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $typedQuestion->id]);
        AnswerBooleanValue::factory()->create(['answer_id' => $typedAnswer->id, 'boolean_value' => true]);
        [$fileAnswer, $answerFile, $file] = $this->savedFileAnswer($attempt, $fileQuestion);

        return [$typedAnswer, $fileAnswer, $file, $typedQuestion, $fileQuestion];
    }

    protected function advanceHistoricalReplay(AssessmentAttempt $attempt, string $status, string $reason, AttemptAnswer $typedAnswer, AttemptAnswer $fileAnswer): void
    {
        $finalizedAt = $reason === 'timeout_auto_submit' ? $attempt->deadline_at : $attempt->started_at->copy()->addSecond();
        $attempt->update([
            'status' => $status,
            'submitted_at' => $reason === 'student_submit' ? $finalizedAt : null,
            'finalized_at' => $finalizedAt, 'locked_at' => $finalizedAt,
            'finalization_reason' => AssessmentAttemptFinalizationReason::from($reason),
            'earned_points' => '2.00000000', 'normalized_score' => '40.00000000', 'scoring_completed_at' => now(),
        ]);
        $this->addHistoricalCheckingMetadata($attempt, $status, $typedAnswer, $fileAnswer);
    }

    protected function addHistoricalCheckingMetadata(AssessmentAttempt $attempt, string $status, AttemptAnswer $typedAnswer, AttemptAnswer $fileAnswer): void
    {
        $typedAnswer->update(['checking_status' => 'auto_checked', 'awarded_points' => '1.00000000',
            'feedback' => 'Private automatic feedback', 'checked_at' => now()]);
        $fileAnswer->update(['checking_status' => $status === 'checked' ? 'teacher_checked' : 'waiting_for_teacher_review',
            'awarded_points' => '1.00000000', 'feedback' => 'Private teacher feedback',
            'checked_by_user_id' => $attempt->assessment->teacher_id, 'checked_at' => now()]);
    }

    protected function historicalReplaySnapshot(): array
    {
        $snapshot = $this->fileAnswerSnapshot();
        foreach (['assessment_attempts', 'idempotency_records', 'assessment_students', 'blitz_tasks', 'topic_result_pairs', 'blitz_attempt_exceptions'] as $table) {
            $snapshot[$table] = DB::table($table)->orderBy($table === 'blitz_tasks' ? 'assessment_id' : 'id')
                ->get()->map(fn (object $row): array => (array) $row)->all();
        }

        return $snapshot;
    }

    protected function assertHistoricalReplayPrivacy(array $value): void
    {
        foreach ($value as $key => $child) {
            $this->assertNotContains($key, ['checking_status', 'awarded_points', 'feedback', 'checked_by_user_id', 'checked_at',
                'earned_points', 'normalized_score', 'scoring_completed_at', 'is_correct', 'correct_value', 'accepted_answers',
                'checking_mode', 'storage_key', 'storage_disk', 'checksum_sha256', 'correct_position', 'match_key']);
            if (is_array($child)) {
                $this->assertHistoricalReplayPrivacy($child);
            }
        }
    }

    protected function submitHistoricalReplay(User $student, AssessmentAttempt $attempt, string $key): TestResponse
    {
        return $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', '{}', $key);
    }
}
