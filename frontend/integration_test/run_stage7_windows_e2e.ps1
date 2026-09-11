param(
    [Parameter(Mandatory = $true)][string] $FlutterExecutable,
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage7_runtime_guard.ps1')
. (Join-Path $PSScriptRoot 'stage7_test_files.ps1')
. (Join-Path $PSScriptRoot 'stage7_oracle.ps1')
. (Join-Path $PSScriptRoot 'stage7_api_security.ps1')

# Project Owner runs only after delivered assets receive ChatGPT Harness Preflight PASS.
# Capture the final PSCredential object for manual smoke; it never prints the password.
# $credential = & .\run_stage7_windows_e2e.ps1 ... | Where-Object { $_ -is [pscredential] }
$frontendRoot = Split-Path -Parent $PSScriptRoot
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$backendContainerName = 'testlabuz-stage7-e2e-app'
$sharedPassword = $null
$manualCredential = $null
$fixtures = $null
$evidenceRoot = $null
$startedAt = [DateTime]::UtcNow

function Assert-Stage7FlutterExecutable {
    if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) { throw 'Stage 7 Flutter executable is absent.' }
    $pin = (Get-Content -LiteralPath (Join-Path $frontendRoot '.fvmrc') -Raw | ConvertFrom-Json).flutter
    $output = @(& $FlutterExecutable --version --machine 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Stage 7 Flutter version probe failed.' }
    try { $version = ($output -join "`n") | ConvertFrom-Json } catch { throw 'Invalid Flutter version response.' }
    if ([string]::IsNullOrWhiteSpace($pin) -or $version.frameworkVersion -cne $pin) { throw 'Stage 7 Flutter executable does not match .fvmrc.' }
}

function New-Stage7Password {
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = [byte[]]::new(32)
    try { $rng.GetBytes($bytes); return 'S07-Aa9!' + [Convert]::ToBase64String($bytes) }
    finally { [Array]::Clear($bytes, 0, $bytes.Length); $rng.Dispose() }
}

function Wait-Stage7Backend {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        try { Invoke-Stage7HttpBoundaryProbe -ApiTarget (Resolve-Stage7ApiTarget $apiBaseUrl); return }
        catch {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Stage 7 backend did not reach its exact HTTP boundary after restart.' }
            Start-Sleep -Milliseconds 250
        }
    } while ($true)
}

function Remove-Stage7UiEvidence {
    param([Parameter(Mandatory = $true)][string] $Root)
    $full = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if (-not [IO.Path]::GetDirectoryName($full).Equals($temp, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($full) -cnotmatch '\Atestlabuz-stage7-evidence-[a-f0-9]{32}\z') { throw 'Unsafe Stage 7 evidence cleanup root.' }
    if (-not (Test-Path -LiteralPath $full)) { return }
    if ((Get-Item -LiteralPath $full).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Stage 7 evidence root cannot be a link.' }
    foreach ($entry in @(Get-ChildItem -LiteralPath $full -Force)) {
        if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            $entry.Name -cnotmatch '\A(?:launcher\.ps1|(?:ui-evidence\.json|checkpoint-(?:first_start|fake_file_rejected|first_file_uploaded|file_replaced)(?:\.ack)?\.json)(?:\.pending)?|sink-open-[a-f0-9-]{36}\.pptx|sink-save-e2e_s07_replacement\.pptx)\z') {
            throw 'Unexpected Stage 7 evidence entry preserved; cleanup stopped.'
        }
        Remove-Item -LiteralPath $entry.FullName
    }
    [IO.Directory]::Delete($full, $false)
    if (Test-Path -LiteralPath $full) { throw 'Stage 7 local evidence cleanup failed.' }
}

function Invoke-Stage7WindowsFlow {
    param([Parameter(Mandatory = $true)][object] $Baseline)
    $launcher = @'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
& $env:STAGE7_E2E_FLUTTER_EXECUTABLE test integration_test/stage7_student_homework_flow_test.dart -d windows --no-pub "--dart-define=API_BASE_URL=$env:STAGE7_E2E_API_BASE_URL"
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
    $startInfo.EnvironmentVariables['STAGE7_E2E_PASSWORD'] = $sharedPassword
    $startInfo.EnvironmentVariables['STAGE7_E2E_FLUTTER_EXECUTABLE'] = [IO.Path]::GetFullPath($FlutterExecutable)
    $startInfo.EnvironmentVariables['STAGE7_E2E_API_BASE_URL'] = $apiBaseUrl
    $startInfo.EnvironmentVariables['STAGE7_E2E_FIXTURE_MANIFEST_PATH'] = $fixtures.ManifestPath
    $startInfo.EnvironmentVariables['STAGE7_E2E_UI_EVIDENCE_PATH'] = (Join-Path $evidenceRoot 'ui-evidence.json')
    $startInfo.EnvironmentVariables['STAGE7_E2E_MODE'] = 'main'
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $snapshots = @{}
    $names = @('first_start', 'fake_file_rejected', 'first_file_uploaded', 'file_replaced')
    $next = 0
    $stdout = $null; $stderr = $null
    $didStart = $false
    try {
        [void] $process.Start()
        $didStart = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTime]::UtcNow.AddMinutes(20)
        while (-not $process.HasExited) {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Stage 7 Windows flow exceeded its bounded completion timeout.' }
            if ($next -lt $names.Count) {
                $name = $names[$next]
                $checkpointPath = Join-Path $evidenceRoot ("checkpoint-$name.json")
                if (Test-Path -LiteralPath $checkpointPath) {
                    $checkpoint = Get-Content -LiteralPath $checkpointPath -Raw | ConvertFrom-Json
                    if ($checkpoint.version -ne 1 -or $checkpoint.checkpoint -cne $name) { throw 'Stage 7 UI checkpoint identity mismatch.' }
                    $facts = Get-Stage7DatabaseFacts -BackendContainerName $backendContainerName
                    $prior = if ($snapshots.ContainsKey('first_file_uploaded')) { $snapshots['first_file_uploaded'] } else { $null }
                    Assert-Stage7UiCheckpoint -Checkpoint $checkpoint -Facts $facts -Baseline $Baseline -PriorCheckpointFacts $prior -FileManifest $fixtures
                    $snapshots[$name] = $facts
                    $ack = @{ version = 1; checkpoint = $name; passed = $true } | ConvertTo-Json -Compress
                    $ackPath = Join-Path $evidenceRoot ("checkpoint-$name.ack.json")
                    [IO.File]::WriteAllText(($ackPath + '.pending'), $ack, [Text.UTF8Encoding]::new($false))
                    Move-Item -LiteralPath ($ackPath + '.pending') -Destination $ackPath
                    Write-Output "Stage7Checkpoint: PASS $name"
                    $next++
                }
            }
            # Poll bounded process/checkpoint conditions; elapsed time never implies success.
            Start-Sleep -Milliseconds 100
            $process.Refresh()
        }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            # Keep all raw child diagnostics in memory and never expose entered credentials.
            $diagnostics = ($stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()).Replace($sharedPassword, '[redacted]')
            $diagnostics = $diagnostics -replace '(?i)Bearer\s+\S+', 'Bearer [redacted]' -replace '\b[0-9]+\|[A-Za-z0-9]{20,}', '[redacted-token]'
            throw ('Stage 7 Windows UI process failed: ' + $diagnostics)
        }
        if ($next -ne $names.Count) { throw 'Stage 7 Windows UI omitted mandatory DB checkpoints.' }
        Write-Host 'Stage7WindowsUiProcess: PASS exit_code=0'
        $uiEvidence = Get-Content -LiteralPath (Join-Path $evidenceRoot 'ui-evidence.json') -Raw | ConvertFrom-Json
        return [pscustomobject] @{ UiEvidence = $uiEvidence; UiSnapshots = $snapshots }
    }
    finally {
        if ($didStart -and -not $process.HasExited) {
            & taskkill.exe /PID ([string] $process.Id) /T /F *> $null
            $process.WaitForExit(10000) | Out-Null
        }
        $startInfo.EnvironmentVariables.Remove('STAGE7_E2E_PASSWORD')
        $stdout = $null; $stderr = $null
        $diagnostics = $null
        $process.Dispose()
    }
}

try {
    Assert-Stage7FlutterExecutable
    $auditedSha = (& git -C (Split-Path -Parent $frontendRoot) rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $auditedSha -cnotmatch '\A[a-f0-9]{40}\z') { throw 'Stage 7 runner could not record the audited Git SHA.' }
    Write-Output "Stage7Run: sha=$auditedSha command=run_stage7_windows_e2e.ps1 FlutterExecutable=$FlutterExecutable ApiPort=$ApiPort"
    $apiTarget = Resolve-Stage7ApiTarget $apiBaseUrl
    Assert-Stage7DedicatedRuntime -ApiTarget $apiTarget | Out-Null
    & (Join-Path $PSScriptRoot 'verify_stage7_runtime_guard.ps1') -ApiPort $ApiPort
    & (Join-Path $PSScriptRoot 'verify_stage7_test_files.ps1')
    & (Join-Path $PSScriptRoot 'verify_stage7_oracle.ps1')
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage7-fixtures-' + [guid]::NewGuid().ToString('N'))
    $fixtures = New-Stage7FixtureManifest -DestinationRoot $fixtureRoot
    Assert-Stage7FixtureManifest $fixtures
    $sharedPassword = New-Stage7Password
    # A full invocation/retry cleans the whole prior manifest before transactional
    # seeder tests. No lifecycle scenario can reset or reseed after the baseline.
    $cleanupProgram = @'
try {
    putenv('STAGE7_E2E_PASSWORD='.$stage7Input['password']);
    (new Database\Seeders\Stage7E2eSeeder)->cleanupOwnedState();
    echo json_encode(['cleaned' => true], JSON_THROW_ON_ERROR);
} finally { putenv('STAGE7_E2E_PASSWORD'); unset($stage7Input['password']); }
'@
    $cleaned = Invoke-Stage7ContainerPhp -Program $cleanupProgram -InputJson (@{ password = $sharedPassword } | ConvertTo-Json -Compress)
    if ($cleaned.cleaned -ne $true) { throw 'Stage 7 prior full-manifest cleanup was not confirmed.' }
    & docker exec $backendContainerName php artisan test tests/Feature/Seeders/Stage7E2eSeederTest.php
    if ($LASTEXITCODE -ne 0) { throw 'Stage 7 focused seeder verification failed.' }
    $seedProgram = @'
try {
    putenv('STAGE7_E2E_PASSWORD='.$stage7Input['password']);
    (new Database\Seeders\Stage7E2eSeeder)->run();
    echo json_encode(['seeded' => true], JSON_THROW_ON_ERROR);
} finally { putenv('STAGE7_E2E_PASSWORD'); unset($stage7Input['password']); }
'@
    $seed = Invoke-Stage7ContainerPhp -Program $seedProgram -InputJson (@{ password = $sharedPassword } | ConvertTo-Json -Compress)
    if ($seed.seeded -ne $true) { throw 'Stage 7 baseline seeding was not confirmed.' }
    $baseline = Get-Stage7DatabaseFacts -BackendContainerName $backendContainerName
    Assert-Stage7DatabaseFacts -Facts $baseline -Mode Baseline
    Write-Output 'Stage7BaselineOracle: PASS'
    & (Join-Path $PSScriptRoot 'verify_stage7_api_security.ps1')
    # This helper performs exact Attempt GET -> due close -> future close -> guarded scheduler twice.
    $lifecycle = Invoke-Stage7LifecycleRequests -ApiBaseUrl $apiBaseUrl -Password $sharedPassword -Baseline $baseline
    Assert-Stage7DatabaseFacts -Facts $lifecycle -Mode Lifecycle -Baseline $baseline
    Write-Output 'Stage7PreUiLifecycleOracle: PASS'

    $evidenceRoot = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage7-evidence-' + [guid]::NewGuid().ToString('N'))
    [void] [IO.Directory]::CreateDirectory($evidenceRoot)
    $flowOutput = @(Invoke-Stage7WindowsFlow -Baseline $baseline)
    $flow = $flowOutput[-1]
    $main = Get-Stage7DatabaseFacts -BackendContainerName $backendContainerName
    Assert-Stage7DatabaseFacts -Facts $main -Mode MainFlow -Baseline $baseline -UiEvidence $flow.UiEvidence -UiSnapshots $flow.UiSnapshots -FileManifest $fixtures
    Write-Output 'Stage7MainFlowOracle: PASS'
    $apiEvidence = Invoke-Stage7ApiSecurityMatrix -ApiBaseUrl $apiBaseUrl -Password $sharedPassword -Baseline $baseline -FileManifest $fixtures -UiEvidence $flow.UiEvidence
    $beforeRestart = Get-Stage7DatabaseFacts -BackendContainerName $backendContainerName
    Assert-Stage7DatabaseFacts -Facts $beforeRestart -Mode Automated -Baseline $baseline -UiEvidence $flow.UiEvidence -UiSnapshots $flow.UiSnapshots -FileManifest $fixtures -ApiEvidence $apiEvidence
    & docker restart $backendContainerName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Stage 7 backend restart failed.' }
    Wait-Stage7Backend
    Assert-Stage7DedicatedRuntime -ApiTarget $apiTarget | Out-Null
    $afterRestart = Get-Stage7DatabaseFacts -BackendContainerName $backendContainerName
    Assert-Stage7RestartPersistence -Before $beforeRestart -After $afterRestart
    Invoke-Stage7PostRestartRead -ApiBaseUrl $apiBaseUrl -Password $sharedPassword -Facts $afterRestart -FileManifest $fixtures
    $finalFacts = Get-Stage7DatabaseFacts -BackendContainerName $backendContainerName
    Assert-Stage7RestartPersistence -Before $afterRestart -After $finalFacts
    Assert-Stage7DatabaseFacts -Facts $finalFacts -Mode Automated -Baseline $baseline -UiEvidence $flow.UiEvidence -UiSnapshots $flow.UiSnapshots -FileManifest $fixtures -ApiEvidence $apiEvidence
    Assert-Stage7DatabaseFacts -Facts $finalFacts -Mode ManualReady
    Write-Output ('Stage7AutomatedEvidence: PASS duration_seconds=' + [math]::Round(([DateTime]::UtcNow - $startedAt).TotalSeconds))
    $manualCredential = [pscredential]::new('e2e_s07_student', (ConvertTo-SecureString $sharedPassword -AsPlainText -Force))
}
finally {
    $cleanupErrors = [Collections.Generic.List[string]]::new()
    try { if ($null -ne $fixtures) { Remove-Stage7FixtureManifest -Root $fixtures.Root } } catch { $cleanupErrors.Add('Stage 7 generated fixture cleanup failed.') }
    try { if ($null -ne $evidenceRoot) { Remove-Stage7UiEvidence -Root $evidenceRoot } } catch { $cleanupErrors.Add('Stage 7 generated evidence cleanup failed.') }
    $sharedPassword = $null
    if ($cleanupErrors.Count -gt 0) { throw ($cleanupErrors -join ' ') }
    Write-Output 'Stage7LocalCleanup: PASS; DB/private fixtures preserved for required manual smoke.'
}
Write-Output -NoEnumerate $manualCredential
