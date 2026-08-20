param(
    [Parameter(Mandatory = $true)]
    [string] $FlutterExecutable,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendContainerName = 'testlabuz-stage3-e2e-app'
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$runtimeGuardVerificationPath = Join-Path $PSScriptRoot 'verify_stage3_runtime_guard.ps1'
$testFile = Join-Path $PSScriptRoot 'stage3_institution_administration_flow_test.dart'
$frontendRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot 'stage3_runtime_guard.ps1')
. (Join-Path $PSScriptRoot 'stage3_oracle.ps1')

$apiTarget = Resolve-Stage3ApiTarget -ApiBaseUrl $apiBaseUrl
if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) {
    throw 'The requested Flutter executable does not exist.'
}
if (-not (Test-Path -LiteralPath $testFile -PathType Leaf)) {
    throw 'The Stage 3 Windows integration test does not exist.'
}

$sharedPassword = 'S03-Aa9-' + [guid]::NewGuid().ToString('N')
$firstLoginPassword = 'S03-Dd6-' + [guid]::NewGuid().ToString('N')
$initialUserPassword = 'S03-Bb8-' + [guid]::NewGuid().ToString('N')
$newUserPassword = 'S03-Cc7-' + [guid]::NewGuid().ToString('N')
$oraclePath = $null
$frozenUnrelatedSnapshotPath = $null

function Assert-LastCommandSucceeded {
    param([Parameter(Mandatory = $true)][string] $FailureMessage)

    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

function Wait-ForDedicatedBackend {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)

    do {
        try {
            $response = Invoke-WebRequest `
                -UseBasicParsing `
                -Headers @{ Accept = 'application/json' } `
                -Uri ($apiBaseUrl + '/auth/me') `
                -TimeoutSec 2

            if ([int] $response.StatusCode -eq 401) {
                return
            }
        }
        catch {
            if (
                $null -ne $_.Exception.Response -and
                [int] $_.Exception.Response.StatusCode -eq 401
            ) {
                return
            }
        }

        Start-Sleep -Milliseconds 500
    } until ([DateTime]::UtcNow -gt $deadline)

    throw 'The dedicated Stage 3 backend did not become HTTP-ready.'
}

function Invoke-GuardedSeeder {
    & docker exec `
        -e "STAGE3_E2E_PASSWORD=$sharedPassword" `
        -e "STAGE3_E2E_FIRST_LOGIN_PASSWORD=$firstLoginPassword" `
        -e "STAGE3_E2E_USER_INITIAL_PASSWORD=$initialUserPassword" `
        -e "STAGE3_E2E_USER_NEW_PASSWORD=$newUserPassword" `
        $backendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage3E2eSeeder `
        --force `
        --no-ansi

    Assert-LastCommandSucceeded 'The guarded Stage 3 E2E seeder failed.'
}

function Invoke-WindowsE2eTest {
    param([Parameter(Mandatory = $true)][string] $TestName)

    Push-Location $frontendRoot
    try {
        & $FlutterExecutable test `
            $testFile `
            -d windows `
            --plain-name $TestName `
            "--dart-define=API_BASE_URL=$apiBaseUrl" `
            "--dart-define=STAGE3_E2E_PASSWORD=$sharedPassword" `
            "--dart-define=STAGE3_E2E_FIRST_LOGIN_PASSWORD=$firstLoginPassword" `
            "--dart-define=STAGE3_E2E_USER_INITIAL_PASSWORD=$initialUserPassword" `
            "--dart-define=STAGE3_E2E_USER_NEW_PASSWORD=$newUserPassword" `
            "--dart-define=STAGE3_E2E_ORACLE_PATH=$oraclePath" `
            "--dart-define=STAGE3_E2E_BACKEND_CONTAINER=$backendContainerName"

        Assert-LastCommandSucceeded "Windows E2E failed: $TestName"
    }
    finally {
        Pop-Location
    }
}

function Assert-RestartedDatabaseState {
    $databaseAssertion = @'
throw_unless(app()->environment('testing'), 'Wrong persistence environment.');
throw_unless(DB::scalar('select current_database()') === 'testlabuz_testing', 'Wrong persistence database.');
throw_unless(DB::connection()->getDriverName() === 'pgsql', 'Wrong persistence driver.');
throw_unless(DB::table('institutions')->where('id', '03000000-0000-4000-8000-000000000101')->where('name', 'E2E S03 Target Institution Edited')->where('contact_email', 'edited-target@e2e-s03.invalid')->count() === 1, 'Profile mutation was not retained.');
throw_unless(DB::table('institutions')->where('id', '03000000-0000-4000-8000-000000000102')->where('name', 'E2E S03 Foreign Institution')->count() === 1, 'Foreign Institution changed.');
throw_unless(DB::table('users')->where('login_name', 'e2e_s03_created_teacher')->where('full_name', 'E2E S03 Created Teacher')->where('is_active', true)->where('must_change_password', false)->count() === 1, 'Created Teacher state was not retained.');
throw_unless(DB::table('users')->where('login_name', 'e2e_s03_created_student')->where('full_name', 'E2E S03 Created Student')->where('is_active', true)->where('must_change_password', false)->count() === 1, 'Created Student state was not retained.');
throw_unless(DB::table('users')->where('login_name', 'e2e_s03_created_parent')->where('full_name', 'E2E S03 Created Parent')->where('is_active', true)->where('must_change_password', false)->count() === 1, 'Created Parent state was not retained.');
throw_unless(DB::table('users')->where('id', '03000000-0000-4000-9000-000000000201')->where('full_name', 'E2E S03 Lifecycle Teacher Edited')->where('email', 'edited-lifecycle@e2e-s03.invalid')->whereNull('phone')->where('is_active', true)->where('must_change_password', false)->count() === 1, 'Lifecycle User state was not retained.');
throw_unless(DB::table('personal_access_tokens')->where('tokenable_id', '03000000-0000-4000-9000-000000000201')->whereIn('name', ['stage3-preservation-a', 'stage3-preservation-b'])->count() === 2, 'Seeded lifecycle token rows changed.');
throw_unless(DB::table('institution_settings')->where('institution_id', '03000000-0000-4000-8000-000000000101')->where('acceptable_score_difference', 12.5)->where('blitz_timer_start_mode', 'individual')->where('student_result_release_mode', 'manual_teacher')->where('parent_result_release_mode', 'hidden')->where('timezone', 'Europe/London')->where('learning_material_max_mb', 20)->where('student_submission_max_mb', 10)->count() === 1, 'Assessment settings mutation was not retained.');
throw_unless(DB::table('institution_understanding_categories')->where('institution_id', '03000000-0000-4000-8000-000000000101')->where('code', 'understood_well')->where('min_score', 91)->where('max_score', 100)->count() === 1, 'Category mutation was not retained.');
throw_unless(DB::table('institution_settings')->where('institution_id', '03000000-0000-4000-8000-000000000102')->where('acceptable_score_difference', 7)->where('timezone', 'Europe/London')->count() === 1, 'Foreign Institution settings changed.');
throw_unless(DB::table('institution_understanding_categories')->where('institution_id', '03000000-0000-4000-8000-000000000102')->where('code', 'understood_well')->where('min_score', 90)->where('max_score', 100)->count() === 1, 'Foreign categories changed.');
throw_unless(DB::table('users')->where('institution_id', '03000000-0000-4000-8000-000000000104')->whereIn('role', ['teacher', 'student', 'parent'])->count() === 0, 'All-zero Institution baseline changed.');
dump('Stage3DatabasePersistence: PASS');
'@

    & docker exec $backendContainerName `
        php artisan tinker `
        "--execute=$databaseAssertion"

    Assert-LastCommandSucceeded 'The restarted Stage 3 database assertions failed.'
}

function Remove-EphemeralOracle {
    if ([string]::IsNullOrWhiteSpace($oraclePath)) {
        return
    }
    if (-not (Test-Path -LiteralPath $oraclePath -PathType Leaf)) {
        return
    }

    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedOraclePath = [IO.Path]::GetFullPath($oraclePath)
    if (-not $resolvedOraclePath.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing to remove an oracle artifact outside the system temp directory.'
    }

    Remove-Item -LiteralPath $resolvedOraclePath -Force
}

function Remove-EphemeralLifecycleTokenSnapshots {
    $cleanupProgram = @'
<?php

$snapshotPaths = [
    '/tmp/testlabuz-stage3-token-active-to-inactive.snapshot',
    '/tmp/testlabuz-stage3-token-repeated-inactive.snapshot',
    '/tmp/testlabuz-stage3-token-inactive-to-active.snapshot',
    '/tmp/testlabuz-stage3-token-repeated-active.snapshot',
];

foreach ($snapshotPaths as $snapshotPath) {
    if (is_file($snapshotPath) && ! unlink($snapshotPath)) {
        throw new RuntimeException('Lifecycle token-row snapshot cleanup failed.');
    }
}

echo 'Stage3LifecycleTokenCleanupFallback: PASS';
'@

    $cleanupOutput = $cleanupProgram | & docker exec -i $backendContainerName php 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'The lifecycle token-row snapshot fallback cleanup failed.'
    }
    if (($cleanupOutput -join "`n").Trim() -cne 'Stage3LifecycleTokenCleanupFallback: PASS') {
        throw 'The lifecycle token-row snapshot fallback cleanup result was invalid.'
    }
}

try {
    $runtime = Assert-Stage3DedicatedRuntime -ApiTarget $apiTarget
    & $runtimeGuardVerificationPath -ApiPort $ApiPort
    Assert-LastCommandSucceeded 'The fail-closed Stage 3 runtime guard matrix failed.'
    Write-Output (
        'Stage3Safety: PASS ' +
        "environment=$($runtime.Environment) " +
        "database=$($runtime.Database) " +
        "driver=$($runtime.ConnectionDriver) " +
        "target=$($runtime.ApiBaseUrl) " +
        "postgres=$($runtime.PostgresContainerName) " +
        "network=$($runtime.DockerNetworkName)"
    )
    Wait-ForDedicatedBackend

    Invoke-GuardedSeeder
    Invoke-GuardedSeeder
    Write-Output 'Stage3Seeder: PASS (two consecutive guarded runs)'

    $oraclePath = Join-Path `
        ([IO.Path]::GetTempPath()) `
        ('testlabuz-stage3-oracle-' + [guid]::NewGuid().ToString('N') + '.json')
    New-Stage3OracleFile `
        -BackendContainerName $backendContainerName `
        -DestinationPath $oraclePath
    Write-Output 'Stage3IndependentOracle: PASS (guarded read-only PostgreSQL)'

    $frozenUnrelatedSnapshotPath = (
        '/tmp/testlabuz-stage3-frozen-' + [guid]::NewGuid().ToString('N') + '.snapshot'
    )
    Invoke-Stage3FrozenUnrelatedStateOracle `
        -Action Capture `
        -BackendContainerName $backendContainerName `
        -ContainerSnapshotPath $frozenUnrelatedSnapshotPath
    Write-Output 'Stage3FrozenUnrelatedStateBaseline: SAVED (deterministic full-row content)'

    Invoke-WindowsE2eTest `
        'Stage 3 institution administration flow uses the real Windows stack'
    Write-Output 'Stage3WindowsMutationE2E: PASS'
    Invoke-Stage3FrozenUnrelatedStateOracle `
        -Action Compare `
        -BackendContainerName $backendContainerName `
        -ContainerSnapshotPath $frozenUnrelatedSnapshotPath
    Write-Output 'Stage3FrozenUnrelatedStatePostRun: PASS (byte-for-byte content)'

    & docker stop $backendContainerName | Out-Null
    Assert-LastCommandSucceeded 'The dedicated Stage 3 backend stop failed.'
    & docker start $backendContainerName | Out-Null
    Assert-LastCommandSucceeded 'The dedicated Stage 3 backend restart failed.'
    Wait-ForDedicatedBackend
    Assert-Stage3DedicatedRuntime -ApiTarget $apiTarget | Out-Null
    Write-Output 'Stage3BackendRestart: PASS'

    Invoke-WindowsE2eTest `
        'Stage 3 state persists in a fresh Windows process after backend restart'
    Write-Output 'Stage3WindowsPersistenceE2E: PASS'
    Assert-RestartedDatabaseState
    Invoke-Stage3FrozenUnrelatedStateOracle `
        -Action Compare `
        -BackendContainerName $backendContainerName `
        -ContainerSnapshotPath $frozenUnrelatedSnapshotPath
    Write-Output 'Stage3FrozenUnrelatedStatePostRestart: PASS (byte-for-byte content)'
}
finally {
    Remove-EphemeralOracle

    $running = & docker inspect --format '{{.State.Running}}' $backendContainerName 2>$null
    if ($running -eq 'false') {
        & docker start $backendContainerName | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($frozenUnrelatedSnapshotPath)) {
        Invoke-Stage3FrozenUnrelatedStateOracle `
            -Action Remove `
            -BackendContainerName $backendContainerName `
            -ContainerSnapshotPath $frozenUnrelatedSnapshotPath
    }
    Remove-EphemeralLifecycleTokenSnapshots

    $sharedPassword = $null
    $firstLoginPassword = $null
    $initialUserPassword = $null
    $newUserPassword = $null
}
