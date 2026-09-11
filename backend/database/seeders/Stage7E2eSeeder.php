<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

class Stage7E2eSeeder extends Seeder
{
    public const QUESTION_TYPES = ['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'file_based', 'matching', 'ordering', 'fill_in_blank'];

    public const LIFECYCLE = ['deadline_read', 'scheduler', 'teacher_close', 'due_teacher_close'];

    public const PRIMARY_KEYS = ['institution_settings' => 'institution_id', 'homework_assignments' => 'assessment_id', 'question_true_false_answers' => 'question_id', 'answer_text_values' => 'answer_id'];

    private const ANSWER_TABLES = ['answer_choice_selections', 'answer_text_values', 'answer_boolean_values', 'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files'];

    public static function id(int $number): string
    {
        return sprintf('07000000-0000-4000-8000-%012d', $number);
    }

    /** All static rows and the exact parent relationships owning runtime rows are declared here. */
    public static function manifest(): array
    {
        $manifest = [
            'institutions' => ['target' => self::id(1), 'foreign' => self::id(2)],
            'users' => array_combine(['teacher', 'student', 'peer_student', 'unassigned_student', 'parent', 'foreign_student', 'foreign_teacher'], array_map(self::id(...), range(101, 107))),
            'groups' => array_combine(['main', 'historical', 'foreign'], array_map(self::id(...), range(201, 203))),
            'topics' => array_combine(['main', 'historical', 'foreign'], array_map(self::id(...), range(401, 403))),
            'homework' => array_combine(['main', 'idempotency', 'peer_only', 'historical', 'deadline_read', 'scheduler', 'teacher_close', 'due_teacher_close', 'android_smoke', 'foreign'], array_map(self::id(...), range(501, 510))),
            'pair' => self::id(601),
            'attempts' => array_combine(self::LIFECYCLE, array_map(self::id(...), range(3001, 3004))),
            'answers' => array_combine(self::LIFECYCLE, array_map(self::id(...), range(4001, 4004))),
            'timestamps' => ['created' => '2020-01-01 00:00:00+00', 'activated' => '2020-01-02 00:00:00+00', 'started' => '2020-01-03 00:00:00+00', 'saved' => '2020-01-03 00:01:00+00', 'deadline' => '2020-01-04 00:00:00+00', 'ended' => '2020-01-05 00:00:00+00', 'future_deadline' => '2099-12-31 00:00:00+00'],
            'saved_text' => 'E2E S07 saved lifecycle answer — unchanged',
            'expected_answers' => ['short_written' => 'O‘zbekiston — E2E S07', 'open_written' => "E2E S07 first line\nStudent's second line", 'fill_in_blank' => 'E2E S07 partial blank', 'true_false' => true],
        ];
        foreach (['main' => 1000, 'idempotency' => 1100, 'foreign' => 1200] as $name => $base) {
            $manifest['questions'][$name] = array_combine(self::QUESTION_TYPES, array_map(self::id(...), range($base + 1, $base + 9)));
        }
        foreach (['peer_only', 'historical', ...self::LIFECYCLE] as $index => $name) {
            $manifest['questions'][$name] = ['short_written' => self::id(1301 + $index)];
        }
        // One intentionally unanswered Question makes the mobile partial-submit count meaningful.
        $manifest['questions']['android_smoke'] = ['single_choice' => self::id(1401), 'short_written' => self::id(1402), 'open_written' => self::id(1403)];
        foreach ($manifest['questions'] as $name => $questions) {
            foreach ($questions as $type => $questionId) {
                $base = ((int) substr($questionId, -12)) * 100;
                $manifest['nested'][$name][$type] = match ($type) {
                    'single_choice', 'multiple_choice', 'ordering' => array_map(self::id(...), range($base + 1, $base + 3)),
                    'matching' => ['left' => [self::id($base + 1), self::id($base + 2)], 'right' => [self::id($base + 11), self::id($base + 12)]],
                    'fill_in_blank' => [self::id($base + 1), self::id($base + 2)],
                    default => [],
                };
            }
        }
        foreach ($manifest['homework'] as $name => $assessmentId) {
            $students = match ($name) {
                'main', 'deadline_read', 'scheduler', 'teacher_close', 'due_teacher_close' => ['student', 'peer_student'],
                'peer_only' => ['peer_student'],
                'foreign' => ['foreign_student'],
                default => ['student'],
            };
            foreach ($students as $index => $student) {
                $manifest['recipients'][$name][$student] = self::id(((int) substr($assessmentId, -12)) * 10 + $index + 1);
            }
        }
        foreach (self::fixtureRows($manifest) as $table => $rows) {
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
        DB::transaction(function () use ($passwordHash): void {
            foreach (self::fixtureRows(self::manifest()) as $table => $rows) {
                if ($table === 'users') {
                    $rows = array_map(fn (array $row): array => $row + ['password' => $passwordHash], $rows);
                }
                DB::table($table)->insert($rows);
            }
        });
    }

    /** Read-only ownership snapshot, including explicitly resolved runtime primary IDs and private keys. */
    public function ownedState(): array
    {
        $this->guard(requirePassword: false);
        $manifest = self::manifest();
        $expectedRows = self::fixtureRows($manifest);
        $state = ['db' => [], 'blobs' => [], 'directories' => []];
        foreach ($expectedRows as $table => $expected) {
            $primaryKey = self::PRIMARY_KEYS[$table] ?? 'id';
            $state['db'][$table] = [];
            foreach ($expected as $identity) {
                $row = DB::table($table)->where($primaryKey, $identity[$primaryKey])->first();
                if ($row === null) {
                    continue;
                }
                foreach ($identity as $column => $value) {
                    if ($column === $primaryKey || str_ends_with($column, '_id') || in_array($column, ['login_name', 'name', 'title', 'role', 'type', 'assignment_mode', 'assignment_source'], true)) {
                        $this->require($row->{$column} === $value, 'Static Stage 7 ownership mismatch: '.$table.'.'.$column);
                    }
                }
                $state['db'][$table][] = $identity[$primaryKey];
            }
        }
        $recipientRows = collect($expectedRows['assessment_students'])->keyBy('id');
        $attemptRows = DB::table('assessment_attempts')->whereIn('assessment_id', $manifest['homework'])->get();
        foreach ($attemptRows as $attempt) {
            $recipient = $recipientRows->get($attempt->assessment_student_id);
            $this->require($recipient !== null && $recipient['assessment_id'] === $attempt->assessment_id
                && $recipient['institution_id'] === $attempt->institution_id && $recipient['student_id'] === $attempt->student_id,
                'Stage 7 Attempt ownership mismatch.');
        }
        $state['db']['assessment_attempts'] = $attemptRows->pluck('id')->all();
        $attempts = $attemptRows->keyBy('id');
        $questions = collect($expectedRows['questions'])->keyBy('id');
        $answerRows = DB::table('attempt_answers')->whereIn('attempt_id', $state['db']['assessment_attempts'])->get();
        foreach ($answerRows as $answer) {
            $question = $questions->get($answer->question_id);
            $attempt = $attempts->get($answer->attempt_id);
            $this->require($question !== null && $question['assessment_id'] === $attempt->assessment_id
                && $answer->institution_id === $attempt->institution_id && $question['institution_id'] === $answer->institution_id,
                'Stage 7 answer ownership mismatch.');
        }
        $state['db']['attempt_answers'] = $answerRows->pluck('id')->all();
        $answers = $answerRows->keyBy('id');
        $state['answer_children'] = [];
        foreach (self::ANSWER_TABLES as $table) {
            $rows = DB::table($table)->whereIn('answer_id', $state['db']['attempt_answers'])->get();
            foreach ($rows as $row) {
                $this->require($row->institution_id === $answers[$row->answer_id]->institution_id, 'Stage 7 typed-answer ownership mismatch.');
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
                && $questions[$answer->question_id]['type'] === 'file_based', 'Stage 7 File ownership mismatch.');
            $this->require($this->isSubmissionKey($file->storage_key, $directory), 'Stage 7 private blob ownership mismatch.');
            $state['blobs'][] = ['disk' => $disk, 'key' => $file->storage_key];
        }
        $this->require($fileRows->count() === $fileLinks->count(), 'Stage 7 linked File missing.');
        $state['db']['files'] = $fileRows->pluck('id')->all();
        // The declared Attempt + file-Question namespace also owns compensated/replaced blobs.
        // Enumerate exact keys, validate every basename, and never delete an institution/prefix tree.
        foreach ($attemptRows as $attempt) {
            foreach ($questions as $question) {
                if ($question['assessment_id'] !== $attempt->assessment_id || $question['type'] !== 'file_based') {
                    continue;
                }
                $directory = 'student-submissions/'.$attempt->institution_id.'/'.$attempt->id.'/'.$question['id'];
                $state['directories'][] = ['disk' => $disk, 'key' => $directory];
                foreach (Storage::disk($disk)->allFiles($directory) as $key) {
                    $this->require($this->isSubmissionKey($key, $directory), 'Unexpected file in Stage 7 submission namespace.');
                    $state['blobs'][] = ['disk' => $disk, 'key' => $key];
                }
            }
        }
        $state['blobs'] = array_values(array_unique($state['blobs'], SORT_REGULAR));
        $records = DB::table('idempotency_records')->whereIn('user_id', $manifest['users'])->get();
        foreach ($records as $record) {
            $attempt = $attempts->get($record->result_resource_id);
            $this->require($attempt !== null && $record->institution_id === $attempt->institution_id
                && $record->user_id === $attempt->student_id && $record->result_resource_type === 'assessment_attempt'
                && in_array($record->operation, ['student.homework.attempt.start', 'student.homework.attempt.submit'], true),
                'Unowned or incomplete idempotency record in Stage 7 actor scope.');
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
            foreach (['idempotency_records', 'attempt_answers', 'assessment_attempts', 'files', 'personal_access_tokens'] as $table) {
                DB::table($table)->whereIn('id', $state['db'][$table])->delete();
            }
            foreach (array_reverse(array_keys(self::fixtureRows(self::manifest()))) as $table) {
                if (in_array($table, ['answer_text_values', 'attempt_answers', 'assessment_attempts'], true)) {
                    continue;
                }
                DB::table($table)->whereIn(self::PRIMARY_KEYS[$table] ?? 'id', $state['db'][$table])->delete();
            }
            foreach ($state['blobs'] as $blob) {
                $this->require(Storage::disk($blob['disk'])->delete($blob['key']), 'Stage 7 private blob cleanup failed.');
            }
        });
    }

    protected function guard(bool $requirePassword = true): string
    {
        $this->require(app()->environment('testing'), 'Stage 7 fixtures require testing environment.');
        $this->require(DB::connection()->getDriverName() === 'pgsql', 'Stage 7 fixtures require PostgreSQL.');
        $this->require(DB::selectOne('select current_database() as database_name')->database_name === 'testlabuz_testing', 'Stage 7 fixtures require testlabuz_testing.');
        if (! $requirePassword) {
            return '';
        }
        $password = getenv('STAGE7_E2E_PASSWORD');
        $this->require(is_string($password) && trim($password) !== '', 'Stage 7 fixture password is required.');

        return $password;
    }

    private function privateDisk(): string
    {
        $disk = config('filesystems.private_files_disk');
        $configuration = is_string($disk) ? config('filesystems.disks.'.$disk) : null;
        $this->require(is_array($configuration) && ($configuration['visibility'] ?? null) !== 'public'
            && ($configuration['driver'] ?? null) === 'local', 'Stage 7 cleanup requires a private local disk.');
        $root = realpath($configuration['root']);
        $privateRoot = realpath(storage_path('app/private'));
        $this->require($root !== false && $privateRoot !== false && ($root === $privateRoot || str_starts_with($root, $privateRoot.DIRECTORY_SEPARATOR)), 'Stage 7 private disk root mismatch.');

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

    /** Non-secret exact fixture rows; insertion order is parent before child. */
    public static function fixtureRows(array $manifest): array
    {
        $rows = [];
        $timestamps = ['created_at' => $manifest['timestamps']['created'], 'updated_at' => $manifest['timestamps']['created']];
        foreach ($manifest['institutions'] as $name => $id) {
            $rows['institutions'][] = ['id' => $id, 'name' => 'E2E S07 '.ucfirst($name).' Institution', 'type' => 'school', 'status' => 'active'] + $timestamps;
        }
        foreach ($manifest['users'] as $name => $id) {
            $role = str_contains($name, 'teacher') ? 'teacher' : ($name === 'parent' ? 'parent' : 'student');
            $rows['users'][] = ['id' => $id, 'institution_id' => $manifest['institutions'][str_starts_with($name, 'foreign_') ? 'foreign' : 'target'],
                'role' => $role, 'full_name' => 'E2E S07 '.ucwords(str_replace('_', ' ', $name)), 'login_name' => 'e2e_s07_'.$name,
                'is_active' => true, 'must_change_password' => false] + $timestamps;
        }
        foreach ($manifest['institutions'] as $name => $id) {
            $rows['institution_settings'][] = ['institution_id' => $id, 'timezone' => 'Asia/Tashkent', 'student_submission_max_mb' => $name === 'target' ? 2 : 15] + $timestamps;
        }
        foreach ($manifest['groups'] as $name => $id) {
            $institution = $manifest['institutions'][$name === 'foreign' ? 'foreign' : 'target'];
            $teacher = $manifest['users'][$name === 'foreign' ? 'foreign_teacher' : 'teacher'];
            $rows['groups'][] = ['id' => $id, 'institution_id' => $institution, 'name' => 'E2E S07 '.ucfirst($name).' Group', 'status' => 'active', 'created_by_user_id' => $teacher] + $timestamps;
        }
        foreach ($manifest['groups'] as $index => $group) {
            $foreign = $index === 'foreign';
            $institution = $manifest['institutions'][$foreign ? 'foreign' : 'target'];
            $teacher = $manifest['users'][$foreign ? 'foreign_teacher' : 'teacher'];
            $number = (int) substr($group, -12);
            $rows['group_teacher_memberships'][] = ['id' => self::id($number + 100), 'institution_id' => $institution, 'group_id' => $group,
                'teacher_id' => $teacher, 'assigned_by_user_id' => $teacher, 'started_at' => $manifest['timestamps']['created'], 'ended_at' => null] + $timestamps;
        }
        foreach (['main' => ['student', 'peer_student'], 'historical' => ['student'], 'foreign' => ['foreign_student']] as $name => $students) {
            foreach ($students as $index => $student) {
                $rows['group_student_memberships'][] = ['id' => self::id(((int) substr($manifest['groups'][$name], -12)) * 10 + $index + 1),
                    'institution_id' => $manifest['institutions'][$name === 'foreign' ? 'foreign' : 'target'], 'group_id' => $manifest['groups'][$name], 'student_id' => $manifest['users'][$student],
                    'assigned_by_user_id' => $manifest['users'][$name === 'foreign' ? 'foreign_teacher' : 'teacher'], 'started_at' => $manifest['timestamps']['created'],
                    'ended_at' => $name === 'historical' ? $manifest['timestamps']['ended'] : null] + $timestamps;
            }
        }
        foreach ($manifest['topics'] as $name => $id) {
            $rows['topics'][] = ['id' => $id, 'institution_id' => $manifest['institutions'][$name === 'foreign' ? 'foreign' : 'target'], 'group_id' => $manifest['groups'][$name],
                'teacher_id' => $manifest['users'][$name === 'foreign' ? 'foreign_teacher' : 'teacher'], 'title' => 'E2E S07 '.ucfirst($name).' Topic', 'subject' => 'E2E S07',
                'student_instructions' => 'E2E S07 Student Homework', 'status' => 'active', 'activated_at' => $manifest['timestamps']['activated']] + $timestamps;
        }
        $labels = ['main' => 'Official', 'idempotency' => 'Idempotency', 'peer_only' => 'Peer-Only', 'historical' => 'Historical', 'deadline_read' => 'Deadline Read', 'scheduler' => 'Scheduler', 'teacher_close' => 'Teacher Close', 'due_teacher_close' => 'Due Teacher Close', 'android_smoke' => 'Android Smoke', 'foreign' => 'Foreign'];
        foreach ($manifest['homework'] as $name => $id) {
            $institution = $manifest['institutions'][$name === 'foreign' ? 'foreign' : 'target'];
            $rows['assessments'][] = ['id' => $id, 'institution_id' => $institution, 'topic_id' => $manifest['topics'][in_array($name, ['historical', 'foreign'], true) ? $name : 'main'],
                'teacher_id' => $manifest['users'][$name === 'foreign' ? 'foreign_teacher' : 'teacher'], 'type' => 'homework', 'title' => 'E2E S07 '.$labels[$name].' Homework',
                'student_instructions' => 'E2E S07 Save answers then submit.', 'assignment_mode' => $name === 'main' || $name === 'historical' ? 'group' : 'selected_students',
                'total_possible_points' => count($manifest['questions'][$name]).'.000000'] + $timestamps;
        }
        foreach ($manifest['homework'] as $name => $id) {
            $rows['homework_assignments'][] = ['assessment_id' => $id, 'institution_id' => $manifest['institutions'][$name === 'foreign' ? 'foreign' : 'target'],
                'status' => $name === 'historical' ? 'closed' : 'active', 'activated_at' => $manifest['timestamps']['activated'],
                'closed_at' => $name === 'historical' ? $manifest['timestamps']['ended'] : null,
                'deadline_at' => $manifest['timestamps'][in_array($name, ['deadline_read', 'scheduler', 'due_teacher_close'], true) ? 'deadline' : 'future_deadline']] + $timestamps;
        }
        foreach ($manifest['recipients'] as $name => $students) {
            foreach ($students as $student => $id) {
                $rows['assessment_students'][] = ['id' => $id, 'institution_id' => $manifest['institutions'][$name === 'foreign' ? 'foreign' : 'target'], 'assessment_id' => $manifest['homework'][$name],
                    'student_id' => $manifest['users'][$student], 'assigned_by_user_id' => $manifest['users'][$name === 'foreign' ? 'foreign_teacher' : 'teacher'],
                    'assignment_source' => in_array($name, ['main', 'historical'], true) ? 'group' : 'direct', 'assigned_at' => $manifest['timestamps']['activated']] + $timestamps;
            }
        }
        $rows['topic_result_pairs'][] = ['id' => $manifest['pair'], 'institution_id' => $manifest['institutions']['target'], 'topic_id' => $manifest['topics']['main'],
            'homework_assessment_id' => $manifest['homework']['main'], 'blitz_assessment_id' => null, 'designated_by_user_id' => $manifest['users']['teacher'],
            'designated_at' => $manifest['timestamps']['created'], 'cohort_snapshotted_at' => $manifest['timestamps']['activated'], 'locked_at' => null] + $timestamps;
        foreach ($manifest['questions'] as $name => $questions) {
            foreach (array_keys($questions) as $index => $type) {
                $rows['questions'][] = ['id' => $questions[$type], 'institution_id' => $manifest['institutions'][$name === 'foreign' ? 'foreign' : 'target'], 'assessment_id' => $manifest['homework'][$name],
                    'type' => $type, 'prompt' => 'E2E S07 '.ucwords(str_replace('_', ' ', $type)), 'instructions' => 'E2E S07 Save your answer.', 'points' => '1.000000',
                    'position' => $index + 1, 'checking_mode' => in_array($type, ['open_written', 'file_based'], true) ? 'manual' : 'automatic'] + $timestamps;
            }
        }
        $children = [];
        foreach ($rows['questions'] as $question) {
            $questionId = $question['id'];
            $base = ((int) substr($questionId, -12)) * 100;
            $parent = ['institution_id' => $question['institution_id'], 'question_id' => $questionId] + $timestamps;
            $type = $question['type'];
            if (in_array($type, ['single_choice', 'multiple_choice'], true)) {
                foreach (range(1, 3) as $position) {
                    $children['question_choice_options'][] = ['id' => self::id($base + $position), 'option_text' => 'E2E S07 Option '.$position, 'position' => $position,
                        'is_correct' => $position <= ($type === 'multiple_choice' ? 2 : 1)] + $parent;
                }
            } elseif ($type === 'true_false') {
                $children['question_true_false_answers'][] = ['correct_value' => true] + $parent;
            } elseif ($type === 'short_written') {
                $children['question_short_accepted_answers'][] = ['id' => self::id($base + 1), 'accepted_text' => 'E2E S07 private correctness', 'position' => 1] + $parent;
            } elseif ($type === 'matching') {
                foreach (['left' => 0, 'right' => 10] as $side => $offset) {
                    foreach (range(1, 2) as $position) {
                        $children['question_matching_items'][] = ['id' => self::id($base + $offset + $position), 'side' => $side, 'match_key' => self::id($base + 20 + $position),
                            'item_text' => 'E2E S07 '.ucfirst($side).' '.$position, 'position' => $position] + $parent;
                    }
                }
            } elseif ($type === 'ordering') {
                foreach (range(1, 3) as $position) {
                    $children['question_ordering_items'][] = ['id' => self::id($base + $position), 'item_text' => 'E2E S07 Order '.$position, 'correct_position' => $position] + $parent;
                }
            } elseif ($type === 'fill_in_blank') {
                foreach (range(1, 2) as $position) {
                    $children['question_fill_blanks'][] = ['id' => self::id($base + $position), 'blank_key' => 'blank'.$position, 'position' => $position] + $parent;
                    $children['question_fill_blank_accepted_answers'][] = ['id' => self::id($base + 10 + $position), 'institution_id' => $question['institution_id'],
                        'blank_id' => self::id($base + $position), 'accepted_text' => 'E2E S07 private blank correctness', 'position' => 1] + $timestamps;
                }
            }
        }
        $rows += $children;
        foreach (self::LIFECYCLE as $name) {
            $rows['assessment_attempts'][] = ['id' => $manifest['attempts'][$name], 'institution_id' => $manifest['institutions']['target'], 'assessment_id' => $manifest['homework'][$name],
                'assessment_student_id' => $manifest['recipients'][$name]['student'], 'student_id' => $manifest['users']['student'], 'attempt_number' => 1, 'status' => 'in_progress',
                'started_at' => $manifest['timestamps']['started'], 'deadline_at' => null, 'official_score_eligible' => true, 'possible_points' => '1.000000',
                'created_at' => $manifest['timestamps']['started'], 'updated_at' => $manifest['timestamps']['started']];
        }
        foreach (self::LIFECYCLE as $name) {
            $rows['attempt_answers'][] = ['id' => $manifest['answers'][$name], 'institution_id' => $manifest['institutions']['target'], 'attempt_id' => $manifest['attempts'][$name],
                'question_id' => $manifest['questions'][$name]['short_written'], 'checking_status' => 'pending', 'awarded_points' => null, 'feedback' => null, 'checked_by_user_id' => null, 'checked_at' => null,
                'created_at' => $manifest['timestamps']['saved'], 'updated_at' => $manifest['timestamps']['saved']];
        }
        foreach (self::LIFECYCLE as $name) {
            $rows['answer_text_values'][] = ['answer_id' => $manifest['answers'][$name], 'institution_id' => $manifest['institutions']['target'], 'text_value' => $manifest['saved_text'],
                'created_at' => $manifest['timestamps']['saved'], 'updated_at' => $manifest['timestamps']['saved']];
        }

        return $rows;
    }
}
