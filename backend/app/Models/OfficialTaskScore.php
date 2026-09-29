<?php

namespace App\Models;

use App\Enums\OfficialScoreSelectionPolicy;
use Database\Factories\OfficialTaskScoreFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'assessment_id',
    'student_id',
    'official_attempt_id',
    'normalized_score',
    'selection_policy_code',
    'selected_by_user_id',
    'selected_at',
])]
class OfficialTaskScore extends Model
{
    /** @use HasFactory<OfficialTaskScoreFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'normalized_score' => 'decimal:8',
            'selection_policy_code' => OfficialScoreSelectionPolicy::class,
            'selected_at' => 'datetime',
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

    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    public function officialAttempt(): BelongsTo
    {
        return $this->belongsTo(AssessmentAttempt::class, 'official_attempt_id');
    }
}
