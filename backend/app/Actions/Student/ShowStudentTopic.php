<?php

namespace App\Actions\Student;

use App\Enums\FileCategory;
use App\Models\Topic;
use App\Models\User;
use App\Support\Results\TopicResultReader;
use App\Support\Student\StudentBlitzReadSnapshot;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/** The Student's Topic with its materials and the Student's Topic result status (docs/09 §29.3). One snapshot read. */
class ShowStudentTopic
{
    public function __construct(
        private readonly TopicResultReader $results,
        private readonly StudentBlitzReadSnapshot $snapshots,
    ) {}

    public function __invoke(User $student, string $topicId): Topic
    {
        if (! Str::isUuid($topicId)) {
            throw new NotFoundHttpException;
        }

        return $this->snapshots->read(function () use ($student, $topicId): Topic {
            $topic = Topic::query()
                ->select([
                    'id',
                    'institution_id',
                    'group_id',
                    'title',
                    'description',
                    'subject',
                    'student_instructions',
                    'lesson_at',
                    'status',
                ])
                ->visibleToStudent($student)
                ->whereKey($topicId)
                ->with([
                    'group:id,name,level,subject_direction,status',
                    'learningMaterials' => function ($query) use ($student): void {
                        $query
                            ->select(['id', 'topic_id', 'file_id', 'title'])
                            ->where('learning_materials.institution_id', $student->institution_id)
                            ->whereNull('learning_materials.removed_at')
                            ->whereHas('file', function (Builder $query) use ($student): void {
                                $query
                                    ->where('files.institution_id', $student->institution_id)
                                    ->where('files.category', FileCategory::LearningMaterial->value)
                                    ->whereNull('files.removed_at');
                            })
                            ->with(['file' => function ($query) use ($student): void {
                                $query
                                    ->select(['id', 'original_name', 'extension', 'size_bytes'])
                                    ->where('files.institution_id', $student->institution_id)
                                    ->where('files.category', FileCategory::LearningMaterial->value)
                                    ->whereNull('files.removed_at');
                            }])
                            ->orderBy('position')
                            ->orderBy('created_at')
                            ->orderBy('id');
                    },
                ])
                ->first();

            if (! $topic instanceof Topic) {
                throw new NotFoundHttpException;
            }

            $topic->setAttribute('student_result_status', $this->results->forStudent($topic, $student->id)?->status);

            return $topic;
        });
    }
}
