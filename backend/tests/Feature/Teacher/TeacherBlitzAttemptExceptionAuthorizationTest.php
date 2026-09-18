<?php

namespace Tests\Feature\Teacher;

use App\Models\GroupTeacherMembership;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\TestCase;

class TeacherBlitzAttemptExceptionAuthorizationTest extends TestCase
{
    use BuildsBlitzExceptionContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_authentication_role_and_account_gates_are_preserved(): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $uri = '/api/v1/teacher/blitz/'.$assessment->id.'/students/'.$student->id.'/attempt-exception';
        $body = '{"reason_type":"technical","reason":"x"}';
        $this->studentBlitzRequest(null, 'POST', $uri, $body)->assertUnauthorized();
        $this->studentBlitzRequest($student, 'POST', $uri, $body)->assertForbidden();
        $teacher->update(['must_change_password' => true]);
        $this->studentBlitzRequest($teacher, 'POST', $uri, $body)->assertForbidden()->assertJsonPath('code', 'password_change_required');
        $teacher->update(['must_change_password' => false, 'is_active' => false]);
        $this->studentBlitzRequest($teacher, 'POST', $uri, $body)->assertForbidden()->assertJsonPath('code', 'user_inactive');
        $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
    }

    #[DataProvider('privateTargets')]
    public function test_blitz_and_student_probing_is_privacy_safe(string $case): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $blitzId = $assessment->id;
        $studentId = $student->id;
        switch ($case) {
            case 'foreign blitz':
                [, $foreign] = $this->exceptionContext();
                $blitzId = $foreign->id;
                break;
            case 'other teacher':
                $teacher = User::factory()->teacher($student->institution)->create(['must_change_password' => false]);
                break;
            case 'ended membership':
                GroupTeacherMembership::query()->where('teacher_id', $teacher->id)->update(['ended_at' => now()]);
                break;
            case 'malformed blitz': $blitzId = 'malformed';
                break;
            case 'unknown blitz': $blitzId = (string) Str::uuid();
                break;
            case 'malformed student': $studentId = 'malformed';
                break;
            case 'foreign student': $studentId = $this->studentBlitzActor()->id;
                break;
            case 'unassigned student': $studentId = $this->studentBlitzActor($student->institution)->id;
                break;
            case 'other blitz recipient':
                $other = $this->studentBlitzActor($student->institution);
                $this->studentBlitz($other);
                $studentId = $other->id;
                break;
            case 'inactive student': $student->update(['is_active' => false]);
                break;
            case 'wrong target role': $student->update(['role' => 'teacher']);
                break;
        }
        $this->studentBlitzRequest($teacher, 'POST', '/api/v1/teacher/blitz/'.$blitzId.'/students/'.$studentId.'/attempt-exception',
            '{"reason_type":"technical","reason":"x"}')->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function privateTargets(): array
    {
        return array_map(fn ($case) => [$case], ['foreign blitz', 'other teacher', 'ended membership', 'malformed blitz',
            'unknown blitz', 'malformed student', 'foreign student', 'unassigned student', 'other blitz recipient', 'inactive student', 'wrong target role']);
    }

    public function test_persisted_assignment_is_sufficient_without_current_student_group_membership(): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $this->assertDatabaseCount('group_student_memberships', 0);
        $this->grantException($teacher, $assessment, $student)->assertCreated();
    }
}
