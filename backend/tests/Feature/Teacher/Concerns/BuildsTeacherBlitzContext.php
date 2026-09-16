<?php

namespace Tests\Feature\Teacher\Concerns;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Testing\TestResponse;

trait BuildsTeacherBlitzContext
{
    /** @return array{Institution, User, User, Group, Topic} */
    protected function blitzContext(TopicStatus $topicStatus = TopicStatus::Draft): array
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
            'blitz_timer_start_mode' => null,
        ]);
        $factory = match ($topicStatus) {
            TopicStatus::Draft => Topic::factory(),
            TopicStatus::Active => Topic::factory()->active(),
            TopicStatus::Closed => Topic::factory()->closed(),
            TopicStatus::Archived => Topic::factory()->archivedFromDraft(),
        };
        $topic = $factory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);

        return [$institution, $teacher, $admin, $group, $topic];
    }

    protected function eligibleBlitzStudent(Institution $institution, User $admin, Group $group, array $attributes = []): User
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

    protected function persistedBlitz(
        Institution $institution,
        User $teacher,
        Topic $topic,
        AssessmentAssignmentMode $mode = AssessmentAssignmentMode::Group,
        BlitzStatus $status = BlitzStatus::Draft,
        array $assessmentAttributes = [],
        array $blitzAttributes = [],
    ): Assessment {
        $assessment = Assessment::factory()->blitz()->create(array_merge([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
            'assignment_mode' => $mode,
        ], $assessmentAttributes));
        $factory = match ($status) {
            BlitzStatus::Draft => BlitzTask::factory()->draft(),
            BlitzStatus::Scheduled => BlitzTask::factory()->scheduled(),
            BlitzStatus::Active => BlitzTask::factory()->activeIndividual(),
            BlitzStatus::Closed => BlitzTask::factory()->closedIndividual(),
            BlitzStatus::Archived => BlitzTask::factory()->archivedFromDraft(),
        };
        $factory->create(array_merge([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
        ], $blitzAttributes));

        return $assessment;
    }

    protected function blitzRecipient(Assessment $assessment, User $student, User $teacher): AssessmentStudent
    {
        return AssessmentStudent::factory()->create([
            'institution_id' => $assessment->institution_id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct,
            'assigned_by_user_id' => $teacher->id,
        ]);
    }

    protected function blitzAttempt(Assessment $assessment, User $student, User $teacher, array $attributes = []): AssessmentAttempt
    {
        $recipient = AssessmentStudent::query()->where('assessment_id', $assessment->id)
            ->where('student_id', $student->id)->first()
            ?? $this->blitzRecipient($assessment, $student, $teacher);

        return AssessmentAttempt::factory()->create(array_merge([
            'assessment_student_id' => $recipient->id,
            'institution_id' => $assessment->institution_id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
        ], $attributes));
    }

    protected function officialBlitzPair(Assessment $assessment, User $teacher, bool $locked = false): TopicResultPair
    {
        $homework = Assessment::factory()->homework()->groupAssignment()->create([
            'institution_id' => $assessment->institution_id,
            'topic_id' => $assessment->topic_id,
            'teacher_id' => $teacher->id,
        ]);

        return TopicResultPair::factory()->create([
            'institution_id' => $assessment->institution_id,
            'topic_id' => $assessment->topic_id,
            'homework_assessment_id' => $homework->id,
            'blitz_assessment_id' => $assessment->id,
            'designated_by_user_id' => $teacher->id,
            'cohort_snapshotted_at' => $locked ? now() : null,
            'locked_at' => $locked ? now() : null,
        ]);
    }

    /** @return array<string, mixed> */
    protected function validBlitzPayload(array $overrides = []): array
    {
        return array_merge([
            'title' => 'Blitz 1',
            'student_instructions' => 'Answer every question.',
            'assignment_mode' => 'group',
            'student_ids' => [],
            'duration_seconds' => 600,
        ], $overrides);
    }

    protected function blitzJson(User $teacher, string $method, string $uri, array $payload = [], array $query = []): TestResponse
    {
        return $this->blitzRaw($teacher, $method, $uri, json_encode($payload, JSON_THROW_ON_ERROR), $query);
    }

    protected function blitzRaw(
        User $teacher,
        string $method,
        string $uri,
        string $content = '',
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $response = $this->call($method, $uri.($query === [] ? '' : '?'.http_build_query($query)), [], [], [], [
            'CONTENT_TYPE' => $contentType,
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('teacher-blitz-api-test')->plainTextToken,
        ], $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }
}
