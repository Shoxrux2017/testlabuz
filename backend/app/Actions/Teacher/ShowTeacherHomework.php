<?php

namespace App\Actions\Teacher;

use App\Models\Assessment;
use App\Models\User;
use App\Support\Teacher\InstitutionHomeworkDeadlineAt;
use App\Support\Teacher\TeacherHomeworkAccess;
use Illuminate\Database\Eloquent\Relations\HasMany;

final class ShowTeacherHomework
{
    public function __construct(
        private readonly TeacherHomeworkAccess $access,
        private readonly InstitutionHomeworkDeadlineAt $deadlineAt,
    ) {}

    public function __invoke(User $teacher, string $homeworkId): Assessment
    {
        $assessment = $this->access->resolveHomework($teacher, $homeworkId);

        $assessment->load([
            'homeworkAssignment',
            'recipients' => fn (HasMany $query) => $query->orderBy('student_id'),
            'questions' => fn (HasMany $query) => $query->orderBy('position'),
            'questions.choiceOptions' => fn (HasMany $query) => $query->orderBy('position'),
            'questions.trueFalseAnswer',
            'questions.shortAcceptedAnswers' => fn (HasMany $query) => $query->orderBy('position'),
            'questions.matchingItems' => fn (HasMany $query) => $query->orderBy('position')->orderBy('side'),
            'questions.orderingItems' => fn (HasMany $query) => $query->orderBy('correct_position'),
            'questions.fillBlanks' => fn (HasMany $query) => $query->orderBy('position'),
            'questions.fillBlanks.acceptedAnswers' => fn (HasMany $query) => $query->orderBy('position'),
        ]);
        $assessment->setAttribute('institution_timezone', $this->deadlineAt->timezone($teacher));

        return $assessment;
    }
}
