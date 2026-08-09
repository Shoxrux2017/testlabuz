<?php

namespace App\Models;

use App\Enums\BlitzTimerStartMode;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use Database\Factories\InstitutionSettingFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'acceptable_score_difference',
    'blitz_timer_start_mode',
    'student_result_release_mode',
    'parent_result_release_mode',
    'timezone',
    'learning_material_max_mb',
    'student_submission_max_mb',
    'updated_by_user_id',
])]
class InstitutionSetting extends Model
{
    /** @use HasFactory<InstitutionSettingFactory> */
    use HasFactory;

    protected $primaryKey = 'institution_id';

    public $incrementing = false;

    protected $keyType = 'string';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'acceptable_score_difference' => 'decimal:8',
            'blitz_timer_start_mode' => BlitzTimerStartMode::class,
            'student_result_release_mode' => StudentResultReleaseMode::class,
            'parent_result_release_mode' => ParentResultReleaseMode::class,
            'learning_material_max_mb' => 'integer',
            'student_submission_max_mb' => 'integer',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function updater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by_user_id');
    }
}
