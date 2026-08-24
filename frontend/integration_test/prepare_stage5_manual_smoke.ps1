param(
    [Parameter(Mandatory = $true)][ValidateSet('Windows', 'Android')][string] $Target,
    [Parameter(Mandatory = $true)][string] $FlutterExecutable,
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort,
    [string] $AndroidDeviceId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$backendContainerName = 'testlabuz-stage5-e2e-app'
$apiBaseUrl = "http://127.0.0.1:$ApiPort/api/v1"
$frontendRoot = Split-Path -Parent $PSScriptRoot
$securePassword = $null
$passwordPointer = [IntPtr]::Zero
$plainPassword = $null
$manualRoot = $null
$reverseAdded = $false

. (Join-Path $PSScriptRoot 'stage5_runtime_guard.ps1')
. (Join-Path $PSScriptRoot 'stage5_test_files.ps1')

function Assert-Stage5ManualLastCommand {
    param([Parameter(Mandatory = $true)][string] $Message)
    if ($LASTEXITCODE -ne 0) { throw $Message }
}

function Assert-Stage5ManualFlutter {
    if (-not (Test-Path -LiteralPath $FlutterExecutable -PathType Leaf)) { throw 'The requested Flutter executable does not exist.' }
    $output = & $FlutterExecutable --version --machine 2>&1
    Assert-Stage5ManualLastCommand 'Flutter could not report its version.'
    try { $version = ($output -join "`n") | ConvertFrom-Json } catch { throw 'The Flutter version response was invalid.' }
    if ([string] $version.frameworkVersion -cne '3.44.7') { throw 'Stage 5 manual smoke requires exactly Flutter 3.44.7.' }
}

function Assert-Stage5AndroidDevice {
    if ([string]::IsNullOrWhiteSpace($AndroidDeviceId)) { throw 'AndroidDeviceId is required for Android smoke.' }
    $adb = Get-Command adb -ErrorAction Stop
    $lines = & $adb.Source devices 2>&1
    Assert-Stage5ManualLastCommand 'ADB could not enumerate devices.'
    $matches = @($lines | Where-Object { $_ -match ('^' + [regex]::Escape($AndroidDeviceId) + '\s+(?<state>\S+)\s*$') })
    if ($matches.Count -ne 1 -or $matches[0] -notmatch '\sdevice\s*$') {
        throw 'The supplied Android device ID must identify exactly one online authorized device.'
    }
    $adb.Source
}

function Remove-Stage5ManualRoot {
    if ([string]::IsNullOrWhiteSpace($manualRoot) -or -not (Test-Path -LiteralPath $manualRoot)) { return }
    $resolved = Assert-Stage5FixtureRoot -Path $manualRoot -Mode Manual
    Remove-Item -LiteralPath $resolved -Recurse -Force
    if (Test-Path -LiteralPath $resolved) { throw 'The Stage 5 manual fixture cleanup failed.' }
}

Assert-Stage5ManualFlutter
$apiTarget = Resolve-Stage5ApiTarget -ApiBaseUrl $apiBaseUrl
Assert-Stage5DedicatedRuntime -ApiTarget $apiTarget | Out-Null
$adbExecutable = if ($Target -ceq 'Android') { Assert-Stage5AndroidDevice } else { $null }

try {
    $securePassword = Read-Host 'Choose the transient Stage 5 shared password' -AsSecureString
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    if ([string]::IsNullOrWhiteSpace($plainPassword)) { throw 'A non-empty transient Stage 5 password is required.' }

    & docker exec `
        -e "STAGE5_E2E_PASSWORD=$plainPassword" `
        $backendContainerName `
        php artisan db:seed `
        --class=Database\Seeders\Stage5E2eSeeder `
        --force `
        --no-ansi
    Assert-Stage5ManualLastCommand 'The guarded Stage 5 manual-smoke seed failed.'

    Write-Output 'Manual smoke login: e2e_s05_target_teacher'
    Write-Output 'Manual smoke login: e2e_s05_target_student'
    if ($Target -ceq 'Windows') {
        $manualRoot = Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage5-manual-' + [guid]::NewGuid().ToString('N'))
        $fixtures = New-Stage5FixtureManifest -DestinationRoot $manualRoot -Mode Manual
        Write-Output ('Manual picker fixture: ' + $fixtures.Files.manual_pdf.path)
    }
    else {
        & $adbExecutable -s $AndroidDeviceId reverse "tcp:$ApiPort" "tcp:$ApiPort"
        Assert-Stage5ManualLastCommand 'The exact Android ADB reverse mapping could not be added.'
        $reverseAdded = $true
    }

    Push-Location $frontendRoot
    try {
        if ($Target -ceq 'Windows') {
            & $FlutterExecutable run -d windows "--dart-define=API_BASE_URL=$apiBaseUrl"
        }
        else {
            & $FlutterExecutable run -d $AndroidDeviceId "--dart-define=API_BASE_URL=$apiBaseUrl"
        }
        Assert-Stage5ManualLastCommand 'The Stage 5 manual-smoke application process failed.'
    }
    finally { Pop-Location }
}
finally {
    $cleanupFailure = $null
    if ($reverseAdded) {
        try {
            & $adbExecutable -s $AndroidDeviceId reverse --remove "tcp:$ApiPort"
            Assert-Stage5ManualLastCommand 'The exact Android ADB reverse mapping could not be removed.'
        }
        catch { $cleanupFailure = $_.Exception.Message }
    }
    try { Remove-Stage5ManualRoot } catch { if ($null -eq $cleanupFailure) { $cleanupFailure = $_.Exception.Message } }
    $plainPassword = $null
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
        $passwordPointer = [IntPtr]::Zero
    }
    if ($null -ne $securePassword) {
        $securePassword.Dispose()
        $securePassword = $null
    }
    if ($null -ne $cleanupFailure) { throw $cleanupFailure }
}
