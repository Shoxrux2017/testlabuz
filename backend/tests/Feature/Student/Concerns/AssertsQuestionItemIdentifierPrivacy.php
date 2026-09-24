<?php

namespace Tests\Feature\Student\Concerns;

use App\Models\User;
use Illuminate\Testing\TestResponse;

/**
 * Attacker-style check: a Student must not recover Matching pairs or the correct Ordering by
 * sorting the item identifiers returned in the public Student Question projection.
 */
trait AssertsQuestionItemIdentifierPrivacy
{
    /** @return list<array{string, string}> */
    protected function keyedMatchingPairs(): array
    {
        return [
            ['DNS', 'Domain Name System'], ['IP', 'Internet Protocol'], ['TCP', 'Transmission Control Protocol'],
            ['HTTP', 'Hypertext Transfer Protocol'], ['SQL', 'Structured Query Language'],
            ['CPU', 'Central Processing Unit'], ['RAM', 'Random Access Memory'], ['USB', 'Universal Serial Bus'],
        ];
    }

    /** @return list<string> */
    protected function keyedOrderingItems(): array
    {
        return ['First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth', 'Seventh', 'Eighth', 'Ninth', 'Tenth'];
    }

    /** Authors Matching and Ordering Questions through the public Teacher API, in correct-answer order. */
    protected function authorKeyedQuestions(User $teacher, string $assessmentId, int $firstPosition): void
    {
        $pairs = $this->keyedMatchingPairs();
        $this->keyedQuestionRequest($teacher, $assessmentId, [
            'type' => 'matching', 'prompt' => 'Match.', 'instructions' => null, 'points' => 1,
            'position' => $firstPosition, 'checking_mode' => 'automatic',
            'configuration' => ['pairs' => array_map(
                fn (array $pair, int $index): array => ['client_key' => 'pair-'.$index, 'left' => $pair[0], 'right' => $pair[1]],
                $pairs, array_keys($pairs),
            )],
        ])->assertCreated();

        $items = $this->keyedOrderingItems();
        $this->keyedQuestionRequest($teacher, $assessmentId, [
            'type' => 'ordering', 'prompt' => 'Order.', 'instructions' => null, 'points' => 1,
            'position' => $firstPosition + 1, 'checking_mode' => 'automatic',
            'configuration' => ['items' => array_map(
                fn (string $text, int $index): array => ['text' => $text, 'correct_position' => $index + 1],
                $items, array_keys($items),
            )],
        ])->assertCreated();
    }

    /** @param list<array<string, mixed>> $questions Student Question resources from a public response */
    protected function assertItemIdentifiersRevealNoKey(array $questions): void
    {
        $byType = collect($questions)->keyBy('type');
        $matching = $byType['matching']['answer_ui'];
        $ordering = $byType['ordering']['answer_ui']['items'];
        $items = array_merge($matching['left_items'], $matching['right_items'], $ordering);

        foreach ($items as $item) {
            $this->assertMatchesRegularExpression('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/', $item['id']);
        }

        $textById = collect($matching['left_items'])->merge($matching['right_items'])->pluck('text', 'id');
        $sortedIds = $textById->keys()->sort(fn (string $left, string $right): int => strcmp($left, $right))->values();
        $recoveredPairs = $sortedIds->chunk(2)
            ->map(fn ($chunk): array => [$textById[$chunk->values()[0]], $textById[$chunk->values()[1]]])
            ->values()->all();
        $this->assertNotSame($this->keyedMatchingPairs(), $recoveredPairs);

        $recoveredOrder = collect($ordering)->sortBy('id', SORT_STRING)->pluck('text')->values()->all();
        $this->assertNotSame($this->keyedOrderingItems(), $recoveredOrder);
    }

    private function keyedQuestionRequest(User $teacher, string $assessmentId, array $payload): TestResponse
    {
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('question-item-privacy')->plainTextToken,
        ];
        try {
            return $this->call('POST', '/api/v1/teacher/assessments/'.$assessmentId.'/questions', [], [], [], $server,
                json_encode($payload, JSON_THROW_ON_ERROR));
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }
}
