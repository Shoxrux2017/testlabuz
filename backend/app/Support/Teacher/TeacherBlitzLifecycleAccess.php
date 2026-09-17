<?php

namespace App\Support\Teacher;

use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;

final class TeacherBlitzLifecycleAccess
{
    public function __construct(private readonly TeacherBlitzAccess $blitzAccess) {}

    public function resolveBlitz(User $teacher, string $blitzId): Assessment
    {
        return $this->blitzAccess->resolveBlitz($teacher, $blitzId);
    }

    /** @return array{group: Group, topic: Topic, assessment: Assessment, blitz: BlitzTask} */
    public function lockBlitz(User $teacher, Assessment $preliminaryAssessment): array
    {
        return $this->blitzAccess->lockBlitz($teacher, $preliminaryAssessment);
    }

    public function lockResultPair(User $teacher, Topic $topic, Assessment $assessment): ?TopicResultPair
    {
        return $this->blitzAccess->lockResultPair($teacher, $topic, $assessment);
    }

    public function lockSettings(User $teacher): ?InstitutionSetting
    {
        return InstitutionSetting::query()
            ->where('institution_id', $teacher->institution_id)
            ->lockForUpdate()
            ->first();
    }

    /** @return Collection<int, Question> */
    public function lockQuestions(User $teacher, Assessment $assessment): Collection
    {
        return Question::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('position')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }
}
