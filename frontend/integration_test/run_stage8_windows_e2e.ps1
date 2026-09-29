param(
    [Parameter(Mandatory = $true)][string] $FlutterExecutable,
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage8_test_files.ps1')
. (Join-Path $PSScriptRoot 'stage8_api_scenarios.ps1')

# Runs only after the delivered assets pass the Integration Harness Preflight.
# STAGE8_E2E_PASSWORD comes from the process or Windows user environment and is never printed.
$frontendRoot = Split-Path -Parent $PSScriptRoot
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$password = $null
$fixtures = $null
$evidenceRoot = $null
$context = $null
$startedAt = [DateTime]::UtcNow
$plan = @('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'seeder_test', 'fresh_seed',
    'baseline_oracle', 'test_files', 'windows_flow', 'api_scenarios', 'guarded_scheduler', 'post_flow_oracle', 'restart', 'post_restart_oracle', 'final_cleanup', 'cleanup_oracle')
$executed = [Collections.Generic.List[string]]::new()

# Steps must complete in exactly the audited plan order; the final PASS requires the whole plan.
function Complete-Stage8Step {
    param([string] $Step)
    if ($executed.Count -ge $plan.Count -or $plan[$executed.Count] -cne $Step) { throw "integration-harness defect: Stage 8 step $Step ran out of the audited plan order." }
    $executed.Add($Step)
}

# The password may reach diagnostics raw or JSON-escaped (for example inside a Dart error payload).
function Get-Stage8SecretForms {
    if ([string]::IsNullOrEmpty($password)) { return @() }
    @($password, $password.Replace('\', '\\').Replace('"', '\"'), ($password | ConvertTo-Json -Compress).Trim('"')) | Select-Object -Unique
}

function Assert-Stage8FlutterExecutable {
    if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) { throw 'Stage 8 Flutter executable is absent.' }
    $pin = (Get-Content -LiteralPath (Join-Path $frontendRoot '.fvmrc') -Raw | ConvertFrom-Json).flutter
    $output = @(& $FlutterExecutable --version --machine 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Stage 8 Flutter version probe failed.' }
    try { $version = (($output | Where-Object { $_ -is [string] }) -join "`n") | ConvertFrom-Json } catch { throw 'Invalid Flutter version response.' }
    if ([string]::IsNullOrWhiteSpace($pin) -or $version.frameworkVersion -cne $pin) { throw 'Stage 8 Flutter executable does not match .fvmrc.' }
}

function Read-Stage8Password {
    $value = [Environment]::GetEnvironmentVariable('STAGE8_E2E_PASSWORD', 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) { $value = [Environment]::GetEnvironmentVariable('STAGE8_E2E_PASSWORD', 'User') }
    if ([string]::IsNullOrWhiteSpace($value) -or $value.Trim().Length -lt 16) { throw 'STAGE8_E2E_PASSWORD must be set (at least 16 characters) in the process or Windows user environment.' }
    $value
}

function Get-Stage8CheckoutState {
    param([Parameter(Mandatory = $true)][string] $Root)
    $sha = [string] (& git -C $Root rev-parse HEAD)
    if ($LASTEXITCODE -ne 0) { throw 'Stage 8 runner could not record the audited Git SHA.' }
    $changes = @(& git -C $Root status --porcelain --untracked-files=all -- backend frontend docker)
    if ($LASTEXITCODE -ne 0) { throw 'Stage 8 runner could not read the checkout status.' }
    [pscustomobject] @{ Sha = $sha.Trim(); Clean = ($changes.Count -eq 0) }
}

function Invoke-Stage8Seeder {
    param([ValidateSet('run', 'cleanupOwnedState', 'ensureSentinels', 'removeSentinels')][string] $Operation)
    $program = @'
try {
    putenv('STAGE8_E2E_PASSWORD='.$stage8Input['password']);
    $operation = $stage8Input['operation'];
    (new Database\Seeders\Stage8E2eSeeder)->{$operation}();
    $disk = config('filesystems.private_files_disk');
    echo json_encode(['cleaned' => true, 'operation' => $operation, 'disk' => $disk, 'root' => config('filesystems.disks.'.$disk.'.root')], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
} finally { putenv('STAGE8_E2E_PASSWORD'); unset($stage8Input['password']); }
'@
    $result = Invoke-Stage8ContainerPhp -Program $program -InputJson (@{ password = $password; operation = $Operation } | ConvertTo-Json -Compress)
    if ($result.operation -cne $Operation) { throw "Stage 8 seeder $Operation was not confirmed." }
    $result
}

function Remove-Stage8LocalRoot {
    param([Parameter(Mandatory = $true)][string] $Root, [Parameter(Mandatory = $true)][string] $Kind, [string[]] $KeepNames = @())
    $full = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if (-not [IO.Path]::GetDirectoryName($full).Equals($temp, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($full) -cnotmatch "\Atestlabuz-stage8-$Kind-[a-f0-9]{32}\z") { throw 'Unsafe Stage 8 local cleanup root.' }
    if (-not (Test-Path -LiteralPath $full)) { return }
    if ((Get-Item -LiteralPath $full).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Stage 8 local root cannot be a link.' }
    foreach ($entry in @(Get-ChildItem -LiteralPath $full -Force)) {
        if ($entry.Name -cin $KeepNames) { continue }
        if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            $entry.Name -cnotmatch '\A(?:launcher\.ps1|manifest\.json|ui-evidence\.json|checkpoint-[a-z_]+(?:\.ack)?\.json(?:\.pending)?|sink-(?:open|save)-[A-Za-z0-9_.-]+)\z') {
            throw 'Unexpected Stage 8 local evidence entry preserved; cleanup stopped.'
        }
        Remove-Item -LiteralPath $entry.FullName
    }
    if ($KeepNames.Count -eq 0) { [IO.Directory]::Delete($full, $false) }
}

function Invoke-Stage8PeerAction {
    param([ValidateSet('start', 'submit')][string] $Action, [string] $AttemptId)
    $m = $context.Manifest
    if ($Action -ceq 'start') {
        $response = Invoke-Stage8Start $context peer $m.assessments.main (New-Stage8StartRequest (New-Stage8Key 60) start_normal)
        Assert-Stage8ApiSuccess $response 201
        return [string] $response.Json.data.id
    }
    Assert-Stage8ApiSuccess (Invoke-Stage8Submit $context peer $AttemptId (New-Stage8Key 61))
}

# Each UI checkpoint is judged by the independent DB oracle before the Flutter test may continue.
function Test-Stage8UiCheckpoint {
    param($Checkpoint, $Baseline, [hashtable] $State)
    $m = $Baseline.manifest
    $facts = Get-Stage8DatabaseFacts
    Assert-Stage8TenantRows $facts
    Assert-Stage8NoStageNineScoring $facts
    switch ($Checkpoint.checkpoint) {
        'builder_archived' {
            $blitz = Get-Stage8Row $facts blitz_tasks ([string] $Checkpoint.blitz_id) assessment_id
            $assessment = Get-Stage8Row $facts assessments ([string] $Checkpoint.blitz_id)
            if ([string] $Checkpoint.blitz_id -cnotin @($facts.dynamic.assessments) -or $assessment.topic_id -cne $m.topics.builder -or $assessment.title -cne 'E2E S08 UI Blitz edited' -or $assessment.assignment_mode -cne 'group' -or
                $blitz.status -cne 'archived' -or $null -eq $blitz.archived_at -or $null -ne $blitz.activated_at -or [int] $blitz.duration_seconds -ne 300) { throw 'production defect: Builder smoke Blitz did not persist its authored lifecycle.' }
            $questions = @(Get-Stage8Rows $facts questions assessment_id $Checkpoint.blitz_id)
            if ($questions.Count -ne 1 -or $questions[0].type -cne 'true_false') { throw 'production defect: Builder smoke Question was not persisted.' }
            if (@(Get-Stage8Rows $facts assessment_students assessment_id $Checkpoint.blitz_id).Count -ne 0 -or @(Get-Stage8Rows $facts assessment_attempts assessment_id $Checkpoint.blitz_id).Count -ne 0) { throw 'production defect: Scheduling or archiving a draft created recipients/Attempts.' }
        }
        'official_activated' {
            Assert-Stage8OfficialPair (Get-Stage8Row $facts topic_result_pairs $m.pairs.official) (Get-Stage8Row $Baseline topic_result_pairs $m.pairs.official) ([string] $m.assessments.main)
            Assert-Stage8BlitzLifecycle (Get-Stage8Row $facts blitz_tasks $m.assessments.main assessment_id) active synchronized 1800
            Assert-Stage8Recipients $facts $m.assessments.main @([string] $m.users.student, [string] $m.users.peer) 'frozen official cohort'
            Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $facts $Checkpoint.key teacher.blitz.activate) $m.institutions.target ([string] $m.users.teacher) teacher.blitz.activate $Checkpoint.key blitz ([string] $m.assessments.main) 200
            if (@(Get-Stage8Rows $facts assessment_attempts assessment_id $m.assessments.main).Count -ne 0) { throw 'production defect: Opening or activating the Blitz created an Attempt.' }
        }
        'pre_start_viewed' {
            if (@(Get-Stage8Rows $facts assessment_attempts assessment_id $m.assessments.main).Count -ne 0) { throw 'production defect: Opening the Student Blitz detail created an Attempt.' }
        }
        'first_submitted' {
            $history = Assert-Stage8AttemptHistory $facts $m.assessments.main ([string] $m.users.student)
            # The Start route never changes, so the UI names its Attempt through the completed Start key.
            $attempt = Get-Stage8Row $facts assessment_attempts ([string] (Get-Stage8IdempotencyRecord $facts $Checkpoint.start_key student.blitz.attempt.start).result_resource_id)
            if ($history.Attempts.Count -ne 1 -or $attempt.id -cne $history.Attempts[0].id) { throw 'production defect: First UI Attempt identity mismatch.' }
            Assert-Stage8TerminalAttempt $attempt student_submit ([string] $attempt.submitted_at)
            $answered = @($Checkpoint.answered_question_ids)
            $answers = Assert-Stage8AnswerSet $facts $attempt.id $answered
            $file = Get-Stage8Row $facts files ([string] $Checkpoint.file_id)
            Assert-Stage8File $facts $file (Get-Stage8FileExpectation $fixtures answer_pdf) $attempt ([string] $m.questions.main.file_based)
            foreach ($expected in @($Checkpoint.expected_answers)) {
                Assert-Stage8TypedAnswer $facts @($answers | Where-Object question_id -CEQ $expected.question_id)[0] $expected.type @($expected.values)
            }
            Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $facts $Checkpoint.start_key student.blitz.attempt.start) $m.institutions.target ([string] $m.users.student) student.blitz.attempt.start $Checkpoint.start_key assessment_attempt $attempt.id 201
            Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $facts $Checkpoint.submit_key student.blitz.attempt.submit) $m.institutions.target ([string] $m.users.student) student.blitz.attempt.submit $Checkpoint.submit_key assessment_attempt $attempt.id 200
            $State.first_submitted = $facts
        }
        'monitoring_open' {
            $State.peer_attempt = Invoke-Stage8PeerAction start
        }
        'granted' {
            $history = Assert-Stage8AttemptHistory $facts $m.assessments.main ([string] $m.users.student)
            if ($history.Attempts.Count -ne 1) { throw 'production defect: The UI grant created Attempt #2.' }
            Assert-Stage8Exception $history.Exception ([string] $history.Attempts[0].id) $null technical ([string] $Checkpoint.reason) ([string] $m.users.teacher)
            Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $facts $Checkpoint.key teacher.blitz.attempt_exception.grant) $m.institutions.target ([string] $m.users.teacher) teacher.blitz.attempt_exception.grant $Checkpoint.key blitz_attempt_exception $history.Exception.id 201
            Assert-Stage8Equal @(Get-Stage8Rows $facts attempt_answers attempt_id $history.Attempts[0].id) @(Get-Stage8Rows $State.first_submitted attempt_answers attempt_id $history.Attempts[0].id) 'grant leaves #1 answers'
            Invoke-Stage8PeerAction submit $State.peer_attempt
        }
        'replacement_submitted' {
            $history = Assert-Stage8AttemptHistory $facts $m.assessments.main ([string] $m.users.student)
            $replacementId = [string] (Get-Stage8IdempotencyRecord $facts $Checkpoint.start_key student.blitz.attempt.start).result_resource_id
            if ($history.Attempts.Count -ne 2 -or $history.Attempts[1].id -cne $replacementId) { throw 'production defect: Replacement #2 identity mismatch.' }
            Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $facts $Checkpoint.submit_key student.blitz.attempt.submit) $m.institutions.target ([string] $m.users.student) student.blitz.attempt.submit $Checkpoint.submit_key assessment_attempt $replacementId 200
            Assert-Stage8TerminalAttempt $history.Attempts[1] student_submit ([string] $history.Attempts[1].submitted_at)
            Assert-Stage8AnswerSet $facts $history.Attempts[1].id @($Checkpoint.answered_question_ids) | Out-Null
        }
        'timed_out' {
            $attempt = Get-Stage8Row $facts assessment_attempts ([string] (Get-Stage8IdempotencyRecord $facts $Checkpoint.start_key student.blitz.attempt.start).result_resource_id)
            if ($attempt.assessment_id -cne $m.assessments.timeout_ui -or $attempt.student_id -cne $m.users.d_timeout_ui) { throw 'production defect: Timeout UI Attempt ownership mismatch.' }
            Assert-Stage8TerminalAttempt $attempt timeout_auto_submit ''
            Assert-Stage8AnswerSet $facts $attempt.id @([string] $m.questions.timeout_ui.short_written, [string] $m.questions.timeout_ui.open_written) | Out-Null
        }
        default { throw 'integration-harness defect: Unknown Stage 8 UI checkpoint.' }
    }
}

function Invoke-Stage8WindowsFlow {
    param([Parameter(Mandatory = $true)] $Baseline)
    $manifestPath = Join-Path $evidenceRoot 'manifest.json'
    [IO.File]::WriteAllText($manifestPath, ($Baseline.manifest | ConvertTo-Json -Depth 30 -Compress), [Text.UTF8Encoding]::new($false))
    $launcher = @'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
& $env:STAGE8_E2E_FLUTTER_EXECUTABLE test integration_test/stage8_blitz_flow_test.dart -d windows --no-pub "--dart-define=API_BASE_URL=$env:STAGE8_E2E_API_BASE_URL"
exit $LASTEXITCODE
'@
    $launcherPath = Join-Path $evidenceRoot 'launcher.ps1'
    [IO.File]::WriteAllText($launcherPath, $launcher, [Text.UTF8Encoding]::new($false))
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command powershell.exe -ErrorAction Stop).Source
    $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $launcherPath + '"'
    $startInfo.WorkingDirectory = $frontendRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['STAGE8_E2E_PASSWORD'] = $password
    $startInfo.EnvironmentVariables['STAGE8_E2E_FLUTTER_EXECUTABLE'] = [IO.Path]::GetFullPath($FlutterExecutable)
    $startInfo.EnvironmentVariables['STAGE8_E2E_API_BASE_URL'] = $apiBaseUrl
    $startInfo.EnvironmentVariables['STAGE8_E2E_FIXTURE_ROOT'] = $fixtures.ManifestPath
    $startInfo.EnvironmentVariables['STAGE8_E2E_MANIFEST_PATH'] = $manifestPath
    $startInfo.EnvironmentVariables['STAGE8_E2E_EVIDENCE_PATH'] = (Join-Path $evidenceRoot 'ui-evidence.json')
    $startInfo.EnvironmentVariables['STAGE8_E2E_MODE'] = 'main'
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $names = @('builder_archived', 'official_activated', 'pre_start_viewed', 'first_submitted', 'monitoring_open', 'granted', 'replacement_submitted', 'timed_out')
    $next = 0
    $state = @{}
    $stdout = $null; $stderr = $null; $didStart = $false
    try {
        [void] $process.Start()
        $didStart = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTime]::UtcNow.AddMinutes(40)
        while (-not $process.HasExited) {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Stage 8 Windows flow exceeded its bounded completion timeout.' }
            if ($next -lt $names.Count) {
                $name = $names[$next]
                $checkpointPath = Join-Path $evidenceRoot ("checkpoint-$name.json")
                if (Test-Path -LiteralPath $checkpointPath) {
                    $checkpoint = [IO.File]::ReadAllText($checkpointPath, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
                    if ([int] $checkpoint.version -ne 1 -or $checkpoint.checkpoint -cne $name) { throw 'Stage 8 UI checkpoint identity mismatch.' }
                    Test-Stage8UiCheckpoint -Checkpoint $checkpoint -Baseline $Baseline -State $state
                    $ackPath = Join-Path $evidenceRoot ("checkpoint-$name.ack.json")
                    [IO.File]::WriteAllText(($ackPath + '.pending'), (@{ version = 1; checkpoint = $name; passed = $true } | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
                    Move-Item -LiteralPath ($ackPath + '.pending') -Destination $ackPath
                    Write-Host "Stage8Checkpoint: PASS $name"
                    $next++
                }
            }
            # Bounded polling of process/checkpoint conditions; elapsed time never implies success.
            Start-Sleep -Milliseconds 100
            $process.Refresh()
        }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            $diagnostics = Protect-Stage8Diagnostic ($stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()) @(Get-Stage8SecretForms)
            throw ('Stage 8 Windows UI process failed: ' + $diagnostics)
        }
        if ($next -ne $names.Count) { throw 'Stage 8 Windows UI omitted mandatory DB checkpoints.' }
        Write-Host 'Stage8WindowsUiProcess: PASS exit_code=0'
        $ui = [IO.File]::ReadAllText((Join-Path $evidenceRoot 'ui-evidence.json'), [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
        $facts = Get-Stage8DatabaseFacts
        $attemptIds = @('start1', 'start2' | ForEach-Object { [string] (Get-Stage8IdempotencyRecord $facts $ui.keys.$_ student.blitz.attempt.start).result_resource_id })
        $ui | Add-Member attempt_ids $attemptIds
        $ui
    }
    finally {
        if ($didStart -and -not $process.HasExited) {
            & taskkill.exe /PID ([string] $process.Id) /T /F *> $null
            $process.WaitForExit(10000) | Out-Null
        }
        $startInfo.EnvironmentVariables.Remove('STAGE8_E2E_PASSWORD')
        $stdout = $null; $stderr = $null
        $process.Dispose()
    }
}

$operationFailed = $false
$stateTouched = $false
$harnessLock = $null
try {
    $harnessLock = Enter-Stage8HarnessLock
    if (Test-Stage8ManualSmokePending) {
        throw ('environment/runtime defect: ' + (Get-Stage8ManualSmokePendingMessage))
    }
    Assert-Stage8RunnerPlan $plan
    Assert-Stage8FlutterExecutable
    $repositoryRoot = Split-Path -Parent $frontendRoot
    $checkout = Get-Stage8CheckoutState -Root $repositoryRoot
    Assert-Stage8AuditedCheckout $checkout
    $auditedSha = $checkout.Sha
    Write-Output "Stage8Run: sha=$auditedSha command=run_stage8_windows_e2e.ps1 ApiPort=$ApiPort plan=$($plan -join ',')"
    $password = Read-Stage8Password
    $apiTarget = Resolve-Stage8ApiTarget $apiBaseUrl

    # runtime_guard
    Write-Output "Stage8Runtime: $(Initialize-Stage8Runtime -ApiTarget $apiTarget)"
    $runtime = Assert-Stage8DedicatedRuntime -ApiTarget $apiTarget
    Assert-Stage8ExclusiveDatabase -ClientAddress $runtime.ClientAddress
    Write-Output "Stage8RuntimeGuard: PASS workers=$($runtime.Workers) client=$($runtime.ClientAddress) exclusive_database=True"
    Complete-Stage8Step runtime_guard
    & (Join-Path $PSScriptRoot 'verify_stage8_runtime_guard.ps1') -ApiPort $ApiPort
    foreach ($verifier in @('verify_stage8_test_files.ps1', 'verify_stage8_concurrency_probe.ps1', 'verify_stage8_oracle.ps1', 'verify_stage8_api_security.ps1')) { & (Join-Path $PSScriptRoot $verifier) }
    Complete-Stage8Step pure_verifiers
    $stateTouched = $true
    Invoke-Stage8Seeder ensureSentinels | Out-Null
    $sentinels = Get-Stage8SentinelFacts
    Write-Output 'Stage8UnrelatedSentinels: captured'
    Complete-Stage8Step sentinel_capture
    # Prior manifest state is removed on the real configured private disk; its oracle re-reads every prior ID.
    $priorFacts = Get-Stage8DatabaseFacts
    $priorRows = 0; foreach ($property in $priorFacts.tables.PSObject.Properties) { $priorRows += @($property.Value).Count }
    $priorBlobs = @($priorFacts.blobs).Count
    Assert-Stage8CleanupDiskIdentity (Invoke-Stage8Seeder cleanupOwnedState)
    Complete-Stage8Step prior_manifest_cleanup
    Assert-Stage8CleanupFacts -Facts (Get-Stage8DatabaseFacts -PriorFacts $priorFacts) -SentinelsBefore $sentinels
    Write-Output "Stage8PriorManifestCleanup: PASS disk=local prior_rows_removed=$priorRows prior_blobs_removed=$priorBlobs"
    Complete-Stage8Step prior_cleanup_oracle
    & docker exec $runtime.ContainerName timeout --kill-after=10 900 php artisan test tests/Feature/Seeders/Stage8E2eSeederTest.php
    if ($LASTEXITCODE -ne 0) { throw 'Stage 8 focused seeder verification failed.' }
    Complete-Stage8Step seeder_test
    Invoke-Stage8Seeder run | Out-Null
    Complete-Stage8Step fresh_seed
    $baseline = Get-Stage8DatabaseFacts
    Assert-Stage8Baseline $baseline
    Assert-Stage8SentinelsUnchanged $sentinels $baseline.sentinels 'seeding'
    Write-Output 'Stage8BaselineOracle: PASS'
    Complete-Stage8Step baseline_oracle
    $fixtures = New-Stage8FixtureManifest -DestinationRoot (Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage8-fixtures-' + [guid]::NewGuid().ToString('N')))
    Assert-Stage8FixtureManifest $fixtures
    Complete-Stage8Step test_files
    $evidenceRoot = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage8-evidence-' + [guid]::NewGuid().ToString('N'))
    [void] [IO.Directory]::CreateDirectory($evidenceRoot)
    $context = New-Stage8ApiContext -ApiBaseUrl $apiBaseUrl -Password $password -Manifest $baseline.manifest -FileManifest $fixtures -Runtime $runtime
    $uiEvidence = @(Invoke-Stage8WindowsFlow -Baseline $baseline)[-1]
    Complete-Stage8Step windows_flow
    Invoke-Stage8SecurityMatrix $context $uiEvidence | Out-Null
    Invoke-Stage8TransportMatrix $context $uiEvidence
    $execution = Invoke-Stage8ExecutionMatrix $context
    $activation = Invoke-Stage8ActivationIdempotency $context
    Invoke-Stage8SyncReplacement $context
    Invoke-Stage8IndividualTiming $context
    Invoke-Stage8SelectedPractice $context
    Invoke-Stage8BlitzFirst $context
    Invoke-Stage8UnsetTimer $context
    Invoke-Stage8LateWrites $context
    Invoke-Stage8Races $context
    Invoke-Stage8TeacherClose $context $execution
    Invoke-Stage8MonitoringApi $context
    Complete-Stage8Step api_scenarios
    Assert-Stage8ExclusiveDatabase -ClientAddress $runtime.ClientAddress
    Invoke-Stage8SchedulerPhase $context
    Complete-Stage8Step guarded_scheduler
    $postFlow = Get-Stage8DatabaseFacts
    Assert-Stage8TenantRows $postFlow
    Assert-Stage8NoStageNineScoring $postFlow
    Assert-Stage8SentinelsUnchanged $sentinels $postFlow.sentinels 'the automated flow'
    foreach ($key in $context.RejectedKeys) { Assert-Stage8NoIdempotencyRecord $postFlow $key }
    Write-Output 'Stage8PostFlowOracle: PASS'
    Complete-Stage8Step post_flow_oracle
    $monitoringBefore = Get-Stage8MonitoringState $context
    & docker restart $runtime.ContainerName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Stage 8 backend restart failed.' }
    Wait-Stage8HttpBoundary -ApiTarget $apiTarget
    $runtime = Assert-Stage8DedicatedRuntime -ApiTarget $apiTarget
    $context.Runtime = $runtime
    Complete-Stage8Step restart
    $afterRestart = Get-Stage8DatabaseFacts
    Assert-Stage8Equal $afterRestart.tables $postFlow.tables 'DB state after backend restart'
    Assert-Stage8Equal $afterRestart.blobs $postFlow.blobs 'private files after backend restart'
    Invoke-Stage8PostRestartReplays $context $execution $activation $uiEvidence $monitoringBefore
    Complete-Stage8Step post_restart_oracle
    $evidence = [ordered] @{ sha = $auditedSha; api_port = $ApiPort; ui = $uiEvidence; scenarios = $context.Evidence; rejected_keys = $context.RejectedKeys.Count }
    Close-Stage8ApiContext $context $false
    $context = $null
    $beforeCleanup = Get-Stage8DatabaseFacts
    Assert-Stage8CleanupDiskIdentity (Invoke-Stage8Seeder cleanupOwnedState)
    Complete-Stage8Step final_cleanup
    Assert-Stage8CleanupFacts -Facts (Get-Stage8DatabaseFacts -PriorFacts $beforeCleanup) -SentinelsBefore $sentinels
    Invoke-Stage8Seeder removeSentinels | Out-Null
    Write-Output 'Stage8FinalCleanup: PASS (manifest rows/blobs removed, unrelated sentinels unchanged then removed)'
    Complete-Stage8Step cleanup_oracle
    # Local generated files go before the PASS line, so a PASS never leaves them behind.
    Remove-Stage8FixtureManifest -Root $fixtures.Root
    $fixtures = $null
    Remove-Stage8LocalRoot -Root $evidenceRoot -Kind evidence
    $evidenceRoot = $null
    if (($executed -join ',') -cne ($plan -join ',')) { throw 'integration-harness defect: Stage 8 run did not execute the whole audited plan.' }
    Assert-Stage8ExclusiveDatabase -ClientAddress $runtime.ClientAddress
    Assert-Stage8AuditedCheckout $checkout (Get-Stage8CheckoutState -Root $repositoryRoot)
    $evidence.checkout_clean = $true
    $evidence.executed_steps = @($executed)
    $evidence.duration_seconds = [math]::Round(([DateTime]::UtcNow - $startedAt).TotalSeconds)
    $evidencePath = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage8-evidence-' + $auditedSha.Substring(0, 12) + '-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '.json')
    [IO.File]::WriteAllText($evidencePath, ($evidence | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    Write-Output "Stage8AutomatedEvidence: PASS duration_seconds=$($evidence.duration_seconds) steps=$($executed.Count) evidence=$evidencePath"
}
catch { $operationFailed = $true; throw }
finally {
    $cleanupErrors = [Collections.Generic.List[string]]::new()
    if ($null -ne $context) { try { Close-Stage8ApiContext $context $operationFailed } catch { $cleanupErrors.Add('Stage 8 API session cleanup failed.') } }
    try { if ($null -ne $fixtures) { Remove-Stage8FixtureManifest -Root $fixtures.Root } } catch { $cleanupErrors.Add('Stage 8 generated fixture cleanup failed.') }
    try { if ($null -ne $evidenceRoot) { Remove-Stage8LocalRoot -Root $evidenceRoot -Kind evidence } } catch { $cleanupErrors.Add('Stage 8 local evidence cleanup failed.') }
    $password = $null
    Exit-Stage8HarnessLock $harnessLock
    if ($cleanupErrors.Count -gt 0 -and -not $operationFailed) { throw ($cleanupErrors -join ' ') }
    if ($operationFailed -and $stateTouched) { Write-Output 'Stage8Run: FAILED; manifest-owned DB/private state is preserved for diagnosis and is removed by the next invocation.' }
    elseif ($operationFailed) { Write-Output 'Stage8Run: FAILED before any Stage 8 manifest state was changed.' }
}
