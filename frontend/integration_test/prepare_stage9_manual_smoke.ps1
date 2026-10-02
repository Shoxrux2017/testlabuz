param(
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort,
    [switch] $CompleteManualSmokeAndCleanup,
    [switch] $AbandonManualSmoke,
    [string] $AndroidDevice,
    [string] $AdbExecutable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage9_api_scenarios.ps1')

# The Project Owner performs the contract section 12 checklist by hand; this script prepares and later judges that state.
# STAGE9_E2E_PASSWORD comes from the process or Windows user environment and is never printed.
$password = [Environment]::GetEnvironmentVariable('STAGE9_E2E_PASSWORD', 'Process')
if ([string]::IsNullOrWhiteSpace($password)) { $password = [Environment]::GetEnvironmentVariable('STAGE9_E2E_PASSWORD', 'User') }
if ([string]::IsNullOrWhiteSpace($password) -or $password.Trim().Length -lt 16) { throw 'environment/runtime defect: STAGE9_E2E_PASSWORD must be set (at least 16 characters).' }

function Invoke-Stage9ManualSeeder {
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
    Invoke-Stage9ContainerPhp -Program $program -InputJson (@{ password = $password; operation = $Operation } | ConvertTo-Json -Compress)
}

function Get-Stage9SentinelHash {
    param($Sentinels)
    $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Sentinels -Depth 60 -Compress))
    $hash = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $hash.Dispose() }
}

function Resolve-Stage9Adb {
    if ($AdbExecutable) { if (Test-Path -LiteralPath $AdbExecutable -PathType Leaf) { return $AdbExecutable }; throw 'environment/runtime defect: The given -AdbExecutable does not exist.' }
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    $default = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (Test-Path -LiteralPath $default -PathType Leaf) { return $default }
    throw 'environment/runtime defect: adb was not found; pass -AdbExecutable <path to adb.exe>.'
}

function Read-Stage9ManualState {
    try { $state = [IO.File]::ReadAllText($script:Stage9ManualSmokeMarker, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json }
    catch { throw "environment/runtime defect: The manual-smoke marker $script:Stage9ManualSmokeMarker is unreadable; withdraw the smoke with -AbandonManualSmoke." }
    if ([string] $state.sentinels_sha256 -cnotmatch '\A[0-9a-f]{64}\z') { throw "environment/runtime defect: The manual-smoke marker lacks the sentinel hash; withdraw the smoke with -AbandonManualSmoke." }
    foreach ($name in @('homework', 'classmate', 'blitz')) {
        if ([string] $state.$name -cnotmatch '\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z') { throw "environment/runtime defect: The manual-smoke marker lacks the $name Attempt; withdraw the smoke with -AbandonManualSmoke." }
    }
    $state
}

if ($CompleteManualSmokeAndCleanup -and $AbandonManualSmoke) { throw 'environment/runtime defect: Choose either -CompleteManualSmokeAndCleanup or -AbandonManualSmoke.' }
# Completion always removes the temporary adb reverse mapping, so the device serial is required there.
if ($CompleteManualSmokeAndCleanup -and $AndroidDevice -cnotmatch '\A[A-Za-z0-9._:-]{1,128}\z') { throw 'environment/runtime defect: Completion needs -AndroidDevice <serial> (letters, digits, dot, colon, dash, underscore).' }
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$apiTarget = Resolve-Stage9ApiTarget -ApiBaseUrl $apiBaseUrl
$harnessLock = $null
$context = $null
$operationFailed = $false
try {
    $harnessLock = Enter-Stage9HarnessLock
    $runtime = Assert-Stage9DedicatedRuntime -ApiTarget $apiTarget
    Assert-Stage9ExclusiveDatabase -ClientAddress $runtime.ClientAddress
    if ($AbandonManualSmoke) {
        # A failed or unfinished smoke is withdrawn without a PASS; its state is removed and verified the same way.
        if (-not (Test-Stage9ManualSmokePending)) { throw "environment/runtime defect: No prepared Android manual smoke is pending (marker $script:Stage9ManualSmokeMarker)." }
        $sentinels = Get-Stage9SentinelFacts
        $facts = Get-Stage9DatabaseFacts
        Assert-Stage9CleanupDiskIdentity (Invoke-Stage9ManualSeeder cleanupOwnedState)
        Assert-Stage9CleanupFacts -Facts (Get-Stage9DatabaseFacts -PriorFacts $facts) -SentinelsBefore $sentinels
        Invoke-Stage9ManualSeeder removeSentinels | Out-Null
        Remove-Item -LiteralPath $script:Stage9ManualSmokeMarker
        Write-Output 'Stage9ManualSmoke: ABANDONED (no PASS; manifest rows/blobs removed, unrelated sentinels unchanged then removed; remove any adb reverse mapping by hand)'
        return
    }
    if ($CompleteManualSmokeAndCleanup) {
        if (-not (Test-Stage9ManualSmokePending)) { throw "environment/runtime defect: No prepared Android manual smoke is pending (marker $script:Stage9ManualSmokeMarker); run the preparation first." }
        $adb = Resolve-Stage9Adb
        $state = Read-Stage9ManualState
        $sentinels = Get-Stage9SentinelFacts
        # The sentinels must still be exactly as they were when the smoke was prepared.
        if ((Get-Stage9SentinelHash $sentinels) -cne [string] $state.sentinels_sha256) { throw 'production defect: the unrelated sentinels changed while the Android smoke was pending.' }
        $facts = Get-Stage9DatabaseFacts
        # The smoke only reads: the prepared Android state must be exactly as left by the preparation.
        Assert-Stage9AndroidState $facts $state
        Assert-Stage9TenantRows $facts
        Write-Output 'Stage9ManualSmokeOracle: PASS'
        Assert-Stage9CleanupDiskIdentity (Invoke-Stage9ManualSeeder cleanupOwnedState)
        Assert-Stage9CleanupFacts -Facts (Get-Stage9DatabaseFacts -PriorFacts $facts) -SentinelsBefore $sentinels
        Invoke-Stage9ManualSeeder removeSentinels | Out-Null
        # The state is gone, so the marker goes before any device step that could still fail.
        Remove-Item -LiteralPath $script:Stage9ManualSmokeMarker
        & $adb -s $AndroidDevice reverse --remove "tcp:$ApiPort" | Out-Null
        $remaining = @(& $adb -s $AndroidDevice reverse --list 2>$null | Where-Object { $_ -match "tcp:$ApiPort\b" })
        if ($LASTEXITCODE -ne 0 -or $remaining.Count -ne 0) { throw 'environment/runtime defect: The temporary Android reverse mapping could not be confirmed removed; the DB cleanup already passed, remove it with adb reverse --remove.' }
        Write-Output 'Stage9AndroidReverse: removed'
        Write-Output 'Stage9ManualSmokeCleanup: PASS (manifest rows/blobs removed, unrelated sentinels unchanged then removed)'
        return
    }
    if (Test-Stage9ManualSmokePending) { throw (Get-Stage9ManualSmokePendingMessage) }
    Invoke-Stage9ManualSeeder ensureSentinels | Out-Null
    $sentinels = Get-Stage9SentinelFacts
    $priorFacts = Get-Stage9DatabaseFacts
    Assert-Stage9CleanupDiskIdentity (Invoke-Stage9ManualSeeder cleanupOwnedState)
    Assert-Stage9CleanupFacts -Facts (Get-Stage9DatabaseFacts -PriorFacts $priorFacts) -SentinelsBefore $sentinels
    Invoke-Stage9ManualSeeder run | Out-Null
    $baseline = Get-Stage9DatabaseFacts
    Assert-Stage9Baseline $baseline
    $context = New-Stage9ApiContext -ApiBaseUrl $apiBaseUrl -Password $password -Manifest $baseline.manifest -FileManifest $null
    $state = Invoke-Stage9AndroidSetup $context
    Close-Stage9ApiContext $context $false
    $context = $null
    Assert-Stage9SentinelsUnchanged $sentinels (Get-Stage9SentinelFacts) 'the Android preparation' -Class 'integration-harness defect'
    # Until completion removes it, the marker stops the runner and a second preparation from reseeding this state.
    $marker = [ordered] @{ prepared_at = [DateTime]::UtcNow.ToString('o'); homework = $state.homework; classmate = $state.classmate; blitz = $state.blitz; sentinels_sha256 = (Get-Stage9SentinelHash (Get-Stage9SentinelFacts)) }
    [IO.File]::WriteAllText($script:Stage9ManualSmokeMarker, ($marker | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
    Write-Output 'Stage9ManualReady: PASS'
    Write-Output "API: $apiBaseUrl"
    Write-Output "Build: frontend> .\.fvm\flutter_sdk\bin\flutter build apk --debug --dart-define=API_BASE_URL=$apiBaseUrl"
    Write-Output "Install: adb -s <serial> install -r frontend\build\app\outputs\flutter-apk\app-debug.apk ; adb -s <serial> reverse tcp:$ApiPort tcp:$ApiPort"
    Write-Output 'Password: the value of STAGE9_E2E_PASSWORD you set; it is not printed.'
    Write-Output 'Student (e2e_s09_android_student):'
    Write-Output '  1. Workspace: Finished Blitz shows "E2E S09 Android Blitz" with "Score 75.0" and "Question 2: Android Blitz feedback."'
    Write-Output '  2. Topic "E2E S09 Android Topic": the Homework card shows "Official score: 90.0".'
    $dot = [char] 0x00B7
    Write-Output "  3. Homework detail, Results: `"Official score: 90.0 (Attempt 1)`" and `"Attempt 1 $dot Checked $dot Score 90.0`".
    Write-Output '  4. "Open attempt 1": "Teacher feedback" with "Android feedback." under Question 2; no correct answers are shown.'
    Write-Output 'Teacher (e2e_s09_teacher):'
    Write-Output '  5. The workspace shows no "Review queue" button.'
    Write-Output '  6. Topic "E2E S09 Android Topic", Homework "E2E S09 Android Hw": the Review card shows "Waiting for review: 1" and "Overdue: 1", and no "Open review queue" button.'
    Write-Output "Then run: .\prepare_stage9_manual_smoke.ps1 -ApiPort $ApiPort -CompleteManualSmokeAndCleanup -AndroidDevice <serial>"
    Write-Output "If the smoke cannot be finished: .\prepare_stage9_manual_smoke.ps1 -ApiPort $ApiPort -AbandonManualSmoke"
}
catch { $operationFailed = $true; throw }
finally {
    if ($null -ne $context) { try { Close-Stage9ApiContext $context $operationFailed } catch { Write-Warning 'Stage 9 API session cleanup failed.' } }
    $password = $null
    Exit-Stage9HarnessLock $harnessLock
}
