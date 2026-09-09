<?php

namespace App\Models;

use App\Enums\AttemptAnswerCheckingStatus;
use Database\Factories\AttemptAnswerFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable([
    'institution_id',
    'attempt_id',
    'question_id',
    'checking_status',
    'awarded_points',
    'feedback',
    'checked_by_user_id',
    'checked_at',
])]
class AttemptAnswer extends Model
{
    /** @use HasFactory<AttemptAnswerFactory> */
    use HasFactory, HasUuids;

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'checking_status' => AttemptAnswerCheckingStatus::class,
            'awarded_points' => 'decimal:8',
            'checked_at' => 'datetime',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function attempt(): BelongsTo
    {
        return $this->belongsTo(AssessmentAttempt::class, 'attempt_id');
    }

    public function question(): BelongsTo
    {
        return $this->belongsTo(Question::class);
    }

    public function checkedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'checked_by_user_id');
    }

    public function selectedOptions(): BelongsToMany
    {
        return $this->belongsToMany(QuestionChoiceOption::class, 'answer_choice_selections', 'answer_id', 'option_id')
            ->withPivot(['institution_id', 'created_at']);
    }

    public function textValue(): HasOne
    {
        return $this->hasOne(AnswerTextValue::class, 'answer_id');
    }

    public function booleanValue(): HasOne
    {
        return $this->hasOne(AnswerBooleanValue::class, 'answer_id');
    }

    public function matchingPairs(): HasMany
    {
        return $this->hasMany(AnswerMatchingPair::class, 'answer_id');
    }

    public function orderingItems(): HasMany
    {
        return $this->hasMany(AnswerOrderingItem::class, 'answer_id');
    }

    public function fillBlankValues(): HasMany
    {
        return $this->hasMany(AnswerFillBlankValue::class, 'answer_id');
    }

    public function answerFile(): HasOne
    {
        return $this->hasOne(AnswerFile::class, 'answer_id');
    }
}
