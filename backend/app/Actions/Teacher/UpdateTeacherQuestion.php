<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\AssessmentPointMath;
use App\Domain\Assessment\QuestionConfigurationValidator;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use App\Http\Resources\Teacher\TeacherQuestionResource;
use App\Models\Assessment;
use App\Models\Question;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use App\Support\Assessment\QuestionPositionWriter;
use App\Support\Teacher\TeacherHomeworkAccess;
use App\Support\Teacher\TeacherQuestionMutationAccess;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;
use stdClass;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class UpdateTeacherQuestion
{
    public function __construct(
        private readonly TeacherHomeworkAccess $homeworkAccess,
        private readonly TeacherQuestionMutationAccess $mutationAccess,
        private readonly QuestionPositionWriter $positionWriter,
        private readonly QuestionConfigurationValidator $configurationValidator,
        private readonly QuestionConfigurationWriter $configurationWriter,
        private readonly AssessmentPointMath $pointMath,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    /** @param array<string, mixed> $attributes */
    public function __invoke(User $teacher, string $questionId, array $attributes): Assessment
    {
        $preliminaryAssessment = $this->homeworkAccess->resolveHomeworkForQuestion($teacher, $questionId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment, $questionId, $attributes): Assessment {
            $context = $this->mutationAccess->lock($teacher, $preliminaryAssessment);
            $assessment = $context['assessment'];
            $homework = $context['homework'];
            $questions = $context['questions'];
            $this->positionWriter->assertContiguous($questions);
            $question = $questions->firstWhere('id', strtolower($questionId));

            if (! $question instanceof Question) {
                throw new NotFoundHttpException;
            }

            $this->configurationWriter->lockAndLoadConfiguration($question);
            $currentConfiguration = $this->currentConfiguration($question);
            $resultingType = array_key_exists('type', $attributes)
                ? QuestionType::from($attributes['type'])
                : $question->type;
            $resultingCheckingMode = array_key_exists('checking_mode', $attributes)
                ? QuestionCheckingMode::from($attributes['checking_mode'])
                : $question->checking_mode;
            $resultingPrompt = $attributes['prompt'] ?? $question->prompt;
            $resultingInstructions = array_key_exists('instructions', $attributes)
                ? $attributes['instructions']
                : $question->instructions;
            $resultingPoints = array_key_exists('points', $attributes)
                ? AssessmentPointMath::normalize($attributes['points'])
                : $question->points;
            $typeChanged = $resultingType !== $question->type;
            $checkingModeChanged = $resultingCheckingMode !== $question->checking_mode;
            $configurationProvided = array_key_exists('configuration', $attributes);

            if (($typeChanged || $checkingModeChanged) && ! $configurationProvided) {
                throw ValidationException::withMessages([
                    'configuration' => ['A complete configuration is required when type or checking_mode changes.'],
                ]);
            }

            $resultingConfiguration = $configurationProvided
                ? $attributes['configuration']
                : $currentConfiguration;

            try {
                $this->configurationValidator->validate(
                    $resultingType,
                    $resultingCheckingMode,
                    $resultingPrompt,
                    $resultingConfiguration,
                );
            } catch (InvalidArgumentException) {
                throw ValidationException::withMessages([
                    'configuration' => ['The Question configuration is invalid.'],
                ]);
            }

            $configurationChanged = $configurationProvided
                && ($typeChanged
                    || $checkingModeChanged
                    || ! $this->sameConfiguration($resultingType, $currentConfiguration, $resultingConfiguration));
            $commonFieldsChanged = $typeChanged
                || $checkingModeChanged
                || $resultingPrompt !== $question->prompt
                || $resultingInstructions !== $question->instructions
                || $resultingPoints !== $question->points;

            if (! $commonFieldsChanged && ! $configurationChanged) {
                return ($this->showTeacherHomework)($teacher, $assessment->id);
            }

            if ($typeChanged || $checkingModeChanged || $configurationChanged) {
                $this->configurationWriter->replaceConfiguration(
                    $question,
                    $resultingType,
                    $resultingCheckingMode,
                    $resultingPrompt,
                    $resultingConfiguration,
                );
            }

            $question->forceFill([
                'type' => $resultingType,
                'prompt' => $resultingPrompt,
                'instructions' => $resultingInstructions,
                'points' => $resultingPoints,
                'checking_mode' => $resultingCheckingMode,
            ]);

            if ($question->isDirty()) {
                $question->save();
            } else {
                $question->touch();
            }

            $totalPossiblePoints = $this->pointMath->sum($questions->pluck('points')->all());
            $this->mutationAccess->ensureActiveResultIsScoreable(
                $homework,
                $questions->count(),
                $totalPossiblePoints,
            );
            $this->persistTotalAndTouch($assessment, $totalPossiblePoints);

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }

    /** @return array<string, mixed> */
    private function currentConfiguration(Question $question): array
    {
        $configuration = (new TeacherQuestionResource($question))->resolve()['configuration'];

        return $configuration instanceof stdClass ? [] : $configuration;
    }

    /** @param array<string, mixed> $current @param array<string, mixed> $resulting */
    private function sameConfiguration(QuestionType $type, array $current, array $resulting): bool
    {
        $current = $this->configurationMeaning($type, $current);
        $resulting = $this->configurationMeaning($type, $resulting);

        return $this->canonicalize($current) === $this->canonicalize($resulting);
    }

    /** @param array<string, mixed> $configuration @return array<string, mixed> */
    private function configurationMeaning(QuestionType $type, array $configuration): array
    {
        return match ($type) {
            QuestionType::SingleChoice,
            QuestionType::MultipleChoice => $this->orderConfigurationList($configuration, 'options', 'position'),
            QuestionType::Ordering => $this->orderConfigurationList($configuration, 'items', 'correct_position'),
            QuestionType::FillInBlank => $this->orderConfigurationList($configuration, 'blanks', 'position'),
            QuestionType::Matching => $this->matchingMeaning($configuration),
            default => $configuration,
        };
    }

    /**
     * @param  array<string, mixed>  $configuration
     * @return array<string, mixed>
     */
    private function orderConfigurationList(
        array $configuration,
        string $listKey,
        string $positionKey,
    ): array {
        usort(
            $configuration[$listKey],
            static fn (array $left, array $right): int => $left[$positionKey] <=> $right[$positionKey],
        );

        return $configuration;
    }

    /** @param array<string, mixed> $configuration @return array<string, mixed> */
    private function matchingMeaning(array $configuration): array
    {
        $pairs = $configuration['pairs'] ?? [];

        foreach ($pairs as &$pair) {
            unset($pair['client_key']);
        }
        unset($pair);

        return ['pairs' => $pairs];
    }

    private function canonicalize(mixed $value): mixed
    {
        if (! is_array($value)) {
            return $value;
        }

        if (array_is_list($value)) {
            return array_map(fn (mixed $item): mixed => $this->canonicalize($item), $value);
        }

        ksort($value);

        return array_map(fn (mixed $item): mixed => $this->canonicalize($item), $value);
    }

    private function persistTotalAndTouch(Assessment $assessment, string $totalPossiblePoints): void
    {
        $assessment->total_possible_points = $totalPossiblePoints;

        if ($assessment->isDirty()) {
            $assessment->save();

            return;
        }

        $assessment->touch();
    }
}
