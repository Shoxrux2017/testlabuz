<?php

namespace App\Models;

use Database\Factories\AnswerBooleanValueFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'answer_id',
    'institution_id',
    'boolean_value',
])]
class AnswerBooleanValue extends Model
{
    /** @use HasFactory<AnswerBooleanValueFactory> */
    use HasFactory;

    protected $primaryKey = 'answer_id';

    public $incrementing = false;

    protected $keyType = 'string';

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'boolean_value' => 'boolean',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function answer(): BelongsTo
    {
        return $this->belongsTo(AttemptAnswer::class, 'answer_id');
    }
}
