<?php

namespace Tests\Feature\Student\Concerns;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\FileExtension;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;

trait BuildsStudentBlitzContext
{
    use BuildsTeacherBlitzContext;

    protected function studentBlitzActor(?Institution $institution = null, array $attributes = []): User
    {
        if ($institution === null) {
            $institution = Institution::factory()->create();
            InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        }

        return User::factory()->student($institution)->create(array_merge(['must_change_password' => false], $attributes));
    }

    protected function studentBlitz(
        User $student,
        string $timerMode = 'individual',
        BlitzStatus $status = BlitzStatus::Active,
        array $assessmentAttributes = [],
        array $blitzAttributes = [],
        bool $assigned = true,
    ): Assessment {
        $topic = Topic::factory()->active()->create(['institution_id' => $student->institution_id]);
        $activation = Carbon::parse($blitzAttributes['activated_at'] ?? '2026-09-17 11:55:00 UTC');
        $timing = $status === BlitzStatus::Active ? [
            'created_at' => $activation->copy()->subMinute(),
            'activated_at' => $activation,
            'timer_start_mode_snapshot' => $timerMode,
            'synchronized_ends_at' => $timerMode === 'synchronized' ? $activation->copy()->addSeconds(600) : null,
        ] : [];
        $assessment = $this->persistedBlitz(
            $student->institution, $topic->teacher, $topic, AssessmentAssignmentMode::SelectedStudents, $status,
            array_merge(['title' => 'Classroom Blitz', 'description' => 'Timed practice.',
                'student_instructions' => 'Answer independently.', 'total_possible_points' => '5.000000'], $assessmentAttributes),
            array_merge($timing, $blitzAttributes),
        );
        if ($assigned) {
            $this->blitzRecipient($assessment, $student, $topic->teacher);
        }

        return $assessment;
    }

    protected function studentBlitzAttempt(Assessment $assessment, User $student, array $attributes = []): AssessmentAttempt
    {
        $blitz = BlitzTask::query()->findOrFail($assessment->id);
        $startedAt = Carbon::parse('2026-09-17 11:59:00 UTC');

        return $this->blitzAttempt($assessment, $student, $assessment->teacher, array_merge([
            'started_at' => $startedAt,
            'deadline_at' => $blitz->synchronized_ends_at ?? $startedAt->copy()->addSeconds($blitz->duration_seconds),
            'possible_points' => $assessment->total_possible_points,
        ], $attributes))->fresh();
    }

    protected function terminateStudentBlitzAttempt(AssessmentAttempt $attempt): void
    {
        $attempt->update([
            'status' => AssessmentAttemptStatus::Submitted,
            'submitted_at' => now()->startOfSecond(), 'finalized_at' => now()->startOfSecond(),
            'locked_at' => now()->startOfSecond(),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
        ]);
    }

    protected function studentBlitzQuestions(Assessment $assessment): array
    {
        $writer = app(QuestionConfigurationWriter::class);
        $choice = $writer->create($assessment, [
            'type' => 'single_choice', 'prompt' => 'Secret timed prompt: choose the prime.',
            'instructions' => 'Choose one.', 'points' => 3, 'position' => 1, 'checking_mode' => 'automatic',
            'configuration' => ['options' => [
                ['text' => 'Secret option seven', 'is_correct' => true, 'position' => 1],
                ['text' => 'Secret option eight', 'is_correct' => false, 'position' => 2],
            ]],
        ]);
        $file = $writer->create($assessment, [
            'type' => 'file_based', 'prompt' => 'Upload your working.', 'instructions' => null,
            'points' => 2, 'position' => 2, 'checking_mode' => 'manual',
            'configuration' => ['allowed_extensions' => FileExtension::values()],
        ]);

        return [$choice, $file];
    }

    protected function officialStudentBlitz(User $student): array
    {
        $assessment = $this->studentBlitz($student, assessmentAttributes: ['assignment_mode' => AssessmentAssignmentMode::Group]);
        AssessmentStudent::query()->where('assessment_id', $assessment->id)->update(['assignment_source' => AssessmentAssignmentSource::Group]);
        $pair = $this->officialBlitzPair($assessment, $assessment->teacher);
        $pair->update([
            'designated_at' => Carbon::parse('2026-09-17 11:49:00 UTC'),
            'cohort_snapshotted_at' => Carbon::parse('2026-09-17 11:50:00 UTC'),
        ]);

        return [$assessment, $pair];
    }

    protected function startStudentBlitz(User $student, Assessment $assessment, ?string $key = '', string $intent = 'start_normal', ?string $attemptId = null): TestResponse
    {
        $body = ['intent' => $intent];
        if ($attemptId !== null) {
            $body['attempt_id'] = $attemptId;
        }

        return $this->studentBlitzRequest($student, 'POST', '/api/v1/student/blitz/'.$assessment->id.'/attempts',
            json_encode($body, JSON_THROW_ON_ERROR), $key);
    }

    protected function studentBlitzRequest(?User $actor, string $method, string $uri, string $body = '', ?string $key = '', string $contentType = 'application/json'): TestResponse
    {
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json'];
        if ($actor !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$actor->createToken('student-blitz-test')->plainTextToken;
        }
        if ($key !== null) {
            $server['HTTP_IDEMPOTENCY_KEY'] = $key === '' ? (string) Str::uuid() : $key;
        }
        try {
            return $this->call($method, $uri, [], [], [], $server, $body);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }

    protected function assertStudentBlitzMetadataIsSecret(TestResponse $response): void
    {
        foreach (['questions', 'answer_ui', 'is_correct', 'correct_value', 'accepted_answers',
            'checking_mode', 'institution_id', 'teacher_id', 'assessment_student_id',
            'Secret timed prompt', 'Secret option seven', 'Secret option eight'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }
}
