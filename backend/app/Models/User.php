<?php

namespace App\Models;

use App\Enums\UserRole;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable([
    'institution_id',
    'role',
    'full_name',
    'login_name',
    'email',
    'phone',
    'password',
    'is_active',
    'must_change_password',
    'last_login_at',
    'deactivated_at',
    'created_by_user_id',
])]
#[Hidden(['password'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, HasUuids, Notifiable;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'role' => UserRole::class,
            'is_active' => 'boolean',
            'must_change_password' => 'boolean',
            'last_login_at' => 'datetime',
            'deactivated_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(self::class, 'created_by_user_id');
    }

    public function teacherGroupMemberships(): HasMany
    {
        return $this->hasMany(GroupTeacherMembership::class, 'teacher_id');
    }

    public function studentGroupMemberships(): HasMany
    {
        return $this->hasMany(GroupStudentMembership::class, 'student_id');
    }

    public function parentStudentRelationships(): HasMany
    {
        return $this->hasMany(ParentStudentRelationship::class, 'parent_id');
    }

    public function studentParentRelationships(): HasMany
    {
        return $this->hasMany(ParentStudentRelationship::class, 'student_id');
    }

    public function teacherTopics(): HasMany
    {
        return $this->hasMany(Topic::class, 'teacher_id');
    }

    public function uploadedFiles(): HasMany
    {
        return $this->hasMany(File::class, 'uploaded_by_user_id');
    }

    public function learningMaterials(): HasMany
    {
        return $this->hasMany(LearningMaterial::class, 'teacher_id');
    }

    public function authoredAssessments(): HasMany
    {
        return $this->hasMany(Assessment::class, 'teacher_id');
    }

    public function assessmentAssignments(): HasMany
    {
        return $this->hasMany(AssessmentStudent::class, 'student_id');
    }

    public function assessmentAssignmentsCreated(): HasMany
    {
        return $this->hasMany(AssessmentStudent::class, 'assigned_by_user_id');
    }

    public function assessmentAttempts(): HasMany
    {
        return $this->hasMany(AssessmentAttempt::class, 'student_id');
    }

    public function designatedTopicResultPairs(): HasMany
    {
        return $this->hasMany(TopicResultPair::class, 'designated_by_user_id');
    }
}
