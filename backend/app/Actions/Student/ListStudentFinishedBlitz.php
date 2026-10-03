<?php

namespace App\Actions\Student;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\InstitutionSetting;
use App\Models\User;
use App\Support\Checking\OfficialScoreEvaluator;
use App\Support\Student\StudentBlitzAccess;
use App\Support\Student\StudentResultRelease;
use App\Support\Student\StudentResultVisibility;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * The Student's finished Blitz tasks with the result of the Attempt that counts: replacement #2
 * after an approved exception, otherwise #1 (docs/09 §20.6). A finished Blitz cannot gain an
 * exception or an Attempt, and a Topic release only ever opens results, so the page is read
 * without a snapshot.
 */
final class ListStudentFinishedBlitz
{
    public const DEFAULT_PAGE = 1;

    public const DEFAULT_PER_PAGE = 25;

    public const MAX_PER_PAGE = 100;

    public function __construct(
        private readonly StudentBlitzAccess $access,
        private readonly StudentResultVisibility $visibility,
        private readonly StudentResultRelease $release,
        private readonly OfficialScoreEvaluator $evaluator,
    ) {}

    public function __invoke(User $student, int $page, int $perPage): LengthAwarePaginator
    {
        $blitz = $this->access->finishedQuery($student)->paginate(perPage: $perPage, pageName: 'page', page: $page);
        $released = $this->release->forTasks($student, Collection::make($blitz->items()), InstitutionSetting::query()
            ->select(['institution_id', 'student_result_release_mode'])
            ->where('institution_id', $student->institution_id)
            ->first()?->student_result_release_mode);
        $counting = [];
        $visible = [];

        foreach ($blitz->items() as $assessment) {
            $attempt = $counting[$assessment->id] = $this->countingAttempt($assessment);

            if ($attempt !== null && $this->visibility->visible($attempt, $assessment, $released[$assessment->id])) {
                $visible[$assessment->id] = $attempt;
            }
        }

        $feedback = $this->feedback($student, array_map(fn (AssessmentAttempt $attempt): string => $attempt->id, array_values($visible)));

        foreach ($blitz->items() as $assessment) {
            $attempt = $counting[$assessment->id];
            $shown = array_key_exists($assessment->id, $visible);
            $assessment->setAttribute('student_attempt_exception', $assessment->getRelation('blitzAttemptExceptions')->isNotEmpty());
            $assessment->setAttribute('student_finished_result', $attempt === null ? null : [
                'attempt_number' => $attempt->attempt_number,
                'visible' => $shown,
                'normalized_score' => $shown ? (float) $attempt->normalized_score : null,
                'feedback' => $shown ? ($feedback[$attempt->id] ?? []) : [],
            ]);
        }

        return $blitz;
    }

    private function countingAttempt(Assessment $assessment): ?AssessmentAttempt
    {
        return $this->evaluator->countingBlitzAttempt(
            $assessment->getRelation('attempts'),
            $assessment->getRelation('blitzAttemptExceptions')->first(),
        );
    }

    /**
     * The Teacher's feedback of these Attempts, in Question order, in one query for the page.
     *
     * @param  list<string>  $attemptIds
     * @return array<string, list<array{question_id: string, position: int, text: string}>>
     */
    private function feedback(User $student, array $attemptIds): array
    {
        if ($attemptIds === []) {
            return [];
        }

        $rows = DB::table('attempt_answers')
            ->join('questions', fn ($join) => $join->on('questions.id', '=', 'attempt_answers.question_id')
                ->on('questions.institution_id', '=', 'attempt_answers.institution_id'))
            ->where('attempt_answers.institution_id', $student->institution_id)
            ->whereIn('attempt_answers.attempt_id', $attemptIds)
            ->whereNotNull('attempt_answers.feedback')
            ->orderBy('questions.position')
            ->orderBy('questions.id')
            ->get(['attempt_answers.attempt_id', 'attempt_answers.question_id', 'questions.position', 'attempt_answers.feedback']);
        $feedback = [];

        foreach ($rows as $row) {
            $feedback[$row->attempt_id][] = [
                'question_id' => (string) $row->question_id,
                'position' => (int) $row->position,
                'text' => (string) $row->feedback,
            ];
        }

        return $feedback;
    }
}
