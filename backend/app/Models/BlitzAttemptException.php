<?php

namespace App\Models;

use App\Enums\BlitzAttemptExceptionReasonType;
use Database\Factories\BlitzAttemptExceptionFactory;
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
    'invalidated_attempt_id',
    'replacement_attempt_id',
    'reason_type',
    'reason',
    'granted_by_user_id',
    'granted_at',
])]
class BlitzAttemptException extends Model
{
    /** @use HasFactory<BlitzAttemptExceptionFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'reason_type' => BlitzAttemptExceptionReasonType::class,
            'granted_at' => 'datetime',
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

    public function invalidatedAttempt(): BelongsTo
    {
        return $this->belongsTo(AssessmentAttempt::class, 'invalidated_attempt_id');
    }

    public function replacementAttempt(): BelongsTo
    {
        return $this->belongsTo(AssessmentAttempt::class, 'replacement_attempt_id');
    }

    public function grantedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'granted_by_user_id');
    }
}
