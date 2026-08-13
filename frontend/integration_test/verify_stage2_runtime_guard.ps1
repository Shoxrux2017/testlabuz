param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage2_runtime_guard.ps1')

$approvedTarget = "http://127.0.0.1:$ApiPort/api/v1"
$invalidTargets = @(
    "https://127.0.0.1:$ApiPort/api/v1",
    "http://localhost:$ApiPort/api/v1",
    "http://[::1]:$ApiPort/api/v1",
    "http://stage2.example.invalid:$ApiPort/api/v1",
    "http://192.0.2.10:$ApiPort/api/v1",
    "http://user@127.0.0.1:$ApiPort/api/v1",
    "http://127.0.0.1:$ApiPort/api/v1?unsafe=true",
    "http://127.0.0.1:$ApiPort/api/v1#fragment",
    "http://127.0.0.1:$ApiPort/api/v2",
    'http://127.0.0.1/api/v1',
    'not-a-url',
    "http://127.0.0.1:$ApiPort/api/v1/",
    'http://127.0.0.1:0/api/v1',
    'http://127.0.0.1:65536/api/v1'
)

foreach ($invalidTarget in $invalidTargets) {
    $rejected = $false
    try {
        Resolve-Stage2ApiTarget -ApiBaseUrl $invalidTarget | Out-Null
    }
    catch {
        $rejected = $true
    }

    if (-not $rejected) {
        throw 'The Stage 2 target guard accepted an invalid API target.'
    }
}

$invalidRuntimeFacts = @(
    @{ Environment = 'local'; Database = 'testlabuz_testing' },
    @{ Environment = 'testing'; Database = 'testlabuz' }
)

foreach ($facts in $invalidRuntimeFacts) {
    $rejected = $false
    try {
        Assert-Stage2RuntimeFacts `
            -Environment $facts.Environment `
            -Database $facts.Database
    }
    catch {
        $rejected = $true
    }

    if (-not $rejected) {
        throw 'The Stage 2 runtime guard accepted invalid environment/database facts.'
    }
}

$apiTarget = Resolve-Stage2ApiTarget -ApiBaseUrl $approvedTarget
Assert-Stage2RuntimeFacts `
    -Environment 'testing' `
    -Database 'testlabuz_testing'
$runtime = Assert-Stage2DedicatedRuntime -ApiTarget $apiTarget

$unboundPort = if ($ApiPort -eq 65535) { 65534 } else { $ApiPort + 1 }
$unboundTarget = Resolve-Stage2ApiTarget `
    -ApiBaseUrl "http://127.0.0.1:$unboundPort/api/v1"
$unboundRejected = $false
try {
    Assert-Stage2DedicatedRuntime -ApiTarget $unboundTarget | Out-Null
}
catch {
    $unboundRejected = $true
}
if (-not $unboundRejected) {
    throw 'The Stage 2 runtime guard accepted a port not bound to the dedicated runtime.'
}

Write-Output (
    'Stage2RuntimeGuardMatrix: PASS ' +
    "($($invalidTargets.Count) invalid targets, " +
    "$($invalidRuntimeFacts.Count) invalid runtime identities, " +
    '1 unbound loopback port, ' +
    "approved $($runtime.ApiBaseUrl))"
)
