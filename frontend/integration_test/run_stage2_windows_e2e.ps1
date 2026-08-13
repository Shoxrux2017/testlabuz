param(
    [Parameter(Mandatory = $true)]
    [string] $FlutterExecutable,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendContainerName = 'testlabuz-stage2-e2e-app'
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$runtimeGuardPath = Join-Path $PSScriptRoot 'stage2_runtime_guard.ps1'
$runtimeGuardVerificationPath = Join-Path `
    $PSScriptRoot `
    'verify_stage2_runtime_guard.ps1'
$oracleSupportPath = Join-Path $PSScriptRoot 'stage2_oracle.ps1'

. $runtimeGuardPath
. $oracleSupportPath

$apiTarget = Resolve-Stage2ApiTarget -ApiBaseUrl $apiBaseUrl

if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) {
    throw 'The requested Flutter executable does not exist.'
}

$sharedPassword = 'S02-Aa9-' + [guid]::NewGuid().ToString('N')
$initialAdminPassword = 'S02-Bb8-' + [guid]::NewGuid().ToString('N')
$newAdminPassword = 'S02-Cc7-' + [guid]::NewGuid().ToString('N')
$testFile = Join-Path $PSScriptRoot 'stage2_platform_management_flow_test.dart'

function Assert-LastCommandSucceeded {
    param([string] $FailureMessage)

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

            if ($null -ne $response) {
                if ([int] $response.StatusCode -eq 401) {
                    return
                }
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

    throw 'The dedicated Stage 2 backend did not become HTTP-ready.'
}

function Invoke-GuardedSeeder {
    & docker exec `
        -e "STAGE2_E2E_PASSWORD=$sharedPassword" `
        -e "STAGE2_E2E_ADMIN_INITIAL_PASSWORD=$initialAdminPassword" `
        -e "STAGE2_E2E_ADMIN_NEW_PASSWORD=$newAdminPassword" `
        $backendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage2E2eSeeder `
        --force `
        --no-ansi

    Assert-LastCommandSucceeded 'The guarded Stage 2 E2E seeder failed.'
}

function Invoke-WindowsE2eTest {
    param([string] $TestName)

    & $FlutterExecutable test `
        $testFile `
        -d windows `
        --plain-name $TestName `
        "--dart-define=API_BASE_URL=$apiBaseUrl" `
        "--dart-define=STAGE2_E2E_PASSWORD=$sharedPassword" `
        "--dart-define=STAGE2_E2E_ADMIN_INITIAL_PASSWORD=$initialAdminPassword" `
        "--dart-define=STAGE2_E2E_ADMIN_NEW_PASSWORD=$newAdminPassword" `
        "--dart-define=STAGE2_E2E_ORACLE_PATH=$oraclePath"

    Assert-LastCommandSucceeded "Windows E2E failed: $TestName"
}

function Assert-RestartedDatabaseState {
    $databaseAssertion = @'
throw_unless(DB::scalar('select current_database()') === 'testlabuz_testing', 'Wrong persistence database.');
throw_unless(DB::table('institutions')->where('name', 'E2E S02 Created Institution Edited')->where('status', 'inactive')->count() === 1, 'Created Institution state was not retained exactly once.');
throw_unless(DB::table('institution_settings')->join('institutions', 'institutions.id', '=', 'institution_settings.institution_id')->where('institutions.name', 'E2E S02 Created Institution Edited')->where('institution_settings.timezone', 'Asia/Tashkent')->where('institution_settings.learning_material_max_mb', 25)->where('institution_settings.student_submission_max_mb', 15)->whereNull('institution_settings.acceptable_score_difference')->whereNull('institution_settings.blitz_timer_start_mode')->whereNull('institution_settings.student_result_release_mode')->whereNull('institution_settings.parent_result_release_mode')->count() === 1, 'Created Institution settings were not retained exactly once.');
throw_unless(DB::table('users')->join('institutions', 'institutions.id', '=', 'users.institution_id')->where('institutions.name', 'E2E S02 Created Institution Edited')->where('users.login_name', 'e2e_s02_created_admin')->where('users.full_name', 'E2E S02 Created Admin Edited')->where('users.email', 'edited-admin@e2e-s02.invalid')->whereNull('users.phone')->where('users.is_active', true)->where('users.must_change_password', false)->count() === 1, 'Created Institution Admin state was not retained exactly once.');
throw_unless(DB::table('institution_settings')->where('institution_id', '02000000-0000-4000-8000-000000000101')->where('timezone', 'Asia/Tashkent')->where('learning_material_max_mb', 25)->where('student_submission_max_mb', 15)->count() === 1, 'Target Institution settings were not retained.');
throw_unless(DB::table('institutions')->where('id', '02000000-0000-4000-8000-000000000103')->where('status', 'active')->count() === 1, 'Unaffected Institution state changed.');
dump('Stage2DatabasePersistence: PASS');
'@

    & docker exec $backendContainerName `
        php artisan tinker `
        "--execute=$databaseAssertion"

    Assert-LastCommandSucceeded 'The restarted database persistence assertions failed.'
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
    if (-not $resolvedOraclePath.StartsWith(
        $tempRoot,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Refusing to remove an oracle artifact outside the system temp directory.'
    }

    Remove-Item -LiteralPath $resolvedOraclePath -Force
}

$oraclePath = $null

try {
    $runtime = Assert-Stage2DedicatedRuntime -ApiTarget $apiTarget
    & $runtimeGuardVerificationPath -ApiPort $ApiPort
    Assert-LastCommandSucceeded 'The fail-closed Stage 2 runtime guard matrix failed.'
    Write-Output (
        'Stage2Safety: PASS ' +
        "environment=$($runtime.Environment) " +
        "database=$($runtime.Database) " +
        "target=$($runtime.ApiBaseUrl)"
    )
    Wait-ForDedicatedBackend

    Invoke-GuardedSeeder
    Invoke-GuardedSeeder
    Write-Output 'Stage2Seeder: PASS (two consecutive guarded runs)'

    $oraclePath = [IO.Path]::GetTempFileName()
    New-Stage2OracleFile `
        -BackendContainerName $backendContainerName `
        -DestinationPath $oraclePath
    Write-Output 'Stage2IndependentOracle: PASS (guarded read-only PostgreSQL)'

    Invoke-WindowsE2eTest `
        'Stage 2 platform management mutation flow uses the real Windows stack'
    Write-Output 'Stage2WindowsMutationE2E: PASS'

    & docker stop $backendContainerName | Out-Null
    Assert-LastCommandSucceeded 'The dedicated backend stop failed.'
    & docker start $backendContainerName | Out-Null
    Assert-LastCommandSucceeded 'The dedicated backend restart failed.'
    Wait-ForDedicatedBackend
    Write-Output 'Stage2BackendRestart: PASS'

    Invoke-WindowsE2eTest `
        'Stage 2 state persists after the dedicated backend restart'
    Write-Output 'Stage2WindowsPersistenceE2E: PASS'
    Assert-RestartedDatabaseState
}
finally {
    Remove-EphemeralOracle
    $running = & docker inspect --format '{{.State.Running}}' $backendContainerName 2>$null
    if ($running -eq 'false') {
        & docker start $backendContainerName | Out-Null
    }
}
