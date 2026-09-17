<?php

namespace Tests\Feature\Teacher;

use App\Models\Assessment;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzActivationContext;
use Tests\TestCase;

class TeacherBlitzActivationAuthorizationTest extends TestCase
{
    use BuildsTeacherBlitzActivationContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-17 12:00:00 UTC'));
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        parent::tearDown();
    }

    public function test_activation_requires_authentication_and_teacher_role(): void
    {
        [, , $admin, , , $student, $assessment] = $this->readyBlitzActivation();
        $student->update(['must_change_password' => false]);
        $before = $this->activationSnapshot($assessment);
        $this->postJson("/api/v1/teacher/blitz/{$assessment->id}/activate", [], ['Idempotency-Key' => (string) Str::uuid()])
            ->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        foreach ([$admin, $student] as $actor) {
            $this->activateBlitz($actor, $assessment->id)->assertForbidden()->assertJsonPath('code', 'forbidden');
        }
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_activation_route_is_registered_exactly_once_with_teacher_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->filter(fn ($route): bool => $route->uri() === 'api/v1/teacher/blitz/{blitz}/activate')
            ->map(fn ($route): array => ['methods' => $route->methods(), 'middleware' => $route->middleware()])
            ->values()->all();
        $this->assertSame([['methods' => ['POST'],
            'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'],
        ]], $routes);
    }

    #[DataProvider('restrictedAccountStates')]
    public function test_activation_obeys_current_account_institution_and_password_gates(string $gate, string $code): void
    {
        [$institution, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        match ($gate) {
            'account' => $teacher->update(['is_active' => false]),
            'password' => $teacher->update(['must_change_password' => true]),
            'institution' => $institution->update(['status' => 'inactive', 'deactivated_at' => now()]),
        };
        $before = $this->activationSnapshot($assessment);
        $this->activateBlitz($teacher, $assessment->id)->assertForbidden()->assertJsonPath('code', $code);
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function restrictedAccountStates(): array
    {
        return [['account', 'user_inactive'], ['password', 'password_change_required'], ['institution', 'institution_inactive']];
    }

    public function test_inaccessible_ids_are_indistinguishable_and_never_claim_idempotency_keys(): void
    {
        [$institution, $teacher, , $group, $topic, , $assessment] = $this->readyBlitzActivation();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $other = $this->persistedBlitz($institution, $otherTeacher, $topic);
        $homework = Assessment::factory()->homework()->create([
            'institution_id' => $institution->id, 'teacher_id' => $teacher->id, 'topic_id' => $topic->id,
        ]);
        $missingDetail = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id, 'teacher_id' => $teacher->id, 'topic_id' => $topic->id,
        ]);
        $hiddenTopic = Topic::factory()->active()->create([
            'institution_id' => $institution->id, 'teacher_id' => $otherTeacher->id, 'group_id' => $group->id,
        ]);
        $hidden = $this->persistedBlitz($institution, $teacher, $hiddenTopic);
        [, , , , , , $foreign] = $this->readyBlitzActivation();
        $expected = null;
        foreach (['bad-id', (string) Str::uuid(), $other->id, $homework->id, $missingDetail->id, $hidden->id, $foreign->id] as $id) {
            $response = $this->activateBlitz($teacher, $id)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $expected ??= $response->json();
            $this->assertSame($expected, $response->json());
        }
        $this->assertSame('draft', $assessment->blitzTask->status->value);
        $this->assertDatabaseCount('idempotency_records', 0);
        $this->assertDatabaseCount('assessment_students', 0);
    }

    public function test_current_teacher_membership_is_required_for_new_activation_and_completed_replay(): void
    {
        [, $teacher, , $group, , , $assessment] = $this->readyBlitzActivation();
        $key = (string) Str::uuid();
        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk();
        $before = $this->activationSnapshot($assessment);
        GroupTeacherMembership::query()->where('group_id', $group->id)->where('teacher_id', $teacher->id)->update(['ended_at' => now()]);

        foreach ([$key, (string) Str::uuid()] as $submittedKey) {
            $this->activateBlitz($teacher, $assessment->id, $submittedKey)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public function test_completed_key_does_not_disclose_another_teachers_or_foreign_blitz(): void
    {
        [$institution, $teacher, , , $topic, , $assessment] = $this->readyBlitzActivation();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $other = $this->persistedBlitz($institution, $otherTeacher, $topic);
        [, , , , , , $foreign] = $this->readyBlitzActivation();
        $key = (string) Str::uuid();
        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk();

        foreach ([$other, $foreign] as $inaccessible) {
            $this->activateBlitz($teacher, $inaccessible->id, $key)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertSame('draft', $inaccessible->blitzTask->status->value);
        }
        $this->assertDatabaseCount('idempotency_records', 1);
    }
}
