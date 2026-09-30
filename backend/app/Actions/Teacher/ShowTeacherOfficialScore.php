<?php

namespace App\Actions\Teacher;

use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\Topic;
use App\Models\User;
use App\Support\Checking\OfficialScoreReader;
use App\Support\Checking\OfficialScoreReading;
use App\Support\Student\StudentBlitzReadSnapshot;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * One Student's official score for one Homework or Blitz (docs/09 §24.1): a task in a Topic
 * visible to the Teacher and a persisted recipient of it. Topic and task status never restrict
 * the read.
 */
final class ShowTeacherOfficialScore
{
    public function __construct(
        private readonly OfficialScoreReader $reader,
        private readonly StudentBlitzReadSnapshot $snapshots,
    ) {}

    public function __invoke(User $teacher, string $assessmentId, string $studentId): OfficialScoreReading
    {
        if (! Str::isUuid($assessmentId) || ! Str::isUuid($studentId)) {
            throw new NotFoundHttpException;
        }

        // One snapshot: a Blitz evaluation reads the Attempts and the exception in separate
        // statements, and a grant or replacement start committed between them breaks the graph.
        return $this->snapshots->read(fn (): OfficialScoreReading => $this->read($teacher, $assessmentId, $studentId));
    }

    private function read(User $teacher, string $assessmentId, string $studentId): OfficialScoreReading
    {
        $assessment = Assessment::query()
            ->select(['id', 'institution_id', 'topic_id', 'type'])
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($assessmentId)
            ->whereIn('topic_id', Topic::query()->select('topics.id')->visibleToTeacher($teacher))
            ->first() ?? throw new NotFoundHttpException;
        $recipient = AssessmentStudent::query()
            ->select(['id', 'institution_id', 'assessment_id', 'student_id'])
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->where('student_id', $studentId)
            ->first() ?? throw new NotFoundHttpException;

        return $this->reader->read($assessment, $recipient);
    }
}
