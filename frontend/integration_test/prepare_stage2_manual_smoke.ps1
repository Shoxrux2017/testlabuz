param(
    [Parameter(Mandatory = $true)]
    [string] $FlutterExecutable,

    [string] $BackendContainerName = 'testlabuz-stage2-e2e-app',

    [string] $ApiBaseUrl = 'http://127.0.0.1:8815/api/v1'
)

$ErrorActionPreference = 'Stop'

if ($BackendContainerName -ne 'testlabuz-stage2-e2e-app') {
    throw 'Manual smoke may target only the exact dedicated Stage 2 backend container.'
}

if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) {
    throw 'The requested Flutter executable does not exist.'
}

$securePassword = Read-Host `
    'Choose the transient e2e_s02_platform_owner password' `
    -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
    $securePassword
)
$sharedPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    $passwordPointer
)
$initialAdminPassword = 'S02-Bb8-' + [guid]::NewGuid().ToString('N')
$newAdminPassword = 'S02-Cc7-' + [guid]::NewGuid().ToString('N')

try {
    if ([string]::IsNullOrWhiteSpace($sharedPassword)) {
        throw 'A non-empty transient password is required.'
    }

    & docker exec $BackendContainerName `
        php artisan tinker `
        --execute="throw_unless(app()->environment('testing'), 'Wrong environment.'); throw_unless(DB::scalar('select current_database()') === 'testlabuz_testing', 'Wrong database.'); dump('Stage2ManualSmokeSafety: PASS');"

    if ($LASTEXITCODE -ne 0) {
        throw 'The dedicated Stage 2 runtime safety check failed.'
    }

    & docker exec `
        -e "STAGE2_E2E_PASSWORD=$sharedPassword" `
        -e "STAGE2_E2E_ADMIN_INITIAL_PASSWORD=$initialAdminPassword" `
        -e "STAGE2_E2E_ADMIN_NEW_PASSWORD=$newAdminPassword" `
        $BackendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage2E2eSeeder `
        --force `
        --no-ansi

    if ($LASTEXITCODE -ne 0) {
        throw 'The guarded Stage 2 fixture seed failed.'
    }

    Write-Output 'Manual smoke login: e2e_s02_platform_owner'
    Write-Output 'Use the transient password entered at the hidden prompt.'
    Write-Output 'Close the app or press q in this terminal after completing the checklist.'

    & $FlutterExecutable run `
        -d windows `
        "--dart-define=API_BASE_URL=$ApiBaseUrl"
}
finally {
    $sharedPassword = $null
    $initialAdminPassword = $null
    $newAdminPassword = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
}
