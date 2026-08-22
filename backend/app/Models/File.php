<?php

namespace App\Models;

use App\Enums\FileCategory;
use App\Enums\FileExtension;
use Database\Factories\FileFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable([
    'institution_id',
    'uploaded_by_user_id',
    'category',
    'original_name',
    'storage_disk',
    'storage_key',
    'mime_type',
    'extension',
    'size_bytes',
    'checksum_sha256',
    'removed_at',
])]
class File extends Model
{
    /** @use HasFactory<FileFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'category' => FileCategory::class,
            'extension' => FileExtension::class,
            'size_bytes' => 'integer',
            'removed_at' => 'datetime',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by_user_id');
    }

    public function learningMaterial(): HasOne
    {
        return $this->hasOne(LearningMaterial::class);
    }
}
