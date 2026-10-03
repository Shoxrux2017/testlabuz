<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\AssessmentActivationValidator;
use App\Enums\BlitzStatus;
use App\Enums\BlitzTimerStartMode;
use App\Enums\GroupStatus;
use App\Enums\HomeworkStatus;
use App\Enums\IdempotencyOperation;
use App\Enums\TopicStatus;
use App\Exceptions\InstitutionSettingsIncompleteException;
use App\Exceptions\OfficialHomeworkNotActivatedException;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskClosedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Assessment\LockedHomeworkCloser;
use App\Support\Idempotency\IdempotencyGuard;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use App\Support\Teacher\TeacherBlitzLifecycleAccess;
use App\Support\Teacher\TeacherOfficialAssessmentCohort;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use LogicException;

final class ActivateTeacherBlitz
{
    public function __construct(
        private readonly TeacherBlitzLifecycleAccess $access,
        private readonly AssessmentActivationValidator $activationValidator,
        private readonly TeacherOfficialAssessmentCohort $cohort,
        private readonly IdempotencyRequestFingerprint $fingerprints,
        private readonly IdempotencyGuard $idempotency,
        private readonly ShowTeacherBlitz $showTeacherBlitz,
        private readonly LockedHomeworkCloser $homeworkCloser,
    ) {}

    public function __invoke(User $teacher, string $blitzId, string $idempotencyKey): Assessment
    {
        $authorizedBlitz = $this->access->resolveBlitz($teacher, $blitzId);
        $operation = IdempotencyOperation::TeacherBlitzActivate;
        $fingerprint = $this->fingerprints->make($teacher, $operation, ['blitz_id' => strtolower($authorizedBlitz->id)]);

        return DB::transaction(function () use ($teacher, $authorizedBlitz, $operation, $idempotencyKey, $fingerprint): Assessment {
            ['group' => $group, 'topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] =
                $this->access->lockBlitz($teacher, $authorizedBlitz);

            $replay = $this->idempotency->completedReplay($teacher, $operation, $idempotencyKey, $fingerprint);

            if ($replay !== null) {
                return $this->replay($teacher, $assessment, $blitz, $replay);
            }

            $claim = $this->idempotency->claim($teacher, $operation, $idempotencyKey, $fingerprint);

            if (! $claim->new) {
                return $this->replay($teacher, $assessment, $blitz, $claim->record);
            }

            if ($blitz->status === BlitzStatus::Active) {
                $this->idempotency->complete($claim, 'blitz', $assessment->id, 200);

                return ($this->showTeacherBlitz)($teacher, $assessment->id);
            }

            if ($blitz->status === BlitzStatus::Closed) {
                throw new TaskClosedException;
            }

            if ($blitz->status === BlitzStatus::Archived) {
                throw new TaskArchivedException;
            }

            if ($topic->status !== TopicStatus::Active || $group->status !== GroupStatus::Active) {
                throw new TopicNotEditableException;
            }

            $assignmentMode = $this->activationValidator->validateMetadata($assessment);
            $pair = $this->access->lockResultPair($teacher, $topic, $assessment);
            $settings = $this->access->lockSettings($teacher);
            $timerMode = $settings?->blitz_timer_start_mode;

            if ($timerMode === null) {
                throw new InstitutionSettingsIncompleteException(['blitz_timer_start_mode']);
            }

            $this->assertOfficialHomeworkActivated($teacher, $pair);
            $lockedCohort = $this->cohort->lock($teacher, $group, $assessment, $assignmentMode, $pair);
            $questions = $this->access->lockQuestions($teacher, $assessment);
            $totalPossiblePoints = $this->activationValidator->validateQuestions($questions);
            $preparedCohort = $this->cohort->validate($teacher, $assessment, $assignmentMode, $lockedCohort);

            // Capture the instant only after all locks and validation; the timer truncates it rather than rounding.
            $closedAt = now();
            $activatedAt = $closedAt->copy()->utc()->startOfSecond();
            $this->cohort->apply($teacher, $assessment, $activatedAt, $preparedCohort);
            $this->closeOfficialHomework($teacher, $pair, $preparedCohort['attempts'], $closedAt);

            $assessment->total_possible_points = $totalPossiblePoints;
            $assessment->updated_at = $activatedAt;
            $assessment->save();

            $blitz->status = BlitzStatus::Active;
            $blitz->activated_at = $activatedAt;
            $blitz->activated_by_user_id = $teacher->id;
            $blitz->timer_start_mode_snapshot = $timerMode;
            $blitz->synchronized_ends_at = $timerMode === BlitzTimerStartMode::Synchronized
                ? $activatedAt->copy()->addSeconds($blitz->duration_seconds)
                : null;
            $blitz->closed_at = null;
            $blitz->archived_at = null;
            $blitz->updated_at = $activatedAt;
            $blitz->save();

            $this->idempotency->complete($claim, 'blitz', $assessment->id, 200);

            return ($this->showTeacherBlitz)($teacher, $assessment->id);
        });
    }

    /**
     * The official Homework comes before the official Blitz (S10-D8). The status is read without a
     * row lock: every Homework lifecycle change takes the Topic, which this activation holds.
     */
    private function assertOfficialHomeworkActivated(User $teacher, ?TopicResultPair $pair): void
    {
        if ($pair === null) {
            return;
        }

        $status = HomeworkAssignment::query()
            ->select(['assessment_id', 'institution_id', 'status'])
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $pair->homework_assessment_id)
            ->first()?->status;

        if ($status === HomeworkStatus::Draft) {
            throw new OfficialHomeworkNotActivatedException;
        }
    }

    /**
     * Activating the official Blitz closes the active official Homework like a Teacher close
     * (S10-D8, docs/09 §19.1). The cohort step already holds the Homework Assessment, its row and
     * every official Attempt FOR UPDATE, so selecting them again takes no new lock.
     *
     * @param  Collection<int, AssessmentAttempt>  $officialAttempts
     */
    private function closeOfficialHomework(User $teacher, ?TopicResultPair $pair, Collection $officialAttempts, CarbonInterface $closedAt): void
    {
        if ($pair === null) {
            return;
        }

        $homeworkAssessment = Assessment::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($pair->homework_assessment_id)
            ->lockForUpdate()
            ->firstOrFail();
        $homework = HomeworkAssignment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $homeworkAssessment->id)
            ->lockForUpdate()
            ->firstOrFail();

        if ($homework->status !== HomeworkStatus::Active) {
            return;
        }

        $this->homeworkCloser->close(
            $homeworkAssessment,
            $homework,
            $officialAttempts->where('assessment_id', $homeworkAssessment->id)->values(),
            $closedAt,
        );
    }

    private function replay(User $teacher, Assessment $assessment, BlitzTask $blitz, IdempotencyRecord $record): Assessment
    {
        if (! in_array($blitz->status, [BlitzStatus::Active, BlitzStatus::Closed, BlitzStatus::Archived], true)
            || $blitz->activated_at === null
            || $blitz->activated_by_user_id === null
            || $blitz->timer_start_mode_snapshot === null) {
            throw new LogicException('Completed Blitz activation requires persisted activation history.');
        }

        if ($record->result_resource_type !== 'blitz'
            || $record->result_resource_id !== $assessment->id
            || $record->response_status !== 200) {
            throw new LogicException('Completed Blitz activation must reference its authorized Blitz and successful response.');
        }

        return ($this->showTeacherBlitz)($teacher, $assessment->id);
    }
}
