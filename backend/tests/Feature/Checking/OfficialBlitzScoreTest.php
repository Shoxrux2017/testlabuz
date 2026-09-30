<?php

namespace Tests\Feature\Checking;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\GroupTeacherMembership;
use App\Models\OfficialTaskScore;
use App\Models\QuestionChoiceOption;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\TestCase;

/**
 * S09-BE-004 / S09-D4: the official Blitz score is the checked normal Attempt, and after an
 * exception only the checked replacement; the grant withdraws the score in its own transaction.
 */
class OfficialBlitzScoreTest extends TestCase
{
    use BuildsBlitzExceptionContext;
    use RefreshDatabase;

    private User $student;

    private Assessment $assessment;

    private User $teacher;

    private TopicResultPair $pair;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        $this->student = $this->studentBlitzActor();
        [$this->assessment, $this->pair] = $this->officialStudentBlitz($this->student);
        $this->teacher = $this->assessment->teacher;
        $this->teacher->update(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $this->student->institution_id, 'group_id' => $this->assessment->topic->group_id,
            'teacher_id' => $this->teacher->id, 'assigned_by_user_id' => $this->teacher->id,
        ]);
    }

    public function test_the_checked_normal_attempt_becomes_the_official_blitz_score(): void
    {
        $normal = $this->submittedNormal();

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$normal->id, '60.00000000', 'valid_normal_blitz'],
            [$row->official_attempt_id, $row->normalized_score, $row->getRawOriginal('selection_policy_code')]);
    }

    public function test_a_grant_withdraws_the_official_score_and_the_checked_replacement_takes_over(): void
    {
        $normal = $this->submittedNormal();
        $this->travel(1)->minutes();

        $this->grant()->assertCreated();

        // #1 was already checked, so nothing was frozen: the grant itself deleted the row.
        $this->assertDatabaseCount('official_task_scores', 0);
        $this->assertFalse($normal->fresh()->official_score_eligible);

        $replacement = AssessmentAttempt::query()->findOrFail(
            $this->startStudentBlitz($this->student, $this->assessment, intent: 'start_replacement')->assertCreated()->json('data.id'));
        $this->assertDatabaseCount('official_task_scores', 0);
        $this->submit($replacement);

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$replacement->id, '0.00000000', 'approved_blitz_exception_replacement'],
            [$row->official_attempt_id, $row->normalized_score, $row->getRawOriginal('selection_policy_code')]);
    }

    public function test_the_normal_attempt_a_grant_timed_out_is_checked_but_never_official(): void
    {
        $normal = $this->studentBlitzAttempt($this->assessment, $this->student, ['started_at' => now()->subMinute()]);
        $this->pair->update(['locked_at' => $normal->started_at]);
        $this->travelTo($normal->deadline_at);

        $this->grant()->assertCreated();

        $this->assertSame(['checked', 'timeout_auto_submit'],
            [$normal->fresh()->getRawOriginal('status'), $normal->fresh()->getRawOriginal('finalization_reason')]);
        $this->assertDatabaseCount('official_task_scores', 0);
    }

    public function test_a_grant_replay_leaves_the_official_score_alone(): void
    {
        $this->submittedNormal();
        $key = (string) Str::uuid();
        $this->grant($key)->assertCreated();
        $replacement = AssessmentAttempt::query()->findOrFail(
            $this->startStudentBlitz($this->student, $this->assessment, intent: 'start_replacement')->assertCreated()->json('data.id'));
        $this->submit($replacement);
        $row = OfficialTaskScore::query()->sole()->getAttributes();
        $this->travel(1)->minutes();
        $statements = [];
        DB::listen(function ($query) use (&$statements): void {
            if (str_contains($query->sql, '"official_task_scores"')) {
                $statements[] = $query->sql;
            }
        });

        $this->grant($key)->assertCreated();

        // A replay never re-resolves.
        $this->assertSame([], $statements);
        $this->assertSame($row, OfficialTaskScore::query()->sole()->getAttributes());
    }

    public function test_a_failing_grant_rolls_the_withdrawal_back(): void
    {
        $normal = $this->submittedNormal();
        $row = OfficialTaskScore::query()->sole()->getAttributes();
        // Fail the grant when it completes its idempotency record, but only once the withdrawal has
        // already deleted the row: a grant that withdrew later or never would succeed instead.
        DB::unprepared(<<<SQL
            create function s09_be_004_fail_grant_completion() returns trigger language plpgsql as \$\$
            begin
                if not exists (select 1 from official_task_scores where assessment_id = '{$this->assessment->id}') then
                    raise exception 'Injected grant completion failure after the withdrawal.';
                end if;
                return new;
            end \$\$;
            create trigger s09_be_004_fail_grant_completion before update on idempotency_records
            for each row execute function s09_be_004_fail_grant_completion();
            SQL);

        $this->grant()->assertStatus(500);

        $this->assertSame($row, OfficialTaskScore::query()->sole()->getAttributes());
        $this->assertTrue($normal->fresh()->official_score_eligible);
        $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
    }

    /** The normal Attempt answers the 3-point choice of the 5-point Blitz correctly and is submitted. */
    private function submittedNormal(): AssessmentAttempt
    {
        [$choice] = $this->studentBlitzQuestions($this->assessment);
        $normal = $this->studentBlitzAttempt($this->assessment, $this->student, ['started_at' => now()->subMinute()]);
        // The first official Attempt locks the pair, as Start does.
        $this->pair->update(['locked_at' => $normal->started_at]);
        $correct = QuestionChoiceOption::query()->where('question_id', $choice->id)->where('is_correct', true)->sole();
        $this->studentBlitzRequest($this->student, 'PUT', '/api/v1/student/attempts/'.$normal->id.'/answers/'.$choice->id,
            json_encode(['type' => 'single_choice', 'selected_option_ids' => [$correct->id]], JSON_THROW_ON_ERROR), null)->assertOk();
        $this->submit($normal);

        return $normal->fresh();
    }

    private function submit(AssessmentAttempt $attempt): void
    {
        $this->studentBlitzRequest($this->student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit')
            ->assertOk()->assertJsonPath('data.status', 'submitted');
    }

    private function grant(?string $key = ''): TestResponse
    {
        return $this->grantException($this->teacher, $this->assessment, $this->student, $key);
    }
}
