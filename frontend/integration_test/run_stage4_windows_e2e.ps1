param(
    [Parameter(Mandatory = $true)]
    [string] $FlutterExecutable,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendContainerName = 'testlabuz-stage4-e2e-app'
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$guardVerificationPath = Join-Path $PSScriptRoot 'verify_stage4_runtime_guard.ps1'
$testFile = Join-Path $PSScriptRoot 'stage4_groups_relationships_flow_test.dart'
$frontendRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot 'stage4_runtime_guard.ps1')
. (Join-Path $PSScriptRoot 'stage4_oracle.ps1')

if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) {
    throw 'The requested Flutter executable does not exist.'
}
if (-not (Test-Path -LiteralPath $testFile -PathType Leaf)) {
    throw 'The Stage 4 Windows integration test does not exist.'
}

$apiTarget = Resolve-Stage4ApiTarget -ApiBaseUrl $apiBaseUrl
$sharedPassword = 'S04-Aa9-' + [guid]::NewGuid().ToString('N')
$oraclePath = $null
$frozenSnapshotPath = $null
$cleanupSucceeded = $false

function Assert-LastCommandSucceeded {
    param([Parameter(Mandatory = $true)][string] $FailureMessage)
    if ($LASTEXITCODE -ne 0) { throw $FailureMessage }
}

function Wait-ForStage4Backend {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        try {
            $response = Invoke-WebRequest `
                -UseBasicParsing `
                -Headers @{ Accept = 'application/json' } `
                -Uri ($apiBaseUrl + '/auth/me') `
                -TimeoutSec 2
            if ([int] $response.StatusCode -eq 401) { return }
        }
        catch {
            if ($null -ne $_.Exception.Response -and [int] $_.Exception.Response.StatusCode -eq 401) {
                return
            }
        }
        Start-Sleep -Milliseconds 500
    } until ([DateTime]::UtcNow -gt $deadline)
    throw 'The dedicated Stage 4 backend did not become HTTP-ready.'
}

function Invoke-GuardedStage4Seeder {
    & docker exec `
        -e "STAGE4_E2E_PASSWORD=$sharedPassword" `
        $backendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage4E2eSeeder `
        --force `
        --no-ansi
    Assert-LastCommandSucceeded 'The guarded Stage 4 E2E seeder failed.'
}

function Invoke-Stage4WindowsTest {
    param([Parameter(Mandatory = $true)][string] $TestName)
    Push-Location $frontendRoot
    try {
        & $FlutterExecutable test `
            $testFile `
            -d windows `
            --plain-name $TestName `
            "--dart-define=API_BASE_URL=$apiBaseUrl" `
            "--dart-define=STAGE4_E2E_PASSWORD=$sharedPassword" `
            "--dart-define=STAGE4_E2E_ORACLE_PATH=$oraclePath" `
            "--dart-define=STAGE4_E2E_BACKEND_CONTAINER=$backendContainerName"
        Assert-LastCommandSucceeded "Windows E2E failed: $TestName"
    }
    finally {
        Pop-Location
    }
}

function Remove-Stage4OracleFile {
    if ([string]::IsNullOrWhiteSpace($oraclePath) -or -not (Test-Path -LiteralPath $oraclePath -PathType Leaf)) {
        return
    }
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedOracle = [IO.Path]::GetFullPath($oraclePath)
    if (
        -not $resolvedOracle.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolvedOracle) -cnotmatch '^testlabuz-stage4-oracle-[a-f0-9]{32}\.json$'
    ) {
        throw 'Refusing to remove a Stage 4 oracle outside its exact system-temp scope.'
    }
    Remove-Item -LiteralPath $resolvedOracle -Force
}

try {
    $runtime = Assert-Stage4DedicatedRuntime -ApiTarget $apiTarget
    & $guardVerificationPath -ApiPort $ApiPort
    Assert-LastCommandSucceeded 'The fail-closed Stage 4 runtime guard matrix failed.'
    Write-Output (
        'Stage4RuntimeGuard: PASS ' +
        "container=$($runtime.ContainerName) target=$($runtime.ApiBaseUrl) " +
        "environment=$($runtime.Environment) database=$($runtime.Database) " +
        "driver=$($runtime.ConnectionDriver) postgres=$($runtime.PostgresContainerName) " +
        "network=$($runtime.DockerNetworkName)"
    )
    Wait-ForStage4Backend

    Invoke-GuardedStage4Seeder
    Invoke-GuardedStage4Seeder
    Write-Output 'Stage4SeederRepeatability: PASS (two consecutive guarded runs)'

    $oraclePath = Join-Path `
        ([IO.Path]::GetTempPath()) `
        ('testlabuz-stage4-oracle-' + [guid]::NewGuid().ToString('N') + '.json')
    New-Stage4OracleFile `
        -BackendContainerName $backendContainerName `
        -DestinationPath $oraclePath
    Write-Output 'Stage4IndependentOracle: PASS (sanitized read-only PostgreSQL baseline)'

    $frozenSnapshotPath = '/tmp/testlabuz-stage4-frozen-' + [guid]::NewGuid().ToString('N') + '.snapshot'
    Invoke-Stage4FrozenStateOracle `
        -Action Capture `
        -BackendContainerName $backendContainerName `
        -ContainerSnapshotPath $frozenSnapshotPath
    Write-Output 'Stage4ForeignUnrelatedBaseline: SAVED'

    Invoke-Stage4WindowsTest 'Stage 4 groups and relationships flow uses the real Windows stack'
    Write-Output 'Stage4WindowsMutationE2E: PASS'
    Assert-Stage4DatabasePostconditions `
        -BackendContainerName $backendContainerName `
        -Phase Mutation
    Write-Output 'Stage4MutationDatabasePostconditions: PASS'
    Invoke-Stage4FrozenStateOracle `
        -Action Compare `
        -BackendContainerName $backendContainerName `
        -ContainerSnapshotPath $frozenSnapshotPath
    Write-Output 'Stage4ForeignUnrelatedPostMutation: PASS (byte-for-byte)'

    & docker stop $backendContainerName | Out-Null
    Assert-LastCommandSucceeded 'The dedicated Stage 4 backend stop failed.'
    & docker start $backendContainerName | Out-Null
    Assert-LastCommandSucceeded 'The dedicated Stage 4 backend restart failed.'
    Wait-ForStage4Backend
    Assert-Stage4DedicatedRuntime -ApiTarget $apiTarget | Out-Null
    Write-Output 'Stage4BackendRestart: PASS'

    Invoke-Stage4WindowsTest 'Stage 4 state persists in a fresh Windows process after backend restart'
    Write-Output 'Stage4WindowsPersistenceE2E: PASS'
    Assert-Stage4DatabasePostconditions `
        -BackendContainerName $backendContainerName `
        -Phase Persistence
    Write-Output 'Stage4PersistenceDatabasePostconditions: PASS'
    Invoke-Stage4FrozenStateOracle `
        -Action Compare `
        -BackendContainerName $backendContainerName `
        -ContainerSnapshotPath $frozenSnapshotPath
    Write-Output 'Stage4ForeignUnrelatedPostRestart: PASS (byte-for-byte)'
}
finally {
    Remove-Stage4OracleFile

    $containerExists = $false
    & docker inspect $backendContainerName *> $null
    if ($LASTEXITCODE -eq 0) { $containerExists = $true }
    if ($containerExists) {
        $running = (& docker inspect --format '{{.State.Running}}' $backendContainerName 2>$null).Trim()
        if ($running -eq 'false') {
            & docker start $backendContainerName | Out-Null
            Assert-LastCommandSucceeded 'The Stage 4 cleanup could not restart the dedicated backend.'
        }
        if (-not [string]::IsNullOrWhiteSpace($frozenSnapshotPath)) {
            Invoke-Stage4FrozenStateOracle `
                -Action Remove `
                -BackendContainerName $backendContainerName `
                -ContainerSnapshotPath $frozenSnapshotPath
        }
    }

    $sharedPassword = $null
    $cleanupSucceeded = $true
    if ($cleanupSucceeded) { Write-Output 'Stage4TemporaryArtifactCleanup: PASS' }
}
