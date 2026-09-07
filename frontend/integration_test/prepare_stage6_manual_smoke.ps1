param(
    [Parameter(Mandatory = $true)][string] $FlutterExecutable,
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendContainerName = 'testlabuz-stage6-e2e-app'
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$frontendRoot = Split-Path -Parent $PSScriptRoot
$plainPassword = $null

. (Join-Path $PSScriptRoot 'stage6_runtime_guard.ps1')

function Assert-Stage6ManualCommand {
    param([string] $Message)
    if ($LASTEXITCODE -ne 0) { throw $Message }
}

function Assert-Stage6ManualFlutter {
    if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) { throw 'The supplied Flutter executable does not exist.' }
    $pinPath = Join-Path $frontendRoot '.fvmrc'
    try { $pin = [string] ((Get-Content -LiteralPath $pinPath -Raw | ConvertFrom-Json).flutter) } catch { throw 'The repository FVM pin is invalid.' }
    $output = & $FlutterExecutable --version --machine 2>&1
    Assert-Stage6ManualCommand 'Flutter could not report its version.'
    try { $version = ($output -join "`n") | ConvertFrom-Json } catch { throw 'The Flutter version response was invalid.' }
    if ([string] $version.frameworkVersion -cne $pin) { throw "Stage 6 manual smoke requires Flutter $pin." }
}

Assert-Stage6ManualFlutter
$apiTarget = Resolve-Stage6ApiTarget -ApiBaseUrl $apiBaseUrl
Assert-Stage6DedicatedRuntime -ApiTarget $apiTarget | Out-Null

try {
    $plainPassword = [Environment]::GetEnvironmentVariable('STAGE6_E2E_PASSWORD', 'Process')
    if ([string]::IsNullOrWhiteSpace($plainPassword)) {
        throw 'STAGE6_E2E_PASSWORD must be supplied privately in the current process environment.'
    }
    & docker exec `
        -e "STAGE6_E2E_PASSWORD=$plainPassword" `
        $backendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage6E2eSeeder `
        --force `
        --no-ansi 2>&1 | Out-Null
    Assert-Stage6ManualCommand 'The guarded Stage 6 manual-smoke seed failed.'

    Write-Output 'Manual smoke login: e2e_s06_target_teacher'
    Write-Output 'Manual smoke Topic: E2E S06 Authoring Topic'
    Write-Output 'Manual smoke draft title: E2E S06 Manual Smoke Homework'
    Write-Output 'Manual smoke locked Topic: E2E S06 Locked Topic'
    Write-Output 'Manual smoke locked Homework: E2E S06 Locked Official Homework'
    Push-Location $frontendRoot
    try {
        & $FlutterExecutable run -d windows "--dart-define=API_BASE_URL=$apiBaseUrl"
        Assert-Stage6ManualCommand 'The Stage 6 Windows manual-smoke application process failed.'
    }
    finally { Pop-Location }
}
finally {
    $plainPassword = $null
}
