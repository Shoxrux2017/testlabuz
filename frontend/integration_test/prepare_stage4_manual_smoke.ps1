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
$frontendRoot = Split-Path -Parent $PSScriptRoot
$securePassword = $null
$passwordPointer = [IntPtr]::Zero
$sharedPassword = $null

. (Join-Path $PSScriptRoot 'stage4_runtime_guard.ps1')

if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) {
    throw 'The requested Flutter executable does not exist.'
}
$apiTarget = Resolve-Stage4ApiTarget -ApiBaseUrl $apiBaseUrl
Assert-Stage4DedicatedRuntime -ApiTarget $apiTarget | Out-Null

try {
    $securePassword = Read-Host 'Choose the transient Stage 4 shared password' -AsSecureString
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $sharedPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    if ([string]::IsNullOrWhiteSpace($sharedPassword)) {
        throw 'A non-empty transient Stage 4 password is required.'
    }

    & docker exec `
        -e "STAGE4_E2E_PASSWORD=$sharedPassword" `
        $backendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage4E2eSeeder `
        --force `
        --no-ansi
    if ($LASTEXITCODE -ne 0) {
        throw 'The guarded Stage 4 manual-smoke seed failed.'
    }

    Write-Output 'Manual smoke login: e2e_s04_target_admin'
    Push-Location $frontendRoot
    try {
        & $FlutterExecutable run `
            -d windows `
            "--dart-define=API_BASE_URL=$apiBaseUrl"
    }
    finally {
        Pop-Location
    }
}
finally {
    $sharedPassword = $null
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    if ($null -ne $securePassword) {
        $securePassword.Dispose()
    }
}
