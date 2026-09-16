<?php

namespace App\Models;

use App\Enums\BlitzStatus;
use App\Enums\BlitzTimerStartMode;
use Database\Factories\BlitzTaskFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

#[Fillable([
    'assessment_id',
    'institution_id',
    'status',
    'duration_seconds',
    'scheduled_at',
    'timer_start_mode_snapshot',
    'activated_at',
    'synchronized_ends_at',
    'closed_at',
    'archived_at',
    'activated_by_user_id',
])]
class BlitzTask extends Model
{
    /** @use HasFactory<BlitzTaskFactory> */
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
            'status' => BlitzStatus::class,
            'duration_seconds' => 'integer',
            'timer_start_mode_snapshot' => BlitzTimerStartMode::class,
            'activated_at' => 'datetime',
            'synchronized_ends_at' => 'datetime',
            'closed_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }

    protected function scheduledAt(): Attribute
    {
        // Keep teacher-entered microseconds separate from the whole-second execution timestamps.
        return Attribute::make(
            get: fn (?string $value): ?Carbon => $value === null ? null : $this->asDateTime($value),
            set: fn (mixed $value): ?string => $value === null
                ? null
                : $this->asDateTime($value)->utc()->format('Y-m-d H:i:s.uP'),
        )->withoutObjectCaching();
    }

    public function assessment(): BelongsTo
    {
        return $this->belongsTo(Assessment::class);
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function activatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'activated_by_user_id');
    }

    public function attemptExceptions(): HasMany
    {
        return $this->hasMany(BlitzAttemptException::class, 'assessment_id');
    }
}
