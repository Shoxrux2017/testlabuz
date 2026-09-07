param(
    [Parameter(Mandatory = $true)][string] $FlutterExecutable,
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendContainerName = 'testlabuz-stage6-e2e-app'
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$frontendRoot = Split-Path -Parent $PSScriptRoot
$testFile = Join-Path $PSScriptRoot 'stage6_homework_authoring_flow_test.dart'
$sharedPassword = $null
$oraclePath = $null
$frozenPath = $null

. (Join-Path $PSScriptRoot 'stage6_runtime_guard.ps1')
. (Join-Path $PSScriptRoot 'stage6_oracle.ps1')
. (Join-Path $PSScriptRoot 'stage6_api_security.ps1')

function Assert-Stage6LastCommand {
    param([Parameter(Mandatory = $true)][string] $Message)
    if ($LASTEXITCODE -ne 0) { throw $Message }
}

function Assert-Stage6FlutterExecutable {
    if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) {
        throw 'The supplied Stage 6 Flutter executable does not exist.'
    }
    $pinPath = Join-Path $frontendRoot '.fvmrc'
    if (-not (Test-Path -LiteralPath $pinPath -PathType Leaf)) { throw 'The repository FVM pin is absent.' }
    try { $pinned = [string] ((Get-Content -LiteralPath $pinPath -Raw | ConvertFrom-Json).flutter) } catch { throw 'The repository FVM pin is invalid.' }
    if ([string]::IsNullOrWhiteSpace($pinned)) { throw 'The repository FVM pin is empty.' }
    $versionOutput = & $FlutterExecutable --version --machine 2>&1
    Assert-Stage6LastCommand 'The supplied Flutter executable could not report its version.'
    try { $version = ($versionOutput -join "`n") | ConvertFrom-Json } catch { throw 'The Flutter version response was invalid.' }
    if ([string] $version.frameworkVersion -cne $pinned) {
        throw "Stage 6 requires the repository-pinned Flutter $pinned executable."
    }
}

function New-Stage6SharedPassword {
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = [byte[]]::new(32)
        $generator.GetBytes($bytes)
        $random = [Convert]::ToBase64String($bytes).Replace('+', 'x').Replace('/', 'y').TrimEnd('=')
        'S06-Aa9!' + $random
    }
    finally { $generator.Dispose() }
}

function Wait-ForStage6Backend {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    do {
        try {
            Invoke-Stage6HttpBoundaryProbe -ApiTarget (Resolve-Stage6ApiTarget -ApiBaseUrl $apiBaseUrl)
            return
        }
        catch { Start-Sleep -Milliseconds 500 }
    } until ([DateTime]::UtcNow -gt $deadline)
    throw 'The dedicated Stage 6 backend did not reach the exact HTTP 401 boundary.'
}

function Invoke-Stage6Seeder {
    & docker exec `
        -e "STAGE6_E2E_PASSWORD=$sharedPassword" `
        $backendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage6E2eSeeder `
        --force `
        --no-ansi 2>&1 | Out-Null
    Assert-Stage6LastCommand 'The guarded Stage 6 E2E seeder failed.'
}

function Invoke-Stage6WindowsTest {
    param([Parameter(Mandatory = $true)][string] $TestName)
    Push-Location $frontendRoot
    try {
        & $FlutterExecutable test `
            $testFile `
            -d windows `
            --plain-name $TestName `
            "--dart-define=API_BASE_URL=$apiBaseUrl" `
            "--dart-define=STAGE6_E2E_PASSWORD=$sharedPassword" `
            "--dart-define=STAGE6_E2E_ORACLE_PATH=$oraclePath"
        Assert-Stage6LastCommand "The Stage 6 Windows integration process failed: $TestName"
    }
    finally { Pop-Location }
}

function Remove-Stage6OracleArtifact {
    if ([string]::IsNullOrWhiteSpace($oraclePath)) { return }
    Remove-Stage6SanitizedOracle -Path $oraclePath
    if (Test-Path -LiteralPath $oraclePath) { throw 'The Stage 6 host oracle cleanup failed.' }
}

Assert-Stage6FlutterExecutable
if (-not (Test-Path -LiteralPath $testFile -PathType Leaf)) { throw 'The Stage 6 Windows integration test is absent.' }
$apiTarget = Resolve-Stage6ApiTarget -ApiBaseUrl $apiBaseUrl

try {
    $runtime = Assert-Stage6DedicatedRuntime -ApiTarget $apiTarget
    & (Join-Path $PSScriptRoot 'verify_stage6_runtime_guard.ps1') -ApiPort $ApiPort | Out-Null
    Assert-Stage6LastCommand 'The Stage 6 runtime-guard verifier failed.'
    & (Join-Path $PSScriptRoot 'verify_stage6_oracle.ps1') | Out-Null
    Assert-Stage6LastCommand 'The Stage 6 database-oracle verifier failed.'
    & (Join-Path $PSScriptRoot 'verify_stage6_api_security.ps1') | Out-Null
    Assert-Stage6LastCommand 'The Stage 6 API-security verifier failed.'
    Write-Output "Stage6RuntimeGuard: PASS container=$($runtime.ContainerName) target=$($runtime.ApiBaseUrl) database=$($runtime.Database)"
    Wait-ForStage6Backend

    $sharedPassword = New-Stage6SharedPassword
    Invoke-Stage6Seeder
    $firstSeederSnapshot = Get-Stage6SeederLogicalSnapshot -BackendContainerName $backendContainerName
    Invoke-Stage6Seeder
    $secondSeederSnapshot = Get-Stage6SeederLogicalSnapshot -BackendContainerName $backendContainerName
    Assert-Stage6SeederRepeatability -FirstSnapshot $firstSeederSnapshot -SecondSnapshot $secondSeederSnapshot
    Write-Output 'Stage6SeederRepeatability: PASS'

    $oraclePath = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage6-oracle-' + [guid]::NewGuid().ToString('N') + '.json')
    New-Stage6SanitizedOracle -BackendContainerName $backendContainerName -Destination $oraclePath | Out-Null
    $frozenPath = '/tmp/testlabuz-stage6-frozen-' + [guid]::NewGuid().ToString('N') + '.json'
    Invoke-Stage6FrozenStateOracle -Action Capture -BackendContainerName $backendContainerName -ContainerPath $frozenPath

    Invoke-Stage6ApiSecurityMatrix -ApiBaseUrl $apiBaseUrl -OraclePath $oraclePath -Password $sharedPassword | Out-Null
    Write-Output 'Stage6ApiSecurity: PASS'

    Invoke-Stage6WindowsTest -TestName 'Stage 6 Homework authoring uses the real Windows stack'
    Write-Output 'Stage6WindowsAuthoringFlow: PASS'
    Assert-Stage6DatabasePostconditions -Facts (Get-Stage6DatabaseFacts -BackendContainerName $backendContainerName)
    Write-Output 'Stage6DatabasePostconditions: PASS'
    Invoke-Stage6FrozenStateOracle -Action Compare -BackendContainerName $backendContainerName -ContainerPath $frozenPath
    Write-Output 'Stage6FrozenUnrelatedState: PASS'

    & docker stop $backendContainerName | Out-Null
    Assert-Stage6LastCommand 'The dedicated Stage 6 backend stop failed.'
    & docker start $backendContainerName | Out-Null
    Assert-Stage6LastCommand 'The dedicated Stage 6 backend start failed.'
    Wait-ForStage6Backend
    Assert-Stage6DedicatedRuntime -ApiTarget $apiTarget | Out-Null
    Write-Output 'Stage6BackendRestartGuard: PASS'

    Invoke-Stage6WindowsTest -TestName 'Stage 6 Homework state persists after backend restart'
    Write-Output 'Stage6WindowsPersistenceFlow: PASS'
    Assert-Stage6DatabasePostconditions -Facts (Get-Stage6DatabaseFacts -BackendContainerName $backendContainerName)
    Invoke-Stage6FrozenStateOracle -Action Compare -BackendContainerName $backendContainerName -ContainerPath $frozenPath
    Write-Output 'Stage6PersistencePostconditions: PASS'
}
finally {
    $cleanupErrors = [Collections.Generic.List[string]]::new()
    try {
        & docker inspect $backendContainerName *> $null
        if ($LASTEXITCODE -eq 0) {
            $running = (& docker inspect --format '{{.State.Running}}' $backendContainerName 2>$null).Trim()
            if ($running -ceq 'false') {
                & docker start $backendContainerName | Out-Null
                Assert-Stage6LastCommand 'Stage 6 cleanup could not restart the dedicated backend.'
                Wait-ForStage6Backend
            }
            if (-not [string]::IsNullOrWhiteSpace($frozenPath)) {
                Invoke-Stage6FrozenStateOracle -Action Remove -BackendContainerName $backendContainerName -ContainerPath $frozenPath
            }
        }
    }
    catch { $cleanupErrors.Add($_.Exception.Message) }
    try { Remove-Stage6OracleArtifact } catch { $cleanupErrors.Add($_.Exception.Message) }
    $sharedPassword = $null
    $oraclePath = $null
    $frozenPath = $null
    if ($cleanupErrors.Count -ne 0) { throw ('Stage 6 mandatory cleanup failed: ' + ($cleanupErrors -join ' | ')) }
    Write-Output 'Stage6MandatoryCleanup: PASS'
}
