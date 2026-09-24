<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Feature\Student\Concerns\AssertsQuestionItemIdentifierPrivacy;
use Tests\Feature\Teacher\Concerns\BuildsTeacherHomeworkContext;
use Tests\TestCase;

class StudentHomeworkQuestionItemIdentifierPrivacyTest extends TestCase
{
    use AssertsQuestionItemIdentifierPrivacy;
    use BuildsTeacherHomeworkContext;
    use RefreshDatabase;

    public function test_homework_start_item_ids_do_not_reveal_matching_pairs_or_ordering(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group, ['must_change_password' => false]);
        $assessment = $this->persistedHomework($institution, $teacher, $topic, AssessmentAssignmentMode::Group,
            HomeworkStatus::Draft, homeworkAttributes: ['deadline_at' => now()->addDay()]);
        $this->authorKeyedQuestions($teacher, $assessment->id, 1);
        $this->homeworkRaw($teacher, 'POST', '/api/v1/teacher/homework/'.$assessment->id.'/activate', '')->assertOk();

        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('homework-item-privacy')->plainTextToken,
            'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(),
        ];
        $start = $this->call('POST', '/api/v1/student/homework/'.$assessment->id.'/attempts', [], [], [], $server, '')
            ->assertCreated();

        $this->assertItemIdentifiersRevealNoKey($start->json('data.questions'));
    }
}
