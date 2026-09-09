<?php

namespace App\Models;

use Database\Factories\AnswerFileFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'answer_id',
    'file_id',
])]
class AnswerFile extends Model
{
    /** @use HasFactory<AnswerFileFactory> */
    use HasFactory, HasUuids;

    public const UPDATED_AT = null;

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function answer(): BelongsTo
    {
        return $this->belongsTo(AttemptAnswer::class, 'answer_id');
    }

    public function file(): BelongsTo
    {
        return $this->belongsTo(File::class);
    }
}
