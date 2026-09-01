<?php

namespace App\Models;

use App\Enums\HomeworkStatus;
use Database\Factories\HomeworkAssignmentFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'assessment_id',
    'institution_id',
    'status',
    'deadline_at',
    'activated_at',
    'closed_at',
    'archived_at',
])]
class HomeworkAssignment extends Model
{
    /** @use HasFactory<HomeworkAssignmentFactory> */
    use HasFactory;

    protected $primaryKey = 'assessment_id';

    public $incrementing = false;

    protected $keyType = 'string';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => HomeworkStatus::class,
            'deadline_at' => 'datetime',
            'activated_at' => 'datetime',
            'closed_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }

    public function assessment(): BelongsTo
    {
        return $this->belongsTo(Assessment::class);
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }
}
