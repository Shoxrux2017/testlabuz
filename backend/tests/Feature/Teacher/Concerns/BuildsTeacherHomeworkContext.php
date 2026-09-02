<?php

namespace Tests\Feature\Teacher\Concerns;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Testing\TestResponse;

trait BuildsTeacherHomeworkContext
{
    /** @return array{Institution, User, User, Group, Topic} */
    protected function homeworkContext(TopicStatus $topicStatus = TopicStatus::Draft): array
    {
        $institution = Institution::factory()->create();
        $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
            'timezone' => 'Asia/Tashkent',
        ]);

        $topicFactory = match ($topicStatus) {
            TopicStatus::Draft => Topic::factory(),
            TopicStatus::Active => Topic::factory()->active(),
            TopicStatus::Closed => Topic::factory()->closed(),
            TopicStatus::Archived => Topic::factory()->archivedFromDraft(),
        };
        $topic = $topicFactory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);

        return [$institution, $teacher, $admin, $group, $topic];
    }

    protected function eligibleStudent(Institution $institution, User $admin, Group $group, array $attributes = []): User
    {
        $student = User::factory()->student($institution)->create($attributes);
        GroupStudentMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $admin->id,
        ]);

        return $student;
    }

    protected function persistedHomework(
        Institution $institution,
        User $teacher,
        Topic $topic,
        AssessmentAssignmentMode $mode = AssessmentAssignmentMode::Group,
        HomeworkStatus $status = HomeworkStatus::Draft,
        array $assessmentAttributes = [],
        array $homeworkAttributes = [],
    ): Assessment {
        $assessment = Assessment::factory()->homework()->create(array_merge([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
            'assignment_mode' => $mode,
        ], $assessmentAttributes));
        $factory = match ($status) {
            HomeworkStatus::Draft => HomeworkAssignment::factory()->draft(),
            HomeworkStatus::Active => HomeworkAssignment::factory()->active(),
            HomeworkStatus::Closed => HomeworkAssignment::factory()->closed(),
            HomeworkStatus::Archived => HomeworkAssignment::factory()->archivedFromDraft(),
        };
        $factory->create(array_merge([
            'assessment_id' => $assessment->id,
            'institution_id' => $institution->id,
        ], $homeworkAttributes));

        return $assessment;
    }

    /** @return array<string, mixed> */
    protected function validHomeworkPayload(array $overrides = []): array
    {
        return array_merge([
            'title' => 'Homework 1',
            'description' => null,
            'student_instructions' => 'Answer every question.',
            'assignment_mode' => 'group',
            'student_ids' => [],
            'deadline_at' => null,
            'questions' => [],
        ], $overrides);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $query
     */
    protected function homeworkJson(
        User $teacher,
        string $method,
        string $uri,
        array $payload = [],
        array $query = [],
    ): TestResponse {
        return $this->homeworkRaw(
            $teacher,
            $method,
            $uri,
            json_encode($payload, JSON_THROW_ON_ERROR),
            $query,
        );
    }

    /** @param array<string, mixed> $query */
    protected function homeworkRaw(
        User $teacher,
        string $method,
        string $uri,
        string $content,
        array $query = [],
    ): TestResponse {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('teacher-homework-api-test')->plainTextToken,
        ];

        $response = $this->call($method, $requestUri, [], [], [], $server, $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }
}
