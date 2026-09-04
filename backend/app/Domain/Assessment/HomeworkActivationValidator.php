<?php

namespace App\Domain\Assessment;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use App\Exceptions\Teacher\AssessmentHasNoScoreablePointsException;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\Question;
use App\Support\Assessment\QuestionConfigurationReader;
use App\Support\Assessment\QuestionConfigurationWriter;
use Illuminate\Database\Eloquent\Collection;
use InvalidArgumentException;
use LogicException;

final class HomeworkActivationValidator
{
    public function __construct(
        private readonly QuestionPositionSetValidator $positionSetValidator,
        private readonly QuestionConfigurationValidator $configurationValidator,
        private readonly QuestionConfigurationWriter $configurationWriter,
        private readonly QuestionConfigurationReader $configurationReader,
        private readonly AssessmentPointMath $pointMath,
    ) {}

    public function validateMetadata(Assessment $assessment): AssessmentAssignmentMode
    {
        $title = $assessment->getRawOriginal('title');
        $studentInstructions = $assessment->getRawOriginal('student_instructions');
        $assignmentMode = AssessmentAssignmentMode::tryFrom((string) $assessment->getRawOriginal('assignment_mode'));

        if (! is_string($title)
            || trim($title) === ''
            || mb_strlen($title) > 255
            || ! is_string($studentInstructions)
            || trim($studentInstructions) === ''
            || mb_strlen($studentInstructions) > 10000
            || ! $assignmentMode instanceof AssessmentAssignmentMode) {
            throw new BusinessConflictException;
        }

        return $assignmentMode;
    }

    /** @param Collection<int, Question> $questions */
    public function validateQuestions(Collection $questions): string
    {
        if ($questions->isEmpty()) {
            throw new AssessmentHasNoScoreablePointsException;
        }

        if ($questions->count() > QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT) {
            throw new BusinessConflictException;
        }

        try {
            $this->positionSetValidator->validate(
                $questions->pluck('position')->all(),
                QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT,
            );
        } catch (InvalidArgumentException) {
            throw new BusinessConflictException;
        }

        $this->configurationWriter->lockAndLoadConfigurations($questions);

        $points = [];

        foreach ($questions as $question) {
            $points[] = $this->validateQuestion($question);
        }

        try {
            $total = $this->pointMath->sum($points);
        } catch (InvalidArgumentException) {
            throw new BusinessConflictException;
        }

        if ($total === '0.000000') {
            throw new AssessmentHasNoScoreablePointsException;
        }

        return $total;
    }

    private function validateQuestion(Question $question): string
    {
        $type = QuestionType::tryFrom((string) $question->getRawOriginal('type'));
        $checkingMode = QuestionCheckingMode::tryFrom((string) $question->getRawOriginal('checking_mode'));
        $prompt = $question->getRawOriginal('prompt');
        $instructions = $question->getRawOriginal('instructions');
        $rawPoints = $question->getRawOriginal('points');

        if (! $type instanceof QuestionType
            || ! $checkingMode instanceof QuestionCheckingMode
            || ! is_string($prompt)
            || ($instructions !== null
                && (! is_string($instructions)
                    || trim($instructions) === ''
                    || mb_strlen($instructions) > QuestionAuthoringLimits::MAX_INSTRUCTIONS_LENGTH))
            || (! is_int($rawPoints) && ! is_float($rawPoints) && ! is_string($rawPoints))) {
            throw new BusinessConflictException;
        }

        try {
            $this->configurationReader->assertNoIncompatibleTypedRows($question, $type, $checkingMode);
            $this->configurationReader->assertCanonicalInternalPositions($question, $type, $checkingMode);
            $configuration = $this->configurationReader->read($question, $type, $checkingMode);
            $this->configurationValidator->validate($type, $checkingMode, $prompt, $configuration);

            return AssessmentPointMath::normalize($rawPoints);
        } catch (InvalidArgumentException|LogicException) {
            throw new BusinessConflictException;
        }
    }
}
