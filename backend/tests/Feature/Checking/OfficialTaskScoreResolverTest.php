<?php

namespace Tests\Feature\Checking;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\OfficialTaskScore;
use App\Models\TopicResultPair;
use App\Support\Checking\OfficialTaskScoreResolver;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class OfficialTaskScoreResolverTest extends TestCase
{
    use RefreshDatabase;

    private AssessmentStudent $recipient;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
    }

    public function test_a_practice_task_never_gets_an_official_row(): void
    {
        $this->recipientOf(HomeworkAssignment::factory()->closed()->create()->assessment_id);
        $this->attempt(1, 'checked', '80.00000000');

        $this->assertFalse($this->resolve());

        $this->assertDatabaseCount('official_task_scores', 0);
    }

    public function test_a_ready_official_homework_score_is_stored_once_and_left_alone_while_unchanged(): void
    {
        $this->officialHomework();
        $first = $this->attempt(1, 'checked', '80.00000000');

        $this->assertTrue($this->resolve());

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$first->id, '80.00000000', 'highest_valid_completed', null],
            [$row->official_attempt_id, $row->normalized_score, $row->getRawOriginal('selection_policy_code'), $row->selected_by_user_id]);
        $this->assertSame([$this->recipient->institution_id, $this->recipient->assessment_id, $this->recipient->student_id],
            [$row->institution_id, $row->assessment_id, $row->student_id]);
        foreach (['selected_at', 'created_at', 'updated_at'] as $field) {
            $this->assertTrue($row->{$field}->equalTo(now()));
        }
        $stored = $row->getAttributes();
        $this->travel(1)->hours();

        $this->assertFalse($this->resolve());
        $this->assertSame($stored, OfficialTaskScore::query()->sole()->getAttributes());
    }

    public function test_a_better_attempt_or_a_changed_score_moves_the_row_and_its_selection_time(): void
    {
        $this->officialHomework();
        $this->attempt(1, 'checked', '80.00000000');
        $this->resolve();
        $createdAt = OfficialTaskScore::query()->sole()->created_at;
        $second = $this->attempt(2, 'checked', '90.00000000');
        $this->travel(1)->hours();

        $this->assertTrue($this->resolve());

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$second->id, '90.00000000'], [$row->official_attempt_id, $row->normalized_score]);
        $this->assertTrue($row->selected_at->equalTo(now()));
        $this->assertTrue($row->updated_at->equalTo(now()));
        $this->assertTrue($row->created_at->equalTo($createdAt));

        DB::table('assessment_attempts')->where('id', $second->id)->update(['normalized_score' => '95.00000000']);
        $this->travel(1)->hours();

        $this->assertTrue($this->resolve());
        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$second->id, '95.00000000'], [$row->official_attempt_id, $row->normalized_score]);
        $this->assertTrue($row->selected_at->equalTo(now()));
    }

    public function test_a_wrong_policy_alone_is_corrected_without_a_new_selection_time(): void
    {
        $this->officialHomework();
        $this->attempt(1, 'checked', '80.00000000');
        $this->resolve();
        DB::table('official_task_scores')->update(['selection_policy_code' => 'valid_normal_blitz']);
        $selectedAt = OfficialTaskScore::query()->sole()->selected_at;
        $this->travel(1)->hours();

        $this->assertTrue($this->resolve());

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame('highest_valid_completed', $row->getRawOriginal('selection_policy_code'));
        $this->assertTrue($row->selected_at->equalTo($selectedAt));
        $this->assertTrue($row->updated_at->equalTo(now()));
    }

    public function test_a_score_that_is_no_longer_ready_loses_its_row(): void
    {
        $this->officialHomework();
        $this->attempt(1, 'checked', '80.00000000');
        $this->resolve();
        // A newly frozen Attempt could still overtake until it is checked.
        $this->attempt(2, 'submitted');

        $this->assertTrue($this->resolve());

        $this->assertDatabaseCount('official_task_scores', 0);
        $this->assertFalse($this->resolve());
    }

    public function test_an_official_blitz_normal_attempt_is_stored_under_its_policy(): void
    {
        $pair = TopicResultPair::factory()->withBlitz()->create();
        $this->recipientOf($pair->blitz_assessment_id);
        $normal = $this->attempt(1, 'checked', '40.00000000');

        $this->assertTrue($this->resolve());

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$normal->id, 'valid_normal_blitz'], [$row->official_attempt_id, $row->getRawOriginal('selection_policy_code')]);
    }

    private function officialHomework(): void
    {
        $this->recipientOf(TopicResultPair::factory()->create()->homework_assessment_id);
    }

    private function recipientOf(string $assessmentId): void
    {
        $this->recipient = AssessmentStudent::factory()->create(['assessment_id' => $assessmentId]);
    }

    private function attempt(int $number, string $status, ?string $normalized = null): AssessmentAttempt
    {
        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $this->recipient->id, 'attempt_number' => $number, 'status' => $status,
            'started_at' => now()->subHour(), 'finalized_at' => now()->subMinutes(30), 'locked_at' => now()->subMinutes(30),
            'finalization_reason' => 'timeout_auto_submit', 'possible_points' => '4.000000',
            'normalized_score' => $normalized, 'earned_points' => $normalized === null ? null : '1.00000000',
            'scoring_completed_at' => $normalized === null ? null : now(),
        ])->fresh();
    }

    private function resolve(): bool
    {
        return app(OfficialTaskScoreResolver::class)->resolve(
            Assessment::query()->findOrFail($this->recipient->assessment_id),
            $this->recipient,
            AssessmentAttempt::query()->where('assessment_student_id', $this->recipient->id)->orderBy('id')->get(),
            now(),
        );
    }
}
