param(
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int] $ApiPort,
    [pscredential] $Credential,
    [switch] $CompleteManualSmokeAndCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage7_runtime_guard.ps1')
. (Join-Path $PSScriptRoot 'stage7_oracle.ps1')
. (Join-Path $PSScriptRoot 'stage7_api_security.ps1')

function Get-Stage7CleanupSentinel {
    param([string] $InstitutionId)
    # Read one existing unrelated row; never create or rewrite rows to obtain evidence.
    $program = @'
if (!app()->environment('testing') || DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new RuntimeException('Stage 7 cleanup sentinel database identity failed.');
}
$owned = Database\Seeders\Stage7E2eSeeder::manifest()['institutions'];
$id = $stage7Input['institution_id'] ?? null;
$query = DB::table('institutions')->whereNotIn('id', array_values($owned));
if ($id !== null) {
    if (!is_string($id) || !Illuminate\Support\Str::isUuid($id) || in_array($id, $owned, true)) {
        throw new RuntimeException('Invalid unrelated cleanup sentinel identity.');
    }
    $query->where('id', $id);
}
$row = $query->orderBy('id')->first();
echo json_encode(['id'=>$row?->id, 'checksum'=>$row === null ? null : hash('sha256', json_encode($row, JSON_THROW_ON_ERROR))], JSON_THROW_ON_ERROR);
'@
    $inputObject = @{ institution_id = if ([string]::IsNullOrEmpty($InstitutionId)) { $null } else { $InstitutionId } }
    Invoke-Stage7ContainerPhp -Program $program -InputJson ($inputObject | ConvertTo-Json -Compress)
}

# Use the in-memory PSCredential returned by the successful automated runner.
# The Owner may explicitly reveal its password locally for real Android login.
# This helper never reveals/persists credentials and cannot partially reset fixtures.
$apiTarget = Resolve-Stage7ApiTarget -ApiBaseUrl "http://127.0.0.1:$ApiPort/api/v1"
Assert-Stage7DedicatedRuntime -ApiTarget $apiTarget | Out-Null
$facts = Get-Stage7DatabaseFacts
$password = $null
try {
    if ($null -ne $Credential) {
        if ($Credential.UserName -cne 'e2e_s07_student') { throw 'Manual smoke requires the exact Stage 7 Student credential.' }
        $password = $Credential.GetNetworkCredential().Password
    }
    if ($CompleteManualSmokeAndCleanup) {
        if ([string]::IsNullOrWhiteSpace($password)) { throw 'Final cleanup requires the Owner-held Stage 7 credential.' }
        Assert-Stage7DatabaseFacts -Facts $facts -Mode ManualSmoke
        $sentinel = Get-Stage7CleanupSentinel
        $cleanupProgram = @'
try {
    putenv('STAGE7_E2E_PASSWORD='.$stage7Input['password']);
    (new Database\Seeders\Stage7E2eSeeder)->cleanupOwnedState();
    echo json_encode(['cleaned' => true], JSON_THROW_ON_ERROR);
} finally { putenv('STAGE7_E2E_PASSWORD'); unset($stage7Input['password']); }
'@
        $result = Invoke-Stage7ContainerPhp -Program $cleanupProgram -InputJson (@{ password = $password } | ConvertTo-Json -Compress)
        if ($result.cleaned -ne $true) { throw 'Stage 7 cleanup was not confirmed.' }
        $cleaned = Get-Stage7DatabaseFacts -PriorFacts $facts
        Assert-Stage7DatabaseFacts -Facts $cleaned -Mode Cleanup -Baseline $facts
        if ($null -ne $sentinel.id) {
            $preserved = Get-Stage7CleanupSentinel -InstitutionId $sentinel.id
            Assert-Stage7Equal $preserved $sentinel 'unrelated cleanup sentinel remains unchanged'
            Write-Output 'Stage7UnrelatedCleanupSentinel: PASS'
        }
        else {
            Write-Output 'Stage7UnrelatedCleanupSentinel: no existing unrelated institution; created row/file sentinel coverage is in Stage7E2eSeederTest.'
        }
        Write-Output 'Stage7ManualSmokeOracleAndCleanup: PASS'
    }
    else {
        Assert-Stage7DatabaseFacts -Facts $facts -Mode ManualReady
        Write-Output 'Stage7ManualReady: e2e_s07_student / E2E S07 Android Smoke Homework'
        Write-Output 'Use the Owner-held credential for real Android login. A consumed fixture requires a complete guarded runner retry.'
    }
}
finally { $password = $null; $Credential = $null }
