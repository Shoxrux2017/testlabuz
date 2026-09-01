<?php

namespace App\Models;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentType;
use Database\Factories\AssessmentFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable([
    'institution_id',
    'topic_id',
    'teacher_id',
    'type',
    'title',
    'description',
    'student_instructions',
    'assignment_mode',
    'total_possible_points',
])]
class Assessment extends Model
{
    /** @use HasFactory<AssessmentFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'type' => AssessmentType::class,
            'assignment_mode' => AssessmentAssignmentMode::class,
            'total_possible_points' => 'decimal:6',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function topic(): BelongsTo
    {
        return $this->belongsTo(Topic::class);
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    public function homeworkAssignment(): HasOne
    {
        return $this->hasOne(HomeworkAssignment::class, 'assessment_id');
    }

    public function recipients(): HasMany
    {
        return $this->hasMany(AssessmentStudent::class);
    }

    public function attempts(): HasMany
    {
        return $this->hasMany(AssessmentAttempt::class);
    }

    public function resultPairAsHomework(): HasOne
    {
        return $this->hasOne(TopicResultPair::class, 'homework_assessment_id');
    }

    public function resultPairAsBlitz(): HasOne
    {
        return $this->hasOne(TopicResultPair::class, 'blitz_assessment_id');
    }
}
