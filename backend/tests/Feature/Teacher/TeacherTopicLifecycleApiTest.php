<?php

namespace Tests\Feature\Teacher;

use App\Actions\Teacher\ActivateTeacherTopic;
use App\Enums\FileCategory;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Http\Resources\Teacher\TeacherTopicResource;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class TeacherTopicLifecycleApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/teacher/topics';

    private const TOPIC_KEYS = [
        'id',
        'group',
        'title',
        'description',
        'subject',
        'student_instructions',
        'lesson_at',
        'status',
        'activated_at',
        'closed_at',
        'archived_at',
        'created_at',
        'updated_at',
    ];

    public function test_exact_lifecycle_routes_are_registered_once_with_teacher_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => in_array($route['uri'], [
                'api/v1/teacher/topics/{topic}/activate',
                'api/v1/teacher/topics/{topic}/close',
                'api/v1/teacher/topics/{topic}/archive',
            ], true))
            ->values()
            ->all();

        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'];

        $this->assertSame([
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/topics/{topic}/activate', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/topics/{topic}/close', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/topics/{topic}/archive', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_lifecycle_routes_enforce_authentication_account_institution_password_and_role_gates(): void
    {
        $institution = Institution::factory()->create();
        $topicId = '00000000-0000-0000-0000-000000000099';

        foreach (['activate', 'close', 'archive'] as $operation) {
            $uri = self::URI.'/'.$topicId.'/'.$operation;
            $this->postJson($uri)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
            $this->requestAs($this->teacher($institution, ['is_active' => false]), $uri)
                ->assertForbidden()->assertJsonPath('code', 'user_inactive');
            $this->requestAs($this->teacher($institution, ['must_change_password' => true]), $uri)
                ->assertForbidden()->assertJsonPath('code', 'password_change_required');
        }

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $this->requestAs($this->teacher($inactiveInstitution), self::URI.'/'.$topicId.'/activate')
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

        foreach ([UserRole::PlatformOwner, UserRole::InstitutionAdmin, UserRole::Student, UserRole::Parent] as $role) {
            $actor = $role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);
            $this->requestAs($actor, self::URI.'/'.$topicId.'/activate')
                ->assertForbidden()->assertJsonPath('code', 'forbidden');
        }
    }

    public function test_no_body_and_explicit_empty_json_object_are_accepted_for_every_lifecycle_endpoint(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $topics = [
            'activate' => $this->topic($institution, $group, $teacher, TopicStatus::Active),
            'close' => $this->topic($institution, $group, $teacher, TopicStatus::Closed),
            'archive' => $this->topic($institution, $group, $teacher, TopicStatus::Archived),
        ];

        foreach ($topics as $operation => $topic) {
            $uri = $this->lifecycleUri($topic, $operation);
            $this->requestAs($teacher, $uri, contentType: 'text/plain')
                ->assertOk()->assertJsonPath('data.status', $topic->status->value);
            $this->requestAs($teacher, $uri, content: '{}')
                ->assertOk()->assertJsonPath('data.status', $topic->status->value);
        }
    }

    public function test_every_lifecycle_endpoint_rejects_query_and_non_empty_or_invalid_bodies(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $topics = [
            'activate' => $this->topic($institution, $group, $teacher, TopicStatus::Active),
            'close' => $this->topic($institution, $group, $teacher, TopicStatus::Closed),
            'archive' => $this->topic($institution, $group, $teacher, TopicStatus::Archived),
        ];

        foreach ($topics as $operation => $topic) {
            $uri = $this->lifecycleUri($topic, $operation);

            foreach (['{', '42', '[]', 'null', '{"status":"active"}'] as $content) {
                $this->requestAs($teacher, $uri, content: $content)
                    ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            }

            $this->requestAs($teacher, $uri, content: 'payload', contentType: 'text/plain')
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            $this->requestAs($teacher, $uri, query: ['unexpected' => 'x'])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
    }

    public function test_lifecycle_scope_is_tenant_teacher_and_current_membership_safe_before_state_disclosure(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $otherTeacher = $this->teacher($institution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $admin = $this->admin($institution);
        $foreignAdmin = $this->admin($foreignInstitution);
        $group = $this->group($institution, $admin);
        $endedGroup = $this->group($institution, $admin);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin);
        $this->membership($institution, $group, $teacher, $admin);
        $this->membership($institution, $endedGroup, $teacher, $admin, ended: true);
        $this->membership($foreignInstitution, $foreignGroup, $foreignTeacher, $foreignAdmin);

        $hiddenTopics = [
            $this->topic($institution, $group, $otherTeacher, TopicStatus::Closed),
            $this->topic($institution, $endedGroup, $teacher, TopicStatus::Closed),
            $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher, TopicStatus::Closed),
        ];

        foreach (['activate', 'close', 'archive'] as $operation) {
            foreach (['not-a-uuid', '00000000-0000-0000-0000-000000000098', ...collect($hiddenTopics)->pluck('id')->all()] as $topicId) {
                $response = $this->requestAs($teacher, self::URI.'/'.$topicId.'/'.$operation);
                $this->assertSame([
                    'message' => 'The requested resource was not found.',
                    'code' => 'resource_not_found',
                    'errors' => [],
                ], $response->assertNotFound()->json());
            }
        }
    }

    public function test_active_group_implements_the_complete_lifecycle_matrix(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $matrix = [
            'activate' => [
                TopicStatus::Draft->value => [200, TopicStatus::Active],
                TopicStatus::Active->value => [200, TopicStatus::Active],
                TopicStatus::Closed->value => [409, TopicStatus::Closed],
                TopicStatus::Archived->value => [409, TopicStatus::Archived],
            ],
            'close' => [
                TopicStatus::Draft->value => [409, TopicStatus::Draft],
                TopicStatus::Active->value => [200, TopicStatus::Closed],
                TopicStatus::Closed->value => [200, TopicStatus::Closed],
                TopicStatus::Archived->value => [409, TopicStatus::Archived],
            ],
            'archive' => [
                TopicStatus::Draft->value => [200, TopicStatus::Archived],
                TopicStatus::Active->value => [409, TopicStatus::Active],
                TopicStatus::Closed->value => [200, TopicStatus::Archived],
                TopicStatus::Archived->value => [200, TopicStatus::Archived],
            ],
        ];

        foreach ($matrix as $operation => $states) {
            foreach ($states as $current => [$statusCode, $finalStatus]) {
                $topic = $this->topic($institution, $group, $teacher, TopicStatus::from($current));
                if ($operation === 'activate' && $current === TopicStatus::Draft->value) {
                    $this->material($institution, $topic, $teacher);
                }

                $response = $this->requestAs($teacher, $this->lifecycleUri($topic, $operation));

                if ($statusCode === 200) {
                    $response->assertOk()->assertJsonPath('data.status', $finalStatus->value);
                } else {
                    $this->assertTopicConflict($response);
                }
                $this->assertSame($finalStatus, $topic->fresh()?->status, $operation.' from '.$current);
            }
        }
    }

    public function test_archived_group_implements_the_complete_historical_lifecycle_matrix(): void
    {
        [$institution, $teacher, $admin] = $this->baseContext();
        $group = $this->group($institution, $admin, archived: true);
        $this->membership($institution, $group, $teacher, $admin);
        $matrix = [
            'activate' => [
                TopicStatus::Draft->value => [409, TopicStatus::Draft],
                TopicStatus::Active->value => [409, TopicStatus::Active],
                TopicStatus::Closed->value => [409, TopicStatus::Closed],
                TopicStatus::Archived->value => [409, TopicStatus::Archived],
            ],
            'close' => [
                TopicStatus::Draft->value => [409, TopicStatus::Draft],
                TopicStatus::Active->value => [200, TopicStatus::Closed],
                TopicStatus::Closed->value => [200, TopicStatus::Closed],
                TopicStatus::Archived->value => [409, TopicStatus::Archived],
            ],
            'archive' => [
                TopicStatus::Draft->value => [200, TopicStatus::Archived],
                TopicStatus::Active->value => [409, TopicStatus::Active],
                TopicStatus::Closed->value => [200, TopicStatus::Archived],
                TopicStatus::Archived->value => [200, TopicStatus::Archived],
            ],
        ];

        foreach ($matrix as $operation => $states) {
            foreach ($states as $current => [$statusCode, $finalStatus]) {
                $topic = $this->topic($institution, $group, $teacher, TopicStatus::from($current));
                $response = $this->requestAs($teacher, $this->lifecycleUri($topic, $operation));

                if ($statusCode === 200) {
                    $response->assertOk()
                        ->assertJsonPath('data.status', $finalStatus->value)
                        ->assertJsonPath('data.group.status', 'archived');
                } else {
                    $this->assertTopicConflict($response);
                }
                $this->assertSame($finalStatus, $topic->fresh()?->status, $operation.' from '.$current);
            }
        }
    }

    public function test_real_transitions_and_same_state_calls_use_exact_messages_and_preserve_timestamps_on_no_op(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $original = CarbonImmutable::parse('2026-08-22 08:00:00', 'UTC');
        $topic = $this->topic($institution, $group, $teacher, TopicStatus::Draft, [
            'title' => 'Lifecycle topic',
            'created_at' => $original,
            'updated_at' => $original,
        ]);
        $this->material($institution, $topic, $teacher);

        try {
            CarbonImmutable::setTestNow('2026-08-22 10:00:00 UTC');
            $activate = $this->requestAs($teacher, $this->lifecycleUri($topic, 'activate'));
            $this->assertSuccessfulLifecycleResponse($activate, 'Topic activated successfully.', TopicStatus::Active);
            $activate->assertJsonPath('data.activated_at', '2026-08-22T10:00:00Z')
                ->assertJsonPath('data.updated_at', '2026-08-22T10:00:00Z');

            CarbonImmutable::setTestNow('2026-08-22 11:00:00 UTC');
            $activateNoOp = $this->requestAs($teacher, $this->lifecycleUri($topic, 'activate'));
            $this->assertSuccessfulLifecycleResponse($activateNoOp, 'Topic activated successfully.', TopicStatus::Active);
            $activateNoOp->assertJsonPath('data.activated_at', '2026-08-22T10:00:00Z')
                ->assertJsonPath('data.updated_at', '2026-08-22T10:00:00Z');

            CarbonImmutable::setTestNow('2026-08-22 12:00:00 UTC');
            $close = $this->requestAs($teacher, $this->lifecycleUri($topic, 'close'));
            $this->assertSuccessfulLifecycleResponse($close, 'Topic closed successfully.', TopicStatus::Closed);
            $close->assertJsonPath('data.activated_at', '2026-08-22T10:00:00Z')
                ->assertJsonPath('data.closed_at', '2026-08-22T12:00:00Z')
                ->assertJsonPath('data.updated_at', '2026-08-22T12:00:00Z');

            CarbonImmutable::setTestNow('2026-08-22 13:00:00 UTC');
            $closeNoOp = $this->requestAs($teacher, $this->lifecycleUri($topic, 'close'));
            $this->assertSuccessfulLifecycleResponse($closeNoOp, 'Topic closed successfully.', TopicStatus::Closed);
            $closeNoOp->assertJsonPath('data.closed_at', '2026-08-22T12:00:00Z')
                ->assertJsonPath('data.updated_at', '2026-08-22T12:00:00Z');

            CarbonImmutable::setTestNow('2026-08-22 14:00:00 UTC');
            $archive = $this->requestAs($teacher, $this->lifecycleUri($topic, 'archive'));
            $this->assertSuccessfulLifecycleResponse($archive, 'Topic archived successfully.', TopicStatus::Archived);
            $archive->assertJsonPath('data.activated_at', '2026-08-22T10:00:00Z')
                ->assertJsonPath('data.closed_at', '2026-08-22T12:00:00Z')
                ->assertJsonPath('data.archived_at', '2026-08-22T14:00:00Z')
                ->assertJsonPath('data.updated_at', '2026-08-22T14:00:00Z');

            CarbonImmutable::setTestNow('2026-08-22 15:00:00 UTC');
            $archiveNoOp = $this->requestAs($teacher, $this->lifecycleUri($topic, 'archive'));
            $this->assertSuccessfulLifecycleResponse($archiveNoOp, 'Topic archived successfully.', TopicStatus::Archived);
            $archiveNoOp->assertJsonPath('data.archived_at', '2026-08-22T14:00:00Z')
                ->assertJsonPath('data.updated_at', '2026-08-22T14:00:00Z');
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_activation_requires_valid_persisted_metadata_and_one_current_material_file_pair(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $notReady = [];
        $notReady[] = $this->topic($institution, $group, $teacher);

        $removedMaterialTopic = $this->topic($institution, $group, $teacher);
        $this->material($institution, $removedMaterialTopic, $teacher, ['removed_at' => now()]);
        $notReady[] = $removedMaterialTopic;

        $removedFileTopic = $this->topic($institution, $group, $teacher);
        $this->material($institution, $removedFileTopic, $teacher, fileAttributes: ['removed_at' => now()]);
        $notReady[] = $removedFileTopic;

        $wrongCategoryTopic = $this->topic($institution, $group, $teacher);
        $this->material($institution, $wrongCategoryTopic, $teacher, fileAttributes: ['category' => FileCategory::StudentSubmission]);
        $notReady[] = $wrongCategoryTopic;

        foreach (['title', 'subject', 'student_instructions'] as $invalidField) {
            $invalidMetadataTopic = $this->topic($institution, $group, $teacher, TopicStatus::Draft, [$invalidField => "\t"]);
            $this->material($institution, $invalidMetadataTopic, $teacher);
            $notReady[] = $invalidMetadataTopic;
        }

        foreach ($notReady as $topic) {
            $this->assertTopicConflict($this->requestAs($teacher, $this->lifecycleUri($topic, 'activate')));
            $this->assertSame(TopicStatus::Draft, $topic->fresh()?->status);
        }

        $ready = $this->topic($institution, $group, $teacher);
        $this->material($institution, $ready, $teacher, fileAttributes: [
            'storage_key' => 'learning-materials/'.$institution->id.'/'.$ready->id.'/physically-missing.pdf',
        ]);

        $this->requestAs($teacher, $this->lifecycleUri($ready, 'activate'))
            ->assertOk()->assertJsonPath('data.status', 'active');
        $this->assertSame(TopicStatus::Active, $ready->fresh()?->status);
    }

    public function test_close_and_archive_preserve_topic_metadata_materials_files_and_lifecycle_history(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher, TopicStatus::Active, [
            'title' => 'Preserved title',
            'description' => 'Preserved description',
            'subject' => 'Preserved subject',
            'student_instructions' => 'Preserved instructions',
        ]);
        $material = $this->material($institution, $topic, $teacher, ['title' => 'Preserved material']);
        $originalTopic = $topic->only([
            'institution_id', 'group_id', 'teacher_id', 'title', 'description', 'subject',
            'student_instructions', 'lesson_at',
        ]);
        $originalActivatedAt = $topic->activated_at?->toIso8601String();
        $originalMaterial = $material->only(['institution_id', 'topic_id', 'file_id', 'teacher_id', 'title', 'position', 'removed_at']);
        $originalFile = $material->file()->firstOrFail()->only([
            'institution_id', 'uploaded_by_user_id', 'category', 'original_name', 'storage_disk',
            'storage_key', 'mime_type', 'extension', 'size_bytes', 'checksum_sha256', 'removed_at',
        ]);

        $this->requestAs($teacher, $this->lifecycleUri($topic, 'close'))->assertOk();
        $this->requestAs($teacher, $this->lifecycleUri($topic, 'archive'))->assertOk();

        $topic->refresh();
        $material->refresh();
        $this->assertSame($originalTopic, $topic->only(array_keys($originalTopic)));
        $this->assertSame($originalActivatedAt, $topic->activated_at?->toIso8601String());
        $this->assertSame($originalMaterial, $material->only(array_keys($originalMaterial)));
        $this->assertSame($originalFile, $material->file()->firstOrFail()->only(array_keys($originalFile)));
        $this->assertNotNull($topic->closed_at);
        $this->assertNotNull($topic->archived_at);
        $this->assertDatabaseCount('topics', 1);
        $this->assertDatabaseCount('learning_materials', 1);
        $this->assertDatabaseCount('files', 1);
    }

    public function test_lifecycle_resource_serialization_issues_no_hidden_queries(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher);
        $this->material($institution, $topic, $teacher);
        $activated = app(ActivateTeacherTopic::class)($teacher, $topic->id);

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $resource = (new TeacherTopicResource($activated))->toArray(Request::create('/'));
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame([], $queries);
        $this->assertSame(self::TOPIC_KEYS, array_keys($resource));
    }

    /** @return array{Institution, User, User} */
    private function baseContext(): array
    {
        $institution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);

        return [$institution, $teacher, $admin];
    }

    /** @return array{Institution, User, User, Group} */
    private function context(): array
    {
        [$institution, $teacher, $admin] = $this->baseContext();
        $group = $this->group($institution, $admin);
        $this->membership($institution, $group, $teacher, $admin);

        return [$institution, $teacher, $admin, $group];
    }

    private function teacher(Institution $institution, array $attributes = []): User
    {
        return User::factory()->teacher($institution)->create(array_merge(['must_change_password' => false], $attributes));
    }

    private function admin(Institution $institution): User
    {
        return User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    }

    private function group(Institution $institution, User $admin, bool $archived = false): Group
    {
        $factory = $archived ? Group::factory()->archived() : Group::factory();

        return $factory->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ]);
    }

    private function membership(Institution $institution, Group $group, User $teacher, User $admin, bool $ended = false): void
    {
        $factory = $ended ? GroupTeacherMembership::factory()->ended() : GroupTeacherMembership::factory();
        $factory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
    }

    private function topic(
        Institution $institution,
        Group $group,
        User $teacher,
        TopicStatus $status = TopicStatus::Draft,
        array $attributes = [],
    ): Topic {
        $factory = match ($status) {
            TopicStatus::Active => Topic::factory()->active(),
            TopicStatus::Closed => Topic::factory()->closed(),
            TopicStatus::Archived => Topic::factory()->archivedFromDraft(),
            TopicStatus::Draft => Topic::factory(),
        };

        return $factory->create(array_merge([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ], $attributes));
    }

    private function material(
        Institution $institution,
        Topic $topic,
        User $teacher,
        array $attributes = [],
        array $fileAttributes = [],
    ): LearningMaterial {
        $file = File::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'uploaded_by_user_id' => $teacher->id,
        ], $fileAttributes));

        return LearningMaterial::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'teacher_id' => $teacher->id,
            'file_id' => $file->id,
        ], $attributes));
    }

    private function lifecycleUri(Topic $topic, string $operation): string
    {
        return self::URI.'/'.$topic->id.'/'.$operation;
    }

    /** @param array<string, mixed> $query */
    private function requestAs(
        User $actor,
        string $uri,
        string $content = '',
        string $contentType = 'application/json',
        array $query = [],
    ): TestResponse {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = [
            'CONTENT_TYPE' => $contentType,
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('teacher-topic-lifecycle-api-test')->plainTextToken,
        ];
        $response = $this->call('POST', $requestUri, [], [], [], $server, $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function assertTopicConflict(TestResponse $response): void
    {
        $this->assertSame([
            'message' => 'The topic is not editable.',
            'code' => 'topic_not_editable',
            'errors' => [],
        ], $response->assertConflict()->json());
    }

    private function assertSuccessfulLifecycleResponse(
        TestResponse $response,
        string $message,
        TopicStatus $status,
    ): void {
        $response->assertOk()->assertJsonPath('message', $message)->assertJsonPath('data.status', $status->value);
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame(self::TOPIC_KEYS, array_keys($response->json('data')));
        $this->assertSame(['id', 'name', 'level', 'subject_direction', 'status'], array_keys($response->json('data.group')));
    }
}
