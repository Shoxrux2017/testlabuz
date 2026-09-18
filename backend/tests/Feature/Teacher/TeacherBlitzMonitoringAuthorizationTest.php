<?php

namespace Tests\Feature\Teacher;

use App\Models\GroupTeacherMembership;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzMonitoringContext;
use Tests\TestCase;

class TeacherBlitzMonitoringAuthorizationTest extends TestCase
{
    use BuildsTeacherBlitzMonitoringContext, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_authentication_role_and_account_gates_are_preserved(): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext();
        $uri = '/api/v1/teacher/blitz/'.$assessment->id.'/monitoring';
        $this->studentBlitzRequest(null, 'GET', $uri)->assertUnauthorized();
        $this->studentBlitzRequest($student, 'GET', $uri)->assertForbidden();
        $teacher->update(['must_change_password' => true]);
        $this->monitor($teacher, $assessment)->assertForbidden()->assertJsonPath('code', 'password_change_required');
        $teacher->update(['must_change_password' => false, 'is_active' => false]);
        $this->monitor($teacher, $assessment)->assertForbidden()->assertJsonPath('code', 'user_inactive');
    }

    #[DataProvider('privateTargets')]
    public function test_private_blitz_identifiers_are_not_disclosed_or_reconciled(string $case): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext();
        $attempt = $this->studentBlitzAttempt($assessment, $student);
        $this->travelTo($attempt->deadline_at);
        $blitzId = $assessment->id;
        switch ($case) {
            case 'foreign institution':
                [, , $teacher] = $this->monitoringContext();
                break;
            case 'other teacher':
                $teacher = User::factory()->teacher($student->institution)->create(['must_change_password' => false]);
                break;
            case 'ended membership':
                GroupTeacherMembership::query()->where('teacher_id', $teacher->id)->update(['ended_at' => now()]);
                break;
            case 'private topic':
                $other = User::factory()->teacher($student->institution)->create();
                $assessment->topic->update(['teacher_id' => $other->id]);
                break;
            case 'missing task': $assessment->blitzTask->delete();
                break;
            case 'not blitz': $assessment->update(['type' => 'homework']);
                break;
            case 'malformed': $blitzId = 'malformed';
                break;
            case 'unknown': $blitzId = (string) Str::uuid();
                break;
        }
        $before = $attempt->fresh()->getAttributes();
        $this->studentBlitzRequest($teacher, 'GET', '/api/v1/teacher/blitz/'.$blitzId.'/monitoring')
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertSame($before, $attempt->fresh()->getAttributes());
    }

    public static function privateTargets(): array
    {
        return array_map(fn ($case) => [$case], ['foreign institution', 'other teacher', 'ended membership',
            'private topic', 'missing task', 'not blitz', 'malformed', 'unknown']);
    }
}
