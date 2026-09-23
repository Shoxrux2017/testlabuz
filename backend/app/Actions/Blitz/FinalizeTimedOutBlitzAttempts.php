<?php

namespace App\Actions\Blitz;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Support\Assessment\BlitzAttemptFinalizer;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;

final class FinalizeTimedOutBlitzAttempts
{
    public function __construct(private readonly BlitzAttemptFinalizer $finalizer) {}

    /**
     * $dueAt is the instant a final read snapshot observed due Attempts; deciding no earlier keeps
     * database-clock reads and app-clock reconciliation consistent.
     */
    public function __invoke(string $institutionId, string $assessmentId, ?CarbonInterface $dueAt = null): int
    {
        return DB::transaction(function () use ($institutionId, $assessmentId, $dueAt): int {
            $assessment = Assessment::query()
                ->where('institution_id', $institutionId)
                ->whereKey($assessmentId)
                ->where('type', AssessmentType::Blitz->value)
                ->lockForUpdate()
                ->first();

            if ($assessment === null) {
                return 0;
            }

            $blitz = BlitzTask::query()
                ->where('institution_id', $institutionId)
                ->where('assessment_id', $assessment->id)
                ->lockForUpdate()
                ->first();
            $observedAt = now();
            if ($dueAt !== null && $dueAt->gt($observedAt)) {
                $observedAt = $dueAt;
            }

            if ($blitz === null || $blitz->status !== BlitzStatus::Active) {
                return 0;
            }

            $attempts = AssessmentAttempt::query()
                ->where('institution_id', $institutionId)
                ->where('assessment_id', $assessment->id)
                ->where('status', AssessmentAttemptStatus::InProgress->value)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();
            $finalized = 0;

            foreach ($attempts as $attempt) {
                $this->finalizer->assertValidAttempt($attempt, $institutionId, $assessment->id);

                if ($observedAt->gte($attempt->deadline_at) && $this->finalizer->finalizeAtTimeout($attempt)) {
                    $finalized++;
                }
            }

            return $finalized;
        });
    }
}
