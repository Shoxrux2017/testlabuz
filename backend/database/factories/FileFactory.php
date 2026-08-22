<?php

namespace Database\Factories;

use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Models\File;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<File>
 */
class FileFactory extends Factory
{
    public function definition(): array
    {
        return [
            'institution_id' => Institution::factory(),
            'uploaded_by_user_id' => fn (array $attributes) => User::factory()
                ->teacher()
                ->state(['institution_id' => $attributes['institution_id']]),
            'category' => FileCategory::LearningMaterial,
            'original_name' => 'learning-material.pdf',
            'storage_disk' => 'private',
            'storage_key' => 'learning-materials/'.Str::uuid().'.pdf',
            'mime_type' => 'application/pdf',
            'extension' => FileExtension::Pdf,
            'size_bytes' => 1_048_576,
            'checksum_sha256' => null,
            'removed_at' => null,
        ];
    }

    public function studentSubmission(): static
    {
        return $this->state(fn (array $attributes) => [
            'category' => FileCategory::StudentSubmission,
            'original_name' => 'student-submission.docx',
            'storage_key' => 'student-submissions/'.Str::uuid().'.docx',
            'mime_type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'extension' => FileExtension::Docx,
            'size_bytes' => 1_048_576,
        ]);
    }

    public function removed(): static
    {
        return $this->state(function (array $attributes) {
            $createdAt = now()->subMinute();

            return [
                'removed_at' => $createdAt->copy()->addSeconds(30),
                'created_at' => $createdAt,
            ];
        });
    }
}
