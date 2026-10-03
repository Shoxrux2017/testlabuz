<?php

namespace Database\Factories;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\TopicResultCalculationMethod;
use App\Enums\TopicResultClosureReason;
use App\Enums\TopicResultConsistency;
use App\Enums\TopicResultMissingComponent;
use App\Enums\TopicResultOutcome;
use App\Enums\TopicResultSideState;
use App\Enums\UnderstandingCategoryCode;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Topic;
use App\Models\TopicResult;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<TopicResult>
 */
class TopicResultFactory extends Factory
{
    public function definition(): array
    {
        return [
            'topic_id' => Topic::factory(),
            'institution_id' => fn (array $attributes) => $this->topicFor($attributes)->institution_id,
            'student_id' => fn (array $attributes) => User::factory()
                ->student()
                ->state(['institution_id' => $attributes['institution_id']]),
        ];
    }

    public function withComment(): static
    {
        return $this->state([
            'teacher_comment' => 'Revise question 4 before the next lesson.',
            'teacher_comment_updated_by_user_id' => fn (array $attributes) => $this->topicFor($attributes)->teacher_id,
            'teacher_comment_updated_at' => now(),
        ]);
    }

    public function releasedToStudent(): static
    {
        return $this->state([
            'student_released_at' => now(),
            'student_released_by_user_id' => fn (array $attributes) => $this->topicFor($attributes)->teacher_id,
        ]);
    }

    public function releasedToParent(): static
    {
        return $this->state([
            'parent_released_at' => now(),
            'parent_released_by_user_id' => fn (array $attributes) => $this->topicFor($attributes)->teacher_id,
        ]);
    }

    /** Closed by the Teacher as calculated: H 88, B 84, T 10 → average 86, Understood well (86–100). */
    public function closedCalculated(): static
    {
        return $this->closed()->state([
            'closed_outcome' => TopicResultOutcome::Calculated,
            'blitz_state' => TopicResultSideState::Ready,
            'blitz_attempt_id' => fn (array $attributes) => $this->checkedAttempt($attributes, $attributes['blitz_assessment_id'], '84.00000000'),
            'blitz_score' => '84.00000000',
            'score_difference' => '4.00000000',
            'acceptable_difference_used' => '10.00000000',
            'calculation_method' => TopicResultCalculationMethod::Average,
            'consistency' => TopicResultConsistency::Consistent,
            'final_score' => '86.00000000',
            'category_score' => 86,
            'category_code' => UnderstandingCategoryCode::UnderstoodWell,
            'category_min_score_used' => 86,
            'category_max_score_used' => 100,
        ]);
    }

    /** Closed by the Teacher as Not completed: the Homework is ready (80) and the Blitz is missing. */
    public function closedNotCompleted(): static
    {
        return $this->closed()->state([
            'closed_outcome' => TopicResultOutcome::NotCompleted,
            'missing_component' => TopicResultMissingComponent::Blitz,
            'blitz_state' => TopicResultSideState::Missing,
            'category_code' => UnderstandingCategoryCode::NotCompleted,
        ]);
    }

    private function closed(): static
    {
        return $this->state([
            'closed_at' => now(),
            'closed_by_user_id' => fn (array $attributes) => $this->topicFor($attributes)->teacher_id,
            'closure_reason' => TopicResultClosureReason::Teacher,
            'homework_assessment_id' => fn (array $attributes) => $this->task($attributes, 'homework'),
            'blitz_assessment_id' => fn (array $attributes) => $this->task($attributes, 'blitz'),
            'homework_state' => TopicResultSideState::Ready,
            'homework_attempt_id' => fn (array $attributes) => $this->checkedAttempt($attributes, $attributes['homework_assessment_id'], '88.00000000'),
            'homework_score' => fn (array $attributes) => AssessmentAttempt::query()->findOrFail($attributes['homework_attempt_id'])->normalized_score,
        ]);
    }

    /** @param array<string, mixed> $attributes */
    private function task(array $attributes, string $type): string
    {
        $topic = $this->topicFor($attributes);

        return Assessment::factory()->{$type}()->groupAssignment()->create([
            'institution_id' => $topic->institution_id,
            'teacher_id' => $topic->teacher_id,
            'topic_id' => $topic->id,
        ])->id;
    }

    /** @param array<string, mixed> $attributes */
    private function checkedAttempt(array $attributes, string $assessmentId, string $score): string
    {
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $attributes['institution_id'],
            'assessment_id' => $assessmentId,
            'student_id' => $attributes['student_id'],
        ]);

        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id,
            'status' => AssessmentAttemptStatus::Checked,
            'started_at' => now()->subMinutes(20),
            'submitted_at' => now()->subMinutes(10),
            'finalized_at' => now()->subMinutes(10),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
            'locked_at' => now()->subMinutes(10),
            'earned_points' => '4.40000000',
            'possible_points' => '5.000000',
            'normalized_score' => $score,
            'scoring_completed_at' => now()->subMinutes(5),
        ])->id;
    }

    /** @param array<string, mixed> $attributes */
    private function topicFor(array $attributes): Topic
    {
        return Topic::query()->findOrFail($attributes['topic_id']);
    }
}
