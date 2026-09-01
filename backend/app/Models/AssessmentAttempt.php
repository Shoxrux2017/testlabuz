<?php

namespace App\Models;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use Database\Factories\AssessmentAttemptFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'assessment_id',
    'assessment_student_id',
    'student_id',
    'attempt_number',
    'status',
    'started_at',
    'deadline_at',
    'submitted_at',
    'finalized_at',
    'finalization_reason',
    'locked_at',
    'official_score_eligible',
    'earned_points',
    'possible_points',
    'normalized_score',
    'scoring_completed_at',
])]
class AssessmentAttempt extends Model
{
    /** @use HasFactory<AssessmentAttemptFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'attempt_number' => 'integer',
            'status' => AssessmentAttemptStatus::class,
            'started_at' => 'datetime',
            'deadline_at' => 'datetime',
            'submitted_at' => 'datetime',
            'finalized_at' => 'datetime',
            'finalization_reason' => AssessmentAttemptFinalizationReason::class,
            'locked_at' => 'datetime',
            'official_score_eligible' => 'boolean',
            'earned_points' => 'decimal:8',
            'possible_points' => 'decimal:6',
            'normalized_score' => 'decimal:8',
            'scoring_completed_at' => 'datetime',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function assessment(): BelongsTo
    {
        return $this->belongsTo(Assessment::class);
    }

    public function assessmentStudent(): BelongsTo
    {
        return $this->belongsTo(AssessmentStudent::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
