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
$frontendRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'stage3_runtime_guard.ps1')

if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) {
    throw 'The requested Flutter executable does not exist.'
}

$apiTarget = Resolve-Stage3ApiTarget -ApiBaseUrl $apiBaseUrl
Assert-Stage3DedicatedRuntime -ApiTarget $apiTarget | Out-Null

$securePassword = Read-Host 'Choose the transient Stage 3 shared password' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$sharedPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
$firstLoginPassword = 'S03-Dd6-' + [guid]::NewGuid().ToString('N')
$initialUserPassword = 'S03-Bb8-' + [guid]::NewGuid().ToString('N')
$newUserPassword = 'S03-Cc7-' + [guid]::NewGuid().ToString('N')

try {
    if ([string]::IsNullOrWhiteSpace($sharedPassword)) {
        throw 'A non-empty transient password is required.'
    }

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

    if ($LASTEXITCODE -ne 0) {
        throw 'The guarded Stage 3 fixture seed failed.'
    }

    Write-Output 'Stage3ManualSmokeSafety: PASS'
    Write-Output 'Manual smoke login: e2e_s03_target_admin'
    Write-Output 'Use the transient password entered at the hidden prompt.'
    Write-Output 'Complete the owner checklist, then close the app or press q.'

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
    $firstLoginPassword = $null
    $initialUserPassword = $null
    $newUserPassword = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
}
