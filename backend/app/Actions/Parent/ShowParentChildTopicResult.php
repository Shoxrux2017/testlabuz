<?php

namespace App\Actions\Parent;

use App\Enums\ParentResultReleaseMode;
use App\Enums\UserRole;
use App\Models\User;
use App\Support\Results\TopicResultReader;
use App\Support\Results\TopicResultReading;
use App\Support\Results\TopicResultReleaseModes;
use App\Support\Results\TopicResultVisibility;
use App\Support\Student\StudentBlitzReadSnapshot;
use App\Support\Student\StudentTopicResultAccess;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * A connected child's Topic result for the Parent (docs/09 §30.5): the child's own Topic access, no
 * result information while the Parent mode is hidden or unconfigured, values only when visible to
 * the Parent and so never before the Student. One snapshot read.
 */
final class ShowParentChildTopicResult
{
    public function __construct(
        private readonly StudentTopicResultAccess $access,
        private readonly TopicResultReader $reader,
        private readonly TopicResultVisibility $visibility,
        private readonly StudentBlitzReadSnapshot $snapshots,
    ) {}

    public function __invoke(User $parent, string $studentId, string $topicId): ?TopicResultReading
    {
        if (! Str::isUuid($studentId)) {
            throw new NotFoundHttpException;
        }

        return $this->snapshots->read(function () use ($parent, $studentId, $topicId): ?TopicResultReading {
            $child = User::query()
                ->select(['id', 'institution_id'])
                ->where('institution_id', $parent->institution_id)
                ->where('role', UserRole::Student->value)
                ->whereKey(strtolower($studentId))
                ->whereExists(fn (Builder $relationship) => $relationship
                    ->selectRaw('1')
                    ->from('parent_student_relationships')
                    ->whereColumn('parent_student_relationships.student_id', 'users.id')
                    ->where('parent_student_relationships.institution_id', $parent->institution_id)
                    ->where('parent_student_relationships.parent_id', $parent->id)
                    ->whereNull('parent_student_relationships.ended_at'))
                ->first() ?? throw new NotFoundHttpException;
            $topic = $this->access->resolve($child, $topicId);
            $modes = TopicResultReleaseModes::current($topic->institution_id);

            if ($modes->parent === null || $modes->parent === ParentResultReleaseMode::Hidden) {
                return null;
            }

            $result = $this->reader->forStudent($topic, $child->id);

            if ($result === null) {
                return null;
            }

            return new TopicResultReading($topic->id, $result, $this->visibility->of($result, $modes->student, $modes->parent)->parentVisible);
        });
    }
}
