param(
    [Parameter(Mandatory = $true)][string] $FlutterExecutable,
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendContainerName = 'testlabuz-stage5-e2e-app'
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$testFile = Join-Path $PSScriptRoot 'stage5_topics_materials_flow_test.dart'
$frontendRoot = Split-Path -Parent $PSScriptRoot
$sharedPassword = $null
$oraclePath = $null
$fixtureRoot = $null
$fixtureManifestPath = $null
$fileSinkRoot = $null
$frozenSnapshotPath = $null

. (Join-Path $PSScriptRoot 'stage5_runtime_guard.ps1')
. (Join-Path $PSScriptRoot 'stage5_test_files.ps1')
. (Join-Path $PSScriptRoot 'stage5_oracle.ps1')

function Assert-Stage5LastCommandSucceeded {
    param([Parameter(Mandatory = $true)][string] $Message)
    if ($LASTEXITCODE -ne 0) { throw $Message }
}

function Assert-Stage5FlutterVersion {
    param([Parameter(Mandatory = $true)][string] $Executable)
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { throw 'The requested Flutter executable does not exist.' }
    $versionOutput = & $Executable --version --machine 2>&1
    Assert-Stage5LastCommandSucceeded 'The requested Flutter executable could not report its version.'
    try { $version = ($versionOutput -join "`n") | ConvertFrom-Json } catch { throw 'The Flutter version response was invalid.' }
    if ([string] $version.frameworkVersion -cne '3.44.7') { throw 'Stage 5 E2E requires exactly Flutter 3.44.7.' }
}

function Wait-ForStage5Backend {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        try {
            $target = Resolve-Stage5ApiTarget -ApiBaseUrl $apiBaseUrl
            Invoke-Stage5HttpBoundaryProbe -ApiTarget $target
            return
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    } until ([DateTime]::UtcNow -gt $deadline)
    throw 'The dedicated Stage 5 backend did not reach the exact HTTP-ready 401 boundary.'
}

function Invoke-GuardedStage5Seeder {
    & docker exec `
        -e "STAGE5_E2E_PASSWORD=$sharedPassword" `
        $backendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage5E2eSeeder `
        --force `
        --no-ansi
    Assert-Stage5LastCommandSucceeded 'The guarded Stage 5 E2E seeder failed.'
}

function Invoke-Stage5WindowsProcess {
    param([Parameter(Mandatory = $true)][string] $TestName)
    Push-Location $frontendRoot
    try {
        & $FlutterExecutable test `
            $testFile `
            -d windows `
            --plain-name $TestName `
            "--dart-define=API_BASE_URL=$apiBaseUrl" `
            "--dart-define=STAGE5_E2E_PASSWORD=$sharedPassword" `
            "--dart-define=STAGE5_E2E_ORACLE_PATH=$oraclePath" `
            "--dart-define=STAGE5_E2E_FIXTURE_MANIFEST_PATH=$fixtureManifestPath" `
            "--dart-define=STAGE5_E2E_FILE_SINK_ROOT=$fileSinkRoot"
        Assert-Stage5LastCommandSucceeded "The Stage 5 Windows integration process failed: $TestName"
    }
    finally { Pop-Location }
}

function Remove-Stage5OracleArtifact {
    if ([string]::IsNullOrWhiteSpace($oraclePath) -or -not (Test-Path -LiteralPath $oraclePath)) { return }
    $resolved = Assert-Stage5OracleDestination -Path $oraclePath
    Remove-Item -LiteralPath $resolved -Force
    if (Test-Path -LiteralPath $resolved) { throw 'The Stage 5 host oracle cleanup failed.' }
}

function Remove-Stage5ControlledRoot {
    param(
        [AllowNull()][string] $Path,
        [Parameter(Mandatory = $true)][string] $NamePattern
    )
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return }
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $resolved = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if (
        -not $resolved.StartsWith($temp + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -cnotmatch $NamePattern
    ) { throw 'Refusing to remove a Stage 5 artifact outside its exact controlled temp root.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
    if (Test-Path -LiteralPath $resolved) { throw 'A controlled Stage 5 temp root remained after cleanup.' }
}

Assert-Stage5FlutterVersion -Executable $FlutterExecutable
if (-not (Test-Path -LiteralPath $testFile -PathType Leaf)) { throw 'The Stage 5 Windows integration test does not exist.' }
$apiTarget = Resolve-Stage5ApiTarget -ApiBaseUrl $apiBaseUrl

try {
    $runtime = Assert-Stage5DedicatedRuntime -ApiTarget $apiTarget
    & (Join-Path $PSScriptRoot 'verify_stage5_runtime_guard.ps1') -ApiPort $ApiPort
    Assert-Stage5LastCommandSucceeded 'The Stage 5 runtime-guard negative matrix failed.'
    Write-Output "Stage5RuntimeGuard: PASS container=$($runtime.ContainerName) target=$($runtime.ApiBaseUrl) database=$($runtime.Database) postgres=$($runtime.PostgresContainerName)"
    Wait-ForStage5Backend

    $sharedPassword = 'S05-Aa9-' + [guid]::NewGuid().ToString('N')
    Invoke-GuardedStage5Seeder
    Invoke-GuardedStage5Seeder
    Write-Output 'Stage5SeederRepeatability: PASS'

    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage5-fixtures-' + [guid]::NewGuid().ToString('N'))
    $fixtures = New-Stage5FixtureManifest -DestinationRoot $fixtureRoot -Mode Automated
    $fixtureManifestPath = $fixtures.ManifestPath
    Write-Output 'Stage5TemporaryFixtures: READY'

    $oraclePath = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage5-oracle-' + [guid]::NewGuid().ToString('N') + '.json')
    New-Stage5OracleFile -BackendContainerName $backendContainerName -DestinationPath $oraclePath
    Write-Output 'Stage5SanitizedOracle: READY'

    $frozenSnapshotPath = '/tmp/testlabuz-stage5-frozen-' + [guid]::NewGuid().ToString('N') + '.snapshot'
    Invoke-Stage5FrozenStateOracle -Action Capture -BackendContainerName $backendContainerName -ContainerSnapshotPath $frozenSnapshotPath
    Write-Output 'Stage5FrozenUnrelatedBaseline: SAVED'

    $fileSinkRoot = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage5-sink-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fileSinkRoot | Out-Null
    if (@(Get-ChildItem -LiteralPath $fileSinkRoot -Force).Count -ne 0) { throw 'The Stage 5 local-file sink root is not empty.' }

    Invoke-Stage5WindowsProcess -TestName 'Stage 5 Topics and protected materials use the real Windows stack'
    Assert-Stage5DatabaseStoragePostconditions -BackendContainerName $backendContainerName -Phase Mutation
    Add-Stage5DynamicOracleBlock -BackendContainerName $backendContainerName -OraclePath $oraclePath
    Invoke-Stage5FrozenStateOracle -Action Compare -BackendContainerName $backendContainerName -ContainerSnapshotPath $frozenSnapshotPath
    Write-Output 'Stage5MutationAndFrozenPostconditions: PASS'

    & docker stop $backendContainerName | Out-Null
    Assert-Stage5LastCommandSucceeded 'The dedicated Stage 5 backend stop failed.'
    & docker start $backendContainerName | Out-Null
    Assert-Stage5LastCommandSucceeded 'The dedicated Stage 5 backend start failed.'
    Wait-ForStage5Backend
    Assert-Stage5DedicatedRuntime -ApiTarget $apiTarget | Out-Null
    Write-Output 'Stage5BackendRestartGuard: PASS'

    Invoke-Stage5WindowsProcess -TestName 'Stage 5 Topic and protected material state persists after backend restart'
    Assert-Stage5DatabaseStoragePostconditions -BackendContainerName $backendContainerName -Phase Persistence
    Invoke-Stage5FrozenStateOracle -Action Compare -BackendContainerName $backendContainerName -ContainerSnapshotPath $frozenSnapshotPath
    Write-Output 'Stage5PersistenceAndFrozenPostconditions: PASS'
}
finally {
    $cleanupErrors = [Collections.Generic.List[string]]::new()
    try {
        & docker inspect $backendContainerName *> $null
        if ($LASTEXITCODE -eq 0) {
            $running = (& docker inspect --format '{{.State.Running}}' $backendContainerName 2>$null).Trim()
            if ($running -ceq 'false') {
                & docker start $backendContainerName | Out-Null
                Assert-Stage5LastCommandSucceeded 'The Stage 5 cleanup could not restart the dedicated backend.'
                Wait-ForStage5Backend
            }
            if (-not [string]::IsNullOrWhiteSpace($frozenSnapshotPath)) {
                Invoke-Stage5FrozenStateOracle -Action Remove -BackendContainerName $backendContainerName -ContainerSnapshotPath $frozenSnapshotPath
            }
        }
    }
    catch { $cleanupErrors.Add($_.Exception.Message) }
    try { Remove-Stage5OracleArtifact } catch { $cleanupErrors.Add($_.Exception.Message) }
    try { Remove-Stage5ControlledRoot -Path $fixtureRoot -NamePattern '^testlabuz-stage5-fixtures-[a-f0-9]{32}$' } catch { $cleanupErrors.Add($_.Exception.Message) }
    try { Remove-Stage5ControlledRoot -Path $fileSinkRoot -NamePattern '^testlabuz-stage5-sink-[a-f0-9]{32}$' } catch { $cleanupErrors.Add($_.Exception.Message) }
    $fixtureManifestPath = $null
    $frozenSnapshotPath = $null
    $sharedPassword = $null
    if ($cleanupErrors.Count -ne 0) { throw ('Stage 5 mandatory cleanup failed: ' + ($cleanupErrors -join ' | ')) }
    Write-Output 'Stage5MandatoryCleanup: PASS'
}
