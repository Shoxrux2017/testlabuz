<?php

namespace Tests\Feature\Results;

use App\Enums\ParentResultReleaseMode as ParentMode;
use App\Enums\StudentResultReleaseMode as StudentMode;
use App\Enums\TopicResultSideState;
use App\Enums\TopicResultStatus;
use App\Models\TopicResult;
use App\Models\User;
use App\Support\Results\TopicResultSideView;
use App\Support\Results\TopicResultView;
use App\Support\Results\TopicResultVisibility;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class TopicResultVisibilityTest extends TestCase
{
    /**
     * @return array<string, array{array<string, mixed>, ?StudentMode, ?ParentMode, array{bool, bool, bool, bool}}>
     */
    public static function cases(): array
    {
        $calculated = ['status' => TopicResultStatus::Calculated, 'terminal' => true, 'finished' => true];

        return [
            'automatic, finished work: both see' => [$calculated, StudentMode::Automatic, ParentMode::WithStudent, [true, true, false, false]],
            'automatic, work not finished: nobody sees' => [['finished' => false] + $calculated, StudentMode::Automatic, ParentMode::WithStudent, [false, false, false, false]],
            'automatic, waiting result: nobody sees' => [['status' => TopicResultStatus::WaitingForTeacherReview, 'terminal' => false] + $calculated, StudentMode::Automatic, ParentMode::WithStudent, [false, false, false, false]],
            'not completed counts as an outcome' => [['status' => TopicResultStatus::NotCompleted] + $calculated, StudentMode::Automatic, ParentMode::WithStudent, [true, true, false, false]],
            'closed counts as an outcome' => [['status' => TopicResultStatus::Closed, 'terminal' => false] + $calculated, StudentMode::Automatic, ParentMode::WithStudent, [true, true, false, false]],
            'manual, unreleased: release possible' => [$calculated, StudentMode::ManualTeacher, ParentMode::WithStudent, [false, false, true, false]],
            'manual, unreleased, unfinished: no release' => [['finished' => false] + $calculated, StudentMode::ManualTeacher, ParentMode::WithStudent, [false, false, false, false]],
            'manual, released: both see' => [['studentReleased' => true] + $calculated, StudentMode::ManualTeacher, ParentMode::WithStudent, [true, true, false, false]],
            'manual released but work reopened: hidden' => [['studentReleased' => true, 'finished' => false] + $calculated, StudentMode::ManualTeacher, ParentMode::WithStudent, [false, false, false, false]],
            'parent manual, unreleased: parent release possible' => [$calculated, StudentMode::Automatic, ParentMode::ManualTeacher, [true, false, false, true]],
            'parent manual, released: parent sees' => [['parentReleased' => true] + $calculated, StudentMode::Automatic, ParentMode::ManualTeacher, [true, true, false, false]],
            'parent manual, student cannot see: no parent release' => [$calculated, StudentMode::ManualTeacher, ParentMode::ManualTeacher, [false, false, true, false]],
            'parent hidden: parent never sees' => [['parentReleased' => true] + $calculated, StudentMode::Automatic, ParentMode::Hidden, [true, false, false, false]],
            'parent released but the student cannot see: hidden from the parent' => [['parentReleased' => true] + $calculated, StudentMode::ManualTeacher, ParentMode::ManualTeacher, [false, false, true, false]],
            'parent mode unconfigured while the student sees: parent sees nothing' => [$calculated, StudentMode::Automatic, null, [true, false, false, false]],
            'unconfigured modes: nothing' => [$calculated, null, null, [false, false, false, false]],
        ];
    }

    /** @param array<string, mixed> $view */
    #[DataProvider('cases')]
    public function test_visibility_and_release_flags(array $view, ?StudentMode $studentMode, ?ParentMode $parentMode, array $expected): void
    {
        $state = app(TopicResultVisibility::class)->of($this->resultView($view), $studentMode, $parentMode);

        $this->assertSame($expected, [$state->studentVisible, $state->parentVisible, $state->canReleaseToStudent, $state->canReleaseToParent]);
    }

    /** @param array<string, mixed> $attributes */
    private function resultView(array $attributes): TopicResultView
    {
        $row = (new TopicResult)->forceFill([
            'student_released_at' => ($attributes['studentReleased'] ?? false) ? now() : null,
            'parent_released_at' => ($attributes['parentReleased'] ?? false) ? now() : null,
        ]);
        $side = new TopicResultSideView(TopicResultSideState::Ready, fake()->uuid());

        return new TopicResultView(
            student: (new User)->forceFill(['id' => fake()->uuid(), 'full_name' => 'Student']),
            status: $attributes['status'],
            closedOutcome: null,
            missingComponent: null,
            homework: $side,
            blitz: $side,
            difference: null,
            threshold: null,
            method: null,
            consistency: null,
            finalScore: null,
            categoryScore: null,
            category: null,
            categoryMinScore: null,
            categoryMaxScore: null,
            terminal: $attributes['terminal'],
            workFinished: $attributes['finished'],
            closable: false,
            row: $row,
        );
    }
}
