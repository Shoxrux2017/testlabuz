<?php

namespace App\Models;

use Database\Factories\QuestionShortAcceptedAnswerFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['institution_id', 'question_id', 'accepted_text', 'position'])]
class QuestionShortAcceptedAnswer extends Model
{
    /** @use HasFactory<QuestionShortAcceptedAnswerFactory> */
    use HasFactory, HasUuids;

    protected function casts(): array
    {
        return ['position' => 'integer'];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function question(): BelongsTo
    {
        return $this->belongsTo(Question::class);
    }
}
