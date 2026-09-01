<?php

namespace App\Models;

use App\Enums\TopicStatus;
use Database\Factories\TopicFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable([
    'institution_id',
    'group_id',
    'teacher_id',
    'title',
    'description',
    'subject',
    'student_instructions',
    'lesson_at',
    'status',
    'activated_at',
    'closed_at',
    'archived_at',
])]
class Topic extends Model
{
    /** @use HasFactory<TopicFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => TopicStatus::class,
            'lesson_at' => 'datetime',
            'activated_at' => 'datetime',
            'closed_at' => 'datetime',
            'archived_at' => 'datetime',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function group(): BelongsTo
    {
        return $this->belongsTo(Group::class);
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    public function learningMaterials(): HasMany
    {
        return $this->hasMany(LearningMaterial::class);
    }

    public function assessments(): HasMany
    {
        return $this->hasMany(Assessment::class);
    }

    public function resultPair(): HasOne
    {
        return $this->hasOne(TopicResultPair::class);
    }

    public function scopeVisibleToTeacher(Builder $query, User $teacher): Builder
    {
        return $query
            ->where('topics.institution_id', $teacher->institution_id)
            ->where('topics.teacher_id', $teacher->id)
            ->whereExists(function ($query) use ($teacher): void {
                $query
                    ->selectRaw('1')
                    ->from('group_teacher_memberships')
                    ->whereColumn('group_teacher_memberships.group_id', 'topics.group_id')
                    ->where('group_teacher_memberships.institution_id', $teacher->institution_id)
                    ->where('group_teacher_memberships.teacher_id', $teacher->id)
                    ->whereNull('group_teacher_memberships.ended_at');
            });
    }

    public function scopeVisibleToStudent(Builder $query, User $student): Builder
    {
        return $query
            ->where('topics.institution_id', $student->institution_id)
            ->whereIn('topics.status', [
                TopicStatus::Active->value,
                TopicStatus::Closed->value,
                TopicStatus::Archived->value,
            ])
            ->whereExists(function ($query) use ($student): void {
                $query
                    ->selectRaw('1')
                    ->from('group_student_memberships')
                    ->whereColumn('group_student_memberships.group_id', 'topics.group_id')
                    ->where('group_student_memberships.institution_id', $student->institution_id)
                    ->where('group_student_memberships.student_id', $student->id)
                    ->whereNull('group_student_memberships.ended_at');
            });
    }
}
