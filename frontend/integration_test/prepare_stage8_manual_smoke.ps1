param(
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort,
    [switch] $CompleteManualSmokeAndCleanup,
    [switch] $AbandonManualSmoke,
    [string] $AndroidDevice
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage8_oracle.ps1')

# The Project Owner performs Sections 78-80 by hand; this script prepares and later judges that state.
# STAGE8_E2E_PASSWORD comes from the process or Windows user environment and is never printed.
$password = [Environment]::GetEnvironmentVariable('STAGE8_E2E_PASSWORD', 'Process')
if ([string]::IsNullOrWhiteSpace($password)) { $password = [Environment]::GetEnvironmentVariable('STAGE8_E2E_PASSWORD', 'User') }
if ([string]::IsNullOrWhiteSpace($password) -or $password.Trim().Length -lt 16) { throw 'STAGE8_E2E_PASSWORD must be set (at least 16 characters).' }

function Invoke-Stage8ManualSeeder {
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
    Invoke-Stage8ContainerPhp -Program $program -InputJson (@{ password = $password; operation = $Operation } | ConvertTo-Json -Compress)
}

# Android smoke outcome: mobile Activate, then one Student Start/save/Submit with an unanswered Question.
function Assert-Stage8ManualSmoke {
    param($Facts)
    $m = $Facts.manifest
    $blitz = Get-Stage8Row $Facts blitz_tasks $m.assessments.android assessment_id
    Assert-Stage8BlitzLifecycle $blitz active synchronized 1800
    if ($blitz.activated_by_user_id -cne $m.users.teacher) { throw 'production defect: The Android Blitz was not activated by the Teacher.' }
    Assert-Stage8Recipients $Facts $m.assessments.android @([string] $m.users.android_student) 'Android cohort'
    $history = Assert-Stage8AttemptHistory $Facts $m.assessments.android ([string] $m.users.android_student)
    if ($history.Attempts.Count -ne 1) { throw 'production defect: Android smoke requires exactly one Attempt.' }
    $attempt = $history.Attempts[0]
    Assert-Stage8TerminalAttempt $attempt student_submit ([string] $attempt.submitted_at)
    $answers = @(Get-Stage8Rows $Facts attempt_answers attempt_id $attempt.id)
    # Three Questions: at least one saved answer and at least one left unanswered.
    if ($answers.Count -lt 1 -or $answers.Count -gt 2) {
        throw 'production defect: Android smoke must save at least one answer and submit with an unanswered Question.'
    }
    Assert-Stage8AnswerSet $Facts $attempt.id @($answers | ForEach-Object { [string] $_.question_id }) | Out-Null
    Assert-Stage8NoStageNineScoring $Facts
    $activation = @($Facts.tables.idempotency_records | Where-Object { $_.operation -ceq 'teacher.blitz.activate' -and $_.result_resource_id -ceq $m.assessments.android })
    if ($activation.Count -ne 1) { throw 'production defect: The mobile activation left no single completed activation result.' }
}

if ($CompleteManualSmokeAndCleanup -and $AbandonManualSmoke) { throw 'Choose either -CompleteManualSmokeAndCleanup or -AbandonManualSmoke.' }
# Completion always removes the temporary adb reverse mapping, so the device serial is required there.
if ($CompleteManualSmokeAndCleanup -and $AndroidDevice -cnotmatch '\A[A-Za-z0-9._:-]{1,128}\z') { throw 'Completion needs -AndroidDevice <serial> (letters, digits, dot, colon, dash, underscore).' }
$apiTarget = Resolve-Stage8ApiTarget -ApiBaseUrl "http://127.0.0.1:$ApiPort/api/v1"
$harnessLock = $null
try {
    $harnessLock = Enter-Stage8HarnessLock
    $runtime = Assert-Stage8DedicatedRuntime -ApiTarget $apiTarget
    Assert-Stage8ExclusiveDatabase -ClientAddress $runtime.ClientAddress
    if ($AbandonManualSmoke) {
        # A failed or unfinished smoke is withdrawn without a PASS; its state is removed and verified the same way.
        if (-not (Test-Stage8ManualSmokePending)) { throw "No prepared Android manual smoke is pending (marker $script:Stage8ManualSmokeMarker)." }
        $sentinels = Get-Stage8SentinelFacts
        $facts = Get-Stage8DatabaseFacts
        Assert-Stage8CleanupDiskIdentity (Invoke-Stage8ManualSeeder cleanupOwnedState)
        Assert-Stage8CleanupFacts -Facts (Get-Stage8DatabaseFacts -PriorFacts $facts) -SentinelsBefore $sentinels
        Invoke-Stage8ManualSeeder removeSentinels | Out-Null
        Remove-Item -LiteralPath $script:Stage8ManualSmokeMarker
        Write-Output 'Stage8ManualSmoke: ABANDONED (no PASS; manifest rows/blobs removed, unrelated sentinels unchanged then removed; remove any adb reverse mapping by hand)'
        return
    }
    if ($CompleteManualSmokeAndCleanup) {
        if (-not (Test-Stage8ManualSmokePending)) { throw "No prepared Android manual smoke is pending (marker $script:Stage8ManualSmokeMarker); run the preparation first." }
        $sentinels = Get-Stage8SentinelFacts
        $facts = Get-Stage8DatabaseFacts
        Assert-Stage8ManualSmoke $facts
        Write-Output 'Stage8ManualSmokeOracle: PASS'
        Assert-Stage8CleanupDiskIdentity (Invoke-Stage8ManualSeeder cleanupOwnedState)
        Assert-Stage8CleanupFacts -Facts (Get-Stage8DatabaseFacts -PriorFacts $facts) -SentinelsBefore $sentinels
        Invoke-Stage8ManualSeeder removeSentinels | Out-Null
        # The state is gone, so the marker goes before any device step that could still fail.
        Remove-Item -LiteralPath $script:Stage8ManualSmokeMarker
        & adb -s $AndroidDevice reverse --remove "tcp:$ApiPort" | Out-Null
        $remaining = @(& adb -s $AndroidDevice reverse --list 2>$null | Where-Object { $_ -match "tcp:$ApiPort\b" })
        if ($LASTEXITCODE -ne 0 -or $remaining.Count -ne 0) { throw 'The temporary Android reverse mapping could not be confirmed removed; the DB cleanup already passed, remove it with adb reverse --remove.' }
        Write-Output 'Stage8AndroidReverse: removed'
        Write-Output 'Stage8ManualSmokeCleanup: PASS (manifest rows/blobs removed, unrelated sentinels unchanged then removed)'
        return
    }
    if (Test-Stage8ManualSmokePending) { throw (Get-Stage8ManualSmokePendingMessage) }
    Invoke-Stage8ManualSeeder ensureSentinels | Out-Null
    $sentinels = Get-Stage8SentinelFacts
    $priorFacts = Get-Stage8DatabaseFacts
    Assert-Stage8CleanupDiskIdentity (Invoke-Stage8ManualSeeder cleanupOwnedState)
    Assert-Stage8CleanupFacts -Facts (Get-Stage8DatabaseFacts -PriorFacts $priorFacts) -SentinelsBefore $sentinels
    Invoke-Stage8ManualSeeder run | Out-Null
    $facts = Get-Stage8DatabaseFacts
    Assert-Stage8Baseline $facts
    # Until completion removes it, the marker stops the runner and a second preparation from reseeding this state.
    [IO.File]::WriteAllText($script:Stage8ManualSmokeMarker, [DateTime]::UtcNow.ToString('o'), [Text.UTF8Encoding]::new($false))
    Write-Output 'Stage8ManualReady: PASS'
    Write-Output "API: http://127.0.0.1:$ApiPort/api/v1 (run: adb reverse tcp:$ApiPort tcp:$ApiPort)"
    Write-Output "App: frontend> .\.fvm\flutter_sdk\bin\flutter run -d <android-device> --dart-define=API_BASE_URL=http://127.0.0.1:$ApiPort/api/v1"
    Write-Output 'Password: the value of STAGE8_E2E_PASSWORD you set; it is not printed.'
    Write-Output 'Teacher (e2e_s08_teacher), Topic "E2E S08 Android Topic", Blitz "E2E S08 Android Blitz":'
    Write-Output '  1. The Blitz detail shows no Edit, Manage Questions, Schedule, Official designation, Archive or Close.'
    Write-Output '  2. Press Activate and confirm; the detail shows Active.'
    Write-Output '  3. Press Monitor; the Student card shows, without reason, Grant, score or answer/file content. Go back.'
    Write-Output 'Student (e2e_s08_android_student):'
    Write-Output '  4. The Active Blitz is in the workspace; its detail shows no Questions before Start.'
    Write-Output '  5. Start; the countdown decreases. Answer one Question (single choice or short written) and save.'
    Write-Output '  6. Leave and reopen the Blitz; Resume keeps the same remaining time.'
    Write-Output '  7. Submit with the open written Question unanswered; the summary shows Submitted and no score.'
    Write-Output "Then run: .\prepare_stage8_manual_smoke.ps1 -ApiPort $ApiPort -CompleteManualSmokeAndCleanup -AndroidDevice <serial>"
    Write-Output "If the smoke cannot be finished: .\prepare_stage8_manual_smoke.ps1 -ApiPort $ApiPort -AbandonManualSmoke"
}
finally { $password = $null; Exit-Stage8HarnessLock $harnessLock }
