<?php

namespace Tests\Feature\Persistence;

use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Models\File;
use App\Models\Group;
use App\Models\Institution;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Persistence\Concerns\AssertsDatabaseRejections;
use Tests\TestCase;

class TopicLearningMaterialPersistenceTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    public function test_all_valid_topic_structural_states_persist(): void
    {
        $institution = Institution::factory()->create();
        $creator = User::factory()->institutionAdmin($institution)->create();
        $teacher = User::factory()->teacher($institution)->create();
        $group = Group::factory()->create([
            'institution_id' => $institution,
            'created_by_user_id' => $creator,
        ]);
        $attributes = [
            'institution_id' => $institution,
            'group_id' => $group,
            'teacher_id' => $teacher,
        ];

        Topic::factory()->create($attributes);
        Topic::factory()->active()->create($attributes);
        Topic::factory()->closed()->create($attributes);
        Topic::factory()->archivedFromDraft()->create($attributes);
        Topic::factory()->archivedFromClosed()->create($attributes);

        $this->assertDatabaseCount('topics', 5);
        $this->assertSame(
            ['active', 'archived', 'archived', 'closed', 'draft'],
            Topic::query()->orderBy('status')->pluck('status')->map->value->all(),
        );
    }

    public function test_topic_text_status_and_lifecycle_checks_reject_invalid_rows(): void
    {
        $topic = Topic::factory()->create();

        foreach (['title', 'subject', 'student_instructions'] as $column) {
            $this->assertDatabaseRejects(fn () => $this->update('topics', $topic->id, [$column => '   ']));
        }

        $this->assertDatabaseRejects(fn () => $this->update('topics', $topic->id, ['status' => 'disabled']));

        foreach ([
            ['status' => 'draft', 'activated_at' => now()],
            ['status' => 'active', 'activated_at' => null],
            ['status' => 'closed', 'activated_at' => now(), 'closed_at' => null],
            ['status' => 'archived', 'activated_at' => now(), 'closed_at' => null, 'archived_at' => now()],
            ['status' => 'archived', 'activated_at' => null, 'closed_at' => null, 'archived_at' => null],
        ] as $invalidLifecycle) {
            $this->assertDatabaseRejects(fn () => $this->update('topics', $topic->id, $invalidLifecycle));
        }
    }

    public function test_topic_timestamp_order_checks_reject_invalid_rows(): void
    {
        $topic = Topic::factory()->create();
        $createdAt = $topic->created_at;

        foreach ([
            [
                'status' => 'active',
                'activated_at' => $createdAt->copy()->subSecond(),
            ],
            [
                'status' => 'closed',
                'activated_at' => $createdAt->copy()->addMinute(),
                'closed_at' => $createdAt->copy()->addSeconds(30),
            ],
            [
                'status' => 'archived',
                'archived_at' => $createdAt->copy()->subSecond(),
            ],
            [
                'status' => 'archived',
                'activated_at' => $createdAt->copy()->addMinute(),
                'closed_at' => $createdAt->copy()->addMinutes(3),
                'archived_at' => $createdAt->copy()->addMinutes(2),
            ],
        ] as $invalidOrdering) {
            $this->assertDatabaseRejects(fn () => $this->update('topics', $topic->id, $invalidOrdering));
        }
    }

    public function test_postgresql_rejects_cross_institution_topic_references(): void
    {
        $firstInstitution = Institution::factory()->create();
        $secondInstitution = Institution::factory()->create();
        $firstCreator = User::factory()->institutionAdmin($firstInstitution)->create();
        $secondCreator = User::factory()->institutionAdmin($secondInstitution)->create();
        $firstGroup = Group::factory()->create([
            'institution_id' => $firstInstitution,
            'created_by_user_id' => $firstCreator,
        ]);
        $secondGroup = Group::factory()->create([
            'institution_id' => $secondInstitution,
            'created_by_user_id' => $secondCreator,
        ]);
        $firstTeacher = User::factory()->teacher($firstInstitution)->create();
        $secondTeacher = User::factory()->teacher($secondInstitution)->create();
        $attributes = [
            'institution_id' => $firstInstitution,
            'group_id' => $firstGroup,
            'teacher_id' => $firstTeacher,
        ];

        $this->assertDatabaseRejects(
            fn () => Topic::factory()->create(array_merge($attributes, ['group_id' => $secondGroup])),
        );
        $this->assertDatabaseRejects(
            fn () => Topic::factory()->create(array_merge($attributes, ['teacher_id' => $secondTeacher])),
        );
    }

    public function test_file_categories_extensions_and_exact_platform_maxima_persist(): void
    {
        File::factory()->create([
            'category' => FileCategory::LearningMaterial,
            'size_bytes' => 26_214_400,
        ]);
        File::factory()->studentSubmission()->create(['size_bytes' => 15_728_640]);

        foreach ([
            [FileExtension::Pdf, 'application/pdf'],
            [FileExtension::Docx, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
            [FileExtension::Ppt, 'application/vnd.ms-powerpoint'],
            [FileExtension::Pptx, 'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
        ] as [$extension, $mimeType]) {
            File::factory()->create([
                'extension' => $extension,
                'mime_type' => $mimeType,
                'original_name' => "material.{$extension->value}",
            ]);
        }

        $this->assertDatabaseCount('files', 6);
    }

    public function test_file_value_text_size_and_checksum_checks_reject_invalid_rows(): void
    {
        $file = File::factory()->create();

        foreach ([
            ['category' => 'attachment'],
            ['extension' => 'exe'],
            ['original_name' => '   '],
            ['storage_disk' => '   '],
            ['storage_key' => '   '],
            ['mime_type' => '   '],
            ['size_bytes' => 0],
            ['size_bytes' => -1],
            ['size_bytes' => 26_214_401],
            ['checksum_sha256' => str_repeat('g', 64)],
            ['checksum_sha256' => str_repeat('a', 63)],
        ] as $invalidAttributes) {
            $this->assertDatabaseRejects(fn () => $this->update('files', $file->id, $invalidAttributes));
        }

        $submission = File::factory()->studentSubmission()->create();
        $this->assertDatabaseRejects(
            fn () => $this->update('files', $submission->id, ['size_bytes' => 15_728_641]),
        );

        $validChecksum = str_repeat('aB', 32);
        $this->update('files', $file->id, ['checksum_sha256' => $validChecksum]);
        $this->assertDatabaseHas('files', ['id' => $file->id, 'checksum_sha256' => $validChecksum]);
    }

    public function test_file_uniqueness_removal_order_and_tenant_uploader_are_enforced(): void
    {
        $institution = Institution::factory()->create();
        $uploader = User::factory()->teacher($institution)->create();
        $file = File::factory()->create([
            'institution_id' => $institution,
            'uploaded_by_user_id' => $uploader,
            'storage_disk' => 'private',
            'storage_key' => 'learning-materials/shared-key.pdf',
        ]);

        $this->assertDatabaseRejects(fn () => File::factory()->create([
            'institution_id' => $institution,
            'storage_disk' => $file->storage_disk,
            'storage_key' => $file->storage_key,
        ]));
        $this->assertDatabaseRejects(fn () => $this->update('files', $file->id, [
            'removed_at' => $file->created_at->copy()->subSecond(),
        ]));

        $otherInstitution = Institution::factory()->create();
        $otherUploader = User::factory()->teacher($otherInstitution)->create();
        $this->assertDatabaseRejects(fn () => File::factory()->create([
            'institution_id' => $institution,
            'uploaded_by_user_id' => $otherUploader,
        ]));
    }

    public function test_learning_material_checks_uniqueness_and_tenant_references_are_enforced(): void
    {
        $firstInstitution = Institution::factory()->create();
        $secondInstitution = Institution::factory()->create();
        $firstCreator = User::factory()->institutionAdmin($firstInstitution)->create();
        $secondCreator = User::factory()->institutionAdmin($secondInstitution)->create();
        $firstTeacher = User::factory()->teacher($firstInstitution)->create();
        $secondTeacher = User::factory()->teacher($secondInstitution)->create();
        $firstGroup = Group::factory()->create([
            'institution_id' => $firstInstitution,
            'created_by_user_id' => $firstCreator,
        ]);
        $secondGroup = Group::factory()->create([
            'institution_id' => $secondInstitution,
            'created_by_user_id' => $secondCreator,
        ]);
        $firstTopic = Topic::factory()->create([
            'institution_id' => $firstInstitution,
            'group_id' => $firstGroup,
            'teacher_id' => $firstTeacher,
        ]);
        $secondTopic = Topic::factory()->create([
            'institution_id' => $secondInstitution,
            'group_id' => $secondGroup,
            'teacher_id' => $secondTeacher,
        ]);
        $firstFile = File::factory()->create([
            'institution_id' => $firstInstitution,
            'uploaded_by_user_id' => $firstTeacher,
        ]);
        $secondFile = File::factory()->create([
            'institution_id' => $secondInstitution,
            'uploaded_by_user_id' => $secondTeacher,
        ]);
        $attributes = [
            'institution_id' => $firstInstitution,
            'topic_id' => $firstTopic,
            'file_id' => $firstFile,
            'teacher_id' => $firstTeacher,
            'title' => 'Lesson handout',
        ];
        $material = LearningMaterial::factory()->create($attributes);

        $this->assertDatabaseHas('learning_materials', ['id' => $material->id]);
        $this->assertDatabaseRejects(fn () => $this->update('learning_materials', $material->id, ['position' => -1]));
        $this->assertDatabaseRejects(fn () => $this->update('learning_materials', $material->id, ['title' => '   ']));
        $this->assertDatabaseRejects(fn () => $this->update('learning_materials', $material->id, [
            'removed_at' => $material->created_at->copy()->subSecond(),
        ]));
        $this->assertDatabaseRejects(fn () => LearningMaterial::factory()->create($attributes));
        $this->assertDatabaseRejects(fn () => LearningMaterial::factory()->create(array_merge($attributes, [
            'topic_id' => $secondTopic,
            'file_id' => File::factory()->create([
                'institution_id' => $firstInstitution,
                'uploaded_by_user_id' => $firstTeacher,
            ]),
        ])));
        $this->assertDatabaseRejects(fn () => LearningMaterial::factory()->create(array_merge($attributes, [
            'file_id' => $secondFile,
        ])));
        $this->assertDatabaseRejects(fn () => LearningMaterial::factory()->create(array_merge($attributes, [
            'file_id' => File::factory()->create([
                'institution_id' => $firstInstitution,
                'uploaded_by_user_id' => $firstTeacher,
            ]),
            'teacher_id' => $secondTeacher,
        ])));
    }

    public function test_restrictive_foreign_keys_preserve_all_referenced_stage_five_history(): void
    {
        $institution = Institution::factory()->create();
        $creator = User::factory()->institutionAdmin($institution)->create();
        $teacher = User::factory()->teacher($institution)->create();
        $group = Group::factory()->create([
            'institution_id' => $institution,
            'created_by_user_id' => $creator,
        ]);
        $topic = Topic::factory()->archivedFromClosed()->create([
            'institution_id' => $institution,
            'group_id' => $group,
            'teacher_id' => $teacher,
        ]);
        $file = File::factory()->removed()->create([
            'institution_id' => $institution,
            'uploaded_by_user_id' => $teacher,
        ]);
        LearningMaterial::factory()->removed()->create([
            'institution_id' => $institution,
            'topic_id' => $topic,
            'file_id' => $file,
            'teacher_id' => $teacher,
        ]);

        foreach ([$topic, $file, $group, $teacher, $creator, $institution] as $referencedModel) {
            $this->assertDatabaseRejects(fn () => $referencedModel->delete());
        }
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function update(string $table, string $id, array $attributes): void
    {
        DB::table($table)->where('id', $id)->update($attributes);
    }
}
