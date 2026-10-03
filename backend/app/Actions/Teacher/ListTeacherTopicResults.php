<?php

namespace App\Actions\Teacher;

use App\Enums\TopicResultStatus;
use App\Models\Topic;
use App\Models\User;
use App\Support\Results\TeacherTopicResultEntry;
use App\Support\Results\TeacherTopicResults;
use App\Support\Student\StudentBlitzReadSnapshot;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Pagination\LengthAwarePaginator;

/**
 * The Topic's cohort results for its Teacher (docs/09 §25.5): ordered by Student name, filtered by
 * status or category, paged, with the status counts of the whole cohort. One snapshot read.
 */
final class ListTeacherTopicResults
{
    public const DEFAULT_PER_PAGE = 25;

    public const MAX_PER_PAGE = 100;

    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TeacherTopicResults $results,
        private readonly StudentBlitzReadSnapshot $snapshots,
    ) {}

    /**
     * @param  array{result_status?: string, category?: string}  $filters
     * @return array{page: LengthAwarePaginator<int, TeacherTopicResultEntry>, counts: array<string, int>}
     */
    public function __invoke(User $teacher, string $topicId, array $filters, int $page, int $perPage): array
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);
        $entries = $this->snapshots->read(fn (): array => $this->ordered($topic, $this->results->forTopic($topic)));
        $counts = array_fill_keys(TopicResultStatus::values(), 0);

        foreach ($entries as $entry) {
            $counts[$entry->result->status->value]++;
        }

        $matching = array_values(array_filter($entries, fn (TeacherTopicResultEntry $entry): bool => (! isset($filters['result_status'])
                || $entry->result->status->value === $filters['result_status'])
            && (! isset($filters['category']) || $entry->result->category?->value === $filters['category'])));

        // A page far beyond the results is empty; the offset can exceed the integer range, so compare first.
        $offset = ($page - 1) * $perPage;

        return [
            'page' => new LengthAwarePaginator(
                $offset < count($matching) ? array_slice($matching, (int) $offset, $perPage) : [],
                count($matching),
                $perPage,
                $page,
            ),
            'counts' => $counts,
        ];
    }

    /**
     * The order every Teacher list of Students uses: the lower-cased name under the database collation, then id.
     *
     * @param  list<TeacherTopicResultEntry>  $entries
     * @return list<TeacherTopicResultEntry>
     */
    private function ordered(Topic $topic, array $entries): array
    {
        if ($entries === []) {
            return [];
        }

        $positions = User::query()
            ->where('institution_id', $topic->institution_id)
            ->whereIn('id', array_map(fn (TeacherTopicResultEntry $entry): string => $entry->result->student->id, $entries))
            ->orderByRaw('lower(full_name) ASC')
            ->orderBy('id')
            ->pluck('id')
            ->flip();
        usort($entries, fn (TeacherTopicResultEntry $left, TeacherTopicResultEntry $right): int => $positions[$left->result->student->id]
            <=> $positions[$right->result->student->id]);

        return $entries;
    }
}
