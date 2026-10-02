param(
    [Parameter(Mandatory = $true)][string] $FlutterExecutable,
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage9_test_files.ps1')
. (Join-Path $PSScriptRoot 'stage9_api_scenarios.ps1')

# Runs only after the delivered assets pass the Integration Harness Preflight (S09-INT-001 section 16).
# STAGE9_E2E_PASSWORD comes from the process or Windows user environment and is never printed.
$frontendRoot = Split-Path -Parent $PSScriptRoot
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$password = $null
$fixtures = $null
$evidenceRoot = $null
$context = $null
$startedAt = [DateTime]::UtcNow
$plan = @('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'seeder_test', 'fresh_seed',
    'baseline_oracle', 'test_files', 'api_setup', 'review_transport', 'scheduled_checking', 'windows_flow', 'post_ui_api', 'post_flow_oracle',
    'restart', 'post_restart_oracle', 'final_cleanup', 'cleanup_oracle')
$checkpointNames = @('review_deadline_set', 'review_partial', 'review_saved', 'review_corrected', 'exception_granted', 'replacement_seen')
$executed = [Collections.Generic.List[string]]::new()

# Steps must complete in exactly the audited plan order; the final PASS requires the whole plan.
function Complete-Stage9Step {
    param([string] $Step)
    if ($executed.Count -ge $plan.Count -or $plan[$executed.Count] -cne $Step) { throw "integration-harness defect: Stage 9 step $Step ran out of the audited plan order." }
    $executed.Add($Step)
}

# The password may reach diagnostics raw or JSON-escaped (for example inside a Dart error payload).
function Get-Stage9SecretForms {
    if ([string]::IsNullOrEmpty($password)) { return @() }
    @($password, $password.Replace('\', '\\').Replace('"', '\"'), ($password | ConvertTo-Json -Compress).Trim('"')) | Select-Object -Unique
}

function Assert-Stage9FlutterExecutable {
    if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) { throw 'Stage 9 Flutter executable is absent.' }
    $pin = (Get-Content -LiteralPath (Join-Path $frontendRoot '.fvmrc') -Raw | ConvertFrom-Json).flutter
    $output = @(& $FlutterExecutable --version --machine 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Stage 9 Flutter version probe failed.' }
    try { $version = (($output | Where-Object { $_ -is [string] }) -join "`n") | ConvertFrom-Json } catch { throw 'Invalid Flutter version response.' }
    if ([string]::IsNullOrWhiteSpace($pin) -or $version.frameworkVersion -cne $pin) { throw 'Stage 9 Flutter executable does not match .fvmrc.' }
}

function Read-Stage9Password {
    $value = [Environment]::GetEnvironmentVariable('STAGE9_E2E_PASSWORD', 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) { $value = [Environment]::GetEnvironmentVariable('STAGE9_E2E_PASSWORD', 'User') }
    if ([string]::IsNullOrWhiteSpace($value) -or $value.Trim().Length -lt 16) { throw 'STAGE9_E2E_PASSWORD must be set (at least 16 characters) in the process or Windows user environment.' }
    $value
}

function Get-Stage9CheckoutState {
    param([Parameter(Mandatory = $true)][string] $Root)
    $sha = [string] (& git -C $Root rev-parse HEAD)
    if ($LASTEXITCODE -ne 0) { throw 'Stage 9 runner could not record the audited Git SHA.' }
    $changes = @(& git -C $Root status --porcelain --untracked-files=all -- backend frontend docker)
    if ($LASTEXITCODE -ne 0) { throw 'Stage 9 runner could not read the checkout status.' }
    [pscustomobject] @{ Sha = $sha.Trim(); Clean = ($changes.Count -eq 0) }
}

function Invoke-Stage9Seeder {
    param([ValidateSet('run', 'cleanupOwnedState', 'ensureSentinels', 'removeSentinels')][string] $Operation)
    $program = @'
try {
    putenv('STAGE9_E2E_PASSWORD='.$stage9Input['password']);
    $operation = $stage9Input['operation'];
    (new Database\Seeders\Stage9E2eSeeder)->{$operation}();
    $disk = config('filesystems.private_files_disk');
    echo json_encode(['cleaned' => true, 'operation' => $operation, 'disk' => $disk, 'root' => config('filesystems.disks.'.$disk.'.root')], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
} finally { putenv('STAGE9_E2E_PASSWORD'); unset($stage9Input['password']); }
'@
    $result = Invoke-Stage9ContainerPhp -Program $program -InputJson (@{ password = $password; operation = $Operation } | ConvertTo-Json -Compress)
    if ($result.operation -cne $Operation) { throw "Stage 9 seeder $Operation was not confirmed." }
    $result
}

function Remove-Stage9LocalRoot {
    param([Parameter(Mandatory = $true)][string] $Root, [Parameter(Mandatory = $true)][string] $Kind)
    $full = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if (-not [IO.Path]::GetDirectoryName($full).Equals($temp, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($full) -cnotmatch "\Atestlabuz-stage9-$Kind-[a-f0-9]{32}\z") { throw 'Unsafe Stage 9 local cleanup root.' }
    if (-not (Test-Path -LiteralPath $full)) { return }
    if ((Get-Item -LiteralPath $full).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Stage 9 local root cannot be a link.' }
    foreach ($entry in @(Get-ChildItem -LiteralPath $full -Force)) {
        if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            $entry.Name -cnotmatch '\A(?:launcher\.ps1|manifest\.json|ui-evidence\.json(?:\.pending)?|checkpoint-[a-z_]+(?:\.ack)?\.json(?:\.pending)?)\z') {
            throw 'Unexpected Stage 9 local evidence entry preserved; cleanup stopped.'
        }
        Remove-Item -LiteralPath $entry.FullName
    }
    [IO.Directory]::Delete($full, $false)
}

function Invoke-Stage9WindowsFlow {
    param([Parameter(Mandatory = $true)] $Baseline)
    $m = $Baseline.manifest
    $r = $context.Runtime
    $runtimeManifest = [ordered] @{ version = 1; users = $m.users; topics = $m.topics; assessments = $m.assessments; questions = $m.questions
        runtime = [ordered] @{ review_attempt_id = $r.review_attempt_id; review_answer_ids = $r.review_answer_ids; review_file_id = $r.review_file_id
            exception_attempt_1_id = $r.exception_attempt_1_id; manual_attempt_id = $r.manual_attempt_id } }
    $manifestPath = Join-Path $evidenceRoot 'manifest.json'
    [IO.File]::WriteAllText($manifestPath, ($runtimeManifest | ConvertTo-Json -Depth 30 -Compress), [Text.UTF8Encoding]::new($false))
    $launcher = @'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
& $env:STAGE9_E2E_FLUTTER_EXECUTABLE test integration_test/stage9_review_flow_test.dart -d windows --no-pub "--dart-define=API_BASE_URL=$env:STAGE9_E2E_API_BASE_URL"
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
    $startInfo.EnvironmentVariables['STAGE9_E2E_PASSWORD'] = $password
    $startInfo.EnvironmentVariables['STAGE9_E2E_FLUTTER_EXECUTABLE'] = [IO.Path]::GetFullPath($FlutterExecutable)
    $startInfo.EnvironmentVariables['STAGE9_E2E_API_BASE_URL'] = $apiBaseUrl
    $startInfo.EnvironmentVariables['STAGE9_E2E_FIXTURE_ROOT'] = $fixtures.ManifestPath
    $startInfo.EnvironmentVariables['STAGE9_E2E_MANIFEST_PATH'] = $manifestPath
    $startInfo.EnvironmentVariables['STAGE9_E2E_EVIDENCE_PATH'] = (Join-Path $evidenceRoot 'ui-evidence.json')
    $startInfo.EnvironmentVariables['STAGE9_E2E_MODE'] = 'main'
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $next = 0
    $state = @{ previous = (Get-Stage9DatabaseFacts) }
    $stdout = $null; $stderr = $null; $didStart = $false
    try {
        [void] $process.Start()
        $didStart = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTime]::UtcNow.AddMinutes(40)
        while (-not $process.HasExited) {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Stage 9 Windows flow exceeded its bounded completion timeout.' }
            if ($next -lt $checkpointNames.Count) {
                $name = $checkpointNames[$next]
                $checkpointPath = Join-Path $evidenceRoot ("checkpoint-$name.json")
                if (Test-Path -LiteralPath $checkpointPath) {
                    $checkpoint = [IO.File]::ReadAllText($checkpointPath, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
                    if ([int] $checkpoint.version -ne 1 -or $checkpoint.checkpoint -cne $name) { throw 'Stage 9 UI checkpoint identity mismatch.' }
                    Test-Stage9UiCheckpoint -Context $context -Checkpoint $checkpoint -State $state
                    $ackPath = Join-Path $evidenceRoot ("checkpoint-$name.ack.json")
                    [IO.File]::WriteAllText(($ackPath + '.pending'), (@{ version = 1; checkpoint = $name; passed = $true } | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
                    Move-Item -LiteralPath ($ackPath + '.pending') -Destination $ackPath
                    Write-Host "Stage9Checkpoint: PASS $name"
                    $next++
                }
            }
            # Bounded polling of process/checkpoint conditions; elapsed time never implies success.
            Start-Sleep -Milliseconds 100
            $process.Refresh()
        }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            $diagnostics = Protect-Stage9Diagnostic ($stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()) @(Get-Stage9SecretForms)
            throw ('Stage 9 Windows UI process failed: ' + $diagnostics)
        }
        if ($next -ne $checkpointNames.Count) { throw 'Stage 9 Windows UI omitted mandatory DB checkpoints.' }
        Write-Host 'Stage9WindowsUiProcess: PASS exit_code=0'
        $ui = [IO.File]::ReadAllText((Join-Path $evidenceRoot 'ui-evidence.json'), [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
        if ([int] $ui.version -ne 1 -or (@($ui.checkpoints) -join ',') -cne ($checkpointNames -join ',') -or [int] $ui.keys_issued -ne 1 -or
            [string] $ui.grant_key -cne (New-Stage9Key 1) -or [int] $ui.file_saves -ne 1 -or [string] $ui.saved_sha256 -cne [string] $fixtures.Files['answer_pdf'].sha256) {
            throw 'integration-harness defect: Stage 9 UI evidence is incomplete.'
        }
        $ui
    }
    finally {
        if ($didStart -and -not $process.HasExited) {
            & taskkill.exe /PID ([string] $process.Id) /T /F *> $null
            $process.WaitForExit(10000) | Out-Null
        }
        $startInfo.EnvironmentVariables.Remove('STAGE9_E2E_PASSWORD')
        $stdout = $null; $stderr = $null
        $process.Dispose()
    }
}

$operationFailed = $false
$stateTouched = $false
$harnessLock = $null
try {
    $harnessLock = Enter-Stage9HarnessLock
    if (Test-Stage9ManualSmokePending) {
        throw ('environment/runtime defect: ' + (Get-Stage9ManualSmokePendingMessage))
    }
    Assert-Stage9RunnerPlan $plan
    Assert-Stage9FlutterExecutable
    $repositoryRoot = Split-Path -Parent $frontendRoot
    $checkout = Get-Stage9CheckoutState -Root $repositoryRoot
    Assert-Stage9AuditedCheckout $checkout
    $auditedSha = $checkout.Sha
    Write-Output "Stage9Run: sha=$auditedSha command=run_stage9_windows_e2e.ps1 ApiPort=$ApiPort plan=$($plan -join ',')"
    $password = Read-Stage9Password
    $apiTarget = Resolve-Stage9ApiTarget $apiBaseUrl

    Write-Output "Stage9Runtime: $(Initialize-Stage9Runtime -ApiTarget $apiTarget)"
    $runtime = Assert-Stage9DedicatedRuntime -ApiTarget $apiTarget
    Assert-Stage9ExclusiveDatabase -ClientAddress $runtime.ClientAddress
    Write-Output "Stage9RuntimeGuard: PASS workers=$($runtime.Workers) client=$($runtime.ClientAddress) exclusive_database=True"
    Complete-Stage9Step runtime_guard
    & (Join-Path $PSScriptRoot 'verify_stage9_runtime_guard.ps1') -ApiPort $ApiPort
    foreach ($verifier in @('verify_stage9_test_files.ps1', 'verify_stage9_oracle.ps1', 'verify_stage9_api_security.ps1')) { & (Join-Path $PSScriptRoot $verifier) }
    Complete-Stage9Step pure_verifiers
    $stateTouched = $true
    Invoke-Stage9Seeder ensureSentinels | Out-Null
    $sentinels = Get-Stage9SentinelFacts
    Write-Output 'Stage9UnrelatedSentinels: captured'
    Complete-Stage9Step sentinel_capture
    # Prior manifest state is removed on the real configured private disk; its oracle re-reads every prior id.
    $priorFacts = Get-Stage9DatabaseFacts
    $priorRows = 0; foreach ($property in $priorFacts.tables.PSObject.Properties) { $priorRows += @($property.Value).Count }
    $priorBlobs = @($priorFacts.blobs).Count
    Assert-Stage9CleanupDiskIdentity (Invoke-Stage9Seeder cleanupOwnedState)
    Complete-Stage9Step prior_manifest_cleanup
    Assert-Stage9CleanupFacts -Facts (Get-Stage9DatabaseFacts -PriorFacts $priorFacts) -SentinelsBefore $sentinels
    Write-Output "Stage9PriorManifestCleanup: PASS disk=local prior_rows_removed=$priorRows prior_blobs_removed=$priorBlobs"
    Complete-Stage9Step prior_cleanup_oracle
    & docker exec $runtime.ContainerName timeout --kill-after=10 900 php artisan test tests/Feature/Seeders/Stage9E2eSeederTest.php
    if ($LASTEXITCODE -ne 0) { throw 'Stage 9 focused seeder verification failed.' }
    Complete-Stage9Step seeder_test
    Invoke-Stage9Seeder run | Out-Null
    Complete-Stage9Step fresh_seed
    $baseline = Get-Stage9DatabaseFacts
    Assert-Stage9Baseline $baseline
    Assert-Stage9SentinelsUnchanged $sentinels $baseline.sentinels 'seeding'
    Write-Output 'Stage9BaselineOracle: PASS'
    Complete-Stage9Step baseline_oracle
    $fixtures = New-Stage9FixtureManifest -DestinationRoot (Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage9-fixtures-' + [guid]::NewGuid().ToString('N')))
    Assert-Stage9FixtureManifest $fixtures
    Complete-Stage9Step test_files
    $context = New-Stage9ApiContext -ApiBaseUrl $apiBaseUrl -Password $password -Manifest $baseline.manifest -FileManifest $fixtures
    Invoke-Stage9ApiSetup $context
    Complete-Stage9Step api_setup
    Invoke-Stage9ReviewTransportMatrix $context
    Complete-Stage9Step review_transport
    $scheduler = Invoke-Stage9ScheduledChecking $context -ClientAddress $runtime.ClientAddress
    Complete-Stage9Step scheduled_checking
    $evidenceRoot = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage9-evidence-' + [guid]::NewGuid().ToString('N'))
    [void] [IO.Directory]::CreateDirectory($evidenceRoot)
    $uiEvidence = @(Invoke-Stage9WindowsFlow -Baseline $baseline)[-1]
    Complete-Stage9Step windows_flow
    Invoke-Stage9TeacherFileDownload $context
    Invoke-Stage9TenantPrivacyMatrix $context
    Invoke-Stage9StudentResultsApi $context
    Complete-Stage9Step post_ui_api
    $postFlow = Get-Stage9DatabaseFacts
    Assert-Stage9TenantRows $postFlow
    Assert-Stage9SentinelsUnchanged $sentinels $postFlow.sentinels 'the automated flow'
    foreach ($key in $context.RejectedKeys) { Assert-Stage9NoIdempotencyRecord $postFlow $key }
    Write-Output 'Stage9PostFlowOracle: PASS'
    Complete-Stage9Step post_flow_oracle
    $readsBefore = Get-Stage9RestartReads $context
    & docker restart $runtime.ContainerName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Stage 9 backend restart failed.' }
    Wait-Stage9HttpBoundary -ApiTarget $apiTarget
    $runtime = Assert-Stage9DedicatedRuntime -ApiTarget $apiTarget
    Complete-Stage9Step restart
    $afterRestart = Get-Stage9DatabaseFacts
    Assert-Stage9Equal $afterRestart.tables $postFlow.tables 'DB state after backend restart'
    Assert-Stage9Equal $afterRestart.blobs $postFlow.blobs 'private files after backend restart'
    $readsAfter = Get-Stage9RestartReads $context
    foreach ($name in $readsBefore.Keys) { if ([string] $readsAfter[$name] -cne [string] $readsBefore[$name]) { throw "production defect: Stage 9 read changed across the backend restart: $name." } }
    Add-Stage9Evidence $context 'restart_persistence' ([pscustomobject] @{ reads = $readsBefore.Count })
    Complete-Stage9Step post_restart_oracle
    $evidence = [ordered] @{ sha = $auditedSha; api_port = $ApiPort; ui = $uiEvidence; runtime = $context.Runtime; scenarios = $context.Evidence; scheduler = $scheduler; rejected_keys = $context.RejectedKeys.Count }
    Close-Stage9ApiContext $context $false
    $context = $null
    $beforeCleanup = Get-Stage9DatabaseFacts
    Assert-Stage9CleanupDiskIdentity (Invoke-Stage9Seeder cleanupOwnedState)
    Complete-Stage9Step final_cleanup
    Assert-Stage9CleanupFacts -Facts (Get-Stage9DatabaseFacts -PriorFacts $beforeCleanup) -SentinelsBefore $sentinels
    Invoke-Stage9Seeder removeSentinels | Out-Null
    Write-Output 'Stage9FinalCleanup: PASS (manifest rows/blobs removed, unrelated sentinels unchanged then removed)'
    Complete-Stage9Step cleanup_oracle
    # Local generated files go before the PASS line, so a PASS never leaves them behind.
    Remove-Stage9FixtureManifest -Root $fixtures.Root
    $fixtures = $null
    Remove-Stage9LocalRoot -Root $evidenceRoot -Kind evidence
    $evidenceRoot = $null
    if (($executed -join ',') -cne ($plan -join ',')) { throw 'integration-harness defect: Stage 9 run did not execute the whole audited plan.' }
    Assert-Stage9ExclusiveDatabase -ClientAddress $runtime.ClientAddress
    Assert-Stage9AuditedCheckout $checkout (Get-Stage9CheckoutState -Root $repositoryRoot)
    $evidence.checkout_clean = $true
    $evidence.executed_steps = @($executed)
    $evidence.duration_seconds = [math]::Round(([DateTime]::UtcNow - $startedAt).TotalSeconds)
    $evidencePath = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage9-evidence-' + $auditedSha.Substring(0, 12) + '-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '.json')
    [IO.File]::WriteAllText($evidencePath, ($evidence | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    Write-Output "Stage9AutomatedEvidence: PASS duration_seconds=$($evidence.duration_seconds) steps=$($executed.Count) evidence=$evidencePath"
}
catch { $operationFailed = $true; throw }
finally {
    $cleanupErrors = [Collections.Generic.List[string]]::new()
    if ($null -ne $context) { try { Close-Stage9ApiContext $context $operationFailed } catch { $cleanupErrors.Add('Stage 9 API session cleanup failed.') } }
    try { if ($null -ne $fixtures) { Remove-Stage9FixtureManifest -Root $fixtures.Root } } catch { $cleanupErrors.Add('Stage 9 generated fixture cleanup failed.') }
    try { if ($null -ne $evidenceRoot) { Remove-Stage9LocalRoot -Root $evidenceRoot -Kind evidence } } catch { $cleanupErrors.Add('Stage 9 local evidence cleanup failed.') }
    $password = $null
    Exit-Stage9HarnessLock $harnessLock
    if ($cleanupErrors.Count -gt 0 -and -not $operationFailed) { throw ($cleanupErrors -join ' ') }
    if ($operationFailed -and $stateTouched) { Write-Output 'Stage9Run: FAILED; manifest-owned DB/private state is preserved for diagnosis and is removed by the next invocation.' }
    elseif ($operationFailed) { Write-Output 'Stage9Run: FAILED before any Stage 9 manifest state was changed.' }
}
