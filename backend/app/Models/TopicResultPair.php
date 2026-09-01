<?php

namespace App\Models;

use Database\Factories\TopicResultPairFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'topic_id',
    'homework_assessment_id',
    'blitz_assessment_id',
    'designated_by_user_id',
    'designated_at',
    'cohort_snapshotted_at',
    'locked_at',
])]
class TopicResultPair extends Model
{
    /** @use HasFactory<TopicResultPairFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'designated_at' => 'datetime',
            'cohort_snapshotted_at' => 'datetime',
            'locked_at' => 'datetime',
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

    public function homeworkAssessment(): BelongsTo
    {
        return $this->belongsTo(Assessment::class, 'homework_assessment_id');
    }

    public function blitzAssessment(): BelongsTo
    {
        return $this->belongsTo(Assessment::class, 'blitz_assessment_id');
    }

    public function designatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'designated_by_user_id');
    }
}
