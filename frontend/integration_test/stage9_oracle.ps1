Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage9_runtime_guard.ps1')

$script:Stage9AnswerTables = @('answer_choice_selections', 'answer_text_values', 'answer_boolean_values', 'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files')
$script:Stage9PrivateRootPath = '/var/www/html/storage/app/private'
$script:Stage9FrozenColumns = @('started_at', 'deadline_at', 'submitted_at', 'finalized_at', 'finalization_reason', 'locked_at', 'possible_points', 'attempt_number')
$script:Stage9ScheduledCommands = @('homework:reconcile-deadlines', 'blitz:reconcile-timeouts', 'attempts:check-frozen')

function Assert-Stage9Equal {
    param($Actual, $Expected, [string] $Label)
    if ((ConvertTo-Json -InputObject $Actual -Depth 60 -Compress) -cne (ConvertTo-Json -InputObject $Expected -Depth 60 -Compress)) {
        throw "production defect: Stage 9 oracle mismatch: $Label."
    }
}

function Assert-Stage9Set {
    param([AllowEmptyCollection()][object[]] $Actual, [AllowEmptyCollection()][object[]] $Expected, [string] $Label)
    Assert-Stage9Equal @($Actual | Sort-Object) @($Expected | Sort-Object) $Label
}

function Get-Stage9Row {
    param($Facts, [string] $Table, [string] $Id, [string] $Column = 'id')
    $rows = @($Facts.tables.$Table | Where-Object { [string] $_.$Column -ceq $Id })
    if ($rows.Count -ne 1) { throw "integration-harness defect: Stage 9 oracle requires one $Table row." }
    $rows[0]
}

function Get-Stage9Rows {
    param($Facts, [string] $Table, [string] $Column, [string] $Value)
    @($Facts.tables.$Table | Where-Object { [string] $_.$Column -ceq $Value })
}

function ConvertTo-Stage9Instant { param([AllowNull()] $Value) if ($null -eq $Value) { $null } else { ([DateTimeOffset] [string] $Value).ToUniversalTime() } }

function Assert-Stage9SameInstant {
    param([AllowNull()] $Actual, [AllowNull()] $Expected, [string] $Label)
    if ($null -eq $Actual -or $null -eq $Expected -or (ConvertTo-Stage9Instant $Actual) -ne (ConvertTo-Stage9Instant $Expected)) {
        throw "production defect: Stage 9 oracle timestamp mismatch: $Label."
    }
}

function Get-Stage9DatabaseFacts {
    param($PriorFacts)
    $program = @'
use Database\Seeders\Stage9E2eSeeder;
if (!app()->environment('testing') || DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new RuntimeException('Stage 9 oracle database identity failed.');
}
$seeder = new Stage9E2eSeeder;
$m = Stage9E2eSeeder::manifest();
// Ownership is resolved by the seeder's fail-closed rules, so the oracle never widens the scope.
$state = $seeder->ownedState();
$keys = Stage9E2eSeeder::PRIMARY_KEYS;
$ids = $state['db'];
$prior = $stage9Input['prior'] ?? null;
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
    $order = match ($table) { 'answer_choice_selections' => 'option_id', 'answer_text_values', 'answer_boolean_values' => 'answer_id', default => 'id' };
    $tables[$table] = DB::table($table)->whereIn('answer_id', $answerIds)->orderBy('answer_id')->orderBy($order)->get()->map(fn ($r) => (array) $r)->all();
}
$diskName = config('filesystems.private_files_disk');
$diskConfig = config('filesystems.disks.'.$diskName);
$root = rtrim((string) ($diskConfig['root'] ?? ''), '/');
$disk = Storage::disk($diskName);
$keysSeen = array_values(array_unique([...array_column($state['blobs'], 'key'), ...($prior['blob_keys'] ?? [])]));
$directories = array_values(array_unique([...array_column($state['directories'], 'key'), ...($prior['directories'] ?? [])]));
foreach ($directories as $directory) {
    if (!preg_match('~^student-submissions/[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}$~D', $directory)) { throw new RuntimeException('Stage 9 oracle directory mismatch.'); }
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
echo json_encode(['manifest' => $m, 'tables' => $tables, 'private_disk' => $diskName, 'private_root' => $root,
    'directories' => $directories, 'blobs' => $blobs, 'public_blobs' => $publicBlobs, 'sentinels' => $seeder->sentinelState(),
    'observed_at' => now()->utc()->format('Y-m-d\TH:i:s.u\Z')], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
'@
    $inputObject = @{}
    if ($null -ne $PriorFacts) {
        $priorIds = @{}
        foreach ($property in $PriorFacts.tables.PSObject.Properties) {
            if ($property.Name -cin $script:Stage9AnswerTables) { continue }
            $key = switch ($property.Name) { 'institution_settings' { 'institution_id' } 'blitz_tasks' { 'assessment_id' } 'homework_assignments' { 'assessment_id' } 'question_true_false_answers' { 'question_id' } default { 'id' } }
            $priorIds[$property.Name] = @($property.Value | ForEach-Object { [string] $_.$key })
        }
        $inputObject.prior = @{ ids = $priorIds; directories = @($PriorFacts.directories); blob_keys = @($PriorFacts.blobs | ForEach-Object key) }
    }
    Invoke-Stage9ContainerPhp -Program $program -InputJson ($inputObject | ConvertTo-Json -Depth 30 -Compress)
}

function Get-Stage9SentinelFacts {
    $program = @'
if (!app()->environment('testing') || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') { throw new RuntimeException('Stage 9 sentinel identity failed.'); }
echo json_encode((new Database\Seeders\Stage9E2eSeeder)->sentinelState(), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
'@
    Invoke-Stage9ContainerPhp -Program $program
}

function Assert-Stage9SentinelsUnchanged {
    param($Before, $After, [string] $Label)
    if ($null -eq $Before -or $null -eq $Before.blob -or @($Before.rows.PSObject.Properties).Count -eq 0) { throw 'integration-harness defect: Stage 9 unrelated sentinels were not captured.' }
    Assert-Stage9Equal $After $Before "unrelated sentinel unchanged by $Label"
}

# ---------------------------------------------------------------- scoring assertions

function Assert-Stage9Answer {
    param([Parameter(Mandatory = $true)] $Facts, [string] $AttemptId, [string] $QuestionId, [string] $Status, [AllowNull()][string] $Points,
        [AllowNull()][string] $Feedback, [AllowNull()][string] $CheckedBy, [string] $Label)
    $rows = @(Get-Stage9Rows $Facts attempt_answers attempt_id $AttemptId | Where-Object question_id -CEQ $QuestionId)
    if ($rows.Count -ne 1) { throw "production defect: Stage 9 answer row missing: $Label." }
    $answer = $rows[0]
    # PowerShell names are case-insensitive and typed [string] parameters turn $null into '', so the expectations get new names.
    $expectedPoints = if ([string]::IsNullOrEmpty($Points)) { $null } else { $Points }
    $expectedFeedback = if ([string]::IsNullOrEmpty($Feedback)) { $null } else { $Feedback }
    $expectedChecker = if ([string]::IsNullOrEmpty($CheckedBy)) { $null } else { $CheckedBy }
    Assert-Stage9Equal @([string] $answer.checking_status, $answer.awarded_points, $answer.feedback, $answer.checked_by_user_id) @($Status, $expectedPoints, $expectedFeedback, $expectedChecker) "answer $Label"
    $checked = $Status -cin @('auto_checked', 'teacher_checked')
    if ($checked -ne ($null -ne $answer.checked_at)) { throw "production defect: Stage 9 answer checked_at does not match its checking state: $Label." }
    if ($Status -ceq 'auto_checked' -and $null -ne $answer.checked_by_user_id) { throw "production defect: Stage 9 automatic answer names a reviewer: $Label." }
    $answer
}

function Assert-Stage9AttemptScore {
    param([Parameter(Mandatory = $true)] $Attempt, [string] $Status, [AllowNull()][string] $Earned, [AllowNull()][string] $Normalized, [string] $Label)
    $expectedEarned = if ([string]::IsNullOrEmpty($Earned)) { $null } else { $Earned }
    $expectedNormalized = if ([string]::IsNullOrEmpty($Normalized)) { $null } else { $Normalized }
    Assert-Stage9Equal @([string] $Attempt.status, $Attempt.earned_points, $Attempt.normalized_score) @($Status, $expectedEarned, $expectedNormalized) "Attempt $Label"
    if (($Status -ceq 'checked') -ne ($null -ne $Attempt.scoring_completed_at)) { throw "production defect: Stage 9 scoring_completed_at does not match the Attempt status: $Label." }
}

function Get-Stage9OfficialRows {
    param($Facts, [string] $AssessmentId, [string] $StudentId)
    @($Facts.tables.official_task_scores | Where-Object { $_.assessment_id -ceq $AssessmentId -and $_.student_id -ceq $StudentId })
}

function Assert-Stage9OfficialRow {
    param($Facts, [string] $AssessmentId, [string] $StudentId, [string] $AttemptId, [string] $Score, [string] $Policy, [string] $Label)
    $rows = @(Get-Stage9OfficialRows $Facts $AssessmentId $StudentId)
    if ($rows.Count -ne 1) { throw "production defect: Stage 9 official score row missing: $Label." }
    Assert-Stage9Equal @($rows[0].official_attempt_id, $rows[0].normalized_score, $rows[0].selection_policy_code, $rows[0].selected_by_user_id) @($AttemptId, $Score, $Policy, $null) "official row $Label"
    $rows[0]
}

function Assert-Stage9NoOfficialRow {
    param($Facts, [string] $AssessmentId, [string] $StudentId, [string] $Label)
    if (@(Get-Stage9OfficialRows $Facts $AssessmentId $StudentId).Count -ne 0) { throw "production defect: Stage 9 official score row must not exist: $Label." }
}

# Checking and review never touch the freeze or the Student's last-save time (S09-DOC-001 section 7, index section 8).
function Assert-Stage9FreezeAndAnswersKept {
    param($Before, $After, [string[]] $AttemptIds, [string] $Label)
    foreach ($attemptId in $AttemptIds) {
        $was = Get-Stage9Row $Before assessment_attempts $attemptId
        $now = Get-Stage9Row $After assessment_attempts $attemptId
        foreach ($column in $script:Stage9FrozenColumns) { Assert-Stage9Equal $now.$column $was.$column "$Label keeps Attempt $column" }
        $answersBefore = @(Get-Stage9Rows $Before attempt_answers attempt_id $attemptId | Sort-Object id | ForEach-Object { "$($_.id)|$($_.question_id)|$($_.created_at)|$($_.updated_at)" })
        $answersAfter = @(Get-Stage9Rows $After attempt_answers attempt_id $attemptId | Sort-Object id | ForEach-Object { "$($_.id)|$($_.question_id)|$($_.created_at)|$($_.updated_at)" })
        Assert-Stage9Equal $answersAfter $answersBefore "$Label keeps answer rows and their updated_at"
        $answerIds = @(Get-Stage9Rows $Before attempt_answers attempt_id $attemptId | ForEach-Object id)
        foreach ($table in $script:Stage9AnswerTables) {
            Assert-Stage9Equal @($After.tables.$table | Where-Object answer_id -CIN $answerIds) @($Before.tables.$table | Where-Object answer_id -CIN $answerIds) "$Label keeps $table"
        }
    }
}

function Assert-Stage9RowsUnchanged {
    param($Before, $After, [string[]] $Tables, [string] $Label)
    foreach ($table in $Tables) { Assert-Stage9Equal @($After.tables.$table) @($Before.tables.$table) "$Label leaves $table unchanged" }
}

function Assert-Stage9OnlyTablesChanged {
    param($Before, $After, [string[]] $Changed, [string] $Label)
    foreach ($property in $After.tables.PSObject.Properties) {
        if ($property.Name -cin $Changed) { continue }
        Assert-Stage9Equal @($property.Value) @($Before.tables.($property.Name)) "$Label leaves $($property.Name) unchanged"
    }
    Assert-Stage9Equal @($After.blobs) @($Before.blobs) "$Label leaves private blobs unchanged"
}

# UI and API sign-ins write tokens and last_login_at; nothing else of a user may change.
function Assert-Stage9OnlySessionsChanged {
    param($Before, $After, [string] $Label)
    $strip = { param($Rows) @($Rows | ForEach-Object { $copy = [ordered] @{}; foreach ($p in $_.PSObject.Properties) { if ($p.Name -cnotin @('last_login_at', 'updated_at')) { $copy[$p.Name] = $p.Value } }; [pscustomobject] $copy }) }
    Assert-Stage9Equal (& $strip $After.tables.users) (& $strip $Before.tables.users) "$Label changes no user beyond its sign-in"
}

function Assert-Stage9File {
    param($Facts, $File, $ExpectedFile, $Attempt, [string] $QuestionId)
    $prefix = "student-submissions/$($Attempt.institution_id)/$($Attempt.id)/$QuestionId/"
    if ($File.category -cne 'student_submission' -or $File.uploaded_by_user_id -cne $Attempt.student_id -or
        $File.institution_id -cne $Attempt.institution_id -or $null -ne $File.removed_at -or
        $File.storage_disk -cne $Facts.private_disk -or -not ([string] $File.storage_key).StartsWith($prefix, [StringComparison]::Ordinal) -or
        [string] $File.storage_key -match '(^|/)\.\.(/|$)|public|\\' -or
        $Facts.private_root -notmatch '\A/var/www/html/storage/app/private(?:/|$)') { throw 'production defect: Stage 9 Student submission private storage/ownership mismatch.' }
    foreach ($field in @('original_name', 'extension', 'mime_type', 'size_bytes', 'checksum_sha256')) {
        Assert-Stage9Equal ([string] $File.$field) ([string] $ExpectedFile.$field) "submission $field"
    }
    $blobs = @($Facts.blobs | Where-Object key -CEQ $File.storage_key)
    if ($blobs.Count -ne 1 -or $blobs[0].public_exists -or [long] $blobs[0].size -ne [long] $ExpectedFile.size_bytes -or
        $blobs[0].checksum -cne $ExpectedFile.checksum_sha256) { throw 'production defect: Stage 9 Student submission blob integrity mismatch.' }
}

function Get-Stage9FileExpectation {
    param($FileManifest, [string] $Key)
    $fixture = $FileManifest.Files[$Key]
    [pscustomobject] @{ original_name = $fixture.original_name; extension = $fixture.extension; mime_type = $fixture.mime_type; size_bytes = $fixture.size_bytes; checksum_sha256 = $fixture.sha256 }
}

# Every private blob under an owned submission directory must be the current file of a linked answer.
function Assert-Stage9NoOrphanBlob {
    param($Facts)
    if (@($Facts.public_blobs).Count -ne 0) { throw 'production defect: Stage 9 submission blob exists on public storage.' }
    Assert-Stage9Set @($Facts.blobs | ForEach-Object key) @($Facts.tables.files | ForEach-Object storage_key) 'no orphan, stale or uncompensated private blobs'
    foreach ($file in @($Facts.tables.files)) {
        if (@($Facts.tables.answer_files | Where-Object file_id -CEQ $file.id).Count -ne 1) { throw 'production defect: Orphan Stage 9 submission File.' }
    }
}

function Assert-Stage9IdempotencyRecord {
    param($Record, [string] $InstitutionId, [string] $UserId, [string] $Operation, [string] $Key, [string] $ResourceType, [string] $ResourceId, [int] $Status)
    if ($null -eq $Record -or $Record.institution_id -cne $InstitutionId -or $Record.user_id -cne $UserId -or $Record.operation -cne $Operation -or
        $Record.idempotency_key -cne $Key.ToLowerInvariant() -or $Record.result_resource_type -cne $ResourceType -or
        $Record.result_resource_id -cne $ResourceId -or [int] $Record.response_status -ne $Status -or
        $null -eq $Record.completed_at -or [string] $Record.request_fingerprint -cnotmatch '\A[0-9a-f]{64}\z') {
        throw 'production defect: Invalid scoped completed Stage 9 idempotency record.'
    }
}

function Get-Stage9IdempotencyRecord {
    param($Facts, [string] $Key, [string] $Operation)
    $rows = @($Facts.tables.idempotency_records | Where-Object { $_.idempotency_key -ceq $Key.ToLowerInvariant() -and $_.operation -ceq $Operation })
    if ($rows.Count -gt 1) { throw 'production defect: Duplicate Stage 9 idempotency record.' }
    if ($rows.Count -eq 1) { $rows[0] } else { $null }
}

function Assert-Stage9NoIdempotencyRecord {
    param($Facts, [string] $Key)
    if (@($Facts.tables.idempotency_records | Where-Object idempotency_key -CEQ $Key.ToLowerInvariant()).Count -ne 0) { throw 'production defect: A rejected Stage 9 request left an idempotency claim.' }
}

function Assert-Stage9TenantRows {
    param($Facts)
    $m = $Facts.manifest
    Assert-Stage9NoOrphanBlob $Facts
    $institutions = @($m.institutions.PSObject.Properties.Value)
    $relations = @{
        users = @{ institution_id = 'institutions' }; groups = @{ institution_id = 'institutions' }
        topics = @{ group_id = 'groups'; teacher_id = 'users' }; assessments = @{ topic_id = 'topics'; teacher_id = 'users' }
        blitz_tasks = @{ assessment_id = 'assessments' }; homework_assignments = @{ assessment_id = 'assessments' }
        assessment_students = @{ assessment_id = 'assessments'; student_id = 'users' }; questions = @{ assessment_id = 'assessments' }
        topic_result_pairs = @{ topic_id = 'topics'; homework_assessment_id = 'assessments' }
        assessment_attempts = @{ assessment_id = 'assessments'; assessment_student_id = 'assessment_students'; student_id = 'users' }
        blitz_attempt_exceptions = @{ assessment_id = 'assessments'; invalidated_attempt_id = 'assessment_attempts'; student_id = 'users'; granted_by_user_id = 'users' }
        attempt_answers = @{ attempt_id = 'assessment_attempts'; question_id = 'questions' }
        official_task_scores = @{ assessment_id = 'assessments'; student_id = 'users'; official_attempt_id = 'assessment_attempts' }
        answer_files = @{ answer_id = 'attempt_answers'; file_id = 'files' }; files = @{ uploaded_by_user_id = 'users' }
        idempotency_records = @{ user_id = 'users' }
    }
    foreach ($table in $relations.Keys) {
        foreach ($row in @($Facts.tables.$table)) {
            if ($row.institution_id -cnotin $institutions) { throw 'production defect: Cross-Tenant Stage 9 oracle row.' }
            foreach ($column in $relations[$table].Keys) {
                $parentTable = $relations[$table][$column]
                $parent = Get-Stage9Row $Facts $parentTable ([string] $row.$column) $(if ($parentTable -ceq 'blitz_tasks') { 'assessment_id' } else { 'id' })
                $institution = if ($parentTable -ceq 'institutions') { $parent.id } else { $parent.institution_id }
                if ($row.institution_id -cne $institution) { throw 'production defect: Cross-Tenant Stage 9 oracle relationship.' }
            }
        }
    }
    foreach ($answer in @($Facts.tables.attempt_answers | Where-Object { $null -ne $_.checked_by_user_id })) {
        $reviewer = Get-Stage9Row $Facts users ([string] $answer.checked_by_user_id)
        if ($reviewer.institution_id -cne $answer.institution_id -or $reviewer.role -cne 'teacher') { throw 'production defect: Stage 9 answer reviewer is not a Teacher of its Institution.' }
    }
}

# Baseline: the fresh seed exactly, before any scenario consumed a fixture.
function Assert-Stage9Baseline {
    param($Facts)
    $m = $Facts.manifest
    Assert-Stage9TenantRows $Facts
    Assert-Stage9Set @($Facts.tables.assessment_attempts | ForEach-Object id) @($m.attempts.PSObject.Properties.Value) 'baseline Attempts are the seeded history only'
    foreach ($table in @('official_task_scores', 'blitz_attempt_exceptions', 'files', 'idempotency_records')) {
        if (@($Facts.tables.$table).Count -ne 0) { throw "integration-harness defect: Stage 9 baseline already has $table." }
    }
    $expected = @{ backfill_hw_1 = 'submitted'; backfill_blitz_1 = 'timed_out_finalized'; repair_hw_1 = 'checked'; deadline_hw_1 = 'in_progress'; timeout_blitz_1 = 'in_progress' }
    foreach ($name in $expected.Keys) {
        if ((Get-Stage9Row $Facts assessment_attempts $m.attempts.$name).status -cne $expected[$name]) { throw "integration-harness defect: Stage 9 seeded $name status mismatch." }
    }
    foreach ($answer in @($Facts.tables.attempt_answers)) {
        $isRepair = $answer.attempt_id -ceq $m.attempts.repair_hw_1
        if (($isRepair -and $answer.checking_status -cne 'auto_checked') -or (-not $isRepair -and ($answer.checking_status -cne 'pending' -or $null -ne $answer.awarded_points -or $null -ne $answer.checked_at))) {
            throw 'integration-harness defect: Stage 9 seeded answers are not in their pre-Stage-9 shape.'
        }
    }
    foreach ($name in @('review_hw', 'android_hw')) {
        Assert-Stage9SameInstant (Get-Stage9Row $Facts homework_assignments $m.assessments.$name assessment_id).review_due_at '2026-01-15T13:00:00Z' "$name seeded review deadline"
    }
    foreach ($name in @('exception_blitz', 'android_blitz', 'timeout_blitz')) {
        if ((Get-Stage9Row $Facts blitz_tasks $m.assessments.$name assessment_id).status -cne 'active') { throw "integration-harness defect: Stage 9 $name must start active." }
    }
    if ($null -eq $Facts.sentinels.blob) { throw 'integration-harness defect: Stage 9 unrelated sentinel graph is missing.' }
}

function Assert-Stage9CleanupFacts {
    param($Facts, $SentinelsBefore)
    foreach ($property in $Facts.tables.PSObject.Properties) {
        if (@($property.Value).Count -ne 0) { throw "production defect: Stage 9 cleanup left manifest-owned $($property.Name) rows." }
    }
    if (@($Facts.blobs).Count -ne 0) { throw 'production defect: Stage 9 cleanup left manifest-owned private blobs.' }
    if (@($Facts.public_blobs).Count -ne 0) { throw 'production defect: Stage 9 cleanup left manifest-owned public blob copies.' }
    Assert-Stage9SentinelsUnchanged $SentinelsBefore $Facts.sentinels 'cleanup'
}

# Prior-run cleanup must use the real configured Stage 9 disk, never the isolated seeder-test disk.
function Assert-Stage9CleanupDiskIdentity {
    param($Evidence)
    if ($Evidence.cleaned -ne $true -or [string] $Evidence.disk -cne 'local' -or [string] $Evidence.root -cne $script:Stage9PrivateRootPath) {
        throw 'integration-harness defect: Stage 9 manifest cleanup did not use the real configured private disk.'
    }
}

# The container runs the live backend tree, so the evidence names a commit only if the checkout under test is
# clean at start and still clean on the same commit before PASS.
function Assert-Stage9AuditedCheckout {
    param([Parameter(Mandatory = $true)] $Start, $Current)
    if ([string] $Start.Sha -cnotmatch '\A[a-f0-9]{40}\z' -or $Start.Clean -ne $true) {
        throw 'environment/runtime defect: the checkout has uncommitted changes under backend/, frontend/ or docker/; the evidence could not name the code under test.'
    }
    if ($null -ne $Current -and ($Current.Clean -ne $true -or [string] $Current.Sha -cne [string] $Start.Sha)) {
        throw 'environment/runtime defect: the audited checkout changed during the run.'
    }
}

# The runner executes exactly this order; the verifier proves unsafe orders are rejected.
function Assert-Stage9RunnerPlan {
    param([string[]] $Plan)
    $required = @('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'seeder_test', 'fresh_seed', 'baseline_oracle',
        'api_setup', 'review_transport', 'scheduled_checking', 'windows_flow', 'post_ui_api', 'post_flow_oracle', 'restart', 'post_restart_oracle', 'final_cleanup', 'cleanup_oracle')
    $positions = @{}
    foreach ($step in $required) {
        $index = [array]::IndexOf($Plan, $step)
        if ($index -lt 0) { throw "integration-harness defect: Stage 9 runner plan misses $step." }
        $positions[$step] = $index
    }
    for ($i = 1; $i -lt $required.Count; $i++) {
        if ($positions[$required[$i]] -le $positions[$required[$i - 1]]) { throw "integration-harness defect: Stage 9 runner plan runs $($required[$i]) before $($required[$i - 1])." }
    }
    if ('previous_final_cleanup' -cin $Plan -or 'requires_previous_cleanup' -cin $Plan) { throw 'integration-harness defect: Stage 9 retry must not depend on a previous final cleanup.' }
}

# ---------------------------------------------------------------- scheduled commands (S09-DOC-001 section 7)

function Get-Stage9ScheduleSafetyFacts {
    $program = @'
use Database\Seeders\Stage9E2eSeeder;
if (!app()->environment('testing') || DB::connection()->getDriverName() !== 'pgsql' || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new RuntimeException('Stage 9 schedule guard identity failed.');
}
$scanNow = now();
// Mirror the three production candidate predicates with the application clock.
$homework = DB::table('homework_assignments')->where('status', 'active')->whereNotNull('deadline_at')->where('deadline_at', '<=', $scanNow)
    ->whereExists(fn ($q) => $q->selectRaw('1')->from('assessment_attempts')->whereColumn('assessment_attempts.institution_id', 'homework_assignments.institution_id')
        ->whereColumn('assessment_attempts.assessment_id', 'homework_assignments.assessment_id')->where('assessment_attempts.status', 'in_progress'))
    ->orderBy('assessment_id')->get(['institution_id', 'assessment_id']);
$blitz = DB::table('blitz_tasks')->where('status', 'active')
    ->whereExists(fn ($q) => $q->selectRaw('1')->from('assessment_attempts')->whereColumn('assessment_attempts.institution_id', 'blitz_tasks.institution_id')
        ->whereColumn('assessment_attempts.assessment_id', 'blitz_tasks.assessment_id')->where('assessment_attempts.status', 'in_progress')
        ->where('assessment_attempts.deadline_at', '<=', $scanNow))
    ->orderBy('assessment_id')->get(['institution_id', 'assessment_id']);
$frozen = DB::table('assessment_attempts')->whereIn('status', ['submitted', 'timed_out_finalized'])->orderBy('id')->get(['id', 'institution_id', 'assessment_id']);
// Stricter than production: every in-progress Attempt, every checked Attempt of a designated pair task and every
// official row in the whole database must be manifest-owned, due or not.
$inProgress = DB::table('assessment_attempts')->where('status', 'in_progress')->orderBy('id')->get(['id', 'institution_id', 'assessment_id']);
$pairTasks = DB::table('topic_result_pairs')->pluck('homework_assessment_id')->merge(DB::table('topic_result_pairs')->whereNotNull('blitz_assessment_id')->pluck('blitz_assessment_id'))->unique()->values()->all();
$pairChecked = DB::table('assessment_attempts')->whereIn('assessment_id', $pairTasks)->where('status', 'checked')->orderBy('id')->get(['id', 'institution_id', 'assessment_id']);
$official = DB::table('official_task_scores')->orderBy('id')->get(['id', 'institution_id', 'assessment_id']);
$m = Stage9E2eSeeder::manifest();
// Owners come from the declared fixtures, never from the rows being judged.
$owners = collect(Stage9E2eSeeder::fixtureRows($m, '2026-01-01 00:00:00+00')['assessments'])->pluck('institution_id', 'id')->all();
$rows = fn ($c) => $c->map(fn ($r) => (array) $r)->all();
echo json_encode(['scan_now' => $scanNow->utc()->format('Y-m-d\TH:i:s.u\Z'), 'homework' => $rows($homework), 'blitz' => $rows($blitz), 'frozen' => $rows($frozen),
    'in_progress' => $rows($inProgress), 'pair_checked' => $rows($pairChecked), 'official' => $rows($official), 'owners' => $owners], JSON_THROW_ON_ERROR);
'@
    Invoke-Stage9ContainerPhp -Program $program
}

# Every candidate and every superset row must be a declared Stage 9 fixture; the expected candidate set is exact.
function Assert-Stage9ScheduleSafeToRun {
    param([Parameter(Mandatory = $true)] $Facts, [Parameter(Mandatory = $true)][hashtable] $Expected)
    foreach ($set in @('homework', 'blitz', 'frozen', 'in_progress', 'pair_checked', 'official')) {
        foreach ($row in @($Facts.$set)) {
            $owner = $Facts.owners.PSObject.Properties[[string] $row.assessment_id]
            if ($null -eq $owner) { throw "environment/runtime defect: a non-Stage-9 row is a scheduled-command candidate ($set); isolation failure, command not run." }
            if ([string] $owner.Value -cne [string] $row.institution_id) { throw "environment/runtime defect: a Stage 9 scheduled-command candidate has the wrong Institution ($set); command not run." }
        }
    }
    foreach ($set in $Expected.Keys) {
        $key = if ($set -ceq 'frozen') { 'id' } else { 'assessment_id' }
        $actual = @($Facts.$set | ForEach-Object { [string] $_.$key })
        if ((@($actual | Sort-Object) -join ',') -cne (@($Expected[$set] | Sort-Object) -join ',')) {
            throw "integration-harness defect: Stage 9 scheduled-command candidates ($set) differ from the expected fixture set; command not run."
        }
    }
}

function Invoke-Stage9ArtisanCommand {
    param([Parameter(Mandatory = $true)][string] $Command)
    $output = @(& docker exec $script:Stage9BackendContainerName timeout --kill-after=10 300 php artisan $Command 2>&1)
    [pscustomobject] @{ ExitCode = $LASTEXITCODE; Output = (@($output | ForEach-Object { [string] $_ }) -join "`n") }
}

function Assert-Stage9CommandOutput {
    param([Parameter(Mandatory = $true)] $Result, [Parameter(Mandatory = $true)][string] $Command, [string[]] $ExpectedLines)
    if ([int] $Result.ExitCode -eq 124 -or [int] $Result.ExitCode -eq 137) { throw "environment/runtime defect: $Command timed out after 300 s." }
    if ([int] $Result.ExitCode -ne 0) { throw "production defect: $Command failed (exit $($Result.ExitCode))." }
    $lines = @(([string] $Result.Output) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ((@($lines) -join "`n") -cne (@($ExpectedLines) -join "`n")) { throw "production defect: $Command output differs from the expected counts." }
}

# A fresh global scan guards every invocation; a previous result is never reused.
function Invoke-Stage9GuardedCommand {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('homework:reconcile-deadlines', 'blitz:reconcile-timeouts', 'attempts:check-frozen')][string] $Command,
        [Parameter(Mandatory = $true)][hashtable] $ExpectedCandidates,
        [Parameter(Mandatory = $true)][string[]] $ExpectedLines,
        [scriptblock] $FactsProvider = { Get-Stage9ScheduleSafetyFacts },
        [scriptblock] $SentinelProvider = { Get-Stage9SentinelFacts },
        [scriptblock] $Invoker = { param($Name) Invoke-Stage9ArtisanCommand -Command $Name }
    )
    $facts = & $FactsProvider
    Assert-Stage9ScheduleSafeToRun -Facts $facts -Expected $ExpectedCandidates
    $sentinelsBefore = & $SentinelProvider
    $result = & $Invoker $Command
    Assert-Stage9CommandOutput -Result $result -Command $Command -ExpectedLines $ExpectedLines
    Assert-Stage9SentinelsUnchanged $sentinelsBefore (& $SentinelProvider) $Command
    [pscustomobject] @{ Command = $Command; Output = [string] $result.Output }
}

function Assert-Stage9ScheduleList {
    param([Parameter(Mandatory = $true)] $Result)
    if ([int] $Result.ExitCode -ne 0) { throw 'production defect: schedule:list failed.' }
    $lines = @(([string] $Result.Output) -split "`r?`n")
    foreach ($command in $script:Stage9ScheduledCommands) {
        if (@($lines | Where-Object { $_ -match '\*\s+\*\s+\*\s+\*\s+\*' -and $_.Contains($command) }).Count -ne 1) {
            throw "production defect: the schedule does not run $command every minute."
        }
    }
}

# schedule:run runs every due command in-process order; it is invoked only when no command has a candidate.
function Invoke-Stage9GuardedScheduleRun {
    param(
        [scriptblock] $FactsProvider = { Get-Stage9ScheduleSafetyFacts },
        [scriptblock] $SentinelProvider = { Get-Stage9SentinelFacts },
        [scriptblock] $Invoker = { Invoke-Stage9ArtisanCommand -Command 'schedule:run' }
    )
    $facts = & $FactsProvider
    Assert-Stage9ScheduleSafeToRun -Facts $facts -Expected @{ homework = @(); blitz = @(); frozen = @() }
    $sentinelsBefore = & $SentinelProvider
    $result = & $Invoker
    if ([int] $result.ExitCode -eq 124 -or [int] $result.ExitCode -eq 137) { throw 'environment/runtime defect: schedule:run timed out after 300 s.' }
    if ([int] $result.ExitCode -ne 0) { throw 'production defect: schedule:run failed.' }
    $lines = @(([string] $result.Output) -split "`r?`n")
    if (@($lines | Where-Object { $_ -match '(?i)\bFAIL\b' }).Count -ne 0) { throw 'production defect: schedule:run reported a failed command.' }
    foreach ($command in $script:Stage9ScheduledCommands) {
        if (@($lines | Where-Object { $_.Contains($command) -and $_ -match 'DONE' }).Count -ne 1) { throw "production defect: schedule:run did not run $command." }
    }
    Assert-Stage9SentinelsUnchanged $sentinelsBefore (& $SentinelProvider) 'schedule:run'
    [string] $result.Output
}

# ---------------------------------------------------------------- bounded waits

# Checking runs after the response is sent, so the harness waits for the authoritative DB state.
function Wait-Stage9AttemptStatus {
    param([Parameter(Mandatory = $true)][string] $AttemptId, [Parameter(Mandatory = $true)][string] $Status, [int] $TimeoutSeconds = 30)
    $program = @'
$row = DB::table('assessment_attempts')->where('id', $stage9Input['attempt'])->first(['status']);
echo json_encode(['status' => $row?->status], JSON_THROW_ON_ERROR);
'@
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $state = Invoke-Stage9ContainerPhp -Program $program -InputJson (@{ attempt = $AttemptId } | ConvertTo-Json -Compress)
        if ([string] $state.status -ceq $Status) { return }
        if ([string] $state.status -cnotin @('in_progress', 'submitted', 'timed_out_finalized', 'waiting_for_teacher_review', 'checked')) { throw 'production defect: Stage 9 Attempt disappeared while waiting for checking.' }
        Start-Sleep -Milliseconds 500
    }
    throw "production defect: Stage 9 Attempt did not reach $Status within $TimeoutSeconds s (post-response checking did not run)."
}

function Wait-Stage9TimestampBoundary {
    param([string] $Timestamp)
    # Persisted timestamps have second precision; a later server second makes a rewrite detectable.
    $recorded = [DateTimeOffset] $Timestamp
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt 10) {
        $clock = Invoke-Stage9ContainerPhp -Program 'echo json_encode(["now"=>now()->utc()->format("Y-m-d\\TH:i:s\\Z")], JSON_THROW_ON_ERROR);'
        if ([DateTimeOffset] $clock.now -gt $recorded) { return }
        Start-Sleep -Milliseconds 200
    }
    throw 'environment/runtime defect: Server clock did not advance beyond the recorded timestamp within the bounded wait.'
}
