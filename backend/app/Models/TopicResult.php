<?php

namespace App\Models;

use App\Enums\TopicResultCalculationMethod;
use App\Enums\TopicResultClosureReason;
use App\Enums\TopicResultConsistency;
use App\Enums\TopicResultMissingComponent;
use App\Enums\TopicResultOutcome;
use App\Enums\TopicResultSideState;
use App\Enums\UnderstandingCategoryCode;
use Database\Factories\TopicResultFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * The stored part of one Student's Topic result (docs/08 §20.2): the Teacher comment, Teacher
 * releases and, once closed, the frozen snapshot. An open result itself is computed live.
 */
#[Fillable([
    'institution_id',
    'topic_id',
    'student_id',
    'teacher_comment',
    'teacher_comment_updated_by_user_id',
    'teacher_comment_updated_at',
    'student_released_at',
    'student_released_by_user_id',
    'parent_released_at',
    'parent_released_by_user_id',
    'closed_at',
    'closed_by_user_id',
    'closure_reason',
    'closed_outcome',
    'missing_component',
    'homework_assessment_id',
    'blitz_assessment_id',
    'homework_state',
    'blitz_state',
    'homework_attempt_id',
    'homework_score',
    'blitz_attempt_id',
    'blitz_score',
    'score_difference',
    'acceptable_difference_used',
    'calculation_method',
    'consistency',
    'final_score',
    'category_score',
    'category_code',
    'category_min_score_used',
    'category_max_score_used',
])]
class TopicResult extends Model
{
    /** @use HasFactory<TopicResultFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'teacher_comment_updated_at' => 'immutable_datetime',
            'student_released_at' => 'immutable_datetime',
            'parent_released_at' => 'immutable_datetime',
            'closed_at' => 'immutable_datetime',
            'closure_reason' => TopicResultClosureReason::class,
            'closed_outcome' => TopicResultOutcome::class,
            'missing_component' => TopicResultMissingComponent::class,
            'homework_state' => TopicResultSideState::class,
            'blitz_state' => TopicResultSideState::class,
            'homework_score' => 'decimal:8',
            'blitz_score' => 'decimal:8',
            'score_difference' => 'decimal:8',
            'acceptable_difference_used' => 'decimal:8',
            'calculation_method' => TopicResultCalculationMethod::class,
            'consistency' => TopicResultConsistency::class,
            'final_score' => 'decimal:8',
            'category_score' => 'integer',
            'category_code' => UnderstandingCategoryCode::class,
            'category_min_score_used' => 'integer',
            'category_max_score_used' => 'integer',
        ];
    }

    public function topic(): BelongsTo
    {
        return $this->belongsTo(Topic::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
