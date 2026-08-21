<?php

namespace App\Models;

use App\Enums\GroupStatus;
use Database\Factories\GroupFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'institution_id',
    'name',
    'level',
    'subject_direction',
    'description',
    'status',
    'created_by_user_id',
    'archived_at',
])]
class Group extends Model
{
    /** @use HasFactory<GroupFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => GroupStatus::class,
            'archived_at' => 'datetime',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_user_id');
    }

    public function teacherMemberships(): HasMany
    {
        return $this->hasMany(GroupTeacherMembership::class);
    }

    public function studentMemberships(): HasMany
    {
        return $this->hasMany(GroupStudentMembership::class);
    }
}
