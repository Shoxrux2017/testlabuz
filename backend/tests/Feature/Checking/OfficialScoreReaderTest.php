<?php

namespace Tests\Feature\Checking;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\OfficialScoreStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\OfficialTaskScore;
use App\Models\TopicResultPair;
use App\Support\Checking\OfficialScoreReader;
use Closure;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class OfficialScoreReaderTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-04 10:00:00 UTC'));
    }

    /** @return array<string, array{Closure(self): AssessmentStudent, OfficialScoreStatus}> */
    public static function scenarios(): array
    {
        return [
            'ready homework' => [function (self $test): AssessmentStudent {
                $recipient = $test->homeworkRecipient();
                OfficialTaskScore::factory()->create(['official_attempt_id' => $test->attempt($recipient, 1, 'checked', '80.00000000')->id]);

                return $recipient;
            }, OfficialScoreStatus::Ready],
            'homework awaiting automatic checking' => [function (self $test): AssessmentStudent {
                $recipient = $test->homeworkRecipient();
                $test->attempt($recipient, 1, 'submitted');

                return $recipient;
            }, OfficialScoreStatus::AutomaticCheckingPending],
            'blitz waiting for the replacement' => [function (self $test): AssessmentStudent {
                $recipient = $test->blitzRecipient('activeIndividual');
                $test->exception($recipient, $test->attempt($recipient, 1, 'checked', '90.00000000', eligible: false));

                return $recipient;
            }, OfficialScoreStatus::WaitingForReplacement],
            'blitz closed before the replacement' => [function (self $test): AssessmentStudent {
                $recipient = $test->blitzRecipient('closedIndividual');
                $test->exception($recipient, $test->attempt($recipient, 1, 'checked', '90.00000000', eligible: false));

                return $recipient;
            }, OfficialScoreStatus::NoCompletedAttempt],
        ];
    }

    #[DataProvider('scenarios')]
    public function test_a_preloaded_read_matches_the_live_read_without_queries(Closure $scenario, OfficialScoreStatus $expected): void
    {
        $recipient = $scenario($this);
        $assessment = Assessment::query()->findOrFail($recipient->assessment_id);
        $reader = app(OfficialScoreReader::class);
        $live = $reader->read($assessment, $recipient);
        $attempts = AssessmentAttempt::query()->where('assessment_student_id', $recipient->id)->get();
        $score = OfficialTaskScore::query()->where('assessment_id', $assessment->id)->where('student_id', $recipient->student_id)->first();
        $exception = BlitzAttemptException::query()->where('assessment_student_id', $recipient->id)->first();
        $blitzStatus = BlitzTask::query()->whereKey($assessment->id)->first()?->status;

        DB::enableQueryLog();
        $loaded = $reader->readLoaded($assessment, $recipient, $attempts, $score, $exception, $blitzStatus);

        $this->assertSame([], DB::getQueryLog());
        $this->assertSame($expected, $live->status);
        $this->assertSame($live->status, $loaded->status);
        $this->assertSame($live->attempt?->id, $loaded->attempt?->id);
        $this->assertSame($live->score?->id, $loaded->score?->id);
    }

    public function homeworkRecipient(): AssessmentStudent
    {
        $homework = HomeworkAssignment::factory()->closed()->create();
        TopicResultPair::factory()->create(['homework_assessment_id' => $homework->assessment_id]);

        return AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);
    }

    public function blitzRecipient(string $state): AssessmentStudent
    {
        $pair = TopicResultPair::factory()->withBlitz()->create();
        BlitzTask::factory()->{$state}()->create(['assessment_id' => $pair->blitz_assessment_id]);

        return AssessmentStudent::factory()->create(['assessment_id' => $pair->blitz_assessment_id]);
    }

    public function attempt(AssessmentStudent $recipient, int $number, string $status, ?string $normalized = null, bool $eligible = true): AssessmentAttempt
    {
        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id, 'attempt_number' => $number, 'status' => $status,
            'started_at' => now()->subHour(), 'finalized_at' => now()->subMinutes(30), 'locked_at' => now()->subMinutes(30),
            'finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit,
            'official_score_eligible' => $eligible, 'possible_points' => '4.000000', 'normalized_score' => $normalized,
            'earned_points' => $normalized === null ? null : '0.00000000',
            'scoring_completed_at' => $status === AssessmentAttemptStatus::Checked->value ? now() : null,
        ])->fresh();
    }

    public function exception(AssessmentStudent $recipient, AssessmentAttempt $normal): void
    {
        BlitzAttemptException::factory()->create([
            'assessment_id' => $recipient->assessment_id, 'assessment_student_id' => $recipient->id,
            'invalidated_attempt_id' => $normal->id, 'replacement_attempt_id' => null,
        ]);
    }
}
