<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Support\Student\StudentResultVisibility;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentResultVisibilityTest extends TestCase
{
    /** @return array<string, array{BlitzStatus, bool}> */
    public static function blitzStatuses(): array
    {
        return [
            'active blitz' => [BlitzStatus::Active, false],
            'closed blitz' => [BlitzStatus::Closed, true],
            'archived blitz' => [BlitzStatus::Archived, true],
        ];
    }

    #[DataProvider('blitzStatuses')]
    public function test_a_blitz_attempt_result_is_visible_only_once_the_blitz_is_closed_or_archived(BlitzStatus $status, bool $visible): void
    {
        $task = $this->task(AssessmentType::Blitz, $status);

        $this->assertSame($visible, app(StudentResultVisibility::class)->visible($this->checkedAttempt($task), $task, true));
    }

    public function test_a_homework_attempt_result_needs_no_task_status(): void
    {
        $task = $this->task(AssessmentType::Homework);

        $this->assertTrue(app(StudentResultVisibility::class)->visible($this->checkedAttempt($task), $task, true));
    }

    public function test_nothing_is_visible_without_release(): void
    {
        $task = $this->task(AssessmentType::Blitz, BlitzStatus::Closed);

        $this->assertFalse(app(StudentResultVisibility::class)->visible($this->checkedAttempt($task), $task, false));
    }

    public function test_the_task_type_must_be_known(): void
    {
        $task = (new Assessment)->forceFill(['id' => fake()->uuid()]);

        $this->expectException(LogicException::class);
        app(StudentResultVisibility::class)->visible($this->checkedAttempt($task), $task, true);
    }

    public function test_the_attempt_must_belong_to_the_task(): void
    {
        $task = $this->task(AssessmentType::Homework);

        $this->expectException(LogicException::class);
        app(StudentResultVisibility::class)->visible($this->checkedAttempt($this->task(AssessmentType::Homework)), $task, true);
    }

    private function task(AssessmentType $type, ?BlitzStatus $status = null): Assessment
    {
        $task = (new Assessment)->forceFill(['id' => fake()->uuid(), 'type' => $type]);

        if ($status !== null) {
            $task->setRelation('blitzTask', (new BlitzTask)->forceFill(['assessment_id' => $task->id, 'status' => $status]));
        }

        return $task;
    }

    private function checkedAttempt(Assessment $task): AssessmentAttempt
    {
        return (new AssessmentAttempt)->forceFill([
            'assessment_id' => $task->id,
            'status' => AssessmentAttemptStatus::Checked,
            'official_score_eligible' => true,
            'normalized_score' => '75.00000000',
        ]);
    }
}
