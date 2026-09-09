<?php

namespace Tests\Feature\Student\Concerns;

use App\Enums\QuestionType;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionFillBlankAcceptedAnswer;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\QuestionShortAcceptedAnswer;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;

trait BuildsStudentHomeworkAnswerContext
{
    protected function answerContext(): array
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        $topic = Topic::factory()->active()->create(['institution_id' => $institution->id]);
        $assessment = Assessment::factory()->homework()->create([
            'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $topic->teacher_id,
            'total_possible_points' => '8.000000',
        ]);
        $homework = HomeworkAssignment::factory()->active()->create([
            'assessment_id' => $assessment->id, 'deadline_at' => now()->addDay(),
        ]);
        $recipient = AssessmentStudent::factory()->create([
            'assessment_id' => $assessment->id, 'student_id' => $student->id,
            'assigned_by_user_id' => $assessment->teacher_id,
        ]);
        $attempt = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id, 'possible_points' => '8.000000']);

        return [$student, $homework, $attempt->fresh()];
    }

    protected function answerQuestion(HomeworkAssignment $homework, string $type, int $position = 1): Question
    {
        $state = match ($type) {
            'single_choice' => 'singleChoice', 'multiple_choice' => 'multipleChoice',
            'true_false' => 'trueFalse', 'short_written' => 'shortWrittenAutomatic',
            'open_written' => 'openWritten', 'matching' => 'matching', 'ordering' => 'ordering',
            'fill_in_blank' => 'fillInBlank', 'file_based' => 'fileBased',
        };
        $question = Question::factory()->{$state}()->create([
            'institution_id' => $homework->institution_id, 'assessment_id' => $homework->assessment_id,
            'position' => $position,
        ]);
        if (in_array($question->type, [QuestionType::SingleChoice, QuestionType::MultipleChoice], true)) {
            foreach (range(1, 4) as $optionPosition) {
                QuestionChoiceOption::factory()->create([
                    'question_id' => $question->id, 'position' => $optionPosition,
                    'is_correct' => $optionPosition <= ($type === 'multiple_choice' ? 2 : 1),
                ]);
            }
        } elseif ($type === 'true_false') {
            QuestionTrueFalseAnswer::factory()->create(['question_id' => $question->id, 'correct_value' => true]);
        } elseif ($type === 'short_written') {
            QuestionShortAcceptedAnswer::factory()->create(['question_id' => $question->id, 'accepted_text' => 'private-short-answer-6187']);
        } elseif ($type === 'matching') {
            foreach (range(1, 3) as $itemPosition) {
                $matchKey = (string) Str::uuid();
                foreach (['left', 'right'] as $side) {
                    QuestionMatchingItem::factory()->{$side}()->create([
                        'question_id' => $question->id, 'position' => $itemPosition, 'match_key' => $matchKey,
                    ]);
                }
            }
        } elseif ($type === 'ordering') {
            foreach (range(1, 5) as $itemPosition) {
                QuestionOrderingItem::factory()->create(['question_id' => $question->id, 'correct_position' => $itemPosition]);
            }
        } elseif ($type === 'fill_in_blank') {
            foreach (range(1, 3) as $blankPosition) {
                $blank = QuestionFillBlank::factory()->create(['question_id' => $question->id, 'position' => $blankPosition]);
                QuestionFillBlankAcceptedAnswer::factory()->create(['blank_id' => $blank->id, 'accepted_text' => 'private-fill-answer-8126']);
            }
        }

        return $question;
    }

    protected function answerPayload(Question $question, bool $replacement = false): array
    {
        $type = $question->type->value;
        if (in_array($type, ['single_choice', 'multiple_choice'], true)) {
            $ids = QuestionChoiceOption::query()->where('question_id', $question->id)->orderBy('position')->pluck('id')->all();
            $answer = ['selected_option_ids' => $type === 'single_choice'
                ? [$ids[$replacement ? 2 : 0]] : ($replacement ? [$ids[3]] : [$ids[2], $ids[0]])];
        } elseif ($type === 'true_false') {
            $answer = ['value' => ! $replacement];
        } elseif (in_array($type, ['short_written', 'open_written'], true)) {
            $answer = ['text' => $replacement ? "  DNS changed\t " : "  DNS\u{00A0}  "];
        } elseif ($type === 'matching') {
            $left = QuestionMatchingItem::query()->where('question_id', $question->id)->where('side', 'left')->orderBy('id')->pluck('id')->all();
            $right = QuestionMatchingItem::query()->where('question_id', $question->id)->where('side', 'right')->orderBy('id')->pluck('id')->all();
            $answer = ['pairs' => $replacement
                ? [['left_item_id' => $left[2], 'right_item_id' => $right[0]]]
                : [['left_item_id' => $left[1], 'right_item_id' => $right[2]], ['left_item_id' => $left[0], 'right_item_id' => $right[1]]]];
        } elseif ($type === 'ordering') {
            $ids = QuestionOrderingItem::query()->where('question_id', $question->id)->orderBy('id')->pluck('id')->all();
            $answer = ['items' => $replacement ? [['item_id' => $ids[4], 'position' => 1]]
                : [['item_id' => $ids[0], 'position' => 5], ['item_id' => $ids[3], 'position' => 2]]];
        } else {
            $ids = QuestionFillBlank::query()->where('question_id', $question->id)->orderBy('position')->pluck('id')->all();
            $answer = ['values' => $replacement ? [['blank_id' => $ids[2], 'text' => "  replacement\n "]]
                : [['blank_id' => $ids[1], 'text' => "  domain name\u{00A0}"], ['blank_id' => $ids[0], 'text' => "\tDNS  "]]];
        }

        return ['type' => $type] + $answer;
    }

    protected function canonicalAnswer(Question $question, array $payload): array
    {
        unset($payload['type']);
        if (isset($payload['selected_option_ids'])) {
            $payload['selected_option_ids'] = QuestionChoiceOption::query()->where('question_id', $question->id)
                ->whereIn('id', $payload['selected_option_ids'])->orderBy('position')->orderBy('id')->pluck('id')->all();
        } elseif (isset($payload['pairs'])) {
            usort($payload['pairs'], fn (array $a, array $b): int => [$a['left_item_id'], $a['right_item_id']] <=> [$b['left_item_id'], $b['right_item_id']]);
        } elseif (isset($payload['items'])) {
            usort($payload['items'], fn (array $a, array $b): int => [$a['position'], $a['item_id']] <=> [$b['position'], $b['item_id']]);
        } elseif (isset($payload['values'])) {
            $positions = QuestionFillBlank::query()->where('question_id', $question->id)->pluck('position', 'id')->all();
            usort($payload['values'], fn (array $a, array $b): int => [$positions[$a['blank_id']], $a['blank_id']] <=> [$positions[$b['blank_id']], $b['blank_id']]);
        }

        return $payload;
    }

    protected function clearPayload(Question $question): array
    {
        return ['type' => $question->type->value] + match ($question->type) {
            QuestionType::MultipleChoice => ['selected_option_ids' => []],
            QuestionType::ShortWritten, QuestionType::OpenWritten => ['text' => "\u{FEFF}\u{0085}\u{2007}\t "],
            QuestionType::Matching => ['pairs' => []], QuestionType::Ordering => ['items' => []],
            QuestionType::FillInBlank => ['values' => []],
        };
    }

    protected function answerRequest(User $student, AssessmentAttempt $attempt, Question $question, array|string $payload, string $contentType = 'application/json', string $query = ''): TestResponse
    {
        return $this->answerHttp($student, 'PUT', '/api/v1/student/attempts/'.$attempt->id.'/answers/'.$question->id.$query,
            is_array($payload) ? json_encode($payload, JSON_THROW_ON_ERROR | JSON_PRESERVE_ZERO_FRACTION) : $payload, $contentType);
    }

    protected function answerHttp(User $student, string $method, string $uri, string $body = '', string $contentType = 'application/json', array $headers = []): TestResponse
    {
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('homework-answer-test')->plainTextToken] + $headers;
        try {
            return $this->call($method, $uri, [], [], [], $server, $body);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }

    protected function answerSnapshot(): array
    {
        $snapshot = [];
        foreach (['attempt_answers', 'answer_choice_selections', 'answer_boolean_values', 'answer_text_values',
            'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files'] as $table) {
            $rows = DB::table($table)->get()->map(fn (object $row): array => (array) $row)->all();
            usort($rows, fn (array $a, array $b): int => json_encode($a) <=> json_encode($b));
            $snapshot[$table] = $rows;
        }

        return $snapshot;
    }

    protected function assertNoAnswerSecrets(array $value): void
    {
        foreach ($value as $key => $child) {
            $this->assertNotContains($key, ['is_correct', 'correct_value', 'accepted_answers', 'correct_position', 'match_key',
                'checking_status', 'awarded_points', 'feedback', 'checked_by_user_id', 'checked_at', 'institution_id', 'attempt_id']);
            if (is_array($child)) {
                $this->assertNoAnswerSecrets($child);
            }
        }
    }
}
