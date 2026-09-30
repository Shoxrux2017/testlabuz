<?php

namespace App\Actions\Teacher;

use App\Models\AssessmentAttempt;
use App\Models\Question;
use App\Models\User;
use App\Support\Student\StudentHomeworkAttemptAnswerStates;
use App\Support\Teacher\TeacherSubmissionAccess;
use App\Support\Teacher\TeacherSubmissionProjection;
use App\Support\Teacher\TeacherSubmissionQuestion;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** One submission with every Question, its Teacher configuration and the Student's answer (docs/09 §21.2). */
final class ShowTeacherSubmission
{
    public function __construct(
        private readonly TeacherSubmissionAccess $access,
        private readonly TeacherSubmissionProjection $projection,
        private readonly StudentHomeworkAttemptAnswerStates $answerStates,
    ) {}

    public function __invoke(User $teacher, string $submissionId): AssessmentAttempt
    {
        $attempt = $this->access->resolve($teacher, $submissionId, fn ($query) => $this->projection->apply($query, now()));
        $institutionId = $teacher->institution_id;
        // The Teacher configuration needs the complete answer keys; the Student answer reader
        // reloads some of the same relations with fewer columns, so it gets its own copies.
        $configured = $this->questions($attempt)->load([
            'choiceOptions' => fn (HasMany $query) => $query->orderBy('position'),
            'trueFalseAnswer',
            'shortAcceptedAnswers' => fn (HasMany $query) => $query->orderBy('position'),
            'matchingItems' => fn (HasMany $query) => $query->orderBy('position')->orderBy('side'),
            'orderingItems' => fn (HasMany $query) => $query->orderBy('correct_position'),
            'fillBlanks' => fn (HasMany $query) => $query->orderBy('position'),
            'fillBlanks.acceptedAnswers' => fn (HasMany $query) => $query->orderBy('position'),
        ]);
        $answers = $this->answerStates->historicalRead($institutionId, $attempt, $this->questions($attempt))
            ->mapWithKeys(fn ($state): array => [$state->question->id => $state->attemptAnswer]);
        $reviewers = User::query()->select(['id', 'institution_id', 'full_name'])
            ->where('institution_id', $institutionId)
            ->whereIn('id', $answers->pluck('checked_by_user_id')->filter()->unique()->values())
            ->get()
            ->keyBy('id');

        $attempt->setAttribute('submission_questions', $configured->map(function (Question $question) use ($answers, $reviewers): TeacherSubmissionQuestion {
            $answer = $answers->get($question->id);

            return new TeacherSubmissionQuestion($question, $answer,
                $answer?->checked_by_user_id === null ? null : $reviewers->get($answer->checked_by_user_id));
        })->values()->all());

        return $attempt;
    }

    /** @return Collection<int, Question> */
    private function questions(AssessmentAttempt $attempt): Collection
    {
        return Question::query()
            ->where('institution_id', $attempt->institution_id)
            ->where('assessment_id', $attempt->assessment_id)
            ->orderBy('position')
            ->orderBy('id')
            ->get();
    }
}
