<?php

namespace Tests\Feature\Teacher;

use App\Models\Assessment;
use App\Models\HomeworkAssignment;
use App\Models\Question;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzActivationContext;
use Tests\TestCase;

class TeacherOfficialHomeworkBlitzFirstAuthoringTest extends TestCase
{
    use BuildsTeacherBlitzActivationContext;
    use RefreshDatabase;

    public function test_blitz_first_activity_keeps_official_homework_authorable_until_its_own_activity(): void
    {
        [$teacher, $topic, $student, $blitz, $homework] = $this->designatedBlitzFirstPair();
        $this->startOfficialBlitz($student, $blitz);

        $this->blitzJson($teacher, 'POST', '/api/v1/teacher/assessments/'.$homework->id.'/questions',
            $this->homeworkQuestionPayload(1))->assertCreated();
        $this->blitzRaw($teacher, 'POST', '/api/v1/teacher/homework/'.$homework->id.'/activate')
            ->assertOk()->assertJsonPath('data.status', 'active');

        $replacement = $this->draftOfficialHomework($topic, $teacher);
        $this->blitzJson($teacher, 'PUT', '/api/v1/teacher/topics/'.$topic->id.'/result-pair', [
            'homework_assessment_id' => $replacement->id,
        ])->assertConflict()->assertJsonPath('code', 'result_pair_locked');

        $this->studentPost($student, '/api/v1/student/homework/'.$homework->id.'/attempts', '')->assertCreated();
        $this->blitzJson($teacher, 'POST', '/api/v1/teacher/assessments/'.$homework->id.'/questions',
            $this->homeworkQuestionPayload(2))->assertConflict()->assertJsonPath('code', 'result_pair_locked');
    }

    #[DataProvider('existingQuestionMutations')]
    public function test_blitz_first_activity_allows_existing_question_mutation_on_zero_attempt_official_homework(string $mutation): void
    {
        [$teacher, , $student, $blitz, $homework] = $this->designatedBlitzFirstPair();
        $first = $this->activationQuestion($homework, '1.000000', 1);
        $second = $this->activationQuestion($homework, '1.000000', 2);
        $this->startOfficialBlitz($student, $blitz);

        $response = match ($mutation) {
            'update' => $this->blitzJson($teacher, 'PATCH', '/api/v1/teacher/questions/'.$first->id, ['prompt' => 'Is the updated statement correct?']),
            'reorder' => $this->blitzJson($teacher, 'POST', '/api/v1/teacher/assessments/'.$homework->id.'/questions/reorder', [
                'question_ids' => [$second->id, $first->id],
            ]),
            'delete' => $this->blitzRaw($teacher, 'DELETE', '/api/v1/teacher/questions/'.$second->id),
        };

        $response->assertOk()->assertJsonPath('data.id', $homework->id);
    }

    /** @return array<string, array{string}> */
    public static function existingQuestionMutations(): array
    {
        return ['update' => ['update'], 'reorder' => ['reorder'], 'delete' => ['delete']];
    }

    public function test_pair_lock_without_any_official_activity_still_blocks_homework_authoring(): void
    {
        [$teacher, $topic, , , $homework] = $this->designatedBlitzFirstPair();
        TopicResultPair::query()->where('topic_id', $topic->id)->update(['locked_at' => now()]);

        $this->blitzJson($teacher, 'POST', '/api/v1/teacher/assessments/'.$homework->id.'/questions',
            $this->homeworkQuestionPayload(1))->assertConflict()->assertJsonPath('code', 'result_pair_locked');
        $this->assertSame(0, Question::query()->where('assessment_id', $homework->id)->count());
    }

    /** @return array{User, Topic, User, Assessment, Assessment} */
    private function designatedBlitzFirstPair(): array
    {
        [, $teacher, , , $topic, $student, $blitz] = $this->readyBlitzActivation('individual');
        $student->forceFill(['must_change_password' => false])->save();
        $homework = $this->draftOfficialHomework($topic, $teacher);
        $this->blitzJson($teacher, 'PUT', '/api/v1/teacher/topics/'.$topic->id.'/result-pair', [
            'homework_assessment_id' => $homework->id, 'blitz_assessment_id' => $blitz->id,
        ])->assertOk();
        $this->activateBlitz($teacher, $blitz->id, body: '')->assertOk();

        return [$teacher, $topic, $student, $blitz, $homework];
    }

    private function startOfficialBlitz(User $student, Assessment $blitz): void
    {
        $this->studentPost($student, '/api/v1/student/blitz/'.$blitz->id.'/attempts', '{"intent":"start_normal"}')->assertCreated();
        $this->assertNotNull(TopicResultPair::query()->where('blitz_assessment_id', $blitz->id)->value('locked_at'));
    }

    private function draftOfficialHomework(Topic $topic, User $teacher): Assessment
    {
        $assessment = Assessment::factory()->homework()->groupAssignment()->create([
            'institution_id' => $topic->institution_id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
        ]);
        HomeworkAssignment::factory()->draft()->create([
            'assessment_id' => $assessment->id, 'deadline_at' => now()->addDay(),
        ]);

        return $assessment;
    }

    /** @return array<string, mixed> */
    private function homeworkQuestionPayload(int $position): array
    {
        return [
            'type' => 'true_false', 'prompt' => 'Is this statement correct?', 'instructions' => null, 'points' => 1,
            'position' => $position, 'checking_mode' => 'automatic', 'configuration' => ['correct_value' => true],
        ];
    }

    private function studentPost(User $student, string $uri, string $body): TestResponse
    {
        try {
            return $this->call('POST', $uri, [], [], [], [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('blitz-first-homework')->plainTextToken,
                'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(),
            ], $body);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }
}
