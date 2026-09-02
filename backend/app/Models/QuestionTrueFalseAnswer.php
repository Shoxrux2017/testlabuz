<?php

namespace App\Models;

use Database\Factories\QuestionTrueFalseAnswerFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['question_id', 'institution_id', 'correct_value'])]
class QuestionTrueFalseAnswer extends Model
{
    /** @use HasFactory<QuestionTrueFalseAnswerFactory> */
    use HasFactory;

    protected $primaryKey = 'question_id';

    public $incrementing = false;

    protected $keyType = 'string';

    /** @return array<string, string> */
    protected function casts(): array
    {
        return ['correct_value' => 'boolean'];
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
