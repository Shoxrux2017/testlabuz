<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAssignmentSource;
use App\Models\Assessment;
use App\Models\User;
use App\Support\Teacher\InstitutionBlitzScheduledAt;
use App\Support\Teacher\TeacherBlitzAccess;
use Illuminate\Database\Eloquent\Relations\HasMany;

final class ShowTeacherBlitz
{
    public function __construct(
        private readonly TeacherBlitzAccess $access,
        private readonly InstitutionBlitzScheduledAt $scheduledAt,
    ) {}

    public function __invoke(User $teacher, string $blitzId): Assessment
    {
        $assessment = $this->access->resolveBlitz($teacher, $blitzId);

        $assessment->load([
            'blitzTask',
            'recipients' => fn (HasMany $query) => $query
                ->where('institution_id', $teacher->institution_id)
                ->where('assignment_source', AssessmentAssignmentSource::Direct->value)
                ->orderBy('student_id'),
            'questions' => fn (HasMany $query) => $query->orderBy('position'),
            'questions.choiceOptions' => fn (HasMany $query) => $query->orderBy('position'),
            'questions.trueFalseAnswer',
            'questions.shortAcceptedAnswers' => fn (HasMany $query) => $query->orderBy('position'),
            'questions.matchingItems' => fn (HasMany $query) => $query->orderBy('position')->orderBy('side'),
            'questions.orderingItems' => fn (HasMany $query) => $query->orderBy('correct_position'),
            'questions.fillBlanks' => fn (HasMany $query) => $query->orderBy('position'),
            'questions.fillBlanks.acceptedAnswers' => fn (HasMany $query) => $query->orderBy('position'),
        ]);
        $assessment->setAttribute('institution_timezone', $this->scheduledAt->timezone($teacher));

        return $assessment;
    }
}
