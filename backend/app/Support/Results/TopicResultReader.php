<?php

namespace App\Support\Results;

use App\Domain\Institution\UnderstandingCategorySetValidator;
use App\Domain\Results\CategoryBand;
use App\Domain\Results\TopicResultCalculator;
use App\Domain\Results\TopicResultSide;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\HomeworkStatus;
use App\Enums\OfficialScoreStatus;
use App\Enums\TopicResultClosureReason;
use App\Enums\TopicResultSideState as State;
use App\Enums\TopicResultStatus;
use App\Enums\UnderstandingCategoryCode;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\OfficialTaskScore;
use App\Models\Topic;
use App\Models\TopicResult;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Checking\OfficialScoreReader;
use App\Support\Checking\OfficialScoreReading;
use Carbon\CarbonImmutable;
use DateTimeInterface;
use Illuminate\Database\Eloquent\Collection;
use InvalidArgumentException;
use LogicException;

/**
 * Reads every cohort Student's Topic result live (S10-T1, docs/09 §25.3): the side states from the
 * Stage 9 official-score read, the status and calculation from the current threshold and category
 * set, work finished and closable; a closed result is read from its snapshot. It takes no locks and
 * runs a constant number of queries, so callers wrap it in one read-only snapshot transaction.
 */
final class TopicResultReader
{
    private const HOMEWORK_ATTEMPT_LIMIT = 3;

    private const FINISHED_BLITZ = [BlitzStatus::Closed, BlitzStatus::Archived];

    private const FINISHED_HOMEWORK = [HomeworkStatus::Closed, HomeworkStatus::Archived];

    public function __construct(
        private readonly OfficialScoreReader $officialScores,
        private readonly TopicResultCalculator $calculator,
        private readonly UnderstandingCategorySetValidator $categoryValidator,
    ) {}

    /** @return list<TopicResultView> The cohort's results, ordered by Student id */
    public function forTopic(Topic $topic): array
    {
        return $this->read($topic, null);
    }

    /** The Student's result, or null when the Student is not in the Topic's cohort. */
    public function forStudent(Topic $topic, string $studentId): ?TopicResultView
    {
        return $this->read($topic, $studentId)[0] ?? null;
    }

    /** @return list<TopicResultView> */
    private function read(Topic $topic, ?string $studentId): array
    {
        $institutionId = $topic->institution_id;
        $tasks = $this->officialTasks($topic);

        if ($tasks === null) {
            return [];
        }

        [$homework, $blitz] = $tasks;
        $taskIds = array_values(array_filter([$homework->id, $blitz?->id]));
        $recipients = AssessmentStudent::query()
            ->select(['id', 'institution_id', 'assessment_id', 'student_id'])
            ->where('institution_id', $institutionId)
            ->whereIn('assessment_id', $taskIds)
            ->when($studentId !== null, fn ($query) => $query->where('student_id', $studentId))
            ->get();

        if ($recipients->isEmpty()) {
            return [];
        }

        $studentIds = $recipients->pluck('student_id')->unique()->sort()->values()->all();
        $students = User::query()
            ->select(['id', 'institution_id', 'full_name'])
            ->where('institution_id', $institutionId)
            ->whereIn('id', $studentIds)
            ->get()
            ->keyBy('id');
        $attempts = AssessmentAttempt::query()
            ->select(['id', 'institution_id', 'assessment_id', 'assessment_student_id', 'student_id', 'attempt_number',
                'status', 'official_score_eligible', 'possible_points', 'normalized_score'])
            ->where('institution_id', $institutionId)
            ->whereIn('assessment_id', $taskIds)
            ->whereIn('student_id', $studentIds)
            ->get();
        $this->loadWaitingAnswers($institutionId, $attempts);
        $officialRows = OfficialTaskScore::query()
            ->select(['id', 'institution_id', 'assessment_id', 'student_id', 'official_attempt_id', 'normalized_score'])
            ->where('institution_id', $institutionId)
            ->whereIn('assessment_id', $taskIds)
            ->whereIn('student_id', $studentIds)
            ->get();
        $exceptions = $blitz === null ? new Collection : BlitzAttemptException::query()
            ->select(['id', 'institution_id', 'assessment_id', 'assessment_student_id', 'invalidated_attempt_id', 'replacement_attempt_id'])
            ->where('institution_id', $institutionId)
            ->where('assessment_id', $blitz->id)
            ->whereIn('assessment_student_id', $recipients->pluck('id'))
            ->get();
        // Every column: a closed row is read from its whole snapshot.
        $rows = TopicResult::query()
            ->where('institution_id', $institutionId)
            ->where('topic_id', $topic->id)
            ->whereIn('student_id', $studentIds)
            ->get()
            ->keyBy('student_id');
        $inputs = new TopicResultInputs(
            homework: $homework,
            blitz: $blitz,
            threshold: InstitutionSetting::query()
                ->select(['institution_id', 'acceptable_score_difference'])
                ->where('institution_id', $institutionId)
                ->first()?->acceptable_score_difference,
            bands: $this->bands($institutionId),
            now: CarbonImmutable::now(),
        );
        $recipientsByStudent = $recipients->groupBy('student_id');
        $attemptsByStudent = $attempts->groupBy('student_id');
        $officialRowsByStudent = $officialRows->groupBy('student_id');
        $exceptionsByRecipient = $exceptions->keyBy('assessment_student_id');

        return array_map(fn (string $id): TopicResultView => $this->view(
            $inputs,
            $students->get($id) ?? throw new LogicException('A recipient is a Student of the Institution.'),
            $recipientsByStudent->get($id)->keyBy('assessment_id'),
            $attemptsByStudent->get($id) ?? new Collection,
            ($officialRowsByStudent->get($id) ?? new Collection)->keyBy('assessment_id'),
            $exceptionsByRecipient,
            $rows->get($id),
        ), $studentIds);
    }

    /** @return ?array{0: Assessment, 1: ?Assessment} The official Homework and Blitz once the cohort is established */
    private function officialTasks(Topic $topic): ?array
    {
        $institutionId = $topic->institution_id;
        $pair = TopicResultPair::query()
            ->select(['id', 'institution_id', 'topic_id', 'homework_assessment_id', 'blitz_assessment_id', 'cohort_snapshotted_at'])
            ->where('institution_id', $institutionId)
            ->where('topic_id', $topic->id)
            ->first();

        if ($pair === null || $pair->cohort_snapshotted_at === null) {
            return null;
        }

        $tasks = Assessment::query()
            ->select(['id', 'institution_id', 'topic_id', 'type'])
            ->where('institution_id', $institutionId)
            ->whereIn('id', array_values(array_filter([$pair->homework_assessment_id, $pair->blitz_assessment_id])))
            ->with([
                'homeworkAssignment' => fn ($query) => $query
                    ->select(['assessment_id', 'institution_id', 'status', 'deadline_at', 'activated_at'])
                    ->where('institution_id', $institutionId),
                'blitzTask' => fn ($query) => $query
                    ->select(['assessment_id', 'institution_id', 'status', 'activated_at'])
                    ->where('institution_id', $institutionId),
            ])
            ->get()
            ->keyBy('id');

        return [
            $tasks->get($pair->homework_assessment_id) ?? throw new LogicException('A result pair names its Homework.'),
            $pair->blitz_assessment_id === null ? null
                : ($tasks->get($pair->blitz_assessment_id) ?? throw new LogicException('A result pair names its Blitz.')),
        ];
    }

    /**
     * @param  Collection<string, AssessmentStudent>  $recipients  The Student's recipients, by task id
     * @param  Collection<int, AssessmentAttempt>  $attempts  The Student's Attempts of both official tasks
     * @param  Collection<string, OfficialTaskScore>  $officialRows  The Student's official rows, by task id
     * @param  Collection<string, BlitzAttemptException>  $exceptions  The cohort's Blitz exceptions, by recipient id
     */
    private function view(
        TopicResultInputs $inputs,
        User $student,
        Collection $recipients,
        Collection $attempts,
        Collection $officialRows,
        Collection $exceptions,
        ?TopicResult $row,
    ): TopicResultView {
        if ($row?->closed_at !== null) {
            return $this->closedView($inputs, $student, $row, $attempts);
        }

        $homework = $inputs->homework;
        $blitz = $inputs->blitz;
        $homeworkSide = $this->homeworkSide($homework, $recipients->get($homework->id), $attempts, $officialRows->get($homework->id), $inputs->now);
        $blitzRecipient = $blitz === null ? null : $recipients->get($blitz->id);
        $blitzSide = $blitz === null
            ? new TopicResultSideView(State::NotDesignated, null)
            : $this->blitzSide($blitz, $blitzRecipient, $attempts, $officialRows->get($blitz->id),
                $blitzRecipient === null ? null : $exceptions->get($blitzRecipient->id), $homeworkSide->state);
        $computation = $this->calculator->calculate(
            new TopicResultSide($homeworkSide->state, $homeworkSide->score),
            new TopicResultSide($blitzSide->state, $blitzSide->score),
            $inputs->threshold,
            $inputs->bands,
        );
        $finished = $this->workFinished($inputs, $attempts);

        return new TopicResultView(
            student: $student,
            status: $computation->status,
            closedOutcome: null,
            missingComponent: $computation->missingComponent,
            homework: $homeworkSide,
            blitz: $blitzSide,
            difference: $computation->difference,
            threshold: $computation->threshold,
            method: $computation->method,
            consistency: $computation->consistency,
            finalScore: $computation->finalScore,
            categoryScore: $computation->categoryScore,
            category: $computation->category,
            categoryMinScore: $computation->categoryMinScore,
            categoryMaxScore: $computation->categoryMaxScore,
            terminal: $computation->terminal(),
            workFinished: $finished,
            closable: $computation->terminal() && $finished,
            row: $row,
        );
    }

    /** @param Collection<int, AssessmentAttempt> $attempts The Student's Attempts of both official tasks */
    private function homeworkSide(Assessment $homework, ?AssessmentStudent $recipient, Collection $attempts, ?OfficialTaskScore $official, CarbonImmutable $now): TopicResultSideView
    {
        $assignment = $homework->homeworkAssignment ?? throw new LogicException('An official Homework has its Homework row.');

        if ($assignment->activated_at === null) {
            return new TopicResultSideView(State::NotActivated, $homework->id);
        }

        $own = $attempts->where('assessment_id', $homework->id)->values();
        $reading = $this->officialScores->readLoaded($homework, $this->recipientOf($recipient), $own, $official, null, null);

        return match ($reading->status) {
            OfficialScoreStatus::Ready => $this->ready($reading),
            OfficialScoreStatus::WaitingForTeacherReview => new TopicResultSideView(State::WaitingForTeacherReview, $homework->id),
            OfficialScoreStatus::AutomaticCheckingPending => new TopicResultSideView(State::Checking, $homework->id),
            OfficialScoreStatus::NoCompletedAttempt => new TopicResultSideView(
                $this->homeworkStillOpen($assignment->status, $assignment->deadline_at, $own, $now) ? State::Open : State::Missing,
                $homework->id,
            ),
            default => throw new LogicException('An official Homework has no replacement or non-official status.'),
        };
    }

    /** @param Collection<int, AssessmentAttempt> $attempts The Student's Homework Attempts */
    private function homeworkStillOpen(HomeworkStatus $status, ?DateTimeInterface $deadline, Collection $attempts, CarbonImmutable $now): bool
    {
        if ($attempts->contains(fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::InProgress)) {
            return true;
        }

        return $status === HomeworkStatus::Active
            && ($deadline === null || $now->lessThan($deadline))
            && $attempts->count() < self::HOMEWORK_ATTEMPT_LIMIT;
    }

    /** @param Collection<int, AssessmentAttempt> $attempts The Student's Attempts of both official tasks */
    private function blitzSide(
        Assessment $blitz,
        ?AssessmentStudent $recipient,
        Collection $attempts,
        ?OfficialTaskScore $official,
        ?BlitzAttemptException $exception,
        State $homeworkState,
    ): TopicResultSideView {
        $task = $blitz->blitzTask ?? throw new LogicException('An official Blitz has its Blitz row.');

        if ($task->activated_at === null) {
            return new TopicResultSideView(State::NotActivated, $blitz->id);
        }

        $own = $attempts->where('assessment_id', $blitz->id)->values();
        $reading = $this->officialScores->readLoaded($blitz, $this->recipientOf($recipient), $own, $official, $exception, $task->status);

        return match ($reading->status) {
            OfficialScoreStatus::Ready => $this->ready($reading),
            OfficialScoreStatus::WaitingForTeacherReview => new TopicResultSideView(State::WaitingForTeacherReview, $blitz->id),
            OfficialScoreStatus::AutomaticCheckingPending => new TopicResultSideView(State::Checking, $blitz->id),
            OfficialScoreStatus::WaitingForReplacement => new TopicResultSideView(State::Open, $blitz->id),
            // S10-D8: a Student who can no longer submit the Homework cannot start the official Blitz.
            OfficialScoreStatus::NoCompletedAttempt => new TopicResultSideView(
                $task->status === BlitzStatus::Active && ! ($own->isEmpty() && $homeworkState === State::Missing) ? State::Open : State::Missing,
                $blitz->id,
            ),
            default => throw new LogicException('An official Blitz always has an official-score status.'),
        };
    }

    private function ready(OfficialScoreReading $reading): TopicResultSideView
    {
        if ($reading->score === null || $reading->attempt === null) {
            throw new LogicException('A ready official score has its row and Attempt.');
        }

        return new TopicResultSideView(
            State::Ready,
            $reading->assessment->id,
            $reading->attempt->id,
            $reading->attempt->attempt_number,
            (string) $reading->score->normalized_score,
        );
    }

    private function recipientOf(?AssessmentStudent $recipient): AssessmentStudent
    {
        return $recipient ?? throw new LogicException('An activated official task holds every cohort Student as a recipient.');
    }

    /**
     * The official Blitz was activated and is closed or archived, the Homework can no longer be
     * submitted, and no Attempt of either task is in progress (S10-D3).
     *
     * @param  Collection<int, AssessmentAttempt>  $attempts  The Student's Attempts of both official tasks
     */
    private function workFinished(TopicResultInputs $inputs, Collection $attempts): bool
    {
        $homework = $inputs->homework;
        $now = $inputs->now;
        $blitzTask = $inputs->blitz?->blitzTask;
        $assignment = $homework->homeworkAssignment ?? throw new LogicException('An official Homework has its Homework row.');
        $blitzDone = $blitzTask !== null && $blitzTask->activated_at !== null && in_array($blitzTask->status, self::FINISHED_BLITZ, true);
        $homeworkDone = in_array($assignment->status, self::FINISHED_HOMEWORK, true)
            || ($assignment->deadline_at !== null && $now->greaterThanOrEqualTo($assignment->deadline_at))
            || $attempts->where('assessment_id', $homework->id)->count() >= self::HOMEWORK_ATTEMPT_LIMIT;

        return $blitzDone && $homeworkDone
            && ! $attempts->contains(fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::InProgress);
    }

    /** @param Collection<int, AssessmentAttempt> $attempts The Student's Attempts of both official tasks */
    private function closedView(TopicResultInputs $inputs, User $student, TopicResult $row, Collection $attempts): TopicResultView
    {
        $numbers = $attempts->pluck('attempt_number', 'id');
        $side = fn (?string $assessmentId, State $state, ?string $attemptId, ?string $score): TopicResultSideView => new TopicResultSideView(
            $state,
            $assessmentId,
            $attemptId,
            $attemptId === null ? null : ($numbers->get($attemptId) ?? throw new LogicException('A closed result names an Attempt of its Student.')),
            $score,
        );

        return new TopicResultView(
            student: $student,
            status: TopicResultStatus::Closed,
            closedOutcome: $row->closed_outcome,
            missingComponent: $row->missing_component,
            homework: $side($row->homework_assessment_id, $row->homework_state, $row->homework_attempt_id, $row->homework_score),
            blitz: $side($row->blitz_assessment_id, $row->blitz_state, $row->blitz_attempt_id, $row->blitz_score),
            difference: $row->score_difference,
            threshold: $row->acceptable_difference_used,
            method: $row->calculation_method,
            consistency: $row->consistency,
            finalScore: $row->final_score,
            categoryScore: $row->category_score,
            category: $row->category_code,
            categoryMinScore: $row->category_min_score_used,
            categoryMaxScore: $row->category_max_score_used,
            terminal: false,
            workFinished: $row->closure_reason === TopicResultClosureReason::Teacher || $this->workFinished($inputs, $attempts),
            closable: false,
            row: $row,
        );
    }

    /**
     * Loads, in one pass, the answers (with Question points) that the evaluator needs for the upper
     * bound of each Attempt waiting for Teacher review.
     *
     * @param  Collection<int, AssessmentAttempt>  $attempts
     */
    private function loadWaitingAnswers(string $institutionId, Collection $attempts): void
    {
        $attempts->filter(fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::WaitingForTeacherReview)
            ->values()
            ->load([
                'answers' => fn ($query) => $query
                    ->select(['id', 'institution_id', 'attempt_id', 'question_id', 'checking_status', 'awarded_points'])
                    ->where('institution_id', $institutionId),
                'answers.question' => fn ($query) => $query
                    ->select(['id', 'institution_id', 'points'])
                    ->where('institution_id', $institutionId),
            ]);
    }

    /** @return ?list<CategoryBand> The four numeric bands of a valid category set, or null */
    private function bands(string $institutionId): ?array
    {
        $categories = InstitutionUnderstandingCategory::query()
            ->select(['institution_id', 'code', 'min_score', 'max_score', 'sort_order'])
            ->where('institution_id', $institutionId)
            ->get();

        try {
            $entries = $this->categoryValidator->validate($categories->map(fn (InstitutionUnderstandingCategory $category): array => [
                'code' => $category->code->value,
                'min_score' => $category->min_score,
                'max_score' => $category->max_score,
                'sort_order' => $category->sort_order,
            ])->all());
        } catch (InvalidArgumentException) {
            return null;
        }

        $bands = [];

        foreach ($entries as $entry) {
            $code = UnderstandingCategoryCode::from($entry['code']);

            if ($code->isNumeric()) {
                $bands[] = new CategoryBand($code, (int) $entry['min_score'], (int) $entry['max_score']);
            }
        }

        return $bands;
    }
}
