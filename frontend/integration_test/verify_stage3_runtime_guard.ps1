param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage3_runtime_guard.ps1')

$approvedTarget = "http://127.0.0.1:$ApiPort/api/v1"
$invalidTargets = @(
    "https://127.0.0.1:$ApiPort/api/v1",
    "http://localhost:$ApiPort/api/v1",
    "http://[::1]:$ApiPort/api/v1",
    "http://stage3.example.invalid:$ApiPort/api/v1",
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
        Resolve-Stage3ApiTarget -ApiBaseUrl $invalidTarget | Out-Null
    }
    catch {
        $rejected = $true
    }

    if (-not $rejected) {
        throw 'The Stage 3 target guard accepted an invalid API target.'
    }
}

$invalidRuntimeFacts = @(
    @{ Environment = 'local'; Database = 'testlabuz_testing'; ConnectionDriver = 'pgsql'; PdoDriver = 'pgsql' },
    @{ Environment = 'testing'; Database = 'testlabuz'; ConnectionDriver = 'pgsql'; PdoDriver = 'pgsql' },
    @{ Environment = 'testing'; Database = 'testlabuz_testing'; ConnectionDriver = 'sqlite'; PdoDriver = 'sqlite' },
    @{ Environment = 'testing'; Database = 'testlabuz_testing'; ConnectionDriver = 'pgsql'; PdoDriver = 'mysql' }
)

foreach ($facts in $invalidRuntimeFacts) {
    $rejected = $false
    try {
        Assert-Stage3RuntimeFacts `
            -Environment $facts.Environment `
            -Database $facts.Database `
            -ConnectionDriver $facts.ConnectionDriver `
            -PdoDriver $facts.PdoDriver
    }
    catch {
        $rejected = $true
    }

    if (-not $rejected) {
        throw 'The Stage 3 runtime guard accepted invalid runtime facts.'
    }
}

$apiTarget = Resolve-Stage3ApiTarget -ApiBaseUrl $approvedTarget
Assert-Stage3RuntimeFacts `
    -Environment 'testing' `
    -Database 'testlabuz_testing' `
    -ConnectionDriver 'pgsql' `
    -PdoDriver 'pgsql'
$runtime = Assert-Stage3DedicatedRuntime -ApiTarget $apiTarget

$unboundPort = if ($ApiPort -eq 65535) { 65534 } else { $ApiPort + 1 }
$unboundTarget = Resolve-Stage3ApiTarget `
    -ApiBaseUrl "http://127.0.0.1:$unboundPort/api/v1"
$unboundRejected = $false
try {
    Assert-Stage3DedicatedRuntime -ApiTarget $unboundTarget | Out-Null
}
catch {
    $unboundRejected = $true
}
if (-not $unboundRejected) {
    throw 'The Stage 3 runtime guard accepted a port not bound to the dedicated runtime.'
}

Write-Output (
    'Stage3RuntimeGuardMatrix: PASS ' +
    "($($invalidTargets.Count) invalid targets, " +
    "$($invalidRuntimeFacts.Count) invalid runtime identities, " +
    '1 unbound loopback port, ' +
    "approved $($runtime.ApiBaseUrl))"
)
