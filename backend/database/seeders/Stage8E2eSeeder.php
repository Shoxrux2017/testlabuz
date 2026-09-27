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

class Stage8E2eSeeder extends Seeder
{
    public const QUESTION_TYPES = ['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'file_based', 'matching', 'ordering', 'fill_in_blank'];

    /** Keeps the Scheduler aggregate's seeded replacement #2 future for the whole run while #1 stays due. */
    public const SCHEDULER_DURATION = 2592000;

    public const PRIMARY_KEYS = ['institution_settings' => 'institution_id', 'blitz_tasks' => 'assessment_id', 'homework_assignments' => 'assessment_id', 'question_true_false_answers' => 'question_id'];

    /** Static columns that the scenarios legitimately change; ownership still requires an owned value. */
    public const MUTABLE_COLUMNS = ['topic_result_pairs' => ['blitz_assessment_id', 'designated_by_user_id'], 'blitz_tasks' => ['activated_by_user_id']];

    public const IDEMPOTENCY_OPERATIONS = ['teacher.blitz.activate', 'teacher.blitz.attempt_exception.grant', 'student.blitz.attempt.start', 'student.blitz.attempt.submit', 'student.homework.attempt.start', 'student.homework.attempt.submit'];

    private const ANSWER_TABLES = ['answer_choice_selections', 'answer_text_values', 'answer_boolean_values', 'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files'];

    private const QUESTION_CHILD_TABLES = ['question_choice_options', 'question_true_false_answers', 'question_short_accepted_answers', 'question_matching_items', 'question_ordering_items', 'question_fill_blanks'];

    private const INSTITUTIONS = ['target' => 'synchronized', 'foreign' => 'synchronized', 'unset' => null, 'individual' => 'individual'];

    private const TEACHERS = ['target' => 'teacher', 'foreign' => 'foreign_teacher', 'unset' => 'unset_teacher', 'individual' => 'individual_teacher'];

    private const INDIVIDUAL_STUDENTS = ['d_matrix', 'd_matrix_peer', 'd_timeout_resume', 'd_late_submit', 'd_waiting', 'd_checked', 'd_first', 'd_second', 'd_timeout_ui', 'd_late_typed', 'd_late_file', 'd_race_typed', 'd_race_file', 'd_close_due', 'd_close_future', 'd_close_never', 'mon_due', 'mon_exception', 'mon_never', 'mon_inactive', 'mon_submitted'];

    /** Group => [institution, members since creation, members who joined after the official cohort]. */
    private const GROUPS = [
        'builder' => ['target', [], []],
        'official' => ['target', ['student', 'peer'], ['late_member']],
        'sync_replacement' => ['target', ['sync_replacement'], []],
        'scheduler' => ['target', ['sched_due', 'sched_future'], []],
        'practice' => ['target', ['practice_member', 'practice_outsider'], []],
        'blitz_first' => ['target', ['bf_one', 'bf_two'], []],
        'android' => ['target', ['android_student'], []],
        'foreign' => ['foreign', ['foreign_student'], []],
        'unset' => ['unset', ['unset_student'], []],
        'individual' => ['individual', self::INDIVIDUAL_STUDENTS, []],
    ];

    /** Every Topic belongs to the same-named Group. */
    private const ASSESSMENTS = [
        'main' => ['blitz', 'official', 'group', 'draft', 1800, 'main', []],
        'official_homework' => ['homework', 'official', 'group', 'active', null, 'short', ['student', 'peer']],
        'sync_replacement' => ['blitz', 'sync_replacement', 'group', 'draft', 8, 'short', []],
        'scheduler' => ['blitz', 'scheduler', 'group', 'active', self::SCHEDULER_DURATION, 'short', ['sched_due', 'sched_future']],
        'practice_homework' => ['homework', 'practice', 'group', 'draft', null, 'short', []],
        'practice_blitz' => ['blitz', 'practice', 'selected_students', 'draft', 7200, 'short', ['practice_member']],
        'bf_homework' => ['homework', 'blitz_first', 'group', 'draft', null, 'short', []],
        'bf_blitz' => ['blitz', 'blitz_first', 'group', 'draft', 7200, 'short', []],
        'android' => ['blitz', 'android', 'group', 'draft', 1800, 'android', []],
        'foreign' => ['blitz', 'foreign', 'group', 'draft', 7200, 'short_file', []],
        'unset' => ['blitz', 'unset', 'group', 'draft', 600, 'short', []],
        'matrix' => ['blitz', 'individual', 'selected_students', 'active', 7200, 'nine', ['d_matrix', 'd_matrix_peer']],
        'matrix_other' => ['blitz', 'individual', 'selected_students', 'active', 7200, 'short', ['d_matrix']],
        'matrix_timeout' => ['blitz', 'individual', 'selected_students', 'active', 3, 'short', ['d_timeout_resume']],
        'matrix_late_submit' => ['blitz', 'individual', 'selected_students', 'active', 3, 'short', ['d_late_submit']],
        'forward_status' => ['blitz', 'individual', 'selected_students', 'active', 7200, 'short', ['d_waiting', 'd_checked']],
        'activation_idem' => ['blitz', 'individual', 'selected_students', 'draft', 7200, 'short', ['d_second']],
        'activation_idem_other' => ['blitz', 'individual', 'selected_students', 'draft', 7200, 'short', ['d_second']],
        'individual_timing' => ['blitz', 'individual', 'selected_students', 'draft', 7200, 'short', ['d_first', 'd_second']],
        'timeout_ui' => ['blitz', 'individual', 'selected_students', 'active', 45, 'short_open', ['d_timeout_ui']],
        'late_typed' => ['blitz', 'individual', 'selected_students', 'active', 6, 'short', ['d_late_typed']],
        'late_file' => ['blitz', 'individual', 'selected_students', 'active', 8, 'file', ['d_late_file']],
        'race_typed' => ['blitz', 'individual', 'selected_students', 'active', 3600, 'short', ['d_race_typed']],
        'race_file' => ['blitz', 'individual', 'selected_students', 'active', 3600, 'file', ['d_race_file']],
        'close' => ['blitz', 'individual', 'selected_students', 'active', 600, 'short', ['d_close_due', 'd_close_future', 'd_close_never']],
        'monitoring' => ['blitz', 'individual', 'selected_students', 'active', 600, 'short', ['mon_due', 'mon_exception', 'mon_never', 'mon_inactive', 'mon_submitted']],
    ];

    /** Pair => [Topic, official Homework, official Blitz, cohort established, locked]. */
    private const PAIRS = [
        'official' => ['official', 'official_homework', null, true, true],
        'practice' => ['practice', 'practice_homework', null, false, false],
        'blitz_first' => ['blitz_first', 'bf_homework', 'bf_blitz', false, false],
    ];

    /** Seeded Attempt => [Assessment, Student, number, status, started, submitted/finalized, reason, deadline source]. */
    private const ATTEMPTS = [
        'sched_due_1' => ['scheduler', 'sched_due', 1, 'in_progress', 'blitz_start', null, null, 'common_end'],
        'sched_future_1' => ['scheduler', 'sched_future', 1, 'submitted', 'blitz_peer_start', 'blitz_submitted', 'student_submit', 'common_end'],
        'sched_future_2' => ['scheduler', 'sched_future', 2, 'in_progress', 'seeded', null, null, 'own_duration'],
        'official_homework_1' => ['official_homework', 'student', 1, 'submitted', 'homework_start', 'homework_submitted', 'student_submit', null],
        'close_due_1' => ['close', 'd_close_due', 1, 'in_progress', 'history', null, null, 'own_duration'],
        'mon_due_1' => ['monitoring', 'mon_due', 1, 'in_progress', 'history', null, null, 'own_duration'],
        'mon_exception_1' => ['monitoring', 'mon_exception', 1, 'submitted', 'history', 'history_submitted', 'student_submit', 'own_duration'],
        'mon_submitted_1' => ['monitoring', 'mon_submitted', 1, 'submitted', 'history', 'history_submitted', 'student_submit', 'own_duration'],
        'waiting_1' => ['forward_status', 'd_waiting', 1, 'waiting_for_teacher_review', 'history', 'history_submitted', 'student_submit', 'own_duration'],
        'checked_1' => ['forward_status', 'd_checked', 1, 'checked', 'history', 'history_submitted', 'student_submit', 'own_duration'],
    ];

    /** Seeded exception => [Assessment, Student, invalidated Attempt, replacement Attempt, granted]. */
    private const EXCEPTIONS = [
        'sched_future' => ['scheduler', 'sched_future', 'sched_future_1', 'sched_future_2', 'blitz_granted'],
        'mon_exception' => ['monitoring', 'mon_exception', 'mon_exception_1', null, 'history_granted'],
    ];

    private const TIMESTAMPS = [
        'created' => '2020-01-01 00:00:00+00',
        'designated' => '2020-01-01 12:00:00+00',
        'activated' => '2020-01-02 00:00:00+00',
        'blitz_start' => '2020-01-02 00:01:00+00',
        'blitz_peer_start' => '2020-01-02 00:02:00+00',
        'blitz_submitted' => '2020-01-02 00:05:00+00',
        'blitz_granted' => '2020-01-02 00:20:00+00',
        'homework_start' => '2020-01-02 01:00:00+00',
        'homework_submitted' => '2020-01-02 01:01:00+00',
        'late_join' => '2020-01-03 00:00:00+00',
        'history' => '2020-01-03 00:00:00+00',
        'history_submitted' => '2020-01-03 00:05:00+00',
        'history_granted' => '2020-01-03 00:20:00+00',
        'future_deadline' => '2099-12-31 00:00:00+00',
    ];

    /** Only used where identity, not the seeded clock, is compared. */
    private const IDENTITY_CLOCK = '2026-01-01 00:00:00+00';

    public static function id(int $number): string
    {
        return sprintf('08000000-0000-4000-8000-%012d', $number);
    }

    public static function sentinelId(int $number): string
    {
        return sprintf('08999999-0000-4000-8000-%012d', $number);
    }

    public static function questionSets(): array
    {
        $nine = array_combine(self::QUESTION_TYPES, self::QUESTION_TYPES);

        return [
            'main' => $nine + ['unanswered' => 'short_written'],
            'nine' => $nine,
            'short' => ['short_written' => 'short_written'],
            'file' => ['file_based' => 'file_based'],
            'short_file' => ['short_written' => 'short_written', 'file_based' => 'file_based'],
            'short_open' => ['short_written' => 'short_written', 'open_written' => 'open_written'],
            'android' => ['single_choice' => 'single_choice', 'short_written' => 'short_written', 'open_written' => 'open_written'],
        ];
    }

    /** Every static row identity and the exact parents that own runtime rows. */
    public static function manifest(): array
    {
        $manifest = ['timestamps' => self::TIMESTAMPS, 'scheduler_duration' => self::SCHEDULER_DURATION];
        $index = 0;
        foreach (array_keys(self::INSTITUTIONS) as $name) {
            $manifest['institutions'][$name] = self::id(++$index);
        }
        $index = 100;
        foreach (self::users() as $name => $institution) {
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
            $manifest[$type === 'blitz' ? 'blitz' : 'homework'][$name] = self::id($number);
            foreach (array_keys(self::questionSets()[self::ASSESSMENTS[$name][5]]) as $position => $label) {
                $questionNumber = 1_000_000 + $number * 100 + $position + 1;
                $manifest['questions'][$name][$label] = self::id($questionNumber);
                $manifest['nested'][$name][$label] = self::nestedIds(self::questionSets()[self::ASSESSMENTS[$name][5]][$label], $questionNumber);
            }
            foreach (self::ASSESSMENTS[$name][6] as $recipientIndex => $student) {
                $manifest['recipients'][$name][$student] = self::id(2_000_000 + $number * 100 + $recipientIndex + 1);
            }
        }
        $index = 600;
        foreach (array_keys(self::PAIRS) as $name) {
            $manifest['pairs'][$name] = self::id(++$index);
        }
        $index = 3_000_000;
        foreach (array_keys(self::ATTEMPTS) as $name) {
            $manifest['attempts'][$name] = self::id(++$index);
        }
        $index = 6_000_000;
        foreach (array_keys(self::EXCEPTIONS) as $name) {
            $manifest['exceptions'][$name] = self::id(++$index);
        }
        foreach (self::fixtureRows($manifest, self::IDENTITY_CLOCK) as $table => $rows) {
            $manifest['db'][$table] = array_column($rows, self::PRIMARY_KEYS[$table] ?? 'id');
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
        $state = ['db' => [], 'dynamic' => [], 'blobs' => [], 'directories' => [], 'answer_children' => []];
        foreach ($expectedRows as $table => $expected) {
            $primaryKey = self::PRIMARY_KEYS[$table] ?? 'id';
            $state['db'][$table] = [];
            foreach ($expected as $identity) {
                $row = DB::table($table)->where($primaryKey, $identity[$primaryKey])->first();
                if ($row === null) {
                    continue;
                }
                foreach ($identity as $column => $value) {
                    if (in_array($column, self::MUTABLE_COLUMNS[$table] ?? [], true)) {
                        $this->require($row->{$column} === null || $row->{$column} === $value
                            || in_array($row->{$column}, $table === 'topic_result_pairs' && $column === 'blitz_assessment_id' ? $manifest['blitz'] : $manifest['users'], true),
                            'Static Stage 8 ownership mismatch: '.$table.'.'.$column);
                    } elseif ($column === $primaryKey || str_ends_with($column, '_id') || in_array($column, ['login_name', 'name', 'title', 'role', 'type', 'assignment_mode', 'assignment_source'], true)) {
                        $this->require($row->{$column} === $value, 'Static Stage 8 ownership mismatch: '.$table.'.'.$column);
                    }
                }
                $state['db'][$table][] = $identity[$primaryKey];
            }
        }

        $topics = collect($expectedRows['topics'])->keyBy('id');
        $dynamicAssessments = DB::table('assessments')->whereIn('topic_id', $manifest['topics'])->whereNotIn('id', $manifest['assessments'])->get();
        foreach ($dynamicAssessments as $assessment) {
            $topic = $topics[$assessment->topic_id];
            // Only the Builder smoke Topic is authored through the UI; every other Topic must stay static.
            $this->require($assessment->topic_id === $manifest['topics']['builder'] && $assessment->type === 'blitz'
                && $assessment->institution_id === $topic['institution_id'] && $assessment->teacher_id === $topic['teacher_id'],
                'Unexpected runtime Stage 8 assessment ownership.');
        }
        $state['dynamic']['assessments'] = $dynamicAssessments->pluck('id')->all();
        $ownedAssessments = collect($expectedRows['assessments'])->merge($dynamicAssessments->map(fn (object $row): array => (array) $row))->keyBy('id');
        $state['dynamic']['blitz_tasks'] = DB::table('blitz_tasks')->whereIn('assessment_id', $state['dynamic']['assessments'])->pluck('assessment_id')->all();
        $this->require(DB::table('homework_assignments')->whereIn('assessment_id', $state['dynamic']['assessments'])->doesntExist(), 'Unexpected runtime Stage 8 Homework.');

        $questions = DB::table('questions')->whereIn('assessment_id', $ownedAssessments->keys())->get();
        foreach ($questions as $question) {
            $this->require($question->institution_id === $ownedAssessments[$question->assessment_id]['institution_id'], 'Stage 8 Question ownership mismatch.');
        }
        $state['dynamic']['questions'] = $questions->pluck('id')->diff($manifest['db']['questions'])->values()->all();
        foreach (self::QUESTION_CHILD_TABLES as $table) {
            $column = $table === 'question_true_false_answers' ? 'question_id' : 'id';
            $state['dynamic'][$table] = DB::table($table)->whereIn('question_id', $state['dynamic']['questions'])->pluck($column)->all();
        }
        $state['dynamic']['question_fill_blank_accepted_answers'] = DB::table('question_fill_blank_accepted_answers')
            ->whereIn('blank_id', $state['dynamic']['question_fill_blanks'])->pluck('id')->all();
        $questions = $questions->keyBy('id');

        $recipients = DB::table('assessment_students')->whereIn('assessment_id', $ownedAssessments->keys())->get();
        foreach ($recipients as $recipient) {
            $student = $users->get($recipient->student_id);
            $this->require($student !== null && $student['institution_id'] === $recipient->institution_id
                && $recipient->institution_id === $ownedAssessments[$recipient->assessment_id]['institution_id'], 'Stage 8 recipient ownership mismatch.');
        }
        $state['dynamic']['assessment_students'] = $recipients->pluck('id')->diff($manifest['db']['assessment_students'])->values()->all();
        $recipients = $recipients->keyBy('id');

        $attemptRows = DB::table('assessment_attempts')->whereIn('assessment_id', $ownedAssessments->keys())->get();
        foreach ($attemptRows as $attempt) {
            $recipient = $recipients->get($attempt->assessment_student_id);
            $this->require($recipient !== null && $recipient->assessment_id === $attempt->assessment_id
                && $recipient->institution_id === $attempt->institution_id && $recipient->student_id === $attempt->student_id,
                'Stage 8 Attempt ownership mismatch.');
        }
        $state['db']['assessment_attempts'] = $attemptRows->pluck('id')->all();
        $attempts = $attemptRows->keyBy('id');

        $exceptions = DB::table('blitz_attempt_exceptions')->whereIn('assessment_id', $ownedAssessments->keys())->get();
        foreach ($exceptions as $exception) {
            $this->require($attempts->has($exception->invalidated_attempt_id)
                && ($exception->replacement_attempt_id === null || $attempts->has($exception->replacement_attempt_id))
                && $exception->institution_id === $attempts[$exception->invalidated_attempt_id]->institution_id,
                'Stage 8 exception ownership mismatch.');
        }
        $state['db']['blitz_attempt_exceptions'] = $exceptions->pluck('id')->all();

        $answerRows = DB::table('attempt_answers')->whereIn('attempt_id', $state['db']['assessment_attempts'])->get();
        foreach ($answerRows as $answer) {
            $question = $questions->get($answer->question_id);
            $attempt = $attempts->get($answer->attempt_id);
            $this->require($question !== null && $question->assessment_id === $attempt->assessment_id
                && $answer->institution_id === $attempt->institution_id && $question->institution_id === $answer->institution_id,
                'Stage 8 answer ownership mismatch.');
        }
        $state['db']['attempt_answers'] = $answerRows->pluck('id')->all();
        $answers = $answerRows->keyBy('id');
        foreach (self::ANSWER_TABLES as $table) {
            $rows = DB::table($table)->whereIn('answer_id', $state['db']['attempt_answers'])->get();
            foreach ($rows as $row) {
                $this->require($row->institution_id === $answers[$row->answer_id]->institution_id, 'Stage 8 typed-answer ownership mismatch.');
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
                && $questions[$answer->question_id]->type === 'file_based', 'Stage 8 File ownership mismatch.');
            $this->require($this->isSubmissionKey($file->storage_key, $directory), 'Stage 8 private blob ownership mismatch.');
            $state['blobs'][] = ['disk' => $disk, 'key' => $file->storage_key];
        }
        $this->require($fileRows->count() === $fileLinks->count(), 'Stage 8 linked File missing.');
        $state['db']['files'] = $fileRows->pluck('id')->all();
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
                    $this->require($this->isSubmissionKey($key, $directory), 'Unexpected file in Stage 8 submission namespace.');
                    $state['blobs'][] = ['disk' => $disk, 'key' => $key];
                }
            }
        }
        $state['blobs'] = array_values(array_unique($state['blobs'], SORT_REGULAR));

        $owners = ['blitz' => $ownedAssessments->keys()->all(), 'assessment_attempt' => $state['db']['assessment_attempts'], 'blitz_attempt_exception' => $state['db']['blitz_attempt_exceptions']];
        $records = DB::table('idempotency_records')->whereIn('user_id', $manifest['users'])->get();
        foreach ($records as $record) {
            $user = $users[$record->user_id];
            $this->require(in_array($record->operation, self::IDEMPOTENCY_OPERATIONS, true) && $record->institution_id === $user['institution_id']
                && in_array($record->result_resource_id, $owners[$record->result_resource_type] ?? [], true),
                'Unowned or incomplete idempotency record in Stage 8 actor scope.');
        }
        $state['db']['idempotency_records'] = $records->pluck('id')->all();
        $state['db']['personal_access_tokens'] = DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
            ->whereIn('tokenable_id', $manifest['users'])->pluck('id')->all();

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
            foreach (['blitz_attempt_exceptions', 'idempotency_records', 'attempt_answers', 'assessment_attempts', 'files', 'personal_access_tokens'] as $table) {
                DB::table($table)->whereIn('id', $state['db'][$table])->delete();
            }
            $dynamic = $state['dynamic'];
            DB::table('question_fill_blank_accepted_answers')->whereIn('id', $dynamic['question_fill_blank_accepted_answers'])->delete();
            foreach (self::QUESTION_CHILD_TABLES as $table) {
                DB::table($table)->whereIn($table === 'question_true_false_answers' ? 'question_id' : 'id', $dynamic[$table])->delete();
            }
            DB::table('questions')->whereIn('id', $dynamic['questions'])->delete();
            DB::table('assessment_students')->whereIn('id', $dynamic['assessment_students'])->delete();
            DB::table('blitz_tasks')->whereIn('assessment_id', $dynamic['blitz_tasks'])->delete();
            DB::table('assessments')->whereIn('id', $dynamic['assessments'])->delete();
            foreach (array_reverse(array_keys(self::fixtureRows(self::manifest(), self::IDENTITY_CLOCK))) as $table) {
                if (in_array($table, ['assessment_attempts', 'blitz_attempt_exceptions'], true)) {
                    continue;
                }
                DB::table($table)->whereIn(self::PRIMARY_KEYS[$table] ?? 'id', $state['db'][$table])->delete();
            }
            foreach ($state['blobs'] as $blob) {
                $this->require(Storage::disk($blob['disk'])->delete($blob['key']), 'Stage 8 private blob cleanup failed.');
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
            $primaryKey = self::PRIMARY_KEYS[$table] ?? 'id';
            $expected += count($tableRows);
            $present += DB::table($table)->whereIn($primaryKey, array_column($tableRows, $primaryKey))->count();
        }
        $disk = $this->privateDisk();
        $blob = self::sentinelBlob();
        if ($present === 0) {
            $this->require(! Storage::disk($disk)->exists($blob['key']), 'Stage 8 sentinel blob exists without its rows.');
            DB::transaction(function () use ($rows): void {
                $password = Hash::make(Str::random(64));
                foreach ($rows as $table => $tableRows) {
                    if ($table === 'users') {
                        $tableRows = array_map(fn (array $row): array => $row + ['password' => $password], $tableRows);
                    }
                    DB::table($table)->insert($tableRows);
                }
            });
            $this->require(Storage::disk($disk)->put($blob['key'], $blob['bytes']), 'Stage 8 sentinel blob write failed.');

            return;
        }
        $this->require($present === $expected, 'Stage 8 sentinel graph is partial.');
        foreach ($rows as $table => $tableRows) {
            $primaryKey = self::PRIMARY_KEYS[$table] ?? 'id';
            foreach ($tableRows as $row) {
                $actual = (array) DB::table($table)->where($primaryKey, $row[$primaryKey])->first();
                foreach ($row as $column => $value) {
                    $this->require(in_array($column, ['created_at', 'updated_at', 'designated_at', 'cohort_snapshotted_at', 'locked_at', 'activated_at', 'closed_at', 'started_at', 'deadline_at', 'submitted_at', 'finalized_at', 'assigned_at'], true)
                        || $actual[$column] === $value, 'Stage 8 sentinel row changed: '.$table.'.'.$column);
                }
            }
        }
        $this->require(Storage::disk($disk)->get($blob['key']) === $blob['bytes'], 'Stage 8 sentinel blob changed.');
    }

    /** Read-only sentinel facts for exact before/after comparison. */
    public function sentinelState(): array
    {
        $this->guard(requirePassword: false);
        $state = ['rows' => []];
        foreach (self::sentinelRows() as $table => $tableRows) {
            $primaryKey = self::PRIMARY_KEYS[$table] ?? 'id';
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
        $rows = self::sentinelRows();
        DB::transaction(function () use ($rows): void {
            foreach (array_reverse(array_keys($rows)) as $table) {
                $primaryKey = self::PRIMARY_KEYS[$table] ?? 'id';
                DB::table($table)->whereIn($primaryKey, array_column($rows[$table], $primaryKey))->delete();
            }
            DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
                ->whereIn('tokenable_id', array_column($rows['users'], 'id'))->delete();
        });
        $disk = Storage::disk($this->privateDisk());
        $blob = self::sentinelBlob();
        if ($disk->exists($blob['key'])) {
            $this->require($disk->delete($blob['key']), 'Stage 8 sentinel blob cleanup failed.');
        }
    }

    protected function guard(bool $requirePassword = true): string
    {
        $this->require(app()->environment('testing'), 'Stage 8 fixtures require testing environment.');
        $this->require(DB::connection()->getDriverName() === 'pgsql', 'Stage 8 fixtures require PostgreSQL.');
        $this->require(DB::selectOne('select current_database() as database_name')->database_name === 'testlabuz_testing', 'Stage 8 fixtures require testlabuz_testing.');
        if (! $requirePassword) {
            return '';
        }
        $password = getenv('STAGE8_E2E_PASSWORD');
        $this->require(is_string($password) && trim($password) !== '', 'Stage 8 fixture password is required.');

        return $password;
    }

    private function privateDisk(): string
    {
        $disk = config('filesystems.private_files_disk');
        $configuration = is_string($disk) ? config('filesystems.disks.'.$disk) : null;
        $this->require(is_array($configuration) && ($configuration['visibility'] ?? null) !== 'public'
            && ($configuration['driver'] ?? null) === 'local', 'Stage 8 cleanup requires a private local disk.');
        $root = realpath($configuration['root']);
        $privateRoot = realpath(storage_path('app/private'));
        $this->require($root !== false && $privateRoot !== false && ($root === $privateRoot || str_starts_with($root, $privateRoot.DIRECTORY_SEPARATOR)), 'Stage 8 private disk root mismatch.');

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

    /** @return array<string, string> Student and Teacher name => institution. */
    private static function users(): array
    {
        $users = [];
        foreach (self::TEACHERS as $institution => $teacher) {
            $users[$teacher] = $institution;
        }
        foreach (self::GROUPS as [$institution, $members, $lateMembers]) {
            foreach ([...$members, ...$lateMembers] as $student) {
                $users[$student] = $institution;
            }
        }

        return $users;
    }

    private static function nestedIds(string $type, int $questionNumber): array
    {
        $nested = fn (int $offset): string => self::id($questionNumber * 100 + $offset);

        return match ($type) {
            'single_choice', 'multiple_choice' => array_map($nested, [1, 2, 3]),
            // Item IDs are public to Students, so their sort order must not reveal pairs or order.
            'matching' => ['left' => array_map($nested, [1, 2, 3]), 'right' => array_map($nested, [13, 11, 12]), 'keys' => array_map($nested, [21, 22, 23])],
            'ordering' => array_map($nested, [4, 2, 1, 3]),
            'fill_in_blank' => ['blanks' => array_map($nested, [1, 2]), 'accepted' => array_map($nested, [11, 12])],
            'short_written' => ['accepted' => $nested(1)],
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

    /** Non-secret exact fixture rows; insertion order is parent before child. */
    public static function fixtureRows(array $manifest, string $seededAt): array
    {
        $rows = [];
        $stamps = ['created_at' => self::at('created'), 'updated_at' => self::at('created')];
        $users = self::users();
        $teacherOf = fn (string $institution): string => $manifest['users'][self::TEACHERS[$institution]];
        foreach (self::INSTITUTIONS as $name => $timer) {
            $rows['institutions'][] = ['id' => $manifest['institutions'][$name], 'name' => 'E2E S08 '.ucfirst($name).' Institution', 'type' => 'school', 'status' => 'active'] + $stamps;
        }
        foreach ($users as $name => $institution) {
            $inactive = $name === 'mon_inactive';
            $rows['users'][] = ['id' => $manifest['users'][$name], 'institution_id' => $manifest['institutions'][$institution],
                'role' => in_array($name, self::TEACHERS, true) ? 'teacher' : 'student', 'full_name' => 'E2E S08 '.ucwords(str_replace('_', ' ', $name)),
                'login_name' => 'e2e_s08_'.$name, 'is_active' => ! $inactive, 'must_change_password' => false,
                'deactivated_at' => $inactive ? self::at('late_join') : null] + $stamps;
        }
        foreach (self::INSTITUTIONS as $name => $timer) {
            $rows['institution_settings'][] = ['institution_id' => $manifest['institutions'][$name], 'timezone' => 'Asia/Tashkent',
                'blitz_timer_start_mode' => $timer, 'learning_material_max_mb' => 25, 'student_submission_max_mb' => 15] + $stamps;
        }
        foreach (self::GROUPS as $name => [$institution]) {
            $rows['groups'][] = ['id' => $manifest['groups'][$name], 'institution_id' => $manifest['institutions'][$institution],
                'name' => 'E2E S08 '.ucwords(str_replace('_', ' ', $name)).' Group', 'status' => 'active', 'created_by_user_id' => $teacherOf($institution)] + $stamps;
        }
        foreach (self::GROUPS as $name => [$institution]) {
            $groupNumber = (int) substr($manifest['groups'][$name], -12);
            $rows['group_teacher_memberships'][] = ['id' => self::id(7_500_000 + $groupNumber), 'institution_id' => $manifest['institutions'][$institution],
                'group_id' => $manifest['groups'][$name], 'teacher_id' => $teacherOf($institution), 'assigned_by_user_id' => $teacherOf($institution),
                'started_at' => self::at('created'), 'ended_at' => null] + $stamps;
        }
        foreach (self::GROUPS as $name => [$institution, $members, $lateMembers]) {
            $groupNumber = (int) substr($manifest['groups'][$name], -12);
            foreach ([...$members, ...$lateMembers] as $index => $student) {
                $rows['group_student_memberships'][] = ['id' => self::id(7_000_000 + $groupNumber * 100 + $index + 1), 'institution_id' => $manifest['institutions'][$institution],
                    'group_id' => $manifest['groups'][$name], 'student_id' => $manifest['users'][$student], 'assigned_by_user_id' => $teacherOf($institution),
                    'started_at' => in_array($student, $lateMembers, true) ? self::at('late_join') : self::at('created'), 'ended_at' => null] + $stamps;
            }
        }
        foreach (self::GROUPS as $name => [$institution]) {
            $rows['topics'][] = ['id' => $manifest['topics'][$name], 'institution_id' => $manifest['institutions'][$institution], 'group_id' => $manifest['groups'][$name],
                'teacher_id' => $teacherOf($institution), 'title' => 'E2E S08 '.ucwords(str_replace('_', ' ', $name)).' Topic', 'subject' => 'E2E S08',
                'student_instructions' => 'E2E S08 Student Blitz', 'status' => 'active', 'activated_at' => self::at('activated')] + $stamps;
        }
        $questionSets = self::questionSets();
        foreach (self::ASSESSMENTS as $name => [$type, $topic, $mode, $state, $duration, $set]) {
            $institution = self::GROUPS[$topic][0];
            $rows['assessments'][] = ['id' => $manifest['assessments'][$name], 'institution_id' => $manifest['institutions'][$institution],
                'topic_id' => $manifest['topics'][$topic], 'teacher_id' => $teacherOf($institution), 'type' => $type,
                'title' => 'E2E S08 '.ucwords(str_replace('_', ' ', $name)).($type === 'blitz' ? ' Blitz' : ''),
                'student_instructions' => 'E2E S08 Answer and submit before the time ends.', 'assignment_mode' => $mode,
                'total_possible_points' => count($questionSets[$set]).'.000000'] + $stamps;
        }
        foreach (self::ASSESSMENTS as $name => [$type, $topic, $mode, $state]) {
            if ($type !== 'homework') {
                continue;
            }
            $rows['homework_assignments'][] = ['assessment_id' => $manifest['assessments'][$name], 'institution_id' => $manifest['institutions'][self::GROUPS[$topic][0]],
                'status' => $state, 'deadline_at' => self::at('future_deadline'), 'activated_at' => $state === 'active' ? self::at('activated') : null] + $stamps;
        }
        foreach (self::ASSESSMENTS as $name => [$type, $topic, $mode, $state, $duration]) {
            if ($type !== 'blitz') {
                continue;
            }
            $institution = self::GROUPS[$topic][0];
            $timer = $state === 'active' ? self::INSTITUTIONS[$institution] : null;
            $rows['blitz_tasks'][] = ['assessment_id' => $manifest['assessments'][$name], 'institution_id' => $manifest['institutions'][$institution],
                'status' => $state, 'duration_seconds' => $duration, 'scheduled_at' => null, 'timer_start_mode_snapshot' => $timer,
                'activated_at' => $timer === null ? null : self::at('activated'), 'activated_by_user_id' => $timer === null ? null : $teacherOf($institution),
                'synchronized_ends_at' => $timer === 'synchronized' ? self::plusSeconds(self::at('activated'), $duration) : null] + $stamps;
        }
        foreach ($manifest['recipients'] as $name => $students) {
            [$type, $topic, $mode] = self::ASSESSMENTS[$name];
            $institution = self::GROUPS[$topic][0];
            foreach ($students as $student => $id) {
                $rows['assessment_students'][] = ['id' => $id, 'institution_id' => $manifest['institutions'][$institution], 'assessment_id' => $manifest['assessments'][$name],
                    'student_id' => $manifest['users'][$student], 'assigned_by_user_id' => $teacherOf($institution),
                    'assignment_source' => $mode === 'group' ? 'group' : 'direct', 'assigned_at' => $mode === 'group' ? self::at('activated') : self::at('created')] + $stamps;
            }
        }
        foreach (self::PAIRS as $name => [$topic, $homework, $blitz, $cohort, $locked]) {
            $rows['topic_result_pairs'][] = ['id' => $manifest['pairs'][$name], 'institution_id' => $manifest['institutions']['target'], 'topic_id' => $manifest['topics'][$topic],
                'homework_assessment_id' => $manifest['assessments'][$homework], 'blitz_assessment_id' => $blitz === null ? null : $manifest['assessments'][$blitz],
                'designated_by_user_id' => $manifest['users']['teacher'], 'designated_at' => self::at('designated'),
                'cohort_snapshotted_at' => $cohort ? self::at('activated') : null, 'locked_at' => $locked ? self::at('homework_start') : null] + $stamps;
        }
        foreach (['questions', ...self::QUESTION_CHILD_TABLES, 'question_fill_blank_accepted_answers'] as $table) {
            $rows[$table] = [];
        }
        foreach ($manifest['questions'] as $name => $questions) {
            $institution = $manifest['institutions'][self::GROUPS[self::ASSESSMENTS[$name][1]][0]];
            $types = $questionSets[self::ASSESSMENTS[$name][5]];
            $position = 0;
            foreach ($questions as $label => $questionId) {
                $type = $types[$label];
                $nested = $manifest['nested'][$name][$label];
                $rows['questions'][] = ['id' => $questionId, 'institution_id' => $institution, 'assessment_id' => $manifest['assessments'][$name],
                    'type' => $type, 'prompt' => 'E2E S08 '.($label === 'unanswered' ? 'Unanswered Short Written' : ucwords(str_replace('_', ' ', $type))),
                    'instructions' => 'E2E S08 Save your answer.', 'points' => '1.000000', 'position' => ++$position,
                    'checking_mode' => in_array($type, ['open_written', 'file_based'], true) ? 'manual' : 'automatic'] + $stamps;
                $parent = ['institution_id' => $institution, 'question_id' => $questionId] + $stamps;
                if (in_array($type, ['single_choice', 'multiple_choice'], true)) {
                    foreach ($nested as $index => $optionId) {
                        $rows['question_choice_options'][] = ['id' => $optionId, 'option_text' => 'E2E S08 Option '.($index + 1), 'position' => $index + 1,
                            'is_correct' => $index < ($type === 'multiple_choice' ? 2 : 1)] + $parent;
                    }
                } elseif ($type === 'true_false') {
                    $rows['question_true_false_answers'][] = ['correct_value' => true] + $parent;
                } elseif ($type === 'short_written') {
                    $rows['question_short_accepted_answers'][] = ['id' => $nested['accepted'], 'accepted_text' => 'E2E S08 private correctness', 'position' => 1] + $parent;
                } elseif ($type === 'matching') {
                    foreach (['left' => 'Left', 'right' => 'Right'] as $side => $sideLabel) {
                        foreach ($nested[$side] as $index => $itemId) {
                            $rows['question_matching_items'][] = ['id' => $itemId, 'side' => $side, 'match_key' => $nested['keys'][$index],
                                'item_text' => 'E2E S08 '.$sideLabel.' '.($index + 1), 'position' => $index + 1] + $parent;
                        }
                    }
                } elseif ($type === 'ordering') {
                    foreach ($nested as $index => $itemId) {
                        $rows['question_ordering_items'][] = ['id' => $itemId, 'item_text' => 'E2E S08 Order '.($index + 1), 'correct_position' => $index + 1] + $parent;
                    }
                } elseif ($type === 'fill_in_blank') {
                    foreach ($nested['blanks'] as $index => $blankId) {
                        $rows['question_fill_blanks'][] = ['id' => $blankId, 'blank_key' => 'blank'.($index + 1), 'position' => $index + 1] + $parent;
                        $rows['question_fill_blank_accepted_answers'][] = ['id' => $nested['accepted'][$index], 'institution_id' => $institution,
                            'blank_id' => $blankId, 'accepted_text' => 'E2E S08 private blank correctness', 'position' => 1] + $stamps;
                    }
                }
            }
        }
        foreach (self::ATTEMPTS as $name => [$assessment, $student, $number, $status, $startedKey, $finishedKey, $reason, $deadlineSource]) {
            $institution = self::GROUPS[self::ASSESSMENTS[$assessment][1]][0];
            $duration = self::ASSESSMENTS[$assessment][4];
            $started = $startedKey === 'seeded' ? $seededAt : self::at($startedKey);
            $deadline = match ($deadlineSource) {
                'common_end' => self::plusSeconds(self::at('activated'), $duration),
                'own_duration' => self::plusSeconds($started, $duration),
                default => null,
            };
            $finished = $finishedKey === null ? null : self::at($finishedKey);
            $rows['assessment_attempts'][] = ['id' => $manifest['attempts'][$name], 'institution_id' => $manifest['institutions'][$institution],
                'assessment_id' => $manifest['assessments'][$assessment], 'assessment_student_id' => $manifest['recipients'][$assessment][$student],
                'student_id' => $manifest['users'][$student], 'attempt_number' => $number, 'status' => $status, 'started_at' => $started,
                'deadline_at' => $deadline, 'submitted_at' => $finished, 'finalized_at' => $finished, 'finalization_reason' => $reason, 'locked_at' => $finished,
                'official_score_eligible' => ! in_array($name, ['sched_future_1', 'mon_exception_1'], true),
                'possible_points' => count($questionSets[self::ASSESSMENTS[$assessment][5]]).'.000000',
                'created_at' => $started, 'updated_at' => $finished ?? $started];
        }
        foreach (self::EXCEPTIONS as $name => [$assessment, $student, $invalidated, $replacement, $grantedKey]) {
            $institution = self::GROUPS[self::ASSESSMENTS[$assessment][1]][0];
            $rows['blitz_attempt_exceptions'][] = ['id' => $manifest['exceptions'][$name], 'institution_id' => $manifest['institutions'][$institution],
                'assessment_id' => $manifest['assessments'][$assessment], 'assessment_student_id' => $manifest['recipients'][$assessment][$student],
                'student_id' => $manifest['users'][$student], 'invalidated_attempt_id' => $manifest['attempts'][$invalidated],
                'replacement_attempt_id' => $replacement === null ? null : $manifest['attempts'][$replacement], 'reason_type' => 'technical',
                'reason' => 'E2E S08 seeded '.str_replace('_', ' ', $name).' exception', 'granted_by_user_id' => $teacherOf($institution),
                'granted_at' => self::at($grantedKey), 'created_at' => self::at($grantedKey), 'updated_at' => self::at($grantedKey)];
        }

        return array_filter($rows, fn (array $tableRows): bool => $tableRows !== []);
    }

    /** Unrelated graph used only to prove Stage 8 cleanup and the Scheduler never touch foreign rows. */
    public static function sentinelRows(): array
    {
        $s = self::sentinelId(...);
        $stamps = ['created_at' => self::at('created'), 'updated_at' => self::at('created')];
        [$institution, $teacher, $student, $group, $topic, $homework, $blitz] = [$s(1), $s(101), $s(102), $s(201), $s(401), $s(501), $s(502)];
        [$homeworkRecipient, $blitzRecipient, $homeworkQuestion, $blitzQuestion, $attempt, $answer, $file] = [$s(601), $s(602), $s(701), $s(702), $s(801), $s(901), $s(1001)];
        $blob = self::sentinelBlob();

        return [
            'institutions' => [['id' => $institution, 'name' => 'E2E S08 Unrelated Sentinel Institution', 'type' => 'school', 'status' => 'active'] + $stamps],
            'users' => [
                ['id' => $teacher, 'institution_id' => $institution, 'role' => 'teacher', 'full_name' => 'E2E S08 Sentinel Teacher', 'login_name' => 'e2e_s08_sentinel_teacher', 'is_active' => true, 'must_change_password' => false] + $stamps,
                ['id' => $student, 'institution_id' => $institution, 'role' => 'student', 'full_name' => 'E2E S08 Sentinel Student', 'login_name' => 'e2e_s08_sentinel_student', 'is_active' => true, 'must_change_password' => false] + $stamps,
            ],
            'institution_settings' => [['institution_id' => $institution, 'timezone' => 'Asia/Tashkent', 'blitz_timer_start_mode' => 'individual', 'learning_material_max_mb' => 25, 'student_submission_max_mb' => 15] + $stamps],
            'groups' => [['id' => $group, 'institution_id' => $institution, 'name' => 'E2E S08 Sentinel Group', 'status' => 'active', 'created_by_user_id' => $teacher] + $stamps],
            'group_teacher_memberships' => [['id' => $s(301), 'institution_id' => $institution, 'group_id' => $group, 'teacher_id' => $teacher, 'assigned_by_user_id' => $teacher, 'started_at' => self::at('created'), 'ended_at' => null] + $stamps],
            'group_student_memberships' => [['id' => $s(302), 'institution_id' => $institution, 'group_id' => $group, 'student_id' => $student, 'assigned_by_user_id' => $teacher, 'started_at' => self::at('created'), 'ended_at' => null] + $stamps],
            'topics' => [['id' => $topic, 'institution_id' => $institution, 'group_id' => $group, 'teacher_id' => $teacher, 'title' => 'E2E S08 Sentinel Topic', 'subject' => 'E2E S08', 'student_instructions' => 'E2E S08 Sentinel', 'status' => 'active', 'activated_at' => self::at('activated')] + $stamps],
            'assessments' => [
                ['id' => $homework, 'institution_id' => $institution, 'topic_id' => $topic, 'teacher_id' => $teacher, 'type' => 'homework', 'title' => 'E2E S08 Sentinel Homework', 'student_instructions' => 'E2E S08 Sentinel', 'assignment_mode' => 'group', 'total_possible_points' => '1.000000'] + $stamps,
                ['id' => $blitz, 'institution_id' => $institution, 'topic_id' => $topic, 'teacher_id' => $teacher, 'type' => 'blitz', 'title' => 'E2E S08 Sentinel Blitz', 'student_instructions' => 'E2E S08 Sentinel', 'assignment_mode' => 'group', 'total_possible_points' => '1.000000'] + $stamps,
            ],
            'homework_assignments' => [['assessment_id' => $homework, 'institution_id' => $institution, 'status' => 'closed', 'deadline_at' => self::at('late_join'), 'activated_at' => self::at('activated'), 'closed_at' => self::at('late_join')] + $stamps],
            'blitz_tasks' => [['assessment_id' => $blitz, 'institution_id' => $institution, 'status' => 'closed', 'duration_seconds' => 600, 'scheduled_at' => null, 'timer_start_mode_snapshot' => 'individual', 'activated_at' => self::at('activated'), 'activated_by_user_id' => $teacher, 'synchronized_ends_at' => null, 'closed_at' => self::at('late_join')] + $stamps],
            'assessment_students' => [
                ['id' => $homeworkRecipient, 'institution_id' => $institution, 'assessment_id' => $homework, 'student_id' => $student, 'assigned_by_user_id' => $teacher, 'assignment_source' => 'group', 'assigned_at' => self::at('activated')] + $stamps,
                ['id' => $blitzRecipient, 'institution_id' => $institution, 'assessment_id' => $blitz, 'student_id' => $student, 'assigned_by_user_id' => $teacher, 'assignment_source' => 'group', 'assigned_at' => self::at('activated')] + $stamps,
            ],
            'topic_result_pairs' => [['id' => $s(1101), 'institution_id' => $institution, 'topic_id' => $topic, 'homework_assessment_id' => $homework, 'blitz_assessment_id' => $blitz, 'designated_by_user_id' => $teacher, 'designated_at' => self::at('designated'), 'cohort_snapshotted_at' => self::at('activated'), 'locked_at' => self::at('blitz_start')] + $stamps],
            'questions' => [
                ['id' => $homeworkQuestion, 'institution_id' => $institution, 'assessment_id' => $homework, 'type' => 'open_written', 'prompt' => 'E2E S08 Sentinel', 'instructions' => null, 'points' => '1.000000', 'position' => 1, 'checking_mode' => 'manual'] + $stamps,
                ['id' => $blitzQuestion, 'institution_id' => $institution, 'assessment_id' => $blitz, 'type' => 'file_based', 'prompt' => 'E2E S08 Sentinel', 'instructions' => null, 'points' => '1.000000', 'position' => 1, 'checking_mode' => 'manual'] + $stamps,
            ],
            'assessment_attempts' => [['id' => $attempt, 'institution_id' => $institution, 'assessment_id' => $blitz, 'assessment_student_id' => $blitzRecipient, 'student_id' => $student, 'attempt_number' => 1, 'status' => 'submitted', 'started_at' => self::at('blitz_start'), 'deadline_at' => self::plusSeconds(self::at('blitz_start'), 600), 'submitted_at' => self::at('blitz_submitted'), 'finalized_at' => self::at('blitz_submitted'), 'finalization_reason' => 'student_submit', 'locked_at' => self::at('blitz_submitted'), 'official_score_eligible' => true, 'possible_points' => '1.000000', 'created_at' => self::at('blitz_start'), 'updated_at' => self::at('blitz_submitted')]],
            'attempt_answers' => [['id' => $answer, 'institution_id' => $institution, 'attempt_id' => $attempt, 'question_id' => $blitzQuestion, 'checking_status' => 'pending', 'created_at' => self::at('blitz_start'), 'updated_at' => self::at('blitz_start')]],
            'files' => [['id' => $file, 'institution_id' => $institution, 'uploaded_by_user_id' => $student, 'category' => 'student_submission', 'original_name' => 'e2e_s08_sentinel.pdf', 'storage_disk' => 'local', 'storage_key' => $blob['key'], 'mime_type' => 'application/pdf', 'extension' => 'pdf', 'size_bytes' => strlen($blob['bytes']), 'checksum_sha256' => hash('sha256', $blob['bytes']), 'created_at' => self::at('blitz_start'), 'updated_at' => self::at('blitz_start')]],
            'answer_files' => [['id' => $s(1201), 'institution_id' => $institution, 'answer_id' => $answer, 'file_id' => $file, 'created_at' => self::at('blitz_start')]],
        ];
    }

    /** @return array{key: string, bytes: string} */
    public static function sentinelBlob(): array
    {
        return ['key' => 'student-submissions/'.self::sentinelId(1).'/'.self::sentinelId(801).'/'.self::sentinelId(702).'/'.self::sentinelId(1301).'.pdf',
            'bytes' => "%PDF-1.7\nE2E S08 unrelated private sentinel bytes\n%%EOF\n"];
    }
}
