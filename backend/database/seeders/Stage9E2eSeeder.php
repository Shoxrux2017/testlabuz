<?php

namespace Database\Seeders;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

/** Stage 9 real-stack integration fixtures (S09-INT-001 §8). Never called by DatabaseSeeder. */
class Stage9E2eSeeder extends Seeder
{
    public const PRIMARY_KEYS = ['institution_settings' => 'institution_id', 'blitz_tasks' => 'assessment_id', 'homework_assignments' => 'assessment_id', 'question_true_false_answers' => 'question_id'];

    public const IDEMPOTENCY_OPERATIONS = ['teacher.blitz.attempt_exception.grant', 'student.blitz.attempt.start', 'student.blitz.attempt.submit', 'student.homework.attempt.start', 'student.homework.attempt.submit'];

    public const REVIEW_DUE_AT = '2026-01-15 13:00:00+00';

    private const ANSWER_TABLES = ['answer_choice_selections', 'answer_text_values', 'answer_boolean_values', 'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files'];

    private const QUESTION_CHILD_TABLES = ['question_choice_options', 'question_true_false_answers', 'question_short_accepted_answers', 'question_matching_items', 'question_ordering_items', 'question_fill_blanks'];

    /** Seeded Attempt history is owned through the dynamic walk, like the rows a run creates. */
    private const DYNAMIC_TABLES = ['assessment_attempts', 'attempt_answers', ...self::ANSWER_TABLES];

    /** Institution => Student result release mode. */
    private const INSTITUTIONS = ['auto' => 'automatic', 'manual' => 'manual_teacher'];

    /** Asia/Tokyo (+09:00, no DST) differs from the +05:00 runner host, so device time cannot pass for Institution time. */
    private const TIMEZONES = ['auto' => 'Asia/Tokyo', 'manual' => 'Asia/Tashkent'];

    /** Institution => the Teacher who owns its Topics. */
    private const OWNERS = ['auto' => 'teacher', 'manual' => 'manual_teacher'];

    private const TEACHERS = ['teacher' => 'auto', 'peer_teacher' => 'auto', 'manual_teacher' => 'manual'];

    /** Topic = Group => [institution, students, Teachers besides the owner]. */
    private const GROUPS = [
        'review' => ['auto', ['student', 'classmate'], ['peer_teacher']],
        'backfill' => ['auto', ['backfill_student', 'repair_student', 'deadline_student', 'timeout_student'], []],
        'android' => ['auto', ['android_student', 'android_classmate'], []],
        'manual' => ['manual', ['manual_student'], []],
    ];

    /**
     * Assessment => [type, Topic, state, selected recipients (null = the whole Group as an official cohort), timing].
     * Timing: Homework deadline `future` / `due` / null, plus `review_due`; Blitz [timer, duration, activation].
     */
    private const ASSESSMENTS = [
        'review_hw' => ['homework', 'review', 'active', null, ['deadline' => 'future', 'review_due' => true]],
        'exception_blitz' => ['blitz', 'review', 'active', null, ['timer' => 'synchronized', 'duration' => 3600, 'activated' => 'seed']],
        'manual_hw' => ['homework', 'manual', 'active', null, ['deadline' => 'future']],
        'backfill_hw' => ['homework', 'backfill', 'closed', ['backfill_student'], []],
        'backfill_blitz' => ['blitz', 'backfill', 'closed', null, ['timer' => 'individual', 'duration' => 600, 'activated' => 'history']],
        'repair_hw' => ['homework', 'backfill', 'closed', null, []],
        'deadline_hw' => ['homework', 'backfill', 'active', ['deadline_student'], ['deadline' => 'due']],
        'timeout_blitz' => ['blitz', 'backfill', 'active', ['timeout_student'], ['timer' => 'individual', 'duration' => 600, 'activated' => 'hour_ago']],
        'android_hw' => ['homework', 'android', 'active', null, ['deadline' => 'future', 'review_due' => true]],
        'android_blitz' => ['blitz', 'android', 'active', null, ['timer' => 'synchronized', 'duration' => 3600, 'activated' => 'seed']],
    ];

    /** Assessment => Questions in position order: [type, points, configuration]. */
    private const QUESTIONS = [
        'review_hw' => [['single_choice', 2, ['options' => 4, 'correct' => [2]]], ['multiple_choice', 3, ['options' => 5, 'correct' => [1, 3, 5]]],
            ['short_written', 5, ['manual' => true]], ['open_written', 5, []], ['file_based', 5, []]],
        'exception_blitz' => [['single_choice', 4, ['options' => 3, 'correct' => [1]]], ['open_written', 6, []]],
        'manual_hw' => [['single_choice', 5, ['options' => 3, 'correct' => [3]]], ['open_written', 5, []]],
        'backfill_hw' => [['single_choice', 2, ['options' => 3, 'correct' => [1]]], ['multiple_choice', 3, ['options' => 5, 'correct' => [2, 3, 4]]],
            ['true_false', 1, ['correct' => false]], ['short_written', 2, ['accepted' => ["O\u{02BB}zbekiston"]]],
            ['fill_in_blank', 3, ['blanks' => ['Tashkent', 'Samarkand']]], ['matching', 3, ['pairs' => 3]], ['ordering', 4, ['items' => 3]],
            ['open_written', 5, []], ['file_based', 5, []]],
        'backfill_blitz' => [['multiple_choice', 1, ['options' => 4, 'correct' => [1, 2, 3]]], ['ordering', 1, ['items' => 3]], ['true_false', 1, ['correct' => true]]],
        'repair_hw' => [['single_choice', 4, ['options' => 2, 'correct' => [1]]]],
        'deadline_hw' => [['single_choice', 3, ['options' => 3, 'correct' => [2]]], ['true_false', 1, ['correct' => false]]],
        'timeout_blitz' => [['true_false', 2, ['correct' => true]], ['single_choice', 2, ['options' => 2, 'correct' => [1]]]],
        'android_hw' => [['single_choice', 2, ['options' => 3, 'correct' => [1]]], ['open_written', 3, []]],
        'android_blitz' => [['single_choice', 2, ['options' => 3, 'correct' => [2]]], ['open_written', 2, []]],
    ];

    /** Official result pair per Topic => [Homework, Blitz or null]. */
    private const PAIRS = [
        'review' => ['review_hw', 'exception_blitz'],
        'backfill' => ['repair_hw', 'backfill_blitz'],
        'android' => ['android_hw', 'android_blitz'],
        'manual' => ['manual_hw', null],
    ];

    /**
     * Seeded pre-Stage-9 history => [Assessment, Student, status, answers by Question label].
     * Answer values: choice = option positions; matching = right index per left index; ordering = submitted position per item.
     */
    private const ATTEMPTS = [
        'backfill_hw_1' => ['backfill_hw', 'backfill_student', 'submitted', [
            'q1' => ['choice' => [1]], 'q2' => ['choice' => [2, 1, 5]], 'q3' => ['boolean' => false], 'q4' => ['text' => "  o'ZBEKISTON "],
            'q5' => ['blanks' => ['TASHKENT', 'Bukhara']], 'q6' => ['matching' => [0, 2, 1]], 'q7' => ['ordering' => [1, 3, 2]],
            'q8' => ['text' => 'E2E S09 seeded open answer.']]],
        'backfill_blitz_1' => ['backfill_blitz', 'backfill_student', 'timed_out_finalized', [
            // 2 of 3 correct options: 2/3 = 0.666... must round half-up to 0.66666667; no item at its position.
            'q1' => ['choice' => [1, 2]], 'q2' => ['ordering' => [2, 3, 1]], 'q3' => ['boolean' => true]]],
        'repair_hw_1' => ['repair_hw', 'repair_student', 'checked', ['q1' => ['choice' => [1]]]],
        'deadline_hw_1' => ['deadline_hw', 'deadline_student', 'in_progress', ['q1' => ['choice' => [2]]]],
        'timeout_blitz_1' => ['timeout_blitz', 'timeout_student', 'in_progress', ['q1' => ['boolean' => true]]],
    ];

    private const TIMESTAMPS = [
        'created' => '2020-01-01 00:00:00+00',
        'designated' => '2020-01-01 12:00:00+00',
        'activated' => '2020-01-02 00:00:00+00',
        'history_start' => '2020-01-02 01:00:00+00',
        'history_answered' => '2020-01-02 01:01:00+00',
        'history_submitted' => '2020-01-02 01:05:00+00',
        'history_checked' => '2020-01-02 02:00:00+00',
        'closed' => '2020-01-03 00:00:00+00',
    ];

    /** Only used where identity, not the seeded clock, is compared. */
    private const IDENTITY_CLOCK = '2026-01-01 00:00:00+00';

    public static function id(int $number): string
    {
        return sprintf('09000000-0000-4000-8000-%012d', $number);
    }

    public static function sentinelId(int $number): string
    {
        return sprintf('09999999-0000-4000-8000-%012d', $number);
    }

    /** Every static row identity, the exact parents that own runtime rows and the seeded Question data. */
    public static function manifest(): array
    {
        $manifest = ['timestamps' => self::TIMESTAMPS, 'review_due_at' => self::REVIEW_DUE_AT];
        $index = 0;
        foreach (array_keys(self::INSTITUTIONS) as $name) {
            $manifest['institutions'][$name] = self::id(++$index);
        }
        $index = 100;
        foreach (array_keys(self::users()) as $name) {
            $manifest['users'][$name] = self::id(++$index);
        }
        $index = 200;
        foreach (array_keys(self::GROUPS) as $name) {
            $manifest['groups'][$name] = self::id(++$index);
            $manifest['topics'][$name] = self::id($index + 200);
        }
        $index = 500;
        foreach (self::ASSESSMENTS as $name => [$type]) {
            $number = ++$index;
            $manifest['assessments'][$name] = self::id($number);
            $manifest[$type][$name] = self::id($number);
            foreach (self::QUESTIONS[$name] as $position => [$questionType, $points]) {
                $label = 'q'.($position + 1);
                $questionNumber = 1_000_000 + $number * 100 + $position + 1;
                $manifest['questions'][$name][$label] = self::id($questionNumber);
                $manifest['question_types'][$name][$label] = $questionType;
                $manifest['question_points'][$name][$label] = $points.'.000000';
                $manifest['nested'][$name][$label] = self::nestedIds(self::QUESTIONS[$name][$position], $questionNumber);
            }
            foreach (self::recipientsOf($name) as $recipientIndex => $student) {
                $manifest['recipients'][$name][$student] = self::id(2_000_000 + $number * 100 + $recipientIndex + 1);
            }
        }
        $index = 600;
        foreach (array_keys(self::PAIRS) as $name) {
            $manifest['pairs'][$name] = self::id(++$index);
        }
        $index = 0;
        foreach (self::ATTEMPTS as $name => [$assessment, , , $answers]) {
            $attemptIndex = ++$index;
            $manifest['attempts'][$name] = self::id(3_000_000 + $attemptIndex);
            foreach (array_keys($answers) as $label) {
                $manifest['answers'][$name][$label] = self::id(4_000_000 + $attemptIndex * 100 + (int) substr($label, 1));
            }
        }
        foreach (self::fixtureRows($manifest, self::IDENTITY_CLOCK) as $table => $rows) {
            if (! in_array($table, self::DYNAMIC_TABLES, true)) {
                $manifest['db'][$table] = array_column($rows, self::PRIMARY_KEYS[$table] ?? 'id');
            }
        }

        return $manifest;
    }

    public function run(): void
    {
        $password = $this->guard();
        $this->cleanupOwnedState();
        $passwordHash = Hash::make($password);
        unset($password);
        $seededAt = now()->utc()->startOfSecond()->format('Y-m-d H:i:sP');
        DB::transaction(function () use ($passwordHash, $seededAt): void {
            foreach (self::fixtureRows(self::manifest(), $seededAt) as $table => $rows) {
                if ($table === 'users') {
                    $rows = array_map(fn (array $row): array => $row + ['password' => $passwordHash], $rows);
                }
                DB::table($table)->insert($rows);
            }
        });
    }

    /** Read-only ownership snapshot: static rows, runtime rows under owned parents and exact private keys. */
    public function ownedState(): array
    {
        $this->guard(requirePassword: false);
        $manifest = self::manifest();
        $expectedRows = self::fixtureRows($manifest, self::IDENTITY_CLOCK);
        $users = collect($expectedRows['users'])->keyBy('id');
        $state = ['db' => [], 'blobs' => [], 'directories' => [], 'answer_children' => []];
        foreach ($expectedRows as $table => $expected) {
            if (in_array($table, self::DYNAMIC_TABLES, true)) {
                continue;
            }
            $primaryKey = self::PRIMARY_KEYS[$table] ?? 'id';
            $state['db'][$table] = [];
            foreach ($expected as $identity) {
                $row = DB::table($table)->where($primaryKey, $identity[$primaryKey])->first();
                if ($row === null) {
                    continue;
                }
                foreach ($identity as $column => $value) {
                    if ($column === $primaryKey || str_ends_with($column, '_id') || in_array($column, ['login_name', 'name', 'title', 'role', 'type', 'assignment_mode', 'assignment_source'], true)) {
                        $this->require($row->{$column} === $value, 'Static Stage 9 ownership mismatch: '.$table.'.'.$column);
                    }
                }
                $state['db'][$table][] = $identity[$primaryKey];
            }
        }

        $ownedAssessments = collect($expectedRows['assessments'])->keyBy('id');
        $this->require(DB::table('assessments')->whereIn('topic_id', $manifest['topics'])->whereNotIn('id', $manifest['assessments'])->doesntExist(),
            'Stage 9 Topics hold an unexpected Assessment.');
        $questions = DB::table('questions')->whereIn('assessment_id', $ownedAssessments->keys())->get();
        $this->require($questions->pluck('id')->diff($manifest['db']['questions'])->isEmpty(), 'Stage 9 Assessments hold an unexpected Question.');
        $questions = $questions->keyBy('id');
        $recipients = DB::table('assessment_students')->whereIn('assessment_id', $ownedAssessments->keys())->get();
        $this->require($recipients->pluck('id')->diff($manifest['db']['assessment_students'])->isEmpty(), 'Stage 9 Assessments hold an unexpected recipient.');
        $recipients = $recipients->keyBy('id');

        $attemptRows = DB::table('assessment_attempts')->whereIn('assessment_id', $ownedAssessments->keys())->get();
        foreach ($attemptRows as $attempt) {
            $recipient = $recipients->get($attempt->assessment_student_id);
            $this->require($recipient !== null && $recipient->assessment_id === $attempt->assessment_id
                && $recipient->institution_id === $attempt->institution_id && $recipient->student_id === $attempt->student_id,
                'Stage 9 Attempt ownership mismatch.');
        }
        $this->require(DB::table('assessment_attempts')->whereIn('student_id', $manifest['users'])->whereNotIn('id', $attemptRows->pluck('id'))->doesntExist(),
            'Unowned Stage 9 Attempt of a manifest Student.');
        $state['db']['assessment_attempts'] = $attemptRows->pluck('id')->all();
        $attempts = $attemptRows->keyBy('id');

        $exceptions = DB::table('blitz_attempt_exceptions')->whereIn('assessment_id', $ownedAssessments->keys())->get();
        foreach ($exceptions as $exception) {
            $this->require($attempts->has($exception->invalidated_attempt_id)
                && ($exception->replacement_attempt_id === null || $attempts->has($exception->replacement_attempt_id))
                && $exception->institution_id === $attempts[$exception->invalidated_attempt_id]->institution_id
                && $users->has($exception->granted_by_user_id), 'Stage 9 exception ownership mismatch.');
        }
        $state['db']['blitz_attempt_exceptions'] = $exceptions->pluck('id')->all();

        $officialRows = DB::table('official_task_scores')->where(fn ($query) => $query->whereIn('assessment_id', $ownedAssessments->keys())
            ->orWhereIn('student_id', $manifest['users'])->orWhereIn('official_attempt_id', $attempts->keys()))->get();
        foreach ($officialRows as $official) {
            $attempt = $attempts->get($official->official_attempt_id);
            $this->require($attempt !== null && $attempt->assessment_id === $official->assessment_id && $attempt->student_id === $official->student_id
                && $attempt->institution_id === $official->institution_id && $official->selected_by_user_id === null, 'Unowned Stage 9 official score row.');
        }
        $state['db']['official_task_scores'] = $officialRows->pluck('id')->all();

        $answerRows = DB::table('attempt_answers')->whereIn('attempt_id', $state['db']['assessment_attempts'])->get();
        foreach ($answerRows as $answer) {
            $question = $questions->get($answer->question_id);
            $attempt = $attempts->get($answer->attempt_id);
            $this->require($question !== null && $question->assessment_id === $attempt->assessment_id
                && $answer->institution_id === $attempt->institution_id && $question->institution_id === $answer->institution_id
                && ($answer->checked_by_user_id === null || $users->has($answer->checked_by_user_id)), 'Stage 9 answer ownership mismatch.');
        }
        $state['db']['attempt_answers'] = $answerRows->pluck('id')->all();
        $answers = $answerRows->keyBy('id');
        foreach (self::ANSWER_TABLES as $table) {
            $rows = DB::table($table)->whereIn('answer_id', $state['db']['attempt_answers'])->get();
            foreach ($rows as $row) {
                $this->require($row->institution_id === $answers[$row->answer_id]->institution_id, 'Stage 9 typed-answer ownership mismatch.');
            }
            $state['answer_children'][$table] = $rows->map(fn (object $row): array => (array) $row)->all();
        }

        $fileLinks = collect($state['answer_children']['answer_files'])->keyBy('file_id');
        $fileRows = DB::table('files')->whereIn('id', $fileLinks->keys())->get();
        $disk = $this->privateDisk();
        foreach ($fileRows as $file) {
            $answer = $answers[$fileLinks[$file->id]['answer_id']];
            $attempt = $attempts[$answer->attempt_id];
            $directory = 'student-submissions/'.$attempt->institution_id.'/'.$attempt->id.'/'.$answer->question_id;
            $this->require($file->institution_id === $attempt->institution_id && $file->uploaded_by_user_id === $attempt->student_id
                && $file->category === 'student_submission' && $file->storage_disk === $disk
                && $questions[$answer->question_id]->type === 'file_based', 'Stage 9 File ownership mismatch.');
            $this->require($this->isSubmissionKey($file->storage_key, $directory), 'Stage 9 private blob ownership mismatch.');
            $state['blobs'][] = ['disk' => $disk, 'key' => $file->storage_key];
        }
        $this->require($fileRows->count() === $fileLinks->count(), 'Stage 9 linked File missing.');
        // A File row without an answer link (for example a replaced upload) is still owned through its key.
        $unlinked = DB::table('files')->whereIn('uploaded_by_user_id', $manifest['users'])->whereNotIn('id', $fileRows->pluck('id'))->get();
        foreach ($unlinked as $file) {
            $parts = explode('/', (string) $file->storage_key);
            $attempt = count($parts) === 5 ? $attempts->get($parts[2]) : null;
            $question = count($parts) === 5 ? $questions->get($parts[3]) : null;
            $this->require($attempt !== null && $question !== null && $parts[0] === 'student-submissions' && $parts[1] === $attempt->institution_id
                && $question->assessment_id === $attempt->assessment_id && $question->type === 'file_based'
                && $file->institution_id === $attempt->institution_id && $file->uploaded_by_user_id === $attempt->student_id
                && $file->category === 'student_submission' && $file->storage_disk === $disk
                && $this->isSubmissionKey($file->storage_key, 'student-submissions/'.$attempt->institution_id.'/'.$attempt->id.'/'.$question->id),
                'Unowned Stage 9 File row.');
        }
        $state['db']['files'] = [...$fileRows->pluck('id')->all(), ...$unlinked->pluck('id')->all()];
        // The owned Attempt + file-Question namespace also holds compensated and replaced blobs.
        // Enumerate exact keys, validate every basename and never delete an institution/prefix tree.
        foreach ($attemptRows as $attempt) {
            foreach ($questions as $question) {
                if ($question->assessment_id !== $attempt->assessment_id || $question->type !== 'file_based') {
                    continue;
                }
                $directory = 'student-submissions/'.$attempt->institution_id.'/'.$attempt->id.'/'.$question->id;
                $state['directories'][] = ['disk' => $disk, 'key' => $directory];
                foreach (Storage::disk($disk)->allFiles($directory) as $key) {
                    $this->require($this->isSubmissionKey($key, $directory), 'Stage 9 submission namespace holds an unexpected file.');
                    $state['blobs'][] = ['disk' => $disk, 'key' => $key];
                }
            }
        }
        $state['blobs'] = array_values(array_unique($state['blobs'], SORT_REGULAR));
        // Cleanup deletes every blob in an owned Attempt directory, so no foreign File row may point into one.
        $foreign = DB::table('files')->whereNotIn('id', $state['db']['files'])->where(function ($query) use ($attemptRows): void {
            foreach ($attemptRows as $attempt) {
                $query->orWhere('storage_key', 'like', 'student-submissions/'.$attempt->institution_id.'/'.$attempt->id.'/%');
            }
        });
        $this->require($attemptRows->isEmpty() || $foreign->doesntExist(), 'Unowned Stage 9 File row.');

        $owners = ['assessment_attempt' => $state['db']['assessment_attempts'], 'blitz_attempt_exception' => $state['db']['blitz_attempt_exceptions']];
        $records = DB::table('idempotency_records')->whereIn('user_id', $manifest['users'])->get();
        foreach ($records as $record) {
            $user = $users[$record->user_id];
            $this->require(in_array($record->operation, self::IDEMPOTENCY_OPERATIONS, true) && $record->institution_id === $user['institution_id']
                && in_array($record->result_resource_id, $owners[$record->result_resource_type] ?? [], true),
                'Stage 9 actor scope holds an unowned or incomplete idempotency record.');
        }
        $state['db']['idempotency_records'] = $records->pluck('id')->all();
        $state['db']['personal_access_tokens'] = DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
            ->whereIn('tokenable_id', $manifest['users'])->pluck('id')->all();

        // The manifest Institutions belong to these fixtures alone: every Institution-scoped row in them must be owned.
        $scopedTables = DB::table('information_schema.columns')->where('table_schema', 'public')->where('column_name', 'institution_id')->pluck('table_name');
        foreach ($scopedTables as $table) {
            [$column, $owned] = in_array($table, self::ANSWER_TABLES, true)
                ? ['answer_id', $state['db']['attempt_answers']]
                : [self::PRIMARY_KEYS[$table] ?? 'id', $state['db'][$table] ?? []];
            $this->require(DB::table($table)->whereIn('institution_id', $manifest['institutions'])->whereNotIn($column, $owned)->doesntExist(),
                'Unowned Stage 9 row in an owned Institution: '.$table.'.');
        }

        return $state;
    }

    public function cleanupOwnedState(): void
    {
        $this->guard();
        DB::transaction(function (): void {
            $state = $this->ownedState();
            foreach (self::ANSWER_TABLES as $table) {
                DB::table($table)->whereIn('answer_id', $state['db']['attempt_answers'])->delete();
            }
            foreach (['official_task_scores', 'blitz_attempt_exceptions', 'idempotency_records', 'attempt_answers', 'assessment_attempts', 'files', 'personal_access_tokens'] as $table) {
                DB::table($table)->whereIn('id', $state['db'][$table])->delete();
            }
            foreach (array_reverse(array_keys(self::fixtureRows(self::manifest(), self::IDENTITY_CLOCK))) as $table) {
                if (! in_array($table, self::DYNAMIC_TABLES, true)) {
                    DB::table($table)->whereIn(self::PRIMARY_KEYS[$table] ?? 'id', $state['db'][$table])->delete();
                }
            }
            foreach ($state['blobs'] as $blob) {
                $this->require(Storage::disk($blob['disk'])->delete($blob['key']), 'Stage 9 private blob cleanup failed.');
            }
            foreach ($state['directories'] as $directory) {
                $disk = Storage::disk($directory['disk']);
                foreach ([$directory['key'], dirname($directory['key'])] as $path) {
                    if ($disk->directoryExists($path) && $disk->allFiles($path) === [] && $disk->allDirectories($path) === []) {
                        $this->require($disk->deleteDirectory($path), 'Stage 9 empty submission directory cleanup failed.');
                    }
                }
            }
        });
    }

    /** Creates the unrelated sentinel graph once; an existing graph must match exactly. */
    public function ensureSentinels(): void
    {
        $this->guard();
        $rows = self::sentinelRows();
        $present = 0;
        $expected = 0;
        foreach ($rows as $table => $tableRows) {
            $primaryKey = self::sentinelPrimaryKey($table);
            $expected += count($tableRows);
            $present += DB::table($table)->whereIn($primaryKey, array_column($tableRows, $primaryKey))->count();
        }
        $disk = $this->privateDisk();
        $blob = self::sentinelBlob();
        if ($present === 0) {
            $storage = Storage::disk($disk);
            $this->require(! $storage->exists($blob['key']) || $storage->get($blob['key']) === $blob['bytes'], 'Stage 9 sentinel blob exists without its rows.');
            $this->require($storage->put($blob['key'], $blob['bytes']), 'Stage 9 sentinel blob write failed.');
            DB::transaction(function () use ($rows): void {
                $password = Hash::make(Str::random(64));
                foreach ($rows as $table => $tableRows) {
                    if ($table === 'users') {
                        $tableRows = array_map(fn (array $row): array => $row + ['password' => $password], $tableRows);
                    }
                    DB::table($table)->insert($tableRows);
                }
            });

            return;
        }
        $this->require($present === $expected, 'Stage 9 sentinel graph is partial.');
        $this->requireSentinelIdentity($rows);
        $this->require(Storage::disk($disk)->get($blob['key']) === $blob['bytes'], 'Stage 9 sentinel blob changed.');
    }

    /** Read-only sentinel facts for exact before/after comparison. */
    public function sentinelState(): array
    {
        $this->guard(requirePassword: false);
        $state = ['rows' => []];
        foreach (self::sentinelRows() as $table => $tableRows) {
            $primaryKey = self::sentinelPrimaryKey($table);
            $state['rows'][$table] = DB::table($table)->whereIn($primaryKey, array_column($tableRows, $primaryKey))->orderBy($primaryKey)->get()
                ->map(function (object $row): array {
                    $values = (array) $row;
                    unset($values['password']);

                    return $values;
                })->all();
        }
        $disk = Storage::disk($this->privateDisk());
        $blob = self::sentinelBlob();
        $state['blob'] = $disk->exists($blob['key']) ? ['key' => $blob['key'], 'sha256' => hash('sha256', $disk->get($blob['key']))] : null;

        return $state;
    }

    public function removeSentinels(): void
    {
        $this->guard();
        $disk = Storage::disk($this->privateDisk());
        $rows = self::sentinelRows();
        // Only the exact declared graph may be removed; a changed row stops the removal.
        $this->requireSentinelIdentity($rows);
        DB::transaction(function () use ($rows): void {
            foreach (array_reverse(array_keys($rows)) as $table) {
                $primaryKey = self::sentinelPrimaryKey($table);
                DB::table($table)->whereIn($primaryKey, array_column($rows[$table], $primaryKey))->delete();
            }
            DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
                ->whereIn('tokenable_id', array_column($rows['users'], 'id'))->delete();
        });
        $blob = self::sentinelBlob();
        if ($disk->exists($blob['key'])) {
            $this->require($disk->delete($blob['key']), 'Stage 9 sentinel blob cleanup failed.');
        }
    }

    /** Every present sentinel row must still equal its declaration, apart from timestamps. */
    private function requireSentinelIdentity(array $rows): void
    {
        $timestamps = ['created_at', 'updated_at', 'activated_at', 'closed_at', 'started_at', 'submitted_at', 'finalized_at', 'locked_at', 'assigned_at', 'checked_at', 'scoring_completed_at'];
        foreach ($rows as $table => $tableRows) {
            $primaryKey = self::sentinelPrimaryKey($table);
            foreach ($tableRows as $row) {
                $actual = DB::table($table)->where($primaryKey, $row[$primaryKey])->first();
                if ($actual === null) {
                    continue;
                }
                foreach ($row as $column => $value) {
                    $this->require(in_array($column, $timestamps, true) || ((array) $actual)[$column] === $value, 'Stage 9 sentinel row changed: '.$table.'.'.$column);
                }
            }
        }
    }

    protected function guard(bool $requirePassword = true): string
    {
        $this->require(app()->environment('testing'), 'Stage 9 fixtures require testing environment.');
        $this->require(DB::connection()->getDriverName() === 'pgsql', 'Stage 9 fixtures require PostgreSQL.');
        $this->require(DB::selectOne('select current_database() as database_name')->database_name === 'testlabuz_testing', 'Stage 9 fixtures require testlabuz_testing.');
        if (! $requirePassword) {
            return '';
        }
        $password = getenv('STAGE9_E2E_PASSWORD');
        $this->require(is_string($password) && trim($password) !== '', 'Stage 9 fixture password is required.');

        return $password;
    }

    private function privateDisk(): string
    {
        $disk = config('filesystems.private_files_disk');
        $configuration = is_string($disk) ? config('filesystems.disks.'.$disk) : null;
        $this->require(is_array($configuration) && ($configuration['visibility'] ?? null) !== 'public'
            && ($configuration['driver'] ?? null) === 'local', 'Stage 9 cleanup requires a private local disk.');
        $root = realpath($configuration['root']);
        $privateRoot = realpath(storage_path('app/private'));
        $this->require($root !== false && $privateRoot !== false && ($root === $privateRoot || str_starts_with($root, $privateRoot.DIRECTORY_SEPARATOR)), 'Stage 9 private disk root mismatch.');

        return $disk;
    }

    private function isSubmissionKey(string $key, string $directory): bool
    {
        return preg_match('~^'.preg_quote($directory, '~').'/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(pdf|docx|ppt|pptx)$~D', $key) === 1;
    }

    private function require(bool $condition, string $message): void
    {
        if (! $condition) {
            throw new RuntimeException($message);
        }
    }

    /** @return array<string, string> User name => institution. */
    private static function users(): array
    {
        $users = self::TEACHERS;
        foreach (self::GROUPS as [$institution, $students]) {
            foreach ($students as $student) {
                $users[$student] = $institution;
            }
        }

        return $users;
    }

    /** @return list<string> */
    private static function recipientsOf(string $assessment): array
    {
        [, $topic, , $selected] = self::ASSESSMENTS[$assessment];

        return $selected ?? self::GROUPS[$topic][1];
    }

    private static function nestedIds(array $question, int $questionNumber): array
    {
        [$type, , $configuration] = $question;
        $nested = fn (int $offset): string => self::id($questionNumber * 100 + $offset);

        return match ($type) {
            'single_choice', 'multiple_choice' => array_map($nested, range(1, $configuration['options'])),
            // Item ids are public to Students, so their sort order must not reveal pairs or order.
            'matching' => ['left' => array_map($nested, [1, 2, 3]), 'right' => array_map($nested, [13, 11, 12]), 'keys' => array_map($nested, [21, 22, 23])],
            'ordering' => array_map($nested, [3, 1, 2]),
            'fill_in_blank' => ['blanks' => array_map($nested, [1, 2]), 'accepted' => array_map($nested, [11, 12])],
            'short_written' => isset($configuration['accepted']) ? ['accepted' => $nested(1)] : [],
            default => [],
        };
    }

    private static function at(string $name): string
    {
        return self::TIMESTAMPS[$name];
    }

    private static function plusSeconds(string $timestamp, int $seconds): string
    {
        return CarbonImmutable::parse($timestamp)->utc()->addSeconds($seconds)->format('Y-m-d H:i:sP');
    }

    private static function sentinelPrimaryKey(string $table): string
    {
        return match ($table) {
            'institution_settings' => 'institution_id',
            'homework_assignments' => 'assessment_id',
            'answer_choice_selections' => 'answer_id',
            default => 'id',
        };
    }

    /** Non-secret exact fixture rows; insertion order is parent before child. */
    public static function fixtureRows(array $manifest, string $seededAt): array
    {
        $rows = [];
        $stamps = ['created_at' => self::at('created'), 'updated_at' => self::at('created')];
        $institutionOf = fn (string $assessment): string => self::GROUPS[self::ASSESSMENTS[$assessment][1]][0];
        $ownerOf = fn (string $institution): string => $manifest['users'][self::OWNERS[$institution]];
        $words = fn (string $name): string => ucwords(str_replace('_', ' ', $name));
        foreach (self::INSTITUTIONS as $name => $release) {
            $rows['institutions'][] = ['id' => $manifest['institutions'][$name], 'name' => 'E2E S09 '.ucfirst($name).' Institution', 'type' => 'school', 'status' => 'active'] + $stamps;
        }
        foreach (self::users() as $name => $institution) {
            $rows['users'][] = ['id' => $manifest['users'][$name], 'institution_id' => $manifest['institutions'][$institution],
                'role' => array_key_exists($name, self::TEACHERS) ? 'teacher' : 'student', 'full_name' => 'E2E S09 '.$words($name),
                'login_name' => 'e2e_s09_'.$name, 'is_active' => true, 'must_change_password' => false] + $stamps;
        }
        foreach (self::INSTITUTIONS as $name => $release) {
            $rows['institution_settings'][] = ['institution_id' => $manifest['institutions'][$name], 'timezone' => self::TIMEZONES[$name],
                'blitz_timer_start_mode' => 'synchronized', 'student_result_release_mode' => $release,
                'learning_material_max_mb' => 25, 'student_submission_max_mb' => 15] + $stamps;
        }
        foreach (self::GROUPS as $name => [$institution]) {
            $rows['groups'][] = ['id' => $manifest['groups'][$name], 'institution_id' => $manifest['institutions'][$institution],
                'name' => 'E2E S09 '.$words($name).' Group', 'status' => 'active', 'created_by_user_id' => $ownerOf($institution)] + $stamps;
        }
        foreach (self::GROUPS as $name => [$institution, , $extraTeachers]) {
            $groupNumber = (int) substr($manifest['groups'][$name], -12);
            foreach ([self::OWNERS[$institution], ...$extraTeachers] as $index => $teacher) {
                $rows['group_teacher_memberships'][] = ['id' => self::id(7_500_000 + $groupNumber * 10 + $index + 1), 'institution_id' => $manifest['institutions'][$institution],
                    'group_id' => $manifest['groups'][$name], 'teacher_id' => $manifest['users'][$teacher], 'assigned_by_user_id' => $ownerOf($institution),
                    'started_at' => self::at('created'), 'ended_at' => null] + $stamps;
            }
        }
        foreach (self::GROUPS as $name => [$institution, $students]) {
            $groupNumber = (int) substr($manifest['groups'][$name], -12);
            foreach ($students as $index => $student) {
                $rows['group_student_memberships'][] = ['id' => self::id(7_000_000 + $groupNumber * 100 + $index + 1), 'institution_id' => $manifest['institutions'][$institution],
                    'group_id' => $manifest['groups'][$name], 'student_id' => $manifest['users'][$student], 'assigned_by_user_id' => $ownerOf($institution),
                    'started_at' => self::at('created'), 'ended_at' => null] + $stamps;
            }
        }
        foreach (self::GROUPS as $name => [$institution]) {
            $rows['topics'][] = ['id' => $manifest['topics'][$name], 'institution_id' => $manifest['institutions'][$institution], 'group_id' => $manifest['groups'][$name],
                'teacher_id' => $ownerOf($institution), 'title' => 'E2E S09 '.$words($name).' Topic', 'subject' => 'E2E S09',
                'student_instructions' => 'E2E S09 Topic instructions', 'status' => 'active', 'activated_at' => self::at('activated')] + $stamps;
        }
        foreach (self::ASSESSMENTS as $name => [$type, $topic, , $selected]) {
            $total = array_sum(array_column(self::QUESTIONS[$name], 1));
            $rows['assessments'][] = ['id' => $manifest['assessments'][$name], 'institution_id' => $manifest['institutions'][$institutionOf($name)],
                'topic_id' => $manifest['topics'][$topic], 'teacher_id' => $ownerOf($institutionOf($name)), 'type' => $type,
                'title' => 'E2E S09 '.$words($name), 'student_instructions' => 'E2E S09 Answer every Question and submit.',
                'assignment_mode' => $selected === null ? 'group' : 'selected_students', 'total_possible_points' => $total.'.000000'] + $stamps;
        }
        foreach (self::ASSESSMENTS as $name => [$type, , $state, , $timing]) {
            if ($type !== 'homework') {
                continue;
            }
            $deadline = match ($timing['deadline'] ?? null) {
                'future' => self::plusSeconds($seededAt, 30 * 86400),
                'due' => self::plusSeconds($seededAt, -600),
                default => null,
            };
            $rows['homework_assignments'][] = ['assessment_id' => $manifest['assessments'][$name], 'institution_id' => $manifest['institutions'][$institutionOf($name)],
                'status' => $state, 'deadline_at' => $deadline, 'activated_at' => self::at('activated'),
                'closed_at' => $state === 'closed' ? self::at('closed') : null,
                'review_due_at' => ($timing['review_due'] ?? false) ? self::REVIEW_DUE_AT : null] + $stamps;
        }
        foreach (self::ASSESSMENTS as $name => [$type, , $state, , $timing]) {
            if ($type !== 'blitz') {
                continue;
            }
            $activated = self::blitzActivation($name, $seededAt);
            $rows['blitz_tasks'][] = ['assessment_id' => $manifest['assessments'][$name], 'institution_id' => $manifest['institutions'][$institutionOf($name)],
                'status' => $state, 'duration_seconds' => $timing['duration'], 'scheduled_at' => null, 'timer_start_mode_snapshot' => $timing['timer'],
                'activated_at' => $activated, 'activated_by_user_id' => $ownerOf($institutionOf($name)),
                'synchronized_ends_at' => $timing['timer'] === 'synchronized' ? self::plusSeconds($activated, $timing['duration']) : null,
                'closed_at' => $state === 'closed' ? self::at('closed') : null] + $stamps;
        }
        foreach ($manifest['recipients'] as $name => $students) {
            $official = self::ASSESSMENTS[$name][3] === null;
            $assignedAt = $official ? (self::ASSESSMENTS[$name][0] === 'blitz' ? self::blitzActivation($name, $seededAt) : self::at('activated')) : self::at('created');
            foreach ($students as $student => $id) {
                $rows['assessment_students'][] = ['id' => $id, 'institution_id' => $manifest['institutions'][$institutionOf($name)], 'assessment_id' => $manifest['assessments'][$name],
                    'student_id' => $manifest['users'][$student], 'assigned_by_user_id' => $ownerOf($institutionOf($name)),
                    'assignment_source' => $official ? 'group' : 'direct', 'assigned_at' => $assignedAt] + $stamps;
            }
        }
        foreach (self::PAIRS as $topic => [$homework, $blitz]) {
            $institution = self::GROUPS[$topic][0];
            $active = collect(self::ATTEMPTS)->contains(fn (array $attempt): bool => in_array($attempt[0], [$homework, $blitz], true));
            $rows['topic_result_pairs'][] = ['id' => $manifest['pairs'][$topic], 'institution_id' => $manifest['institutions'][$institution], 'topic_id' => $manifest['topics'][$topic],
                'homework_assessment_id' => $manifest['assessments'][$homework], 'blitz_assessment_id' => $blitz === null ? null : $manifest['assessments'][$blitz],
                'designated_by_user_id' => $ownerOf($institution), 'designated_at' => self::at('designated'),
                'cohort_snapshotted_at' => self::at('activated'), 'locked_at' => $active ? self::at('history_start') : null] + $stamps;
        }
        foreach (['questions', ...self::QUESTION_CHILD_TABLES, 'question_fill_blank_accepted_answers'] as $table) {
            $rows[$table] = [];
        }
        foreach (self::QUESTIONS as $name => $questions) {
            $institution = $manifest['institutions'][$institutionOf($name)];
            foreach ($questions as $position => [$type, $points, $configuration]) {
                $label = 'q'.($position + 1);
                $questionId = $manifest['questions'][$name][$label];
                $nested = $manifest['nested'][$name][$label];
                $manual = in_array($type, ['open_written', 'file_based'], true) || ($configuration['manual'] ?? false);
                $rows['questions'][] = ['id' => $questionId, 'institution_id' => $institution, 'assessment_id' => $manifest['assessments'][$name],
                    // Activation validates every configuration, including the fill-in-blank placeholders.
                    'type' => $type, 'prompt' => 'E2E S09 '.$words($type).' question '.($position + 1).($type === 'fill_in_blank' ? ' {{blank1}} and {{blank2}}' : ''),
                    'instructions' => null, 'points' => $points.'.000000', 'position' => $position + 1, 'checking_mode' => $manual ? 'manual' : 'automatic'] + $stamps;
                $parent = ['institution_id' => $institution, 'question_id' => $questionId] + $stamps;
                if (in_array($type, ['single_choice', 'multiple_choice'], true)) {
                    foreach ($nested as $index => $optionId) {
                        $rows['question_choice_options'][] = ['id' => $optionId, 'option_text' => 'E2E S09 Option '.($index + 1), 'position' => $index + 1,
                            'is_correct' => in_array($index + 1, $configuration['correct'], true)] + $parent;
                    }
                } elseif ($type === 'true_false') {
                    $rows['question_true_false_answers'][] = ['correct_value' => $configuration['correct']] + $parent;
                } elseif ($type === 'short_written' && isset($configuration['accepted'])) {
                    $rows['question_short_accepted_answers'][] = ['id' => $nested['accepted'], 'accepted_text' => $configuration['accepted'][0], 'position' => 1] + $parent;
                } elseif ($type === 'matching') {
                    foreach (['left' => 'Left', 'right' => 'Right'] as $side => $sideLabel) {
                        foreach ($nested[$side] as $index => $itemId) {
                            $rows['question_matching_items'][] = ['id' => $itemId, 'side' => $side, 'match_key' => $nested['keys'][$index],
                                'item_text' => 'E2E S09 '.$sideLabel.' '.($index + 1), 'position' => $index + 1] + $parent;
                        }
                    }
                } elseif ($type === 'ordering') {
                    foreach ($nested as $index => $itemId) {
                        $rows['question_ordering_items'][] = ['id' => $itemId, 'item_text' => 'E2E S09 Order '.($index + 1), 'correct_position' => $index + 1] + $parent;
                    }
                } elseif ($type === 'fill_in_blank') {
                    foreach ($nested['blanks'] as $index => $blankId) {
                        $rows['question_fill_blanks'][] = ['id' => $blankId, 'blank_key' => 'blank'.($index + 1), 'position' => $index + 1] + $parent;
                        $rows['question_fill_blank_accepted_answers'][] = ['id' => $nested['accepted'][$index], 'institution_id' => $institution,
                            'blank_id' => $blankId, 'accepted_text' => $configuration['blanks'][$index], 'position' => 1] + $stamps;
                    }
                }
            }
        }
        foreach (['assessment_attempts', 'attempt_answers', ...self::ANSWER_TABLES] as $table) {
            $rows[$table] = [];
        }
        foreach (self::ATTEMPTS as $name => [$assessment, $student, $status, $answers]) {
            $institution = $manifest['institutions'][$institutionOf($assessment)];
            [$started, $deadline, $finalized, $reason] = self::attemptTimes($name, $seededAt);
            // Only the repair fixture is seeded checked: every answer is fully correct, so it earns all points.
            $checked = $status === 'checked';
            $possible = array_sum(array_column(self::QUESTIONS[$assessment], 1));
            $rows['assessment_attempts'][] = ['id' => $manifest['attempts'][$name], 'institution_id' => $institution,
                'assessment_id' => $manifest['assessments'][$assessment], 'assessment_student_id' => $manifest['recipients'][$assessment][$student],
                'student_id' => $manifest['users'][$student], 'attempt_number' => 1, 'status' => $status, 'started_at' => $started,
                'deadline_at' => $deadline, 'submitted_at' => $reason === 'student_submit' ? $finalized : null, 'finalized_at' => $finalized,
                'finalization_reason' => $reason, 'locked_at' => $finalized, 'official_score_eligible' => true,
                'possible_points' => $possible.'.000000',
                'earned_points' => $checked ? $possible.'.00000000' : null, 'normalized_score' => $checked ? '100.00000000' : null,
                'scoring_completed_at' => $checked ? self::at('history_checked') : null,
                'created_at' => $started, 'updated_at' => $finalized ?? $started];
            $answeredAt = self::plusSeconds($started, 60);
            foreach ($answers as $label => $value) {
                $answerId = $manifest['answers'][$name][$label];
                $position = (int) substr($label, 1);
                $rows['attempt_answers'][] = ['id' => $answerId, 'institution_id' => $institution, 'attempt_id' => $manifest['attempts'][$name],
                    'question_id' => $manifest['questions'][$assessment][$label], 'checking_status' => $checked ? 'auto_checked' : 'pending',
                    'awarded_points' => $checked ? self::QUESTIONS[$assessment][$position - 1][1].'.00000000' : null, 'feedback' => null, 'checked_by_user_id' => null,
                    'checked_at' => $checked ? self::at('history_checked') : null, 'created_at' => $answeredAt, 'updated_at' => $answeredAt];
                $nested = $manifest['nested'][$assessment][$label];
                $child = ['answer_id' => $answerId, 'institution_id' => $institution, 'created_at' => $answeredAt];
                $childId = fn (int $k): string => self::id(5_000_000 + (int) substr($manifest['attempts'][$name], -3) * 10_000 + $position * 100 + $k);
                if (isset($value['choice'])) {
                    foreach ($value['choice'] as $optionPosition) {
                        $rows['answer_choice_selections'][] = ['option_id' => $nested[$optionPosition - 1]] + $child;
                    }
                } elseif (isset($value['text'])) {
                    $rows['answer_text_values'][] = ['text_value' => $value['text'], 'updated_at' => $answeredAt] + $child;
                } elseif (array_key_exists('boolean', $value)) {
                    $rows['answer_boolean_values'][] = ['boolean_value' => $value['boolean'], 'updated_at' => $answeredAt] + $child;
                } elseif (isset($value['blanks'])) {
                    foreach ($value['blanks'] as $index => $text) {
                        $rows['answer_fill_blank_values'][] = ['id' => $childId($index + 1), 'blank_id' => $nested['blanks'][$index], 'text_value' => $text, 'updated_at' => $answeredAt] + $child;
                    }
                } elseif (isset($value['matching'])) {
                    foreach ($value['matching'] as $leftIndex => $rightIndex) {
                        $rows['answer_matching_pairs'][] = ['id' => $childId($leftIndex + 1), 'left_item_id' => $nested['left'][$leftIndex], 'right_item_id' => $nested['right'][$rightIndex]] + $child;
                    }
                } elseif (isset($value['ordering'])) {
                    foreach ($value['ordering'] as $itemIndex => $submittedPosition) {
                        $rows['answer_ordering_items'][] = ['id' => $childId($itemIndex + 1), 'ordering_item_id' => $nested[$itemIndex], 'submitted_position' => $submittedPosition] + $child;
                    }
                }
            }
        }

        return array_filter($rows, fn (array $tableRows): bool => $tableRows !== []);
    }

    private static function blitzActivation(string $assessment, string $seededAt): string
    {
        return match (self::ASSESSMENTS[$assessment][4]['activated']) {
            'seed' => $seededAt,
            'hour_ago' => self::plusSeconds($seededAt, -3600),
            default => self::at('activated'),
        };
    }

    /** @return array{0: string, 1: ?string, 2: ?string, 3: ?string} started, deadline, finalized, finalization reason */
    private static function attemptTimes(string $attempt, string $seededAt): array
    {
        return match ($attempt) {
            'backfill_blitz_1' => [self::at('history_start'), self::plusSeconds(self::at('history_start'), 600), self::plusSeconds(self::at('history_start'), 600), 'timeout_auto_submit'],
            'deadline_hw_1' => [self::plusSeconds($seededAt, -1800), self::plusSeconds($seededAt, -600), null, null],
            'timeout_blitz_1' => [self::plusSeconds($seededAt, -1200), self::plusSeconds($seededAt, -600), null, null],
            default => [self::at('history_start'), null, self::at('history_submitted'), 'student_submit'],
        };
    }

    /** Unrelated graph used only to prove Stage 9 cleanup and the scheduled commands never touch foreign rows. */
    public static function sentinelRows(): array
    {
        $s = self::sentinelId(...);
        $stamps = ['created_at' => self::at('created'), 'updated_at' => self::at('created')];
        [$institution, $teacher, $student, $group, $topic, $homework, $recipient] = [$s(1), $s(101), $s(102), $s(201), $s(401), $s(501), $s(601)];
        [$choiceQuestion, $fileQuestion, $option, $attempt, $choiceAnswer, $fileAnswer, $file] = [$s(701), $s(702), $s(711), $s(801), $s(901), $s(902), $s(1001)];
        $blob = self::sentinelBlob();

        return [
            'institutions' => [['id' => $institution, 'name' => 'E2E S09 Unrelated Sentinel Institution', 'type' => 'school', 'status' => 'active'] + $stamps],
            'users' => [
                ['id' => $teacher, 'institution_id' => $institution, 'role' => 'teacher', 'full_name' => 'E2E S09 Sentinel Teacher', 'login_name' => 'e2e_s09_sentinel_teacher', 'is_active' => true, 'must_change_password' => false] + $stamps,
                ['id' => $student, 'institution_id' => $institution, 'role' => 'student', 'full_name' => 'E2E S09 Sentinel Student', 'login_name' => 'e2e_s09_sentinel_student', 'is_active' => true, 'must_change_password' => false] + $stamps,
            ],
            'institution_settings' => [['institution_id' => $institution, 'timezone' => 'Asia/Tashkent', 'blitz_timer_start_mode' => 'individual', 'learning_material_max_mb' => 25, 'student_submission_max_mb' => 15] + $stamps],
            'groups' => [['id' => $group, 'institution_id' => $institution, 'name' => 'E2E S09 Sentinel Group', 'status' => 'active', 'created_by_user_id' => $teacher] + $stamps],
            'group_teacher_memberships' => [['id' => $s(301), 'institution_id' => $institution, 'group_id' => $group, 'teacher_id' => $teacher, 'assigned_by_user_id' => $teacher, 'started_at' => self::at('created'), 'ended_at' => null] + $stamps],
            'group_student_memberships' => [['id' => $s(302), 'institution_id' => $institution, 'group_id' => $group, 'student_id' => $student, 'assigned_by_user_id' => $teacher, 'started_at' => self::at('created'), 'ended_at' => null] + $stamps],
            'topics' => [['id' => $topic, 'institution_id' => $institution, 'group_id' => $group, 'teacher_id' => $teacher, 'title' => 'E2E S09 Sentinel Topic', 'subject' => 'E2E S09', 'student_instructions' => 'E2E S09 Sentinel', 'status' => 'active', 'activated_at' => self::at('activated')] + $stamps],
            'assessments' => [['id' => $homework, 'institution_id' => $institution, 'topic_id' => $topic, 'teacher_id' => $teacher, 'type' => 'homework', 'title' => 'E2E S09 Sentinel Homework', 'student_instructions' => 'E2E S09 Sentinel', 'assignment_mode' => 'selected_students', 'total_possible_points' => '2.000000'] + $stamps],
            'homework_assignments' => [['assessment_id' => $homework, 'institution_id' => $institution, 'status' => 'closed', 'deadline_at' => null, 'activated_at' => self::at('activated'), 'closed_at' => self::at('closed')] + $stamps],
            'assessment_students' => [['id' => $recipient, 'institution_id' => $institution, 'assessment_id' => $homework, 'student_id' => $student, 'assigned_by_user_id' => $teacher, 'assignment_source' => 'direct', 'assigned_at' => self::at('created')] + $stamps],
            'questions' => [
                ['id' => $choiceQuestion, 'institution_id' => $institution, 'assessment_id' => $homework, 'type' => 'single_choice', 'prompt' => 'E2E S09 Sentinel', 'instructions' => null, 'points' => '1.000000', 'position' => 1, 'checking_mode' => 'automatic'] + $stamps,
                ['id' => $fileQuestion, 'institution_id' => $institution, 'assessment_id' => $homework, 'type' => 'file_based', 'prompt' => 'E2E S09 Sentinel', 'instructions' => null, 'points' => '1.000000', 'position' => 2, 'checking_mode' => 'manual'] + $stamps,
            ],
            'question_choice_options' => [
                ['id' => $option, 'institution_id' => $institution, 'question_id' => $choiceQuestion, 'option_text' => 'E2E S09 Sentinel A', 'position' => 1, 'is_correct' => true] + $stamps,
                ['id' => $s(712), 'institution_id' => $institution, 'question_id' => $choiceQuestion, 'option_text' => 'E2E S09 Sentinel B', 'position' => 2, 'is_correct' => false] + $stamps,
            ],
            // Checked and outside any result pair: never a candidate of a scheduled command or of the repair.
            'assessment_attempts' => [['id' => $attempt, 'institution_id' => $institution, 'assessment_id' => $homework, 'assessment_student_id' => $recipient, 'student_id' => $student, 'attempt_number' => 1, 'status' => 'checked', 'started_at' => self::at('history_start'), 'deadline_at' => null, 'submitted_at' => self::at('history_submitted'), 'finalized_at' => self::at('history_submitted'), 'finalization_reason' => 'student_submit', 'locked_at' => self::at('history_submitted'), 'official_score_eligible' => true, 'possible_points' => '2.000000', 'earned_points' => '2.00000000', 'normalized_score' => '100.00000000', 'scoring_completed_at' => self::at('history_checked'), 'created_at' => self::at('history_start'), 'updated_at' => self::at('history_checked')]],
            'attempt_answers' => [
                ['id' => $choiceAnswer, 'institution_id' => $institution, 'attempt_id' => $attempt, 'question_id' => $choiceQuestion, 'checking_status' => 'auto_checked', 'awarded_points' => '1.00000000', 'feedback' => null, 'checked_by_user_id' => null, 'checked_at' => self::at('history_checked'), 'created_at' => self::at('history_answered'), 'updated_at' => self::at('history_answered')],
                ['id' => $fileAnswer, 'institution_id' => $institution, 'attempt_id' => $attempt, 'question_id' => $fileQuestion, 'checking_status' => 'teacher_checked', 'awarded_points' => '1.00000000', 'feedback' => 'E2E S09 sentinel feedback', 'checked_by_user_id' => $teacher, 'checked_at' => self::at('history_checked'), 'created_at' => self::at('history_answered'), 'updated_at' => self::at('history_answered')],
            ],
            'answer_choice_selections' => [['answer_id' => $choiceAnswer, 'option_id' => $option, 'institution_id' => $institution, 'created_at' => self::at('history_answered')]],
            'files' => [['id' => $file, 'institution_id' => $institution, 'uploaded_by_user_id' => $student, 'category' => 'student_submission', 'original_name' => 'e2e_s09_sentinel.pdf', 'storage_disk' => 'local', 'storage_key' => $blob['key'], 'mime_type' => 'application/pdf', 'extension' => 'pdf', 'size_bytes' => strlen($blob['bytes']), 'checksum_sha256' => hash('sha256', $blob['bytes']), 'created_at' => self::at('history_answered'), 'updated_at' => self::at('history_answered')]],
            'answer_files' => [['id' => $s(1201), 'institution_id' => $institution, 'answer_id' => $fileAnswer, 'file_id' => $file, 'created_at' => self::at('history_answered')]],
        ];
    }

    /** @return array{key: string, bytes: string} */
    public static function sentinelBlob(): array
    {
        return ['key' => 'student-submissions/'.self::sentinelId(1).'/'.self::sentinelId(801).'/'.self::sentinelId(702).'/'.self::sentinelId(1301).'.pdf',
            'bytes' => "%PDF-1.7\nE2E S09 unrelated private sentinel bytes\n%%EOF\n"];
    }
}
