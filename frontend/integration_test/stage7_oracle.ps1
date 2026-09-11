Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage7_runtime_guard.ps1')

function Assert-Stage7Equal {
    param($Actual, $Expected, [string] $Label)
    if ((ConvertTo-Json -InputObject $Actual -Depth 60 -Compress) -cne (ConvertTo-Json -InputObject $Expected -Depth 60 -Compress)) {
        throw "production defect: Stage 7 oracle mismatch: $Label."
    }
}

function Assert-Stage7Set {
    param([AllowEmptyCollection()][object[]] $Actual, [AllowEmptyCollection()][object[]] $Expected, [string] $Label)
    Assert-Stage7Equal @($Actual | Sort-Object) @($Expected | Sort-Object) $Label
}

function Get-Stage7Row {
    param($Facts, [string] $Table, [string] $Id, [string] $Column = 'id')
    $rows = @($Facts.tables.$Table | Where-Object { [string] $_.$Column -ceq $Id })
    if ($rows.Count -ne 1) { throw "integration-harness defect: Stage 7 oracle requires one $Table row." }
    $rows[0]
}

function Get-Stage7DatabaseFacts {
    param([string] $BackendContainerName = 'testlabuz-stage7-e2e-app', $PriorFacts)
    $program = @'
use Database\Seeders\Stage7E2eSeeder;
if (!app()->environment('testing') || DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new RuntimeException('Stage 7 oracle database identity failed.');
}
$m = Stage7E2eSeeder::manifest();
$prior = $stage7Input['prior'] ?? [];
$tables = [];
$take = function (string $table, string $column, array $ids, array $columns = ['*']) use (&$tables): array {
    $rows = DB::table($table)->whereIn($column, array_values($ids))->orderBy($column)->get($columns)->map(fn($r) => (array)$r)->all();
    usort($rows, fn($a,$b) => json_encode($a) <=> json_encode($b));
    $tables[$table] = $rows;
    return $rows;
};
$ids = fn(array $rows): array => array_column($rows, 'id');
$require = function (bool $valid): void { if (!$valid) { throw new RuntimeException('Stage 7 oracle manifest relationship mismatch.'); } };
$institutions = $take('institutions', 'id', $m['institutions']);
$take('institution_settings', 'institution_id', $m['institutions']);
$users = $take('users', 'id', $m['users'], ['id','institution_id','login_name','role','is_active','must_change_password']);
$groups = $take('groups', 'id', $m['groups']);
$topics = $take('topics', 'id', $m['topics']);
$assessments = $take('assessments', 'id', $m['homework']);
$take('homework_assignments', 'assessment_id', $m['homework']);
$questionIds = array_merge(...array_map('array_values', array_values($m['questions'])));
$questions = $take('questions', 'id', $questionIds, ['id','institution_id','assessment_id','type','position','points']);
$take('topic_result_pairs', 'id', [$m['pair']]);
$cleanup = ($stage7Input['cleanup'] ?? false) === true;
if (!$cleanup) {
    $require(count($institutions) === count($m['institutions']) && count($users) === count($m['users'])
        && count($groups) === count($m['groups']) && count($topics) === count($m['topics'])
        && count($assessments) === count($m['homework']) && count($questions) === count($questionIds));
    foreach (['users'=>$m['users'], 'groups'=>$m['groups'], 'topics'=>$m['topics'], 'assessments'=>$m['homework']] as $table=>$labels) {
        foreach ($tables[$table] as $row) {
            $label = array_search($row['id'], $labels, true);
            $foreign = str_starts_with($label, 'foreign');
            $require($row['institution_id'] === $m['institutions'][$foreign ? 'foreign' : 'target']);
        }
    }
    foreach ($assessments as $row) {
        $label = array_search($row['id'], $m['homework'], true);
        $require($row['type'] === 'homework' && $row['topic_id'] === $m['topics'][$label === 'foreign' ? 'foreign' : ($label === 'historical' ? 'historical' : 'main')]);
    }
    foreach ($questions as $row) {
        $label = array_search($row['assessment_id'], $m['homework'], true);
        $require($label !== false && ($m['questions'][$label][$row['type']] ?? null) === $row['id']
            && $row['institution_id'] === $m['institutions'][$label === 'foreign' ? 'foreign' : 'target']);
    }
}
$take('group_teacher_memberships', 'group_id', $m['groups']);
$take('group_student_memberships', 'group_id', $m['groups']);
$recipients = $take('assessment_students', 'assessment_id', $m['homework']);
foreach (['question_choice_options','question_matching_items','question_ordering_items','question_fill_blanks'] as $table) {
    $take($table, 'question_id', $questionIds);
}
$attempts = $take('assessment_attempts', 'assessment_id', $m['homework']);
    if ($cleanup) {
    $attempts = DB::table('assessment_attempts')->whereIn('assessment_id', $m['homework'])->orWhereIn('id', $prior['attempt_ids'] ?? [])->orderBy('id')->get()->map(fn($r)=>(array)$r)->all();
    $tables['assessment_attempts'] = $attempts;
}
if (!$cleanup) {
    foreach ($attempts as $attempt) {
        $recipient = array_values(array_filter($recipients, fn($r) => $r['id'] === $attempt['assessment_student_id']));
        $require(count($recipient) === 1 && $recipient[0]['assessment_id'] === $attempt['assessment_id']
            && $recipient[0]['student_id'] === $attempt['student_id'] && $recipient[0]['institution_id'] === $attempt['institution_id']
            && in_array($attempt['student_id'], $m['users'], true));
    }
}
$attemptIds = array_values(array_unique([...$ids($attempts), ...($prior['attempt_ids'] ?? [])]));
$answers = $take('attempt_answers', 'attempt_id', $attemptIds);
if ($cleanup) {
    $answers = DB::table('attempt_answers')->whereIn('attempt_id', $attemptIds)->orWhereIn('id', $prior['answer_ids'] ?? [])->orderBy('id')->get()->map(fn($r)=>(array)$r)->all();
    $tables['attempt_answers'] = $answers;
}
foreach ($answers as $answer) {
    $attempt = array_values(array_filter($attempts, fn($a) => $a['id'] === $answer['attempt_id']));
    $question = array_values(array_filter($questions, fn($q) => $q['id'] === $answer['question_id']));
    if (!$cleanup) { $require(count($attempt) === 1 && count($question) === 1 && $attempt[0]['institution_id'] === $answer['institution_id']
        && $question[0]['institution_id'] === $answer['institution_id'] && $question[0]['assessment_id'] === $attempt[0]['assessment_id']); }
}
$answerIds = array_values(array_unique([...$ids($answers), ...($prior['answer_ids'] ?? [])]));
foreach (['answer_choice_selections','answer_text_values','answer_boolean_values','answer_matching_pairs','answer_ordering_items','answer_fill_blank_values','answer_files'] as $table) {
    $take($table, 'answer_id', $answerIds);
}
$files = $take('files', 'uploaded_by_user_id', $m['users']);
if ($cleanup) {
    $files = DB::table('files')->whereIn('uploaded_by_user_id', $m['users'])->orWhereIn('id', $prior['file_ids'] ?? [])->orderBy('id')->get()->map(fn($r)=>(array)$r)->all();
    $tables['files'] = $files;
    $tables['personal_access_tokens'] = DB::table('personal_access_tokens')->where('tokenable_type', (new \App\Models\User)->getMorphClass())
        ->whereIn('tokenable_id', $m['users'])->orderBy('id')->get(['id','tokenable_type','tokenable_id'])->map(fn($r)=>(array)$r)->all();
}
$take('idempotency_records', 'user_id', $m['users']);
foreach ($m['db'] as $table=>$primaryIds) {
    if (!array_key_exists($table, $tables)) { $take($table, Stage7E2eSeeder::PRIMARY_KEYS[$table] ?? 'id', $primaryIds); }
    if (!$cleanup && !in_array($table, ['assessment_attempts','attempt_answers','answer_text_values'], true)) {
        $actualIds = array_column($tables[$table], Stage7E2eSeeder::PRIMARY_KEYS[$table] ?? 'id');
        sort($actualIds); sort($primaryIds); $require($actualIds === $primaryIds);
    }
}
if (!$cleanup) {
    foreach (Stage7E2eSeeder::fixtureRows($m) as $table=>$expectedRows) {
        $primaryKey = Stage7E2eSeeder::PRIMARY_KEYS[$table] ?? 'id';
        foreach ($expectedRows as $expected) {
            $actual = array_values(array_filter($tables[$table], fn($r) => $r[$primaryKey] === $expected[$primaryKey]));
            $require(count($actual) === 1);
            foreach ($expected as $column=>$value) {
                if ($column === $primaryKey || str_ends_with($column, '_id') || in_array($column, ['login_name','role','name','title','type','assignment_mode','assignment_source'], true)) {
                    $require(($actual[0][$column] ?? null) === $value);
                }
            }
        }
    }
}
$diskName = config('filesystems.private_files_disk');
$diskConfig = config('filesystems.disks.'.$diskName);
$root = rtrim((string)($diskConfig['root'] ?? ''), '/');
$require(is_string($diskName) && ($diskConfig['visibility'] ?? null) !== 'public'
    && ($root === '/var/www/html/storage/app/private' || str_starts_with($root, '/var/www/html/storage/app/private/')));
$disk = Storage::disk($diskName);
$directories = $prior['directories'] ?? [];
foreach ($attempts as $attempt) {
    foreach ($questions as $question) {
        if ($question['assessment_id'] === $attempt['assessment_id'] && $question['type'] === 'file_based') {
            $directories[] = "student-submissions/{$attempt['institution_id']}/{$attempt['id']}/{$question['id']}";
        }
    }
}
$directories = array_values(array_unique($directories));
$blobs = [];
$publicBlobs = [];
foreach ($directories as $directory) {
    $require((bool)preg_match('~^student-submissions/[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}$~D', $directory));
    foreach ($disk->allFiles($directory) as $key) {
        $blobs[] = ['key'=>$key, 'size'=>$disk->size($key), 'checksum'=>hash_file('sha256', $disk->path($key)),
            'public_exists'=>is_file(storage_path('app/public/'.$key))];
    }
    foreach (Storage::disk('public')->allFiles($directory) as $key) { $publicBlobs[] = $key; }
}
foreach ($prior['blob_keys'] ?? [] as $key) {
    $require(in_array(dirname($key), $directories, true));
    if (is_file(storage_path('app/public/'.$key))) { $publicBlobs[] = $key; }
}
$publicBlobs = array_values(array_unique($publicBlobs)); sort($publicBlobs);
usort($blobs, fn($a,$b) => $a['key'] <=> $b['key']);
foreach ($files as $file) {
    if ($cleanup) { continue; }
    $require($file['category'] === 'student_submission' && $file['storage_disk'] === $diskName
        && in_array(dirname($file['storage_key']), $directories, true));
}
echo json_encode(['manifest'=>$m, 'tables'=>$tables, 'private_disk'=>$diskName, 'private_root'=>$root,
    'directories'=>$directories, 'blobs'=>$blobs, 'public_blobs'=>$publicBlobs, 'observed_at'=>now()->utc()->toIso8601String()], JSON_THROW_ON_ERROR);
'@
    $inputObject = @{ cleanup = $null -ne $PriorFacts }
    if ($null -ne $PriorFacts) {
        $inputObject.prior = @{ attempt_ids = @($PriorFacts.tables.assessment_attempts | ForEach-Object id); answer_ids = @($PriorFacts.tables.attempt_answers | ForEach-Object id); file_ids = @($PriorFacts.tables.files | ForEach-Object id); directories = @($PriorFacts.directories); blob_keys = @($PriorFacts.blobs | ForEach-Object key) }
    }
    Invoke-Stage7ContainerPhp -BackendContainerName $BackendContainerName -Program $program -InputJson ($inputObject | ConvertTo-Json -Depth 30 -Compress)
}

function Assert-Stage7Unscored {
    param($Attempt, [AllowEmptyCollection()][object[]] $Answers)
    foreach ($field in @('earned_points','normalized_score','scoring_completed_at')) {
        if ($null -ne $Attempt.$field) { throw 'production defect: Stage 7 Attempt contains scoring data.' }
    }
    foreach ($answer in $Answers) {
        if ($answer.checking_status -cne 'pending') { throw 'production defect: Stage 7 answer was checked.' }
        foreach ($field in @('awarded_points','feedback','checked_by_user_id','checked_at')) {
            if ($null -ne $answer.$field) { throw 'production defect: Stage 7 answer contains scoring/review data.' }
        }
    }
}

function Assert-Stage7AttemptLimit {
    param([AllowEmptyCollection()][object[]] $Attempts)
    foreach ($attempt in $Attempts) {
        if ([int] $attempt.attempt_number -lt 1 -or [int] $attempt.attempt_number -gt 3) { throw 'production defect: Unexpected fourth/non-normal Attempt.' }
    }
    foreach ($group in @($Attempts | Group-Object assessment_id,student_id)) {
        if ($group.Count -gt 3) { throw 'production defect: More than three normal Attempts persisted for one Student Homework.' }
        Assert-Stage7Set @($group.Group.attempt_number) @(1..$group.Count) 'contiguous unique normal Attempt numbers'
    }
}

function Assert-Stage7ReplacementIdentity {
    param($BeforeAnswer, $AfterAnswer, $BeforeLink, $AfterLink)
    Assert-Stage7Equal $AfterAnswer.id $BeforeAnswer.id 'replacement AttemptAnswer ID'
    Assert-Stage7Equal $AfterLink $BeforeLink 'replacement AnswerFile and File IDs'
}

function Assert-Stage7TerminalAttempt {
    param($Attempt, [string] $Reason, [string] $Timestamp)
    if ($Attempt.status -cne 'submitted' -or $Attempt.finalization_reason -cne $Reason) { throw 'production defect: Stage 7 Attempt terminal state/reason mismatch.' }
    if ([string]::IsNullOrWhiteSpace($Timestamp)) { throw 'production defect: Stage 7 terminal timestamp missing.' }
    foreach ($field in @('finalized_at','locked_at')) { Assert-Stage7Equal ([string] $Attempt.$field) $Timestamp $field }
    if ($Reason -ceq 'student_submit') { Assert-Stage7Equal ([string] $Attempt.submitted_at) $Timestamp 'submitted_at' }
    elseif ($null -ne $Attempt.submitted_at) { throw 'production defect: Auto-finalized Attempt fabricated submitted_at.' }
}

function Assert-Stage7TypedAnswer {
    param($Facts, $Answer, [string] $Type, [AllowEmptyCollection()][object[]] $Expected)
    $expectedTable = switch ($Type) {
        { $_ -in @('single_choice','multiple_choice') } { 'answer_choice_selections' }
        { $_ -in @('short_written','open_written') } { 'answer_text_values' }
        'true_false' { 'answer_boolean_values' }
        'matching' { 'answer_matching_pairs' }
        'ordering' { 'answer_ordering_items' }
        'fill_in_blank' { 'answer_fill_blank_values' }
        'file_based' { 'answer_files' }
        default { throw 'integration-harness defect: Unknown answer type.' }
    }
    foreach ($table in @('answer_choice_selections','answer_text_values','answer_boolean_values','answer_matching_pairs','answer_ordering_items','answer_fill_blank_values','answer_files')) {
        $rows = @($Facts.tables.$table | Where-Object answer_id -CEQ $Answer.id)
        if ($table -cne $expectedTable -and $rows.Count -ne 0) { throw 'production defect: Answer has wrong typed-child residue.' }
        if ($table -ceq $expectedTable) {
            $actual = @($rows | ForEach-Object {
                $row = $_
                switch ($Type) {
                    { $_ -in @('single_choice','multiple_choice') } { [string] $row.option_id }
                    { $_ -in @('short_written','open_written') } { [string] $row.text_value }
                    'true_false' { [bool] $row.boolean_value }
                    'matching' { "$($row.left_item_id):$($row.right_item_id)" }
                    'ordering' { "$($row.ordering_item_id):$($row.submitted_position)" }
                    'fill_in_blank' { "$($row.blank_id):$($row.text_value)" }
                    'file_based' { [string] $row.file_id }
                }
            })
            Assert-Stage7Set $actual $Expected "$Type normalized persistence"
        }
    }
}

function Assert-Stage7IdempotencyRecord {
    param($Record, [string] $InstitutionId, [string] $StudentId, [string] $Operation, [string] $Key, [string] $AttemptId, [int] $Status)
    if ($Record.institution_id -cne $InstitutionId -or $Record.user_id -cne $StudentId -or $Record.operation -cne $Operation -or
        $Record.idempotency_key -cne $Key -or $Record.result_resource_type -cne 'assessment_attempt' -or
        $Record.result_resource_id -cne $AttemptId -or [int] $Record.response_status -ne $Status -or
        $null -eq $Record.completed_at -or [string] $Record.request_fingerprint -cnotmatch '\A[0-9a-f]{64}\z') {
        throw 'production defect: Invalid scoped completed Stage 7 idempotency record.'
    }
}

function Assert-Stage7Pair {
    param($Pair, $BaselinePair, $FirstAttempt)
    foreach ($field in @('id','institution_id','topic_id','homework_assessment_id','cohort_snapshotted_at','designated_at')) {
        Assert-Stage7Equal $Pair.$field $BaselinePair.$field "official pair $field"
    }
    if ($null -ne $Pair.blitz_assessment_id -or $null -eq $Pair.cohort_snapshotted_at) { throw 'production defect: Official pair cohort/Blitz changed.' }
    Assert-Stage7Equal ([string] $Pair.locked_at) ([string] $FirstAttempt.started_at) 'first Attempt pair lock'
}

function Assert-Stage7File {
    param($Facts, $File, $ExpectedFile, [string] $AttemptId, [string] $QuestionId)
    $prefix = "student-submissions/$($Facts.manifest.institutions.target)/$AttemptId/$QuestionId/"
    if ($File.category -cne 'student_submission' -or $File.uploaded_by_user_id -cne $Facts.manifest.users.student -or
        $File.institution_id -cne $Facts.manifest.institutions.target -or $null -ne $File.removed_at -or
        $File.storage_disk -cne $Facts.private_disk -or -not ([string] $File.storage_key).StartsWith($prefix, [StringComparison]::Ordinal) -or
        [string] $File.storage_key -match '(^|/)\.\.(/|$)|public|\\' -or
        $Facts.private_root -notmatch '\A/var/www/html/storage/app/private(?:/|$)') { throw 'production defect: Student submission private storage/ownership mismatch.' }
    foreach ($field in @('original_name','extension','mime_type','size_bytes','checksum_sha256')) {
        Assert-Stage7Equal ([string] $File.$field) ([string] $ExpectedFile.$field) "submission $field"
    }
    $blobs = @($Facts.blobs | Where-Object key -CEQ $File.storage_key)
    if ($blobs.Count -ne 1 -or $blobs[0].public_exists -or [long] $blobs[0].size -ne [long] $ExpectedFile.size_bytes -or
        $blobs[0].checksum -cne $ExpectedFile.checksum_sha256) { throw 'production defect: Student submission blob integrity mismatch.' }
}

function Get-Stage7SchedulerCandidates {
    param([string] $BackendContainerName = 'testlabuz-stage7-e2e-app')
    $program = @'
if (!app()->environment('testing') || DB::connection()->getDriverName() !== 'pgsql' || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') { throw new RuntimeException('Stage 7 scheduler guard identity failed.'); }
$candidates = DB::table('homework_assignments')->select(['institution_id','assessment_id'])->where('status','active')
    ->whereNotNull('deadline_at')->where('deadline_at','<=',now())->whereExists(function($q) {
        $q->selectRaw('1')->from('assessment_attempts')->whereColumn('assessment_attempts.institution_id','homework_assignments.institution_id')
          ->whereColumn('assessment_attempts.assessment_id','homework_assignments.assessment_id')->where('assessment_attempts.status','in_progress');
    })->orderBy('assessment_id')->get();
echo json_encode(['candidates'=>$candidates], JSON_THROW_ON_ERROR);
'@
    $result = Invoke-Stage7ContainerPhp -BackendContainerName $BackendContainerName -Program $program
    @($result.candidates)
}

function Assert-Stage7SchedulerCandidates {
    param([AllowEmptyCollection()][object[]] $Candidates, $Manifest, [switch] $SecondInvocation)
    foreach ($candidate in $Candidates) {
        if ($candidate.assessment_id -cnotin @($Manifest.homework.PSObject.Properties.Value)) { throw 'environment/runtime defect: Unexpected non-Stage-7 global scheduler candidate; isolation failure.' }
    }
    if ($SecondInvocation) {
        if ($Candidates.Count -ne 0) { throw 'integration-harness defect: Second scheduler invocation requires zero global candidates.' }
    }
    elseif ($Candidates.Count -ne 1 -or $Candidates[0].assessment_id -cne $Manifest.homework.scheduler -or $Candidates[0].institution_id -cne $Manifest.institutions.target) {
        throw 'integration-harness defect: First scheduler invocation requires exactly the manifest Scheduler Homework.'
    }
}

function Assert-Stage7TenantRows {
    param($Facts)
    $m = $Facts.manifest
    if (@($Facts.public_blobs).Count -ne 0) { throw 'production defect: Stage 7 submission blob exists on public storage.' }
    $relations = @{
        institution_settings = @{ institution_id = 'institutions' }
        users = @{ institution_id = 'institutions' }
        groups = @{ institution_id = 'institutions' }
        topics = @{ institution_id = 'institutions'; group_id = 'groups'; teacher_id = 'users' }
        group_teacher_memberships = @{ group_id = 'groups'; teacher_id = 'users' }
        group_student_memberships = @{ group_id = 'groups'; student_id = 'users' }
        assessments = @{ topic_id = 'topics'; teacher_id = 'users' }
        homework_assignments = @{ assessment_id = 'assessments' }
        assessment_students = @{ assessment_id = 'assessments'; student_id = 'users' }
        questions = @{ assessment_id = 'assessments' }
        question_choice_options = @{ question_id = 'questions' }
        question_matching_items = @{ question_id = 'questions' }
        question_ordering_items = @{ question_id = 'questions' }
        question_fill_blanks = @{ question_id = 'questions' }
        topic_result_pairs = @{ topic_id = 'topics'; homework_assessment_id = 'assessments' }
        assessment_attempts = @{ assessment_id = 'assessments'; assessment_student_id = 'assessment_students'; student_id = 'users' }
        attempt_answers = @{ attempt_id = 'assessment_attempts'; question_id = 'questions' }
        answer_choice_selections = @{ answer_id = 'attempt_answers'; option_id = 'question_choice_options' }
        answer_text_values = @{ answer_id = 'attempt_answers' }
        answer_boolean_values = @{ answer_id = 'attempt_answers' }
        answer_matching_pairs = @{ answer_id = 'attempt_answers'; left_item_id = 'question_matching_items'; right_item_id = 'question_matching_items' }
        answer_ordering_items = @{ answer_id = 'attempt_answers'; ordering_item_id = 'question_ordering_items' }
        answer_fill_blank_values = @{ answer_id = 'attempt_answers'; blank_id = 'question_fill_blanks' }
        answer_files = @{ answer_id = 'attempt_answers'; file_id = 'files' }
        files = @{ uploaded_by_user_id = 'users' }
        idempotency_records = @{ user_id = 'users' }
    }
    foreach ($table in $relations.Keys) {
        foreach ($row in @($Facts.tables.$table)) {
            if ($row.institution_id -cnotin @($m.institutions.target, $m.institutions.foreign)) { throw 'production defect: Cross-Tenant oracle row.' }
            foreach ($column in $relations[$table].Keys) {
                $parentTable = $relations[$table][$column]
                $parent = Get-Stage7Row $Facts $parentTable ([string] $row.$column)
                $institution = if ($parentTable -ceq 'institutions') { $parent.id } else { $parent.institution_id }
                if ($row.institution_id -cne $institution) { throw 'production defect: Cross-Tenant oracle relationship.' }
            }
        }
    }
    foreach ($file in @($Facts.tables.files)) {
        if (@($Facts.tables.answer_files | Where-Object file_id -CEQ $file.id).Count -ne 1) { throw 'production defect: Orphan Stage 7 submission File.' }
    }
    Assert-Stage7Set @($Facts.blobs | ForEach-Object key) @($Facts.tables.files | ForEach-Object storage_key) 'no orphan or old private blobs'
}

function Assert-Stage7LifecycleState {
    param($Facts, $Baseline, [string[]] $Terminal)
    $m = $Facts.manifest
    foreach ($name in @('deadline_read','scheduler','teacher_close','due_teacher_close')) {
        $homework = Get-Stage7Row $Facts homework_assignments $m.homework.$name assessment_id
        $attempt = Get-Stage7Row $Facts assessment_attempts $m.attempts.$name
        $original = Get-Stage7Row $Baseline assessment_attempts $m.attempts.$name
        $attemptRows = @($Facts.tables.assessment_attempts | Where-Object assessment_id -CEQ $m.homework.$name)
        Assert-Stage7Set @($attemptRows.id) @($m.attempts.$name) "no fabricated $name recipient Attempt"
        foreach ($field in @('started_at','assessment_student_id','student_id','possible_points','official_score_eligible')) {
            Assert-Stage7Equal $attempt.$field $original.$field "$name $field preserved"
        }
        if ($name -cin $Terminal) {
            $reason = if ($name -ceq 'teacher_close') { 'task_closed_auto_finalize' } else { 'homework_deadline_auto_submit' }
            $time = if ($name -ceq 'teacher_close') { [string] $homework.closed_at } else { [string] $homework.deadline_at }
            Assert-Stage7TerminalAttempt $attempt $reason $time
            if ($name -cin @('teacher_close','due_teacher_close') -and ($homework.status -cne 'closed' -or $null -eq $homework.closed_at)) { throw 'production defect: Teacher close did not close Homework.' }
        }
        else {
            Assert-Stage7Equal $attempt $original "$name must remain entirely in_progress before its trigger"
            if ($attempt.status -cne 'in_progress' -or $homework.status -cne 'active') { throw 'integration-harness defect: Lifecycle fixture consumed out of sequence.' }
        }
        $answerRows = @($Facts.tables.attempt_answers | Where-Object attempt_id -CEQ $attempt.id)
        $beforeAnswers = @($Baseline.tables.attempt_answers | Where-Object attempt_id -CEQ $attempt.id)
        Assert-Stage7Equal $answerRows $beforeAnswers "$name saved answer parents preserved"
        foreach ($answer in $answerRows) {
            Assert-Stage7TypedAnswer $Facts $answer short_written @($m.saved_text)
            $beforeText = @($Baseline.tables.answer_text_values | Where-Object answer_id -CEQ $answer.id)
            Assert-Stage7Equal @($Facts.tables.answer_text_values | Where-Object answer_id -CEQ $answer.id) $beforeText "$name saved text timestamps preserved"
        }
    }
}

function Get-Stage7FileExpectation {
    param($FileManifest, [string] $Key)
    $fixture = $FileManifest.files.$Key
    [pscustomobject] @{ original_name = $fixture.original_name; extension = $fixture.extension; mime_type = $fixture.mime_type; size_bytes = $fixture.size_bytes; checksum_sha256 = $fixture.sha256 }
}

function Assert-Stage7UiCheckpoint {
    param($Checkpoint, $Facts, $Baseline, $PriorCheckpointFacts, $FileManifest)
    if ([int] $Checkpoint.version -ne 1 -or $Checkpoint.checkpoint -cnotin @('first_start','fake_file_rejected','first_file_uploaded','file_replaced')) { throw 'integration-harness defect: Unknown UI checkpoint.' }
    Assert-Stage7TenantRows $Facts
    $m = $Facts.manifest
    $attempt = Get-Stage7Row $Facts assessment_attempts ([string] $Checkpoint.attempt_id)
    if ($attempt.assessment_id -cne $m.homework.main -or $attempt.student_id -cne $m.users.student -or [int] $attempt.attempt_number -ne 1 -or $attempt.status -cne 'in_progress') { throw 'production defect: UI checkpoint did not persist the first editable Main Attempt.' }
    Assert-Stage7Set @($Facts.tables.assessment_attempts | Where-Object assessment_id -CEQ $m.homework.main | ForEach-Object id) @($attempt.id) 'only first Main Attempt at checkpoint'
    Assert-Stage7Pair (Get-Stage7Row $Facts topic_result_pairs $m.pair) (Get-Stage7Row $Baseline topic_result_pairs $m.pair) $attempt
    $answer = @($Facts.tables.attempt_answers | Where-Object { $_.attempt_id -ceq $attempt.id -and $_.question_id -ceq $m.questions.main.file_based })
    if ($Checkpoint.checkpoint -cin @('first_start','fake_file_rejected')) {
        if ($answer.Count -ne 0 -or @($Facts.tables.files).Count -ne 0 -or @($Facts.blobs).Count -ne 0) { throw 'production defect: Unsupported file or initial Start left a file answer/blob.' }
        return
    }
    if ($answer.Count -ne 1) { throw 'production defect: Saved file answer parent missing.' }
    $file = Get-Stage7Row $Facts files ([string] $Checkpoint.file_id)
    Assert-Stage7TypedAnswer $Facts $answer[0] file_based @($file.id)
    $fixtureKey = if ($Checkpoint.checkpoint -ceq 'first_file_uploaded') { 'valid_pdf' } else { 'replacement_pptx' }
    Assert-Stage7File $Facts $file (Get-Stage7FileExpectation $FileManifest $fixtureKey) $attempt.id $m.questions.main.file_based
    if ($Checkpoint.checkpoint -ceq 'file_replaced') {
        if ($null -eq $PriorCheckpointFacts) { throw 'integration-harness defect: Replacement requires first-upload DB evidence.' }
        $beforeAnswer = @($PriorCheckpointFacts.tables.attempt_answers | Where-Object question_id -CEQ $m.questions.main.file_based)[0]
        $link = Get-Stage7Row $Facts answer_files $answer[0].id answer_id
        $beforeLink = Get-Stage7Row $PriorCheckpointFacts answer_files $beforeAnswer.id answer_id
        Assert-Stage7ReplacementIdentity $beforeAnswer $answer[0] $beforeLink $link
        $beforeFile = Get-Stage7Row $PriorCheckpointFacts files $beforeLink.file_id
        if ($beforeFile.storage_key -ceq $file.storage_key -or @($Facts.blobs | Where-Object key -CEQ $beforeFile.storage_key).Count -ne 0) { throw 'production defect: Old replacement blob remains authoritative/present.' }
    }
}

function Assert-Stage7DatabaseFacts {
    param($Facts, [ValidateSet('Baseline','DeadlineRead','DueClose','TeacherClose','Lifecycle','MainFlow','Automated','ManualReady','ManualSmoke','Cleanup')][string] $Mode,
        $Baseline, $UiEvidence, $UiSnapshots, $FileManifest, $ApiEvidence)
    if ($Mode -ceq 'Cleanup') {
        foreach ($property in $Facts.tables.PSObject.Properties) {
            if (@($property.Value).Count -ne 0) { throw "production defect: Cleanup left manifest-owned $($property.Name) rows." }
        }
        if (@($Facts.blobs).Count -ne 0) { throw 'production defect: Cleanup left manifest-owned private blobs.' }
        if (@($Facts.public_blobs).Count -ne 0) { throw 'production defect: Cleanup left manifest-owned public blob copies.' }
        return
    }
    Assert-Stage7TenantRows $Facts
    $m = $Facts.manifest
    Assert-Stage7AttemptLimit @($Facts.tables.assessment_attempts)
    foreach ($attempt in @($Facts.tables.assessment_attempts)) {
        Assert-Stage7Unscored $attempt @($Facts.tables.attempt_answers | Where-Object attempt_id -CEQ $attempt.id)
    }
    foreach ($name in @('peer_only','historical','foreign')) {
        if (@($Facts.tables.assessment_attempts | Where-Object assessment_id -CEQ $m.homework.$name).Count -ne 0) { throw 'production defect: Unrequested Homework Attempt was fabricated.' }
    }
    $mainAttempts = @($Facts.tables.assessment_attempts | Where-Object assessment_id -CEQ $m.homework.main | Sort-Object attempt_number)
    if (@($mainAttempts | Where-Object student_id -CNE $m.users.student).Count -ne 0) { throw 'production defect: Main peer Attempt fabricated.' }
    if ($mainAttempts.Count -gt 3) { throw 'production defect: Main fourth Attempt exists.' }
    if ($Mode -ceq 'Baseline') {
        if (@($Facts.tables.assessment_attempts).Count -ne 4 -or $mainAttempts.Count -ne 0 -or @($Facts.tables.files).Count -ne 0 -or @($Facts.tables.idempotency_records).Count -ne 0) { throw 'integration-harness defect: Baseline is already mutated.' }
        $pair = Get-Stage7Row $Facts topic_result_pairs $m.pair
        if ($null -ne $pair.locked_at -or $null -eq $pair.cohort_snapshotted_at -or $null -ne $pair.blitz_assessment_id -or $pair.homework_assessment_id -cne $m.homework.main) { throw 'integration-harness defect: Baseline official pair mismatch.' }
        Assert-Stage7LifecycleState $Facts $Facts @()
        foreach ($name in @('deadline_read','scheduler','due_teacher_close','teacher_close','main')) {
            $homework = Get-Stage7Row $Facts homework_assignments $m.homework.$name assessment_id
            $due = [DateTimeOffset] $homework.deadline_at -le [DateTimeOffset] $Facts.observed_at
            if ($homework.status -cne 'active' -or $due -ne ($name -cin @('deadline_read','scheduler','due_teacher_close'))) { throw 'integration-harness defect: Baseline lifecycle deadline/status mismatch.' }
            if ($name -cne 'main') {
                $attempt = Get-Stage7Row $Facts assessment_attempts $m.attempts.$name
                foreach ($field in @('submitted_at','finalized_at','locked_at','finalization_reason')) { if ($null -ne $attempt.$field) { throw 'integration-harness defect: Lifecycle baseline is already terminal.' } }
                if ([DateTimeOffset] $attempt.started_at -ge [DateTimeOffset] $homework.deadline_at) { throw 'integration-harness defect: Lifecycle Attempt did not start before deadline.' }
            }
        }
        $questions = @($Facts.tables.questions | Where-Object assessment_id -CEQ $m.homework.main | Sort-Object position)
        Assert-Stage7Equal @($questions.type) @('single_choice','multiple_choice','true_false','short_written','open_written','file_based','matching','ordering','fill_in_blank') 'nine Question types/order'
        Assert-Stage7Equal @($questions.position | ForEach-Object { [int] $_ }) @(1,2,3,4,5,6,7,8,9) 'nine Question positions'
        Assert-Stage7Set @($Facts.tables.assessment_students | Where-Object assessment_id -CEQ $m.homework.main | ForEach-Object student_id) @($m.users.student,$m.users.peer_student) 'main recipient snapshot'
        $setting = Get-Stage7Row $Facts institution_settings $m.institutions.target institution_id
        if ([int] $setting.student_submission_max_mb -ne 2) { throw 'integration-harness defect: Submission limit fixture mismatch.' }
        foreach ($actor in $m.users.PSObject.Properties) {
            $user = Get-Stage7Row $Facts users $actor.Value
            $role = if ($actor.Name.Contains('teacher')) { 'teacher' } elseif ($actor.Name -ceq 'parent') { 'parent' } else { 'student' }
            if ($user.login_name -cne "e2e_s07_$($actor.Name)" -or $user.role -cne $role -or -not $user.is_active -or $user.must_change_password) { throw 'integration-harness defect: Actor identity/role mismatch.' }
        }
        $historicalMembership = @($Facts.tables.group_student_memberships | Where-Object { $_.group_id -ceq $m.groups.historical -and $_.student_id -ceq $m.users.student })
        if ($historicalMembership.Count -ne 1 -or $null -eq $historicalMembership[0].ended_at) { throw 'integration-harness defect: Historical membership has not ended.' }
        if (@($Facts.tables.assessment_students | Where-Object { $_.assessment_id -ceq $m.homework.historical -and $_.student_id -ceq $m.users.student }).Count -ne 1) { throw 'integration-harness defect: Historical frozen assignment missing.' }
        return
    }
    if ($Mode -cin @('DeadlineRead','DueClose','TeacherClose','Lifecycle','MainFlow','Automated')) {
        if ($null -eq $Baseline) { throw 'integration-harness defect: Baseline evidence required.' }
        $terminal = switch ($Mode) {
            'DeadlineRead' { @('deadline_read') }
            'DueClose' { @('deadline_read','due_teacher_close') }
            'TeacherClose' { @('deadline_read','due_teacher_close','teacher_close') }
            default { @('deadline_read','due_teacher_close','teacher_close','scheduler') }
        }
        Assert-Stage7LifecycleState $Facts $Baseline @($terminal)
        if ($Mode -cin @('Lifecycle','MainFlow','Automated')) {
            foreach ($homework in @($Facts.tables.homework_assignments)) {
                if ($homework.status -ceq 'active' -and $null -ne $homework.deadline_at -and [DateTimeOffset] $homework.deadline_at -le [DateTimeOffset] $Facts.observed_at -and
                    @($Facts.tables.assessment_attempts | Where-Object { $_.assessment_id -ceq $homework.assessment_id -and $_.status -ceq 'in_progress' }).Count -ne 0) {
                    throw 'integration-harness defect: Due Stage 7 in_progress Attempt remains before/after Main UI.'
                }
            }
        }
        if ($Mode -cin @('DeadlineRead','DueClose','TeacherClose','Lifecycle')) {
            if ($mainAttempts.Count -ne 0) { throw 'integration-harness defect: Lifecycle preparation consumed Main Homework.' }
            Assert-Stage7Equal (Get-Stage7Row $Facts topic_result_pairs $m.pair) (Get-Stage7Row $Baseline topic_result_pairs $m.pair) 'Main pair untouched by lifecycle'
            return
        }
    }
    $manualAttempts = @($Facts.tables.assessment_attempts | Where-Object assessment_id -CEQ $m.homework.android_smoke)
    if ($Mode -ceq 'ManualSmoke') {
        if ($manualAttempts.Count -ne 1) { throw 'production defect: Android smoke requires exactly one Attempt.' }
        $attempt = $manualAttempts[0]
        Assert-Stage7TerminalAttempt $attempt student_submit ([string] $attempt.submitted_at)
        $answers = @($Facts.tables.attempt_answers | Where-Object attempt_id -CEQ $attempt.id)
        Assert-Stage7Set @($answers.question_id) @($m.questions.android_smoke.single_choice,$m.questions.android_smoke.short_written) 'exact two Android answers'
        foreach ($answer in $answers) {
            $type = (Get-Stage7Row $Facts questions $answer.question_id).type
            $expected = if ($type -ceq 'single_choice') { @($Facts.tables.answer_choice_selections | Where-Object answer_id -CEQ $answer.id | ForEach-Object option_id) } else { @($Facts.tables.answer_text_values | Where-Object answer_id -CEQ $answer.id | ForEach-Object text_value) }
            if (@($expected).Count -ne 1 -or [string]::IsNullOrWhiteSpace([string] $expected[0])) { throw 'production defect: Android saved answer missing.' }
            Assert-Stage7TypedAnswer $Facts $answer $type @($expected)
        }
        return
    }
    if ($manualAttempts.Count -ne 0) { throw 'integration-harness defect: Automated runner changed Android fixture.' }
    if ($Mode -ceq 'ManualReady') {
        $homework = Get-Stage7Row $Facts homework_assignments $m.homework.android_smoke assessment_id
        if ($homework.status -cne 'active' -or [DateTimeOffset] $homework.deadline_at -le [DateTimeOffset] $Facts.observed_at) { throw 'integration-harness defect: Android fixture is not ready.' }
        return
    }
    if ($mainAttempts.Count -ne 3 -or $null -eq $UiEvidence -or $null -eq $UiSnapshots) { throw 'integration-harness defect: Main oracle requires all three Attempts and UI/checkpoint evidence.' }
    $uiKeys = @('07111111-1111-4111-8111-111111111111','07222222-2222-4222-8222-222222222222','07333333-3333-4333-8333-333333333333','07444444-4444-4444-8444-444444444444','07555555-5555-4555-8555-555555555555','07666666-6666-4666-8666-666666666666')
    Assert-Stage7Equal @($UiEvidence.idempotency_keys) $uiKeys 'exact six UI idempotency operations, no redundant Start during Resume'
    Assert-Stage7Equal @($mainAttempts.id) @($UiEvidence.attempt_ids) 'UI/DB Main Attempt identities'
    Assert-Stage7Pair (Get-Stage7Row $Facts topic_result_pairs $m.pair) (Get-Stage7Row $Baseline topic_result_pairs $m.pair) $mainAttempts[0]
    $firstPair = Get-Stage7Row $UiSnapshots.first_start topic_result_pairs $m.pair
    Assert-Stage7Equal (Get-Stage7Row $Facts topic_result_pairs $m.pair).locked_at $firstPair.locked_at 'pair lock unchanged on later Attempts'
    $assessment = Get-Stage7Row $Facts assessments $m.homework.main
    foreach ($attempt in $mainAttempts) {
        Assert-Stage7TerminalAttempt $attempt student_submit ([string] $attempt.submitted_at)
        if (-not $attempt.official_score_eligible -or [decimal] $attempt.possible_points -ne [decimal] $assessment.total_possible_points) { throw 'production defect: Official Attempt snapshot mismatch.' }
        $answers = @($Facts.tables.attempt_answers | Where-Object attempt_id -CEQ $attempt.id)
        $expectedCount = if ([int] $attempt.attempt_number -eq 1) { 9 } else { 0 }
        if ($answers.Count -ne $expectedCount) { throw 'production defect: Main saved-answer count mismatch.' }
    }
    $nested = $m.nested.main
    $expectedAnswers = @{
        single_choice = @($nested.single_choice[1]); multiple_choice = @($nested.multiple_choice[0],$nested.multiple_choice[2]); true_false = @($true)
        short_written = @("O‘zbekiston — E2E S07"); open_written = @("E2E S07 first line`nStudent's second line")
        matching = @("$($nested.matching.left[0]):$($nested.matching.right[1])")
        ordering = @("$($nested.ordering[1]):1","$($nested.ordering[0]):2")
        fill_in_blank = @("$($nested.fill_in_blank[0]):E2E S07 partial blank"); file_based = @($UiEvidence.replacement_file_id)
    }
    foreach ($type in $expectedAnswers.Keys) {
        $answer = @($Facts.tables.attempt_answers | Where-Object { $_.attempt_id -ceq $mainAttempts[0].id -and $_.question_id -ceq $m.questions.main.$type })
        if ($answer.Count -ne 1) { throw 'production defect: Main answer identity mismatch.' }
        Assert-Stage7TypedAnswer $Facts $answer[0] $type $expectedAnswers[$type]
    }
    Assert-Stage7Equal $UiEvidence.first_file_id $UiEvidence.replacement_file_id 'UI replacement File ID'
    $file = Get-Stage7Row $Facts files $UiEvidence.replacement_file_id
    Assert-Stage7File $Facts $file (Get-Stage7FileExpectation $FileManifest replacement_pptx) $mainAttempts[0].id $m.questions.main.file_based
    $replacementFile = Get-Stage7Row $UiSnapshots.file_replaced files $file.id
    Assert-Stage7Equal $file $replacementFile 'file persistence after replacement'
    for ($i = 0; $i -lt 6; $i++) {
        $key = [string] $UiEvidence.idempotency_keys[$i]
        $operation = if ($i % 2 -eq 0) { 'student.homework.attempt.start' } else { 'student.homework.attempt.submit' }
        $status = if ($i % 2 -eq 0) { 201 } else { 200 }
        $rows = @($Facts.tables.idempotency_records | Where-Object { $_.idempotency_key -ceq $key -and $_.operation -ceq $operation })
        if ($rows.Count -ne 1) { throw 'production defect: UI idempotency record missing/duplicated.' }
        Assert-Stage7IdempotencyRecord $rows[0] $m.institutions.target $m.users.student $operation $key $mainAttempts[[int][Math]::Floor($i / 2)].id $status
    }
    if ($Mode -ceq 'Automated') {
        if ($null -eq $ApiEvidence) { throw 'integration-harness defect: Automated oracle requires direct API evidence.' }
        Assert-Stage7ApiPersistence $Facts $ApiEvidence
    }
}

function Assert-Stage7ApiPersistence {
    param($Facts, $Evidence)
    $m = $Facts.manifest
    $attempts = @($Facts.tables.assessment_attempts | Where-Object assessment_id -CEQ $m.homework.idempotency)
    Assert-Stage7Set @($attempts.id) @($Evidence.attempt_id) 'one idempotency Homework Attempt'
    Assert-Stage7TerminalAttempt $attempts[0] student_submit ([string] $Evidence.submitted_at)
    foreach ($success in @($Evidence.success_keys)) {
        $records = @($Facts.tables.idempotency_records | Where-Object { $_.idempotency_key -ceq $success.key -and $_.operation -ceq $success.operation })
        if ($records.Count -ne 1) { throw 'production defect: Direct API idempotency success record missing.' }
        Assert-Stage7IdempotencyRecord $records[0] $m.institutions.target $m.users.student $success.operation $success.key $Evidence.attempt_id ([int] $success.status)
    }
    foreach ($key in @($Evidence.rejected_keys)) {
        if (@($Facts.tables.idempotency_records | Where-Object idempotency_key -CEQ $key).Count -ne 0) { throw 'production defect: Rejected operation committed idempotency state.' }
    }
    Assert-Stage7Equal @($Facts.tables.attempt_answers | Where-Object attempt_id -CEQ $Evidence.attempt_id) @($Evidence.answers) 'direct API answers remain exact'
    foreach ($table in $Evidence.typed_answers.PSObject.Properties.Name) {
        $answerIds = @($Evidence.answers | ForEach-Object id)
        Assert-Stage7Equal @($Facts.tables.$table | Where-Object answer_id -CIN $answerIds) @($Evidence.typed_answers.$table) 'direct API normalized child persistence'
    }
    if (@($Facts.tables.idempotency_records).Count -ne 9) { throw 'production defect: Unexpected/incomplete idempotency rows beyond six UI and three API successes.' }
}

function Assert-Stage7RestartPersistence {
    param($Before, $After)
    Assert-Stage7Equal $After.tables $Before.tables 'DB state after backend restart'
    Assert-Stage7Equal $After.blobs $Before.blobs 'private blob state after backend restart'
    Assert-Stage7Equal $After.public_blobs $Before.public_blobs 'public blob absence after backend restart'
    Assert-Stage7Equal $After.private_disk $Before.private_disk 'private disk after restart'
}

function Wait-Stage7TimestampBoundary {
    param([string] $Timestamp, [string] $BackendContainerName = 'testlabuz-stage7-e2e-app')
    # Persisted timestamps have second precision. A later observed server second makes
    # timestamp no-op assertions capable of detecting an accidental rewrite.
    $recorded = [DateTimeOffset] $Timestamp
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt 10) {
        $clock = Invoke-Stage7ContainerPhp -BackendContainerName $BackendContainerName -Program 'echo json_encode(["now"=>now()->utc()->format("Y-m-d\\TH:i:s\\Z")], JSON_THROW_ON_ERROR);'
        if ([DateTimeOffset] $clock.now -gt $recorded) { return }
    }
    throw 'environment/runtime defect: Server clock did not advance beyond the recorded timestamp within the bounded wait.'
}
