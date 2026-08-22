param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage4_runtime_guard.ps1')

$approvedTarget = "http://127.0.0.1:$ApiPort/api/v1"
$invalidTargets = @(
    "https://127.0.0.1:$ApiPort/api/v1",
    "http://localhost:$ApiPort/api/v1",
    "http://[::1]:$ApiPort/api/v1",
    "http://stage4.example.invalid:$ApiPort/api/v1",
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
    try { Resolve-Stage4ApiTarget -ApiBaseUrl $invalidTarget | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'The Stage 4 guard accepted an invalid API target.' }
}

$invalidRuntimeFacts = @(
    @{ Environment = 'local'; Database = 'testlabuz_testing'; ConnectionDriver = 'pgsql'; PdoDriver = 'pgsql' },
    @{ Environment = 'testing'; Database = 'testlabuz'; ConnectionDriver = 'pgsql'; PdoDriver = 'pgsql' },
    @{ Environment = 'testing'; Database = 'testlabuz_testing'; ConnectionDriver = 'sqlite'; PdoDriver = 'pgsql' },
    @{ Environment = 'testing'; Database = 'testlabuz_testing'; ConnectionDriver = 'pgsql'; PdoDriver = 'mysql' }
)
foreach ($facts in $invalidRuntimeFacts) {
    $rejected = $false
    try {
        Assert-Stage4RuntimeFacts `
            -Environment $facts.Environment `
            -Database $facts.Database `
            -ConnectionDriver $facts.ConnectionDriver `
            -PdoDriver $facts.PdoDriver
    }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'The Stage 4 guard accepted invalid runtime facts.' }
}

$validServerFacts = @{
    DatabaseHost = 'postgres'
    PostgresContainerName = 'testlabuz-postgres-1'
    PostgresImage = 'postgres:18.4'
    BackendNetworkPresent = $true
    PostgresNetworkPresent = $true
    PostgresRunning = $true
}
$invalidServerFacts = @(
    @{ DatabaseHost = 'remote-postgres' },
    @{ PostgresContainerName = 'another-postgres' },
    @{ PostgresImage = 'mysql:8' },
    @{ BackendNetworkPresent = $false },
    @{ PostgresNetworkPresent = $false },
    @{ PostgresRunning = $false }
)
foreach ($override in $invalidServerFacts) {
    $facts = $validServerFacts.Clone()
    foreach ($name in $override.Keys) { $facts[$name] = $override[$name] }
    $rejected = $false
    try { Assert-Stage4ServerFacts @facts } catch { $rejected = $true }
    if (-not $rejected) { throw 'The Stage 4 guard accepted invalid database server facts.' }
}

$acceptedBinding = [pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] $ApiPort }
$invalidBindings = @(
    @{ Configured = @(); Active = @($acceptedBinding) },
    @{ Configured = @($acceptedBinding); Active = @() },
    @{ Configured = @([pscustomobject] @{ HostIp = '0.0.0.0'; HostPort = [string] $ApiPort }); Active = @($acceptedBinding) },
    @{ Configured = @($acceptedBinding); Active = @([pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] ($ApiPort + 1) }) },
    @{ Configured = @($acceptedBinding, $acceptedBinding); Active = @($acceptedBinding) }
)
foreach ($bindingFacts in $invalidBindings) {
    $rejected = $false
    try {
        Assert-Stage4PortBindingFacts `
            -ConfiguredBindings $bindingFacts.Configured `
            -ActiveBindings $bindingFacts.Active `
            -ApiPort $ApiPort
    }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'The Stage 4 guard accepted invalid port bindings.' }
}

Assert-Stage4RuntimeFacts `
    -Environment 'testing' `
    -Database 'testlabuz_testing' `
    -ConnectionDriver 'pgsql' `
    -PdoDriver 'pgsql'
Assert-Stage4ServerFacts @validServerFacts
Assert-Stage4PortBindingFacts `
    -ConfiguredBindings @($acceptedBinding) `
    -ActiveBindings @($acceptedBinding) `
    -ApiPort $ApiPort

$apiTarget = Resolve-Stage4ApiTarget -ApiBaseUrl $approvedTarget
$wrongContainerRejected = $false
try {
    Assert-Stage4DedicatedRuntime -ApiTarget $apiTarget -BackendContainerName 'testlabuz-app-1' | Out-Null
}
catch { $wrongContainerRejected = $true }
if (-not $wrongContainerRejected) { throw 'The Stage 4 guard accepted the wrong backend container.' }

$unboundPort = if ($ApiPort -eq 65535) { 65534 } else { $ApiPort + 1 }
$unboundTarget = Resolve-Stage4ApiTarget -ApiBaseUrl "http://127.0.0.1:$unboundPort/api/v1"
$unboundRejected = $false
try { Assert-Stage4DedicatedRuntime -ApiTarget $unboundTarget | Out-Null } catch { $unboundRejected = $true }
if (-not $unboundRejected) { throw 'The Stage 4 guard accepted an unbound loopback port.' }

$runtime = Assert-Stage4DedicatedRuntime -ApiTarget $apiTarget
Write-Output (
    'Stage4RuntimeGuardMatrix: PASS ' +
    "($($invalidTargets.Count) invalid targets, " +
    "$($invalidRuntimeFacts.Count) invalid runtime identities, " +
    "$($invalidServerFacts.Count) invalid database server identities, " +
    "$($invalidBindings.Count) invalid binding shapes, wrong container, unbound port, " +
    "approved $($runtime.ApiBaseUrl))"
)
