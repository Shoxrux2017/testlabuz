Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage8_runtime_guard.ps1')

$script:Stage8AnswerTables = @('answer_choice_selections', 'answer_text_values', 'answer_boolean_values', 'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files')
$script:Stage8PrivateRootPath = '/var/www/html/storage/app/private'

function Assert-Stage8Equal {
    param($Actual, $Expected, [string] $Label)
    if ((ConvertTo-Json -InputObject $Actual -Depth 60 -Compress) -cne (ConvertTo-Json -InputObject $Expected -Depth 60 -Compress)) {
        throw "production defect: Stage 8 oracle mismatch: $Label."
    }
}

function Assert-Stage8Set {
    param([AllowEmptyCollection()][object[]] $Actual, [AllowEmptyCollection()][object[]] $Expected, [string] $Label)
    Assert-Stage8Equal @($Actual | Sort-Object) @($Expected | Sort-Object) $Label
}

function Get-Stage8Row {
    param($Facts, [string] $Table, [string] $Id, [string] $Column = 'id')
    $rows = @($Facts.tables.$Table | Where-Object { [string] $_.$Column -ceq $Id })
    if ($rows.Count -ne 1) { throw "integration-harness defect: Stage 8 oracle requires one $Table row." }
    $rows[0]
}

function Get-Stage8Rows {
    param($Facts, [string] $Table, [string] $Column, [string] $Value)
    @($Facts.tables.$Table | Where-Object { [string] $_.$Column -ceq $Value })
}

function ConvertTo-Stage8Instant { param([AllowNull()] $Value) if ($null -eq $Value) { $null } else { ([DateTimeOffset] [string] $Value).ToUniversalTime() } }

function Assert-Stage8SameInstant {
    param([AllowNull()] $Actual, [AllowNull()] $Expected, [string] $Label)
    if ($null -eq $Actual -or $null -eq $Expected -or (ConvertTo-Stage8Instant $Actual) -ne (ConvertTo-Stage8Instant $Expected)) {
        throw "production defect: Stage 8 oracle timestamp mismatch: $Label."
    }
}

function Get-Stage8DatabaseFacts {
    param([string] $BackendContainerName = 'testlabuz-stage8-e2e-app', $PriorFacts)
    $program = @'
use Database\Seeders\Stage8E2eSeeder;
if (!app()->environment('testing') || DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new RuntimeException('Stage 8 oracle database identity failed.');
}
$seeder = new Stage8E2eSeeder;
$m = Stage8E2eSeeder::manifest();
// Ownership is resolved by the seeder's fail-closed rules, so the oracle never widens the scope.
$state = $seeder->ownedState();
$keys = Stage8E2eSeeder::PRIMARY_KEYS;
$ids = [];
foreach ($state['db'] as $table => $tableIds) { $ids[$table] = $tableIds; }
foreach ($state['dynamic'] as $table => $tableIds) { $ids[$table] = array_values(array_unique([...($ids[$table] ?? []), ...$tableIds])); }
$prior = $stage8Input['prior'] ?? null;
if (is_array($prior)) {
    foreach ($prior['ids'] as $table => $tableIds) { $ids[$table] = array_values(array_unique([...($ids[$table] ?? []), ...$tableIds])); }
}
$tables = [];
foreach ($ids as $table => $tableIds) {
    if ($table === 'personal_access_tokens') {
        $tables[$table] = DB::table($table)->whereIn('id', $tableIds)->orderBy('id')->get(['id', 'tokenable_type', 'tokenable_id'])->map(fn ($r) => (array) $r)->all();
        continue;
    }
    $key = $keys[$table] ?? 'id';
    $tables[$table] = DB::table($table)->whereIn($key, $tableIds)->orderBy($key)->get()->map(function ($row) {
        $values = (array) $row;
        unset($values['password']);
        return $values;
    })->all();
}
$answerIds = array_values(array_unique([...array_column($tables['attempt_answers'] ?? [], 'id'), ...($prior['ids']['attempt_answers'] ?? [])]));
foreach (['answer_choice_selections', 'answer_text_values', 'answer_boolean_values', 'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files'] as $table) {
    $tables[$table] = DB::table($table)->whereIn('answer_id', $answerIds)->orderBy('answer_id')->get()->map(fn ($r) => (array) $r)->all();
}
$diskName = config('filesystems.private_files_disk');
$diskConfig = config('filesystems.disks.'.$diskName);
$root = rtrim((string) ($diskConfig['root'] ?? ''), '/');
$disk = Storage::disk($diskName);
$keysSeen = array_values(array_unique([...array_column($state['blobs'], 'key'), ...($prior['blob_keys'] ?? [])]));
$directories = array_values(array_unique([...array_column($state['directories'], 'key'), ...($prior['directories'] ?? [])]));
foreach ($directories as $directory) {
    if (!preg_match('~^student-submissions/[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}$~D', $directory)) { throw new RuntimeException('Stage 8 oracle directory mismatch.'); }
    foreach ($disk->allFiles($directory) as $key) { $keysSeen[] = $key; }
}
$blobs = [];
$publicBlobs = [];
foreach (array_values(array_unique($keysSeen)) as $key) {
    if ($disk->exists($key)) {
        $blobs[] = ['key' => $key, 'size' => $disk->size($key), 'checksum' => hash_file('sha256', $disk->path($key)), 'public_exists' => is_file(storage_path('app/public/'.$key))];
    }
    if (is_file(storage_path('app/public/'.$key)) || is_file(public_path($key))) { $publicBlobs[] = $key; }
}
usort($blobs, fn ($a, $b) => $a['key'] <=> $b['key']);
sort($publicBlobs);
echo json_encode(['manifest' => $m, 'tables' => $tables, 'dynamic' => $state['dynamic'], 'private_disk' => $diskName, 'private_root' => $root,
    'directories' => $directories, 'blobs' => $blobs, 'public_blobs' => $publicBlobs, 'sentinels' => $seeder->sentinelState(),
    'observed_at' => now()->utc()->format('Y-m-d\TH:i:s.u\Z')], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
'@
    $inputObject = @{}
    if ($null -ne $PriorFacts) {
        $priorIds = @{}
        foreach ($property in $PriorFacts.tables.PSObject.Properties) {
            if ($property.Name -cin $script:Stage8AnswerTables) { continue }
            $key = switch ($property.Name) { 'institution_settings' { 'institution_id' } 'blitz_tasks' { 'assessment_id' } 'homework_assignments' { 'assessment_id' } 'question_true_false_answers' { 'question_id' } default { 'id' } }
            $priorIds[$property.Name] = @($property.Value | ForEach-Object { [string] $_.$key })
        }
        $inputObject.prior = @{ ids = $priorIds; directories = @($PriorFacts.directories); blob_keys = @($PriorFacts.blobs | ForEach-Object key) }
    }
    Invoke-Stage8ContainerPhp -BackendContainerName $BackendContainerName -Program $program -InputJson ($inputObject | ConvertTo-Json -Depth 30 -Compress)
}

function Get-Stage8SentinelFacts {
    $program = @'
if (!app()->environment('testing') || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') { throw new RuntimeException('Stage 8 sentinel identity failed.'); }
echo json_encode((new Database\Seeders\Stage8E2eSeeder)->sentinelState(), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
'@
    Invoke-Stage8ContainerPhp -Program $program
}

function Assert-Stage8SentinelsUnchanged {
    param($Before, $After, [string] $Label)
    if ($null -eq $Before -or $null -eq $Before.blob -or @($Before.rows.PSObject.Properties).Count -eq 0) { throw 'integration-harness defect: Stage 8 unrelated sentinels were not captured.' }
    Assert-Stage8Equal $After $Before "unrelated sentinel unchanged by $Label"
}

function Assert-Stage8Unscored {
    param($Attempt, [AllowEmptyCollection()][object[]] $Answers)
    foreach ($field in @('earned_points', 'normalized_score', 'scoring_completed_at')) {
        if ($null -ne $Attempt.$field) { throw 'production defect: Stage 8 Attempt contains scoring data.' }
    }
    foreach ($answer in $Answers) {
        if ($answer.checking_status -cne 'pending') { throw 'production defect: Stage 8 answer was checked.' }
        foreach ($field in @('awarded_points', 'feedback', 'checked_by_user_id', 'checked_at')) {
            if ($null -ne $answer.$field) { throw 'production defect: Stage 8 answer contains scoring/review data.' }
        }
    }
}

function Assert-Stage8BlitzLifecycle {
    param($Blitz, [string] $Status, [AllowEmptyString()][AllowNull()][string] $TimerMode, [int] $Duration)
    if ($Blitz.status -cne $Status -or [int] $Blitz.duration_seconds -ne $Duration) { throw 'production defect: Stage 8 Blitz lifecycle status/duration mismatch.' }
    if ([string] $Blitz.timer_start_mode_snapshot -cne [string] $TimerMode) { throw 'production defect: Stage 8 Blitz timer snapshot mismatch.' }
    # A [string] parameter turns $null into '', so an unactivated Blitz arrives as an empty mode.
    if ([string]::IsNullOrEmpty($TimerMode)) {
        foreach ($field in @('activated_at', 'synchronized_ends_at', 'activated_by_user_id')) { if ($null -ne $Blitz.$field) { throw 'production defect: Unactivated Stage 8 Blitz carries activation timing.' } }
        return
    }
    if ($null -eq $Blitz.activated_at) { throw 'production defect: Activated Stage 8 Blitz has no activation instant.' }
    if ($TimerMode -ceq 'synchronized') {
        Assert-Stage8SameInstant $Blitz.synchronized_ends_at ((ConvertTo-Stage8Instant $Blitz.activated_at).AddSeconds($Duration)) 'synchronized common end = activated_at + duration'
    }
    elseif ($null -ne $Blitz.synchronized_ends_at) { throw 'production defect: Individual Stage 8 Blitz has a common end.' }
    if ($Status -ceq 'closed' -and $null -eq $Blitz.closed_at) { throw 'production defect: Closed Stage 8 Blitz has no close instant.' }
    if ($Status -ceq 'active' -and ($null -ne $Blitz.closed_at -or $null -ne $Blitz.archived_at)) { throw 'production defect: Active Stage 8 Blitz has terminal timestamps.' }
}

function Assert-Stage8Recipients {
    param($Facts, [string] $AssessmentId, [AllowEmptyCollection()][string[]] $StudentIds, [string] $Label)
    Assert-Stage8Set @(Get-Stage8Rows $Facts assessment_students assessment_id $AssessmentId | ForEach-Object { [string] $_.student_id }) $StudentIds "$Label recipients"
}

function Assert-Stage8OfficialPair {
    param($Pair, $Baseline, [AllowNull()] $BlitzId)
    foreach ($field in @('id', 'institution_id', 'topic_id', 'homework_assessment_id', 'cohort_snapshotted_at', 'locked_at')) {
        Assert-Stage8Equal $Pair.$field $Baseline.$field "official pair $field preserved"
    }
    Assert-Stage8Equal $Pair.blitz_assessment_id $BlitzId 'official pair Blitz side'
}

function Assert-Stage8CohortEstablished {
    param($Pair, $Blitz, $Facts, [string[]] $CohortStudentIds, [string] $HomeworkId)
    Assert-Stage8SameInstant $Pair.cohort_snapshotted_at $Blitz.activated_at 'first official Blitz activation establishes the cohort'
    if ($null -ne $Pair.locked_at) { throw 'production defect: Activation alone locked the Stage 8 pair.' }
    Assert-Stage8Recipients $Facts $Blitz.assessment_id $CohortStudentIds 'established Blitz cohort'
    Assert-Stage8Recipients $Facts $HomeworkId @() 'no Homework recipients fabricated by Blitz activation'
}

# Blitz-first official activity must not block the later official Homework activation or its first Start.
function Assert-Stage8BlitzFirstHomework {
    param($HomeworkActivation, $HomeworkStart, $PairAfterBlitzStart, $PairAfterHomeworkStart, $BlitzAttempt, $Facts, [string] $HomeworkId, [string[]] $CohortStudentIds)
    if ([int] $HomeworkActivation.StatusCode -ne 200) { throw 'production defect: Blitz-first pair lock blocked the official Homework activation.' }
    if ([int] $HomeworkStart.StatusCode -ne 201 -or [int] $HomeworkStart.Json.data.attempt_number -ne 1) { throw 'production defect: Blitz-first pair lock blocked the first Homework Start.' }
    Assert-Stage8SameInstant $PairAfterBlitzStart.locked_at $BlitzAttempt.started_at 'pair locked by the first Blitz Start'
    foreach ($field in @('locked_at', 'updated_at', 'homework_assessment_id', 'blitz_assessment_id', 'cohort_snapshotted_at')) {
        Assert-Stage8Equal $PairAfterHomeworkStart.$field $PairAfterBlitzStart.$field "Homework Start keeps pair $field"
    }
    Assert-Stage8Recipients $Facts $HomeworkId $CohortStudentIds 'Homework reuses the Blitz-established cohort'
}

function Assert-Stage8TerminalAttempt {
    param($Attempt, [ValidateSet('student_submit', 'timeout_auto_submit', 'task_closed_auto_finalize')][string] $Reason, [string] $At)
    $status = if ($Reason -ceq 'timeout_auto_submit') { 'timed_out_finalized' } else { 'submitted' }
    if ($Attempt.status -cne $status -or $Attempt.finalization_reason -cne $Reason) { throw 'production defect: Stage 8 Attempt terminal status/reason mismatch.' }
    if ($Reason -ceq 'timeout_auto_submit') { $At = [string] $Attempt.deadline_at }
    foreach ($field in @('finalized_at', 'locked_at')) { Assert-Stage8SameInstant $Attempt.$field $At "terminal $field" }
    if ($Reason -ceq 'student_submit') {
        Assert-Stage8SameInstant $Attempt.submitted_at $At 'submitted_at'
        if ((ConvertTo-Stage8Instant $Attempt.finalized_at) -ge (ConvertTo-Stage8Instant $Attempt.deadline_at)) { throw 'production defect: Explicit Submit finalized at/after the deadline.' }
    }
    elseif ($null -ne $Attempt.submitted_at) { throw 'production defect: Auto-finalized Stage 8 Attempt fabricated submitted_at.' }
}

function Assert-Stage8AttemptDeadline {
    param($Attempt, $Blitz)
    if ([int] $Attempt.attempt_number -eq 1 -and $Blitz.timer_start_mode_snapshot -ceq 'synchronized') {
        Assert-Stage8SameInstant $Attempt.deadline_at $Blitz.synchronized_ends_at 'synchronized #1 deadline = common end'
    }
    else {
        Assert-Stage8SameInstant $Attempt.deadline_at ((ConvertTo-Stage8Instant $Attempt.started_at).AddSeconds([int] $Blitz.duration_seconds)) 'own deadline = started_at + duration'
    }
}

# The full history of one Student in one Blitz: #1, optional exception, optional #2 and never #3.
function Assert-Stage8AttemptHistory {
    param($Facts, [string] $AssessmentId, [string] $StudentId)
    $attempts = @(Get-Stage8Rows $Facts assessment_attempts assessment_id $AssessmentId | Where-Object student_id -CEQ $StudentId | Sort-Object { [int] $_.attempt_number })
    $blitz = Get-Stage8Row $Facts blitz_tasks $AssessmentId assessment_id
    $exceptions = @(Get-Stage8Rows $Facts blitz_attempt_exceptions assessment_id $AssessmentId | Where-Object student_id -CEQ $StudentId)
    if ($attempts.Count -gt 2 -or @($attempts | Where-Object { [int] $_.attempt_number -gt 2 }).Count -ne 0) { throw 'production defect: Stage 8 Attempt #3 exists.' }
    if ($attempts.Count -gt 0) { Assert-Stage8Equal @($attempts | ForEach-Object { [int] $_.attempt_number }) @(1..$attempts.Count) 'contiguous Attempt numbers' }
    if ($exceptions.Count -gt 1) { throw 'production defect: More than one Stage 8 exception.' }
    $recipient = @(Get-Stage8Rows $Facts assessment_students assessment_id $AssessmentId | Where-Object student_id -CEQ $StudentId)
    if ($attempts.Count -gt 0 -and $recipient.Count -ne 1) { throw 'production defect: Stage 8 Attempt without a recipient.' }
    foreach ($attempt in $attempts) {
        if ($attempt.assessment_student_id -cne $recipient[0].id -or $attempt.institution_id -cne $blitz.institution_id) { throw 'production defect: Stage 8 Attempt ownership mismatch.' }
        Assert-Stage8AttemptDeadline $attempt $blitz
    }
    if ($attempts.Count -eq 2) {
        if ($exceptions.Count -ne 1) { throw 'production defect: Stage 8 replacement #2 exists without an exception.' }
        if ($exceptions[0].replacement_attempt_id -cne $attempts[1].id) { throw 'production defect: Stage 8 exception does not link #2.' }
        if ((ConvertTo-Stage8Instant $attempts[1].started_at) -lt (ConvertTo-Stage8Instant $exceptions[0].granted_at)) { throw 'production defect: Stage 8 #2 started before its grant.' }
        if (-not [bool] $attempts[1].official_score_eligible) { throw 'production defect: Stage 8 replacement #2 must stay official-score eligible.' }
    }
    if ($exceptions.Count -eq 1) {
        if ($attempts.Count -lt 1 -or $exceptions[0].invalidated_attempt_id -cne $attempts[0].id) { throw 'production defect: Stage 8 exception invalidates the wrong Attempt.' }
        if ([bool] $attempts[0].official_score_eligible) { throw 'production defect: Stage 8 invalidated #1 is still official-score eligible.' }
        if ($attempts[0].status -ceq 'in_progress') { throw 'production defect: Stage 8 exception granted on an in-progress #1.' }
        if ($attempts.Count -eq 1 -and $null -ne $exceptions[0].replacement_attempt_id) { throw 'production defect: Stage 8 exception links a missing #2.' }
    }
    elseif ($attempts.Count -ge 1 -and -not [bool] $attempts[0].official_score_eligible) { throw 'production defect: Stage 8 #1 lost eligibility without an exception.' }
    [pscustomobject] @{ Attempts = $attempts; Exception = $(if ($exceptions.Count -eq 1) { $exceptions[0] } else { $null }) }
}

function Assert-Stage8Exception {
    param($Exception, [string] $InvalidatedId, [AllowNull()][string] $ReplacementId, [string] $ReasonType, [string] $Reason, [string] $GrantedBy)
    if ($null -eq $Exception -or $Exception.invalidated_attempt_id -cne $InvalidatedId -or [string] $Exception.replacement_attempt_id -cne [string] $ReplacementId -or
        $Exception.reason_type -cne $ReasonType -or $Exception.reason -cne $Reason -or $Exception.granted_by_user_id -cne $GrantedBy -or $null -eq $Exception.granted_at) {
        throw 'production defect: Stage 8 exception row mismatch.'
    }
}

function Assert-Stage8TypedAnswer {
    param($Facts, $Answer, [string] $Type, [AllowEmptyCollection()][object[]] $Expected)
    $expectedTable = switch ($Type) {
        { $_ -in @('single_choice', 'multiple_choice') } { 'answer_choice_selections' }
        { $_ -in @('short_written', 'open_written') } { 'answer_text_values' }
        'true_false' { 'answer_boolean_values' }
        'matching' { 'answer_matching_pairs' }
        'ordering' { 'answer_ordering_items' }
        'fill_in_blank' { 'answer_fill_blank_values' }
        'file_based' { 'answer_files' }
        default { throw 'integration-harness defect: Unknown Stage 8 answer type.' }
    }
    foreach ($table in $script:Stage8AnswerTables) {
        $rows = @($Facts.tables.$table | Where-Object answer_id -CEQ $Answer.id)
        if ($table -cne $expectedTable -and $rows.Count -ne 0) { throw 'production defect: Stage 8 answer has wrong typed-child residue.' }
        if ($table -ceq $expectedTable) {
            $actual = @($rows | ForEach-Object {
                $row = $_
                switch ($Type) {
                    { $_ -in @('single_choice', 'multiple_choice') } { [string] $row.option_id }
                    { $_ -in @('short_written', 'open_written') } { [string] $row.text_value }
                    'true_false' { [bool] $row.boolean_value }
                    'matching' { "$($row.left_item_id):$($row.right_item_id)" }
                    'ordering' { "$($row.ordering_item_id):$($row.submitted_position)" }
                    'fill_in_blank' { "$($row.blank_id):$($row.text_value)" }
                    'file_based' { [string] $row.file_id }
                }
            })
            Assert-Stage8Set $actual $Expected "$Type normalized persistence"
        }
    }
}

# No placeholder rows: exactly the answered Questions have answer rows.
function Assert-Stage8AnswerSet {
    param($Facts, [string] $AttemptId, [AllowEmptyCollection()][string[]] $AnsweredQuestionIds)
    $answers = @(Get-Stage8Rows $Facts attempt_answers attempt_id $AttemptId)
    Assert-Stage8Set @($answers | ForEach-Object { [string] $_.question_id }) $AnsweredQuestionIds 'exact answered Questions, no fabricated unanswered rows'
    $attempt = Get-Stage8Row $Facts assessment_attempts $AttemptId
    Assert-Stage8Unscored $attempt $answers
    $answers
}

function Assert-Stage8File {
    param($Facts, $File, $ExpectedFile, $Attempt, [string] $QuestionId)
    $prefix = "student-submissions/$($Attempt.institution_id)/$($Attempt.id)/$QuestionId/"
    if ($File.category -cne 'student_submission' -or $File.uploaded_by_user_id -cne $Attempt.student_id -or
        $File.institution_id -cne $Attempt.institution_id -or $null -ne $File.removed_at -or
        $File.storage_disk -cne $Facts.private_disk -or -not ([string] $File.storage_key).StartsWith($prefix, [StringComparison]::Ordinal) -or
        [string] $File.storage_key -match '(^|/)\.\.(/|$)|public|\\' -or
        $Facts.private_root -notmatch '\A/var/www/html/storage/app/private(?:/|$)') { throw 'production defect: Stage 8 Student submission private storage/ownership mismatch.' }
    foreach ($field in @('original_name', 'extension', 'mime_type', 'size_bytes', 'checksum_sha256')) {
        Assert-Stage8Equal ([string] $File.$field) ([string] $ExpectedFile.$field) "submission $field"
    }
    $blobs = @($Facts.blobs | Where-Object key -CEQ $File.storage_key)
    if ($blobs.Count -ne 1 -or $blobs[0].public_exists -or [long] $blobs[0].size -ne [long] $ExpectedFile.size_bytes -or
        $blobs[0].checksum -cne $ExpectedFile.checksum_sha256) { throw 'production defect: Stage 8 Student submission blob integrity mismatch.' }
}

function Get-Stage8FileExpectation {
    param($FileManifest, [string] $Key)
    $fixture = $FileManifest.Files[$Key]
    [pscustomobject] @{ original_name = $fixture.original_name; extension = $fixture.extension; mime_type = $fixture.mime_type; size_bytes = $fixture.size_bytes; checksum_sha256 = $fixture.sha256 }
}

# Every private blob under an owned submission directory must be the current file of a linked answer.
function Assert-Stage8NoOrphanBlob {
    param($Facts)
    if (@($Facts.public_blobs).Count -ne 0) { throw 'production defect: Stage 8 submission blob exists on public storage.' }
    Assert-Stage8Set @($Facts.blobs | ForEach-Object key) @($Facts.tables.files | ForEach-Object storage_key) 'no orphan, stale or uncompensated private blobs'
    foreach ($file in @($Facts.tables.files)) {
        if (@($Facts.tables.answer_files | Where-Object file_id -CEQ $file.id).Count -ne 1) { throw 'production defect: Orphan Stage 8 submission File.' }
    }
}

function Assert-Stage8IdempotencyRecord {
    param($Record, [string] $InstitutionId, [string] $UserId, [string] $Operation, [string] $Key, [string] $ResourceType, [string] $ResourceId, [int] $Status)
    if ($null -eq $Record -or $Record.institution_id -cne $InstitutionId -or $Record.user_id -cne $UserId -or $Record.operation -cne $Operation -or
        $Record.idempotency_key -cne $Key.ToLowerInvariant() -or $Record.result_resource_type -cne $ResourceType -or
        $Record.result_resource_id -cne $ResourceId -or [int] $Record.response_status -ne $Status -or
        $null -eq $Record.completed_at -or [string] $Record.request_fingerprint -cnotmatch '\A[0-9a-f]{64}\z') {
        throw 'production defect: Invalid scoped completed Stage 8 idempotency record.'
    }
}

function Get-Stage8IdempotencyRecord {
    param($Facts, [string] $Key, [string] $Operation)
    $rows = @($Facts.tables.idempotency_records | Where-Object { $_.idempotency_key -ceq $Key.ToLowerInvariant() -and $_.operation -ceq $Operation })
    if ($rows.Count -gt 1) { throw 'production defect: Duplicate Stage 8 idempotency record.' }
    if ($rows.Count -eq 1) { $rows[0] } else { $null }
}

function Assert-Stage8NoIdempotencyRecord {
    param($Facts, [string] $Key)
    if (@($Facts.tables.idempotency_records | Where-Object idempotency_key -CEQ $Key.ToLowerInvariant()).Count -ne 0) { throw 'production defect: A rejected Stage 8 request left an idempotency claim.' }
}

# Start requests are semantic identity; replays must reuse the exact original tuple.
function Assert-Stage8StartRequest {
    param($Request)
    $keys = @($Request.Body.PSObject.Properties.Name)
    if ($Request.Key -cnotmatch '\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z' -or [string] $Request.Body.intent -cnotin @('start_normal', 'resume', 'start_replacement')) {
        throw 'integration-harness defect: Stage 8 Start request lacks an exact intent/key.'
    }
    if ($Request.Body.intent -ceq 'resume') {
        if ((@($keys | Sort-Object) -join ',') -cne 'attempt_id,intent' -or [string] $Request.Body.attempt_id -cnotmatch '\A[0-9a-f-]{36}\z') { throw 'integration-harness defect: Stage 8 Resume must carry exactly its attempt_id.' }
    }
    elseif ((@($keys) -join ',') -cne 'intent') { throw 'integration-harness defect: Stage 8 non-Resume Start must not carry attempt_id.' }
}

function Assert-Stage8StartReplay {
    param($Original, $Replay)
    Assert-Stage8StartRequest $Original
    Assert-Stage8StartRequest $Replay
    if ($Replay.Key -cne $Original.Key -or (ConvertTo-Json $Replay.Body -Compress) -cne (ConvertTo-Json $Original.Body -Compress)) {
        throw 'integration-harness defect: Stage 8 Start replay changed its original intent/attempt_id/key.'
    }
}

function Assert-Stage8KeyReuseOutcome {
    param($Response)
    if ([int] $Response.StatusCode -ne 409 -or $null -eq $Response.Json -or $Response.Json.code -cne 'idempotency_key_reused') {
        throw 'production defect: Stage 8 key reused with a changed request was not rejected as idempotency_key_reused.'
    }
}

function Assert-Stage8NoSwitch {
    param($Before, $After, [string] $AssessmentId, [string] $StudentId, [AllowNull()] $Response, [AllowNull()][string] $ExpectedAttemptId)
    $beforeIds = @(Get-Stage8Rows $Before assessment_attempts assessment_id $AssessmentId | Where-Object student_id -CEQ $StudentId | ForEach-Object id)
    $afterIds = @(Get-Stage8Rows $After assessment_attempts assessment_id $AssessmentId | Where-Object student_id -CEQ $StudentId | ForEach-Object id)
    Assert-Stage8Set $afterIds $beforeIds 'stale Resume created no Attempt'
    if ($null -ne $Response -and [int] $Response.StatusCode -lt 300 -and [string] $Response.Json.data.id -cne $ExpectedAttemptId) { throw 'production defect: Stage 8 Resume switched to another Attempt.' }
}

function Assert-Stage8RowsUnchanged {
    param($Before, $After, [string[]] $Tables, [string] $Label)
    foreach ($table in $Tables) { Assert-Stage8Equal @($After.tables.$table) @($Before.tables.$table) "$Label leaves $table unchanged" }
}

# A Blitz activation that failed must leave no lifecycle, recipient, cohort or idempotency trace.
function Assert-Stage8NoActivationWrites {
    param($Before, $After, [string] $AssessmentId, [string] $Key)
    Assert-Stage8Equal (Get-Stage8Row $After blitz_tasks $AssessmentId assessment_id) (Get-Stage8Row $Before blitz_tasks $AssessmentId assessment_id) 'failed activation Blitz row'
    Assert-Stage8Equal @(Get-Stage8Rows $After assessment_students assessment_id $AssessmentId) @(Get-Stage8Rows $Before assessment_students assessment_id $AssessmentId) 'failed activation recipients'
    Assert-Stage8Equal @($After.tables.topic_result_pairs) @($Before.tables.topic_result_pairs) 'failed activation pairs'
    Assert-Stage8Equal @(Get-Stage8Rows $After assessment_attempts assessment_id $AssessmentId) @() 'failed activation Attempts'
    Assert-Stage8NoIdempotencyRecord $After $Key
}

function Assert-Stage8LateWriteUnchanged {
    param($Before, $After, [string] $AttemptId)
    $answers = @(Get-Stage8Rows $Before attempt_answers attempt_id $AttemptId)
    Assert-Stage8Equal @(Get-Stage8Rows $After attempt_answers attempt_id $AttemptId) $answers 'late write keeps the frozen answer rows'
    $answerIds = @($answers | ForEach-Object id)
    foreach ($table in $script:Stage8AnswerTables) {
        Assert-Stage8Equal @($After.tables.$table | Where-Object answer_id -CIN $answerIds) @($Before.tables.$table | Where-Object answer_id -CIN $answerIds) "late write keeps $table"
    }
    $fileIds = @($Before.tables.answer_files | Where-Object answer_id -CIN $answerIds | ForEach-Object file_id)
    Assert-Stage8Equal @($After.tables.files | Where-Object id -CIN $fileIds) @($Before.tables.files | Where-Object id -CIN $fileIds) 'late write keeps the File row'
    Assert-Stage8Equal @($After.blobs | Where-Object { $_.key -cin @($Before.tables.files | Where-Object id -CIN $fileIds | ForEach-Object storage_key) }) @($Before.blobs | Where-Object { $_.key -cin @($Before.tables.files | Where-Object id -CIN $fileIds | ForEach-Object storage_key) }) 'late write keeps the private blob'
    Assert-Stage8NoOrphanBlob $After
}

# Exactly one complete serialization per race; the harness never forces which request wins.
# ActualValue is the caller's reading of the persisted answer: the raced value, the pre-race value or neither.
function Assert-Stage8RaceBranch {
    param($ResultWrite, $ResultSubmit, $Facts, [string] $AttemptId, [string] $QuestionId, [ValidateSet('written', 'prior', 'other')][string] $ActualValue)
    $attempt = Get-Stage8Row $Facts assessment_attempts $AttemptId
    if ([int] $ResultSubmit.StatusCode -ne 200) { throw 'production defect: Stage 8 race Submit did not succeed.' }
    Assert-Stage8TerminalAttempt $attempt student_submit ([string] $attempt.submitted_at)
    $answer = @(Get-Stage8Rows $Facts attempt_answers attempt_id $AttemptId | Where-Object question_id -CEQ $QuestionId)
    if ($answer.Count -ne 1) { throw 'production defect: Stage 8 race answer row missing.' }
    $branch = switch ([int] $ResultWrite.StatusCode) {
        200 { 'write_first' }
        409 { if ($null -ne $ResultWrite.Json -and $ResultWrite.Json.code -ceq 'attempt_not_editable') { 'submit_first' } else { $null } }
        default { $null }
    }
    if ($null -eq $branch -or $ActualValue -cne $(if ($branch -ceq 'write_first') { 'written' } else { 'prior' })) {
        throw 'production defect: Stage 8 race result matches neither approved serialized branch.'
    }
    if ((ConvertTo-Stage8Instant $answer[0].updated_at) -gt (ConvertTo-Stage8Instant $attempt.locked_at)) { throw 'production defect: Stage 8 answer changed after the Submit freeze.' }
    Assert-Stage8NoOrphanBlob $Facts
    $branch
}

function Assert-Stage8TenantRows {
    param($Facts)
    $m = $Facts.manifest
    Assert-Stage8NoOrphanBlob $Facts
    $institutions = @($m.institutions.PSObject.Properties.Value)
    $relations = @{
        users = @{ institution_id = 'institutions' }; groups = @{ institution_id = 'institutions' }
        topics = @{ group_id = 'groups'; teacher_id = 'users' }; assessments = @{ topic_id = 'topics'; teacher_id = 'users' }
        blitz_tasks = @{ assessment_id = 'assessments' }; homework_assignments = @{ assessment_id = 'assessments' }
        assessment_students = @{ assessment_id = 'assessments'; student_id = 'users' }; questions = @{ assessment_id = 'assessments' }
        topic_result_pairs = @{ topic_id = 'topics'; homework_assessment_id = 'assessments' }
        assessment_attempts = @{ assessment_id = 'assessments'; assessment_student_id = 'assessment_students'; student_id = 'users' }
        blitz_attempt_exceptions = @{ assessment_id = 'assessments'; invalidated_attempt_id = 'assessment_attempts'; student_id = 'users' }
        attempt_answers = @{ attempt_id = 'assessment_attempts'; question_id = 'questions' }
        answer_files = @{ answer_id = 'attempt_answers'; file_id = 'files' }; files = @{ uploaded_by_user_id = 'users' }
        idempotency_records = @{ user_id = 'users' }
    }
    foreach ($table in $relations.Keys) {
        foreach ($row in @($Facts.tables.$table)) {
            if ($row.institution_id -cnotin $institutions) { throw 'production defect: Cross-Tenant Stage 8 oracle row.' }
            foreach ($column in $relations[$table].Keys) {
                $parentTable = $relations[$table][$column]
                $parent = Get-Stage8Row $Facts $parentTable ([string] $row.$column) $(if ($parentTable -ceq 'blitz_tasks') { 'assessment_id' } else { 'id' })
                $institution = if ($parentTable -ceq 'institutions') { $parent.id } else { $parent.institution_id }
                if ($row.institution_id -cne $institution) { throw 'production defect: Cross-Tenant Stage 8 oracle relationship.' }
            }
        }
    }
}

function Assert-Stage8NoStageNineScoring {
    param($Facts)
    foreach ($attempt in @($Facts.tables.assessment_attempts)) {
        Assert-Stage8Unscored $attempt @($Facts.tables.attempt_answers | Where-Object attempt_id -CEQ $attempt.id)
    }
}

# Baseline: the fresh seed exactly, before any scenario consumed a fixture.
function Assert-Stage8Baseline {
    param($Facts)
    $m = $Facts.manifest
    Assert-Stage8TenantRows $Facts
    Assert-Stage8NoStageNineScoring $Facts
    Assert-Stage8Set @($Facts.tables.assessment_attempts | ForEach-Object id) @($m.attempts.PSObject.Properties.Value) 'baseline Attempts are the seeded history only'
    Assert-Stage8Set @($Facts.tables.blitz_attempt_exceptions | ForEach-Object id) @($m.exceptions.PSObject.Properties.Value) 'baseline exceptions are seeded only'
    foreach ($table in @('attempt_answers', 'files', 'idempotency_records')) { if (@($Facts.tables.$table).Count -ne 0) { throw "integration-harness defect: Stage 8 baseline already has $table." } }
    if (@($Facts.dynamic.assessments).Count -ne 0 -or @($Facts.dynamic.assessment_students).Count -ne 0) { throw 'integration-harness defect: Stage 8 baseline already has runtime rows.' }
    $pair = Get-Stage8Row $Facts topic_result_pairs $m.pairs.official
    if ($null -ne $pair.blitz_assessment_id -or $null -eq $pair.locked_at -or $null -eq $pair.cohort_snapshotted_at) { throw 'integration-harness defect: Stage 8 locked-partial pair baseline mismatch.' }
    foreach ($name in @('main', 'sync_replacement', 'bf_blitz', 'android', 'foreign', 'unset', 'activation_idem', 'activation_idem_other', 'individual_timing', 'practice_blitz')) {
        if ((Get-Stage8Row $Facts blitz_tasks $m.assessments.$name assessment_id).status -cne 'draft') { throw "integration-harness defect: Stage 8 $name must start as draft." }
    }
    $questions = @(Get-Stage8Rows $Facts questions assessment_id $m.assessments.main | Sort-Object { [int] $_.position })
    Assert-Stage8Equal @($questions.type) @('single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'file_based', 'matching', 'ordering', 'fill_in_blank', 'short_written') 'main Blitz nine safe types plus an unanswered Question'
    $scheduler = Get-Stage8Row $Facts blitz_tasks $m.assessments.scheduler assessment_id
    Assert-Stage8BlitzLifecycle $scheduler active synchronized ([int] $m.scheduler_duration)
    Assert-Stage8AttemptHistory $Facts $m.assessments.scheduler $m.users.sched_future | Out-Null
    if ($null -eq $Facts.sentinels.blob) { throw 'integration-harness defect: Stage 8 unrelated sentinel graph is missing.' }
}

function Assert-Stage8CleanupFacts {
    param($Facts, $SentinelsBefore)
    foreach ($property in $Facts.tables.PSObject.Properties) {
        if (@($property.Value).Count -ne 0) { throw "production defect: Stage 8 cleanup left manifest-owned $($property.Name) rows." }
    }
    if (@($Facts.blobs).Count -ne 0) { throw 'production defect: Stage 8 cleanup left manifest-owned private blobs.' }
    if (@($Facts.public_blobs).Count -ne 0) { throw 'production defect: Stage 8 cleanup left manifest-owned public blob copies.' }
    Assert-Stage8SentinelsUnchanged $SentinelsBefore $Facts.sentinels 'cleanup'
}

# Prior-run cleanup must use the real configured Stage 8 disk, never the isolated seeder-test disk.
function Assert-Stage8CleanupDiskIdentity {
    param($Evidence)
    if ($Evidence.cleaned -ne $true -or [string] $Evidence.disk -cne 'local' -or [string] $Evidence.root -cne $script:Stage8PrivateRootPath) {
        throw 'integration-harness defect: Stage 8 prior-manifest cleanup did not use the real configured private disk.'
    }
}

# The runner executes exactly this order; the verifier proves unsafe orders are rejected.
function Assert-Stage8RunnerPlan {
    param([string[]] $Plan)
    $required = @('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'seeder_test', 'fresh_seed', 'baseline_oracle')
    $positions = @{}
    foreach ($step in $required) {
        $index = [array]::IndexOf($Plan, $step)
        if ($index -lt 0) { throw "integration-harness defect: Stage 8 runner plan misses $step." }
        $positions[$step] = $index
    }
    for ($i = 1; $i -lt $required.Count; $i++) {
        if ($positions[$required[$i]] -le $positions[$required[$i - 1]]) { throw "integration-harness defect: Stage 8 runner plan runs $($required[$i]) before $($required[$i - 1])." }
    }
    if ('previous_final_cleanup' -cin $Plan -or 'requires_previous_cleanup' -cin $Plan) { throw 'integration-harness defect: Stage 8 retry must not depend on a previous final cleanup.' }
    $scheduler = [array]::IndexOf($Plan, 'guarded_scheduler')
    if ($scheduler -ge 0 -and $scheduler -lt $positions['baseline_oracle']) { throw 'integration-harness defect: Stage 8 Scheduler runs before the baseline.' }
}

function Get-Stage8SchedulerSafetyFacts {
    $program = @'
use Database\Seeders\Stage8E2eSeeder;
if (!app()->environment('testing') || DB::connection()->getDriverName() !== 'pgsql' || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new RuntimeException('Stage 8 scheduler guard identity failed.');
}
// Mirrors ReconcileDueBlitzTimeouts exactly, including its application clock.
$guardScanNow = now();
$candidates = DB::table('blitz_tasks')->select(['institution_id', 'assessment_id'])->where('status', 'active')
    ->whereExists(fn ($query) => $query->selectRaw('1')->from('assessment_attempts')
        ->whereColumn('assessment_attempts.institution_id', 'blitz_tasks.institution_id')
        ->whereColumn('assessment_attempts.assessment_id', 'blitz_tasks.assessment_id')
        ->where('assessment_attempts.status', 'in_progress')
        ->where('assessment_attempts.deadline_at', '<=', $guardScanNow))
    ->orderBy('assessment_id')->get();
// Stricter than production: every active in-progress Blitz Attempt must be manifest-owned, due or not.
$superset = DB::table('blitz_tasks')->join('assessment_attempts', fn ($join) => $join->on('assessment_attempts.assessment_id', '=', 'blitz_tasks.assessment_id')
        ->on('assessment_attempts.institution_id', '=', 'blitz_tasks.institution_id'))
    ->where('blitz_tasks.status', 'active')->where('assessment_attempts.status', 'in_progress')->whereNotNull('assessment_attempts.deadline_at')
    ->orderBy('assessment_attempts.id')->get(['blitz_tasks.institution_id', 'blitz_tasks.assessment_id', 'assessment_attempts.id as attempt_id', 'assessment_attempts.deadline_at']);
$m = Stage8E2eSeeder::manifest();
// Owners come from the declared fixtures, never from the rows being judged.
$owners = collect(Stage8E2eSeeder::fixtureRows($m, '2026-01-01 00:00:00+00')['assessments'])->where('type', 'blitz')->pluck('institution_id', 'id')->all();
echo json_encode(['guard_scan_now' => $guardScanNow->utc()->format('Y-m-d\TH:i:s.u\Z'), 'candidates' => $candidates, 'superset' => $superset->map(fn ($row) => [
        'institution_id' => $row->institution_id, 'assessment_id' => $row->assessment_id, 'attempt_id' => $row->attempt_id,
        'due' => \Carbon\CarbonImmutable::parse($row->deadline_at)->lessThanOrEqualTo($guardScanNow)])->all(),
    'owners' => $owners, 'scheduler' => ['assessment_id' => $m['assessments']['scheduler'], 'institution_id' => $m['institutions']['target']]], JSON_THROW_ON_ERROR);
'@
    Invoke-Stage8ContainerPhp -Program $program
}

function Assert-Stage8SchedulerSafeToRun {
    param([Parameter(Mandatory = $true)] $Facts, [Parameter(Mandatory = $true)][ValidateSet('First', 'Second')][string] $Invocation)
    foreach ($row in @($Facts.candidates) + @($Facts.superset)) {
        $owner = $Facts.owners.PSObject.Properties[[string] $row.assessment_id]
        if ($null -eq $owner) { throw 'environment/runtime defect: Non-Stage-8 Blitz is a Scheduler candidate or active in-progress; isolation failure, command not run.' }
        if ([string] $owner.Value -cne [string] $row.institution_id) { throw 'environment/runtime defect: Stage 8 Scheduler candidate has the wrong Institution; command not run.' }
    }
    if ($Invocation -ceq 'Second') {
        if (@($Facts.candidates).Count -ne 0) { throw 'integration-harness defect: Second Scheduler invocation requires zero global candidates.' }
        return
    }
    $candidates = @($Facts.candidates)
    if ($candidates.Count -ne 1 -or $candidates[0].assessment_id -cne $Facts.scheduler.assessment_id -or $candidates[0].institution_id -cne $Facts.scheduler.institution_id) {
        throw 'integration-harness defect: First Scheduler invocation requires exactly the manifest Scheduler aggregate.'
    }
    $aggregate = @($Facts.superset | Where-Object assessment_id -CEQ $Facts.scheduler.assessment_id)
    if (@($aggregate | Where-Object { $_.due }).Count -lt 1 -or @($aggregate | Where-Object { -not $_.due }).Count -lt 1) {
        throw 'integration-harness defect: The Scheduler aggregate needs one due and one future in-progress Attempt.'
    }
}

function Invoke-Stage8GuardedScheduler {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('First', 'Second')][string] $Invocation,
        [scriptblock] $FactsProvider = { Get-Stage8SchedulerSafetyFacts },
        [scriptblock] $SentinelProvider = { Get-Stage8SentinelFacts },
        [scriptblock] $Invoker = {
            $output = @(& docker exec testlabuz-stage8-e2e-app php artisan blitz:reconcile-timeouts 2>&1)
            [pscustomobject] @{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
        }
    )
    # A fresh global scan guards every invocation; a previous result is never reused.
    $facts = & $FactsProvider
    Assert-Stage8SchedulerSafeToRun -Facts $facts -Invocation $Invocation
    $sentinelsBefore = & $SentinelProvider
    $result = & $Invoker
    if ([int] $result.ExitCode -ne 0) { throw 'production defect: blitz:reconcile-timeouts failed.' }
    $match = [regex]::Match([string] $result.Output, 'Candidates: (?<c>[0-9]+); finalized attempts: (?<f>[0-9]+); failures: (?<x>[0-9]+)\.')
    if (-not $match.Success) { throw 'production defect: blitz:reconcile-timeouts output format changed.' }
    $counts = [pscustomobject] @{ candidates = [int] $match.Groups['c'].Value; finalized = [int] $match.Groups['f'].Value; failures = [int] $match.Groups['x'].Value }
    $expectedCandidates = @($facts.candidates).Count
    if ($counts.candidates -ne $expectedCandidates -or $counts.failures -ne 0 -or ($Invocation -ceq 'Second' -and $counts.finalized -ne 0)) {
        throw 'production defect: blitz:reconcile-timeouts counts differ from the guarded candidate set.'
    }
    Assert-Stage8SentinelsUnchanged $sentinelsBefore (& $SentinelProvider) "Scheduler $Invocation invocation"
    [pscustomobject] @{ Facts = $facts; Counts = $counts }
}

function Wait-Stage8TimestampBoundary {
    param([string] $Timestamp)
    # Persisted timestamps have second precision; a later server second makes no-op checks able to detect a rewrite.
    $recorded = [DateTimeOffset] $Timestamp
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt 10) {
        $clock = Invoke-Stage8ContainerPhp -Program 'echo json_encode(["now"=>now()->utc()->format("Y-m-d\\TH:i:s\\Z")], JSON_THROW_ON_ERROR);'
        if ([DateTimeOffset] $clock.now -gt $recorded) { return }
    }
    throw 'environment/runtime defect: Server clock did not advance beyond the recorded timestamp within the bounded wait.'
}

function Wait-Stage8ServerPast {
    param([string] $Timestamp, [int] $TimeoutSeconds = 120)
    $target = [DateTimeOffset] $Timestamp
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $clock = Invoke-Stage8ContainerPhp -Program 'echo json_encode(["now"=>now()->utc()->format("Y-m-d\\TH:i:s.u\\Z")], JSON_THROW_ON_ERROR);'
        if ([DateTimeOffset] $clock.now -gt $target.AddMilliseconds(500)) { return }
        Start-Sleep -Milliseconds 500
    }
    throw 'environment/runtime defect: Server-side deadline did not pass within the bounded wait.'
}
