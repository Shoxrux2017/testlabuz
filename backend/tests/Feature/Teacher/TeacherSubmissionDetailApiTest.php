<?php

namespace Tests\Feature\Teacher;

use App\Actions\Checking\CheckFrozenAttempt;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class TeacherSubmissionDetailApiTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext;
    use RefreshDatabase;

    private const TYPES = ['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written',
        'matching', 'ordering', 'fill_in_blank', 'file_based'];

    private User $student;

    private HomeworkAssignment $homework;

    private AssessmentAttempt $attempt;

    private User $teacher;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        Storage::fake('local');
        [$this->student, $this->homework, $this->attempt] = $this->answerContext();
        $this->teacher = $this->homework->assessment->teacher;
        $this->teacher->update(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $this->teacher->institution_id, 'group_id' => $this->homework->assessment->topic->group_id,
            'teacher_id' => $this->teacher->id, 'assigned_by_user_id' => $this->teacher->id,
        ]);
    }

    public function test_a_submission_shows_every_question_with_its_configuration_and_the_students_answer(): void
    {
        $questions = [];
        $values = [];
        // Created against position order, so the response order proves the sort.
        foreach (self::TYPES as $index => $type) {
            $questions[$type] = $this->answerQuestion($this->homework, $type, count(self::TYPES) - $index);
            if ($type === 'fill_in_blank') {
                // The Teacher configuration requires one prompt placeholder per blank.
                $questions[$type]->update(['prompt' => 'Complete '.QuestionFillBlank::query()->where('question_id', $questions[$type]->id)
                    ->orderBy('position')->pluck('blank_key')->map(fn (string $key): string => '{{'.$key.'}}')->implode(' and ').'.']);
            }
            if ($type !== 'file_based') {
                $values[$type] = $this->answerRequest($this->student, $this->attempt, $questions[$type],
                    $this->answerPayload($questions[$type]))->assertOk()->json('data.answer');
            }
        }
        [, , $file] = $this->savedFileAnswer($this->attempt, $questions['file_based']);
        $unanswered = $this->answerQuestion($this->homework, 'single_choice', 10);
        $this->freezeAndCheck();
        $reviewed = AttemptAnswer::query()->where('question_id', $questions['open_written']->id)->sole();
        DB::table('attempt_answers')->where('id', $reviewed->id)->update([
            'checking_status' => 'teacher_checked', 'awarded_points' => '0.50000000', 'feedback' => 'Clear reasoning.',
            'checked_by_user_id' => $this->teacher->id, 'checked_at' => now()->addMinute(),
        ]);
        $configurations = collect($this->teacherRequest('/api/v1/teacher/homework/'.$this->homework->assessment_id)
            ->assertOk()->json('data.questions'))->pluck('configuration', 'id');

        $data = $this->detail($this->attempt->id)->assertOk()->json('data');

        $this->assertSame(['id', 'assessment', 'official', 'topic', 'group', 'student', 'attempt_number', 'status',
            'official_score_eligible', 'finalization_reason', 'finalized_at', 'review', 'review_due_at', 'review_overdue',
            'score', 'submitted_at', 'questions'], array_keys($data));
        $this->assertSame('2026-09-30T10:00:00Z', $data['submitted_at']);
        $this->assertSame('waiting_for_teacher_review', $data['status']);
        $this->assertSame(['waiting_answers' => 1, 'reviewed_answers' => 1], $data['review']);
        $this->assertSame([...array_reverse(array_map(fn ($question): string => $question->id, array_values($questions))), $unanswered->id],
            array_column(array_column($data['questions'], 'question'), 'id'));
        foreach ($data['questions'] as $item) {
            $question = $item['question'];
            $this->assertSame(['id', 'type', 'position', 'prompt', 'points', 'checking_mode', 'configuration'], array_keys($question));
            // The Teacher authoring configuration plus the ids that answers refer to.
            $this->assertEquals($configurations[$question['id']], $this->withoutRowIds($question['configuration']));
            $this->assertConfigurationRowIds($question['id'], $question['type'], $question['configuration']);
            if ($item['answer'] !== null && $question['type'] !== 'file_based') {
                $this->assertAnswerRefersToConfiguration($question['type'], $item['answer']['value'], $question['configuration']);
            }
        }
        foreach ($values as $type => $value) {
            $this->assertSame($value, collect($data['questions'])->firstWhere('question.id', $questions[$type]->id)['answer']['value'], $type);
        }
        $fileAnswer = collect($data['questions'])->firstWhere('question.id', $questions['file_based']->id)['answer'];
        $this->assertSame(['file' => ['id' => $file->id, 'original_name' => $file->original_name, 'extension' => 'pdf',
            'size_bytes' => $file->size_bytes]], $fileAnswer['value']);
        $this->assertSame(['checking_status' => 'waiting_for_teacher_review', 'awarded_points' => null, 'feedback' => null,
            'checked_by' => null, 'checked_at' => null], array_diff_key($fileAnswer, ['id' => true, 'value' => true]));
        $this->assertSame([
            'id' => $reviewed->id, 'value' => $values['open_written'], 'checking_status' => 'teacher_checked',
            'awarded_points' => 0.5, 'feedback' => 'Clear reasoning.',
            'checked_by' => ['id' => $this->teacher->id, 'full_name' => $this->teacher->full_name],
            'checked_at' => '2026-09-30T10:01:00Z',
        ], collect($data['questions'])->firstWhere('question.id', $questions['open_written']->id)['answer']);
        $automatic = collect($data['questions'])->firstWhere('question.id', $questions['true_false']->id)['answer'];
        $this->assertSame(['auto_checked', null, '2026-09-30T10:00:00Z'],
            [$automatic['checking_status'], $automatic['checked_by'], $automatic['checked_at']]);
        // The saved `true` matches the true/false key worth 1 point.
        $this->assertEquals(1, $automatic['awarded_points']);
        $this->assertNull(collect($data['questions'])->firstWhere('question.id', $unanswered->id)['answer']);
    }

    public function test_a_submission_awaiting_automatic_checking_shows_its_pending_answers(): void
    {
        $question = $this->answerQuestion($this->homework, 'true_false');
        $this->answerRequest($this->student, $this->attempt, $question, ['type' => 'true_false', 'value' => true])->assertOk();
        $this->freeze();

        $data = $this->detail($this->attempt->id)->assertOk()->json('data');

        $this->assertSame('submitted', $data['status']);
        $this->assertSame(['value' => true], $data['questions'][0]['answer']['value']);
        $this->assertSame(['pending', null, null], [$data['questions'][0]['answer']['checking_status'],
            $data['questions'][0]['answer']['awarded_points'], $data['questions'][0]['answer']['checked_at']]);
    }

    public function test_work_outside_the_review_rule_is_not_found(): void
    {
        $this->answerQuestion($this->homework, 'true_false');
        $inProgress = $this->attempt->id;
        $otherTeacher = User::factory()->teacher($this->teacher->institution)->create(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $this->teacher->institution_id, 'group_id' => $this->homework->assessment->topic->group_id,
            'teacher_id' => $otherTeacher->id, 'assigned_by_user_id' => $this->teacher->id,
        ]);

        foreach (['not-a-uuid', (string) Str::uuid(), $inProgress] as $id) {
            $this->detail($id)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $this->freeze();
        $this->detail($this->attempt->id)->assertOk();
        $this->detail($this->attempt->id, $otherTeacher)->assertNotFound();
        $foreignTeacher = User::factory()->teacher(Institution::factory()->create())->create(['must_change_password' => false]);
        $this->detail($this->attempt->id, $foreignTeacher)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        GroupTeacherMembership::query()->where('teacher_id', $this->teacher->id)->update(['ended_at' => now()]);
        $this->detail($this->attempt->id)->assertNotFound();
    }

    /** @return array<string, array{string, string}> */
    public static function strictRequests(): array
    {
        return ['query parameter' => ['?include=answers', ''], 'request body' => ['', '{}']];
    }

    #[DataProvider('strictRequests')]
    public function test_the_detail_request_takes_no_query_or_body(string $query, string $body): void
    {
        $this->freeze();

        $this->teacherRequest('/api/v1/teacher/submissions/'.$this->attempt->id.$query, $this->teacher, $body)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    private function freeze(): void
    {
        DB::table('assessment_attempts')->where('id', $this->attempt->id)->update([
            'status' => 'submitted', 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit',
        ]);
    }

    private function freezeAndCheck(): void
    {
        $this->freeze();
        $this->assertTrue(app(CheckFrozenAttempt::class)($this->attempt->id));
    }

    private function detail(string $id, ?User $teacher = null): TestResponse
    {
        return $this->teacherRequest('/api/v1/teacher/submissions/'.$id, $teacher ?? $this->teacher);
    }

    private function teacherRequest(string $uri, ?User $teacher = null, string $body = ''): TestResponse
    {
        return $this->answerHttp($teacher ?? $this->teacher, 'GET', $uri, $body);
    }

    /** @param array<string, mixed> $configuration */
    private function assertAnswerRefersToConfiguration(string $type, array $value, array $configuration): void
    {
        [$references, $ids] = match ($type) {
            'single_choice', 'multiple_choice' => [$value['selected_option_ids'], array_column($configuration['options'], 'id')],
            'matching' => [array_merge(array_column($value['pairs'], 'left_item_id'), array_column($value['pairs'], 'right_item_id')),
                array_merge(array_column($configuration['pairs'], 'left_item_id'), array_column($configuration['pairs'], 'right_item_id'))],
            'ordering' => [array_column($value['items'], 'item_id'), array_column($configuration['items'], 'id')],
            'fill_in_blank' => [array_column($value['values'], 'blank_id'), array_column($configuration['blanks'], 'id')],
            default => [[], []],
        };
        $this->assertSame([], array_values(array_diff($references, $ids)), $type);
        $this->assertSame(count($ids), count(array_unique($ids)), $type);
    }

    /**
     * Each configuration row carries the id of the persisted row with the same position, correct
     * position, blank key or matching key and side.
     *
     * @param  array<string, mixed>  $configuration
     */
    private function assertConfigurationRowIds(string $questionId, string $type, array $configuration): void
    {
        foreach (match ($type) {
            'single_choice', 'multiple_choice' => array_map(fn (array $option): array => [$option['id'],
                QuestionChoiceOption::query()->where('question_id', $questionId)->where('position', $option['position'])->sole()->id],
                $configuration['options']),
            'ordering' => array_map(fn (array $item): array => [$item['id'],
                QuestionOrderingItem::query()->where('question_id', $questionId)->where('correct_position', $item['correct_position'])->sole()->id],
                $configuration['items']),
            'fill_in_blank' => array_map(fn (array $blank): array => [$blank['id'],
                QuestionFillBlank::query()->where('question_id', $questionId)->where('blank_key', $blank['key'])->sole()->id],
                $configuration['blanks']),
            'matching' => array_merge(...array_map(fn (array $pair): array => [
                [$pair['left_item_id'], QuestionMatchingItem::query()->where('question_id', $questionId)
                    ->where('match_key', $pair['client_key'])->where('side', 'left')->sole()->id],
                [$pair['right_item_id'], QuestionMatchingItem::query()->where('question_id', $questionId)
                    ->where('match_key', $pair['client_key'])->where('side', 'right')->sole()->id],
            ], $configuration['pairs'])),
            default => [],
        } as [$actual, $expected]) {
            $this->assertSame($expected, $actual, $type);
        }
    }

    private function withoutRowIds(mixed $configuration): mixed
    {
        if (! is_array($configuration)) {
            return $configuration;
        }

        return array_map(fn (mixed $rows): mixed => is_array($rows) && array_is_list($rows)
            ? array_map(fn (mixed $row): mixed => is_array($row)
                ? array_diff_key($row, ['id' => true, 'left_item_id' => true, 'right_item_id' => true]) : $row, $rows)
            : $rows, $configuration);
    }
}
