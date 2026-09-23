<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\AssessmentActivationValidator;
use App\Enums\BlitzStatus;
use App\Enums\BlitzTimerStartMode;
use App\Enums\GroupStatus;
use App\Enums\IdempotencyOperation;
use App\Enums\TopicStatus;
use App\Exceptions\InstitutionSettingsIncompleteException;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskClosedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\IdempotencyRecord;
use App\Models\User;
use App\Support\Idempotency\IdempotencyGuard;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use App\Support\Teacher\TeacherBlitzLifecycleAccess;
use App\Support\Teacher\TeacherOfficialAssessmentCohort;
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

            $lockedCohort = $this->cohort->lock($teacher, $group, $assessment, $assignmentMode, $pair);
            $questions = $this->access->lockQuestions($teacher, $assessment);
            $totalPossiblePoints = $this->activationValidator->validateQuestions($questions);
            $preparedCohort = $this->cohort->validate($teacher, $assessment, $assignmentMode, $lockedCohort);

            // Capture the timer instant only after all locks and validation, truncating rather than rounding.
            $activatedAt = now()->utc()->startOfSecond();
            $this->cohort->apply($teacher, $assessment, $activatedAt, $preparedCohort);

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
