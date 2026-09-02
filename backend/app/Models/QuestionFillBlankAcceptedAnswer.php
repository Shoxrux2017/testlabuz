<?php

namespace App\Models;

use Database\Factories\QuestionFillBlankAcceptedAnswerFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['institution_id', 'blank_id', 'accepted_text', 'position'])]
class QuestionFillBlankAcceptedAnswer extends Model
{
    /** @use HasFactory<QuestionFillBlankAcceptedAnswerFactory> */
    use HasFactory, HasUuids;

    protected function casts(): array
    {
        return ['position' => 'integer'];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function blank(): BelongsTo
    {
        return $this->belongsTo(QuestionFillBlank::class, 'blank_id');
    }
}
