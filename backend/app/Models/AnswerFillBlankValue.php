<?php

namespace App\Models;

use Database\Factories\AnswerFillBlankValueFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'answer_id',
    'blank_id',
    'text_value',
])]
class AnswerFillBlankValue extends Model
{
    /** @use HasFactory<AnswerFillBlankValueFactory> */
    use HasFactory, HasUuids;

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function answer(): BelongsTo
    {
        return $this->belongsTo(AttemptAnswer::class, 'answer_id');
    }

    public function blank(): BelongsTo
    {
        return $this->belongsTo(QuestionFillBlank::class, 'blank_id');
    }
}
