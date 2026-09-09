<?php

namespace App\Models;

use Database\Factories\AnswerTextValueFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'answer_id',
    'institution_id',
    'text_value',
])]
class AnswerTextValue extends Model
{
    /** @use HasFactory<AnswerTextValueFactory> */
    use HasFactory;

    protected $primaryKey = 'answer_id';

    public $incrementing = false;

    protected $keyType = 'string';

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function answer(): BelongsTo
    {
        return $this->belongsTo(AttemptAnswer::class, 'answer_id');
    }
}
