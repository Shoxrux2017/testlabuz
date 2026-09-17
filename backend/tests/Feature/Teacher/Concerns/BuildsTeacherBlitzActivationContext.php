<?php

namespace Tests\Feature\Teacher\Concerns;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;

trait BuildsTeacherBlitzActivationContext
{
    use BuildsTeacherBlitzContext;

    protected function readyBlitzActivation(
        string $timerMode = 'synchronized',
        AssessmentAssignmentMode $assignmentMode = AssessmentAssignmentMode::Group,
        BlitzStatus $status = BlitzStatus::Draft,
    ): array {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext(TopicStatus::Active);
        InstitutionSetting::query()->whereKey($institution->id)->update(['blitz_timer_start_mode' => $timerMode]);
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, $assignmentMode, $status);
        $this->activationQuestion($assessment);
        if ($assignmentMode === AssessmentAssignmentMode::SelectedStudents) {
            $this->blitzRecipient($assessment, $student, $teacher);
        }

        return [$institution, $teacher, $admin, $group, $topic, $student, $assessment];
    }

    protected function activationQuestion(Assessment $assessment, string $points = '2.000001', int $position = 1): Question
    {
        return app(QuestionConfigurationWriter::class)->create($assessment, [
            'type' => 'true_false', 'prompt' => 'Is this statement correct?', 'instructions' => null,
            'points' => $points, 'position' => $position, 'checking_mode' => 'automatic',
            'configuration' => ['correct_value' => true],
        ]);
    }

    protected function activationPair(Assessment $assessment, User $teacher): TopicResultPair
    {
        $pair = $this->officialBlitzPair($assessment, $teacher);
        HomeworkAssignment::factory()->draft()->create(['assessment_id' => $pair->homework_assessment_id]);

        return $pair;
    }

    protected function activateBlitz(
        User $teacher,
        string $assessmentId,
        ?string $key = null,
        string $body = '{}',
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $headers = [
            'CONTENT_TYPE' => $contentType,
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('blitz-activation-test')->plainTextToken,
        ];
        if ($key !== '') {
            $headers['HTTP_IDEMPOTENCY_KEY'] = $key ?? (string) Str::uuid();
        }
        $uri = "/api/v1/teacher/blitz/{$assessmentId}/activate";
        $response = $this->call('POST', $uri.($query === [] ? '' : '?'.http_build_query($query)), [], [], [], $headers, $body);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    protected function activationSnapshot(Assessment $assessment, ?TopicResultPair $pair = null): array
    {
        return [
            'assessment' => $assessment->fresh()->getAttributes(),
            'blitz' => BlitzTask::query()->findOrFail($assessment->id)->getAttributes(),
            'recipients' => AssessmentStudent::query()->where('assessment_id', $assessment->id)
                ->orderBy('student_id')->get()->map->getAttributes()->all(),
            'pair' => $pair?->fresh()->getAttributes(),
        ];
    }
}
