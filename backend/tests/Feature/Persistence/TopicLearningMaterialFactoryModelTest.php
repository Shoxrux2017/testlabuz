<?php

namespace Tests\Feature\Persistence;

use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Models\File;
use App\Models\Group;
use App\Models\Institution;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class TopicLearningMaterialFactoryModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_models_cast_fields_generate_uuids_and_expose_required_relationships(): void
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
            'lesson_at' => now()->addDay(),
        ]);
        $file = File::factory()->removed()->create([
            'institution_id' => $institution,
            'uploaded_by_user_id' => $teacher,
            'checksum_sha256' => str_repeat('a', 64),
        ]);
        $material = LearningMaterial::factory()->removed()->create([
            'institution_id' => $institution,
            'topic_id' => $topic,
            'file_id' => $file,
            'teacher_id' => $teacher,
            'position' => 3,
        ]);

        foreach ([$topic, $file, $material] as $model) {
            $this->assertTrue(Str::isUuid($model->id));
        }

        $this->assertSame(TopicStatus::Archived, $topic->status);
        foreach ([$topic->lesson_at, $topic->activated_at, $topic->closed_at, $topic->archived_at] as $instant) {
            $this->assertInstanceOf(CarbonInterface::class, $instant);
        }
        $this->assertSame(FileCategory::LearningMaterial, $file->category);
        $this->assertSame(FileExtension::Pdf, $file->extension);
        $this->assertIsInt($file->size_bytes);
        $this->assertInstanceOf(CarbonInterface::class, $file->removed_at);
        $this->assertSame(3, $material->position);
        $this->assertInstanceOf(CarbonInterface::class, $material->removed_at);

        $this->assertTrue($institution->is($topic->institution));
        $this->assertTrue($group->is($topic->group));
        $this->assertTrue($teacher->is($topic->teacher));
        $this->assertTrue($topic->learningMaterials->contains($material));
        $this->assertTrue($institution->topics->contains($topic));
        $this->assertTrue($group->topics->contains($topic));
        $this->assertTrue($teacher->teacherTopics->contains($topic));

        $this->assertTrue($institution->is($file->institution));
        $this->assertTrue($teacher->is($file->uploader));
        $this->assertTrue($material->is($file->learningMaterial));
        $this->assertTrue($institution->files->contains($file));
        $this->assertTrue($teacher->uploadedFiles->contains($file));

        $this->assertTrue($institution->is($material->institution));
        $this->assertTrue($topic->is($material->topic));
        $this->assertTrue($file->is($material->file));
        $this->assertTrue($teacher->is($material->teacher));
        $this->assertTrue($institution->learningMaterials->contains($material));
        $this->assertTrue($teacher->learningMaterials->contains($material));
    }

    public function test_topic_factory_defaults_and_states_create_valid_same_institution_lifecycles(): void
    {
        $draft = Topic::factory()->create();
        $active = Topic::factory()->active()->create();
        $closed = Topic::factory()->closed()->create();
        $archivedFromDraft = Topic::factory()->archivedFromDraft()->create();
        $archivedFromClosed = Topic::factory()->archivedFromClosed()->create();

        $this->assertSame(TopicStatus::Draft, $draft->status);
        $this->assertNull($draft->activated_at);
        $this->assertNull($draft->closed_at);
        $this->assertNull($draft->archived_at);
        $this->assertTopicFactoryGraph($draft);

        $this->assertSame(TopicStatus::Active, $active->status);
        $this->assertNotNull($active->activated_at);
        $this->assertNull($active->closed_at);
        $this->assertNull($active->archived_at);
        $this->assertTrue($active->activated_at->greaterThanOrEqualTo($active->created_at));

        $this->assertSame(TopicStatus::Closed, $closed->status);
        $this->assertTrue($closed->closed_at->greaterThanOrEqualTo($closed->activated_at));
        $this->assertNull($closed->archived_at);

        $this->assertSame(TopicStatus::Archived, $archivedFromDraft->status);
        $this->assertNull($archivedFromDraft->activated_at);
        $this->assertNull($archivedFromDraft->closed_at);
        $this->assertTrue($archivedFromDraft->archived_at->greaterThanOrEqualTo($archivedFromDraft->created_at));

        $this->assertSame(TopicStatus::Archived, $archivedFromClosed->status);
        $this->assertTrue($archivedFromClosed->closed_at->greaterThanOrEqualTo($archivedFromClosed->activated_at));
        $this->assertTrue($archivedFromClosed->archived_at->greaterThanOrEqualTo($archivedFromClosed->closed_at));

        foreach ([$active, $closed, $archivedFromDraft, $archivedFromClosed] as $topic) {
            $this->assertTopicFactoryGraph($topic);
        }
    }

    public function test_file_and_learning_material_factories_create_valid_same_institution_states(): void
    {
        $file = File::factory()->create();
        $submission = File::factory()->studentSubmission()->create();
        $removedFile = File::factory()->removed()->create();
        $material = LearningMaterial::factory()->create();
        $removedMaterial = LearningMaterial::factory()->removed()->create();

        $this->assertSame(FileCategory::LearningMaterial, $file->category);
        $this->assertSame(FileExtension::Pdf, $file->extension);
        $this->assertSame('local', $file->storage_disk);
        $this->assertSame('application/pdf', $file->mime_type);
        $this->assertGreaterThan(0, $file->size_bytes);
        $this->assertLessThanOrEqual(26_214_400, $file->size_bytes);
        $this->assertNull($file->removed_at);
        $this->assertSame($file->institution_id, $file->uploader->institution_id);
        $this->assertSame(UserRole::Teacher, $file->uploader->role);

        $this->assertSame(FileCategory::StudentSubmission, $submission->category);
        $this->assertSame(FileExtension::Docx, $submission->extension);
        $this->assertSame(
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            $submission->mime_type,
        );
        $this->assertGreaterThan(0, $submission->size_bytes);
        $this->assertLessThanOrEqual(15_728_640, $submission->size_bytes);

        $this->assertTrue($removedFile->removed_at->greaterThanOrEqualTo($removedFile->created_at));

        foreach ([$material, $removedMaterial] as $learningMaterial) {
            $this->assertSame($learningMaterial->institution_id, $learningMaterial->topic->institution_id);
            $this->assertSame($learningMaterial->institution_id, $learningMaterial->file->institution_id);
            $this->assertSame($learningMaterial->institution_id, $learningMaterial->teacher->institution_id);
            $this->assertSame(FileCategory::LearningMaterial, $learningMaterial->file->category);
            $this->assertSame($learningMaterial->teacher_id, $learningMaterial->topic->teacher_id);
            $this->assertSame($learningMaterial->teacher_id, $learningMaterial->file->uploaded_by_user_id);
            $this->assertSame(0, $learningMaterial->position);
        }

        $this->assertNull($material->removed_at);
        $this->assertTrue($removedMaterial->removed_at->greaterThanOrEqualTo($removedMaterial->created_at));
    }

    public function test_explicit_same_institution_factory_overrides_are_preserved(): void
    {
        $institution = Institution::factory()->create();
        $creator = User::factory()->institutionAdmin($institution)->create();
        $teacher = User::factory()->teacher($institution)->create();
        $group = Group::factory()->create([
            'institution_id' => $institution,
            'created_by_user_id' => $creator,
        ]);
        $topic = Topic::factory()->create([
            'institution_id' => $institution,
            'group_id' => $group,
            'teacher_id' => $teacher,
        ]);
        $file = File::factory()->create([
            'institution_id' => $institution,
            'uploaded_by_user_id' => $teacher,
        ]);
        $material = LearningMaterial::factory()->create([
            'institution_id' => $institution,
            'topic_id' => $topic,
            'file_id' => $file,
            'teacher_id' => $teacher,
        ]);

        $this->assertSame($institution->id, $topic->institution_id);
        $this->assertSame($group->id, $topic->group_id);
        $this->assertSame($teacher->id, $topic->teacher_id);
        $this->assertSame($institution->id, $file->institution_id);
        $this->assertSame($teacher->id, $file->uploaded_by_user_id);
        $this->assertSame($institution->id, $material->institution_id);
        $this->assertSame($topic->id, $material->topic_id);
        $this->assertSame($file->id, $material->file_id);
        $this->assertSame($teacher->id, $material->teacher_id);
    }

    private function assertTopicFactoryGraph(Topic $topic): void
    {
        $this->assertSame($topic->institution_id, $topic->group->institution_id);
        $this->assertSame($topic->institution_id, $topic->teacher->institution_id);
        $this->assertSame(UserRole::Teacher, $topic->teacher->role);
        $this->assertNotSame('', trim($topic->title));
        $this->assertNotSame('', trim($topic->subject));
        $this->assertNotSame('', trim($topic->student_instructions));
    }
}
