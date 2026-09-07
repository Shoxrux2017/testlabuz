param(
    [ValidateRange(1, 65535)][int] $ApiPort = 18006,
    [switch] $SkipLiveRuntime
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage6_runtime_guard.ps1')

function Assert-Stage6Rejected {
    param(
        [Parameter(Mandatory = $true)][scriptblock] $Action,
        [Parameter(Mandatory = $true)][string] $FailureMessage
    )
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw $FailureMessage }
}

$approvedUrl = "http://127.0.0.1:$ApiPort/api/v1"
$invalidTargets = @(
    "https://127.0.0.1:$ApiPort/api/v1",
    "http://localhost:$ApiPort/api/v1",
    "http://[::1]:$ApiPort/api/v1",
    "http://0.0.0.0:$ApiPort/api/v1",
    "http://stage6.example.invalid:$ApiPort/api/v1",
    "http://192.0.2.6:$ApiPort/api/v1",
    "http://user:pass@127.0.0.1:$ApiPort/api/v1",
    "http://127.0.0.1:$ApiPort/api/v1?unsafe=true",
    "http://127.0.0.1:$ApiPort/api/v1#unsafe",
    "http://127.0.0.1:$ApiPort/api/v2",
    'http://127.0.0.1/api/v1',
    "http://127.0.0.1:$ApiPort/api/v1/",
    'http://127.0.0.1:0/api/v1',
    'http://127.0.0.1:65536/api/v1',
    'not-a-url'
)
foreach ($target in $invalidTargets) {
    Assert-Stage6Rejected { Resolve-Stage6ApiTarget -ApiBaseUrl $target | Out-Null } 'The Stage 6 guard accepted an invalid API target.'
}

$validContainer = @{
    InspectionCount = 1
    ContainerName = 'testlabuz-stage6-e2e-app'
    Running = $true
    AutoRemove = $false
    WorkingDirectory = '/var/www/html'
}
$invalidContainers = @(
    @{ InspectionCount = 0 }, @{ InspectionCount = 2 }, @{ ContainerName = 'testlabuz-app-1' },
    @{ Running = $false }, @{ AutoRemove = $true }, @{ WorkingDirectory = '/app' }
)
foreach ($override in $invalidContainers) {
    $facts = $validContainer.Clone()
    foreach ($name in $override.Keys) { $facts[$name] = $override[$name] }
    Assert-Stage6Rejected { Assert-Stage6ContainerFacts @facts } 'The Stage 6 guard accepted invalid container facts.'
}

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$backendSource = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'backend')).Path
$backendMount = [pscustomobject] @{ Type = 'bind'; Name = ''; Source = $backendSource; Destination = '/var/www/html'; RW = $true }
$invalidMounts = @(
    @(),
    @([pscustomobject] @{ Type = 'bind'; Name = ''; Source = (Split-Path -Parent $backendSource); Destination = '/var/www/html'; RW = $true }),
    @([pscustomobject] @{ Type = 'bind'; Name = ''; Source = $backendSource; Destination = '/var/www/html'; RW = $false }),
    @($backendMount, $backendMount),
    @([pscustomobject] @{ Type = 'volume'; Name = 'wrong'; Source = '/wrong'; Destination = '/var/www/html'; RW = $true })
)
foreach ($mounts in $invalidMounts) {
    Assert-Stage6Rejected { Assert-Stage6MountFacts -Mounts $mounts -ExpectedBackendSource $backendSource } 'The Stage 6 guard accepted invalid source mount facts.'
}
Assert-Stage6MountFacts -Mounts @($backendMount) -ExpectedBackendSource $backendSource

$binding = [pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] $ApiPort }
$invalidBindings = @(
    @{ Configured = @(); Active = @($binding) },
    @{ Configured = @($binding); Active = @() },
    @{ Configured = @([pscustomobject] @{ HostIp = '0.0.0.0'; HostPort = [string] $ApiPort }); Active = @($binding) },
    @{ Configured = @($binding); Active = @([pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] ($ApiPort + 1) }) },
    @{ Configured = @($binding, $binding); Active = @($binding) }
)
foreach ($facts in $invalidBindings) {
    Assert-Stage6Rejected {
        Assert-Stage6PortBindingFacts -ConfiguredBindings $facts.Configured -ActiveBindings $facts.Active -ApiPort $ApiPort
    } 'The Stage 6 guard accepted invalid port bindings.'
}
Assert-Stage6PortBindingFacts -ConfiguredBindings @($binding) -ActiveBindings @($binding) -ApiPort $ApiPort

$validServer = @{
    DatabaseHost = 'postgres'; DatabasePort = '5432'; PostgresContainerName = 'testlabuz-postgres-1';
    PostgresImage = 'postgres:18.4'; BackendNetworkPresent = $true; PostgresNetworkPresent = $true; PostgresRunning = $true
}
$invalidServers = @(
    @{ DatabaseHost = 'remote-postgres' }, @{ DatabasePort = '5433' }, @{ PostgresContainerName = 'another-postgres' },
    @{ PostgresImage = 'postgres:18.3' }, @{ BackendNetworkPresent = $false }, @{ PostgresNetworkPresent = $false }, @{ PostgresRunning = $false }
)
foreach ($override in $invalidServers) {
    $facts = $validServer.Clone()
    foreach ($name in $override.Keys) { $facts[$name] = $override[$name] }
    Assert-Stage6Rejected { Assert-Stage6ServerFacts @facts } 'The Stage 6 guard accepted invalid database/server facts.'
}
Assert-Stage6ServerFacts @validServer

$validLaravel = [pscustomobject] @{
    environment = 'testing'; debug = $false; database_default = 'pgsql'; connection_driver = 'pgsql';
    pdo_driver = 'pgsql'; database = 'testlabuz_testing'; pending_migrations = 0
}
$invalidLaravel = @(
    @{ environment = 'local' }, @{ debug = $true }, @{ database_default = 'sqlite' },
    @{ connection_driver = 'mysql' }, @{ pdo_driver = 'mysql' }, @{ database = 'testlabuz' }, @{ pending_migrations = 1 }
)
foreach ($override in $invalidLaravel) {
    $facts = $validLaravel | Select-Object *
    foreach ($name in $override.Keys) { $facts.$name = $override[$name] }
    Assert-Stage6Rejected { Assert-Stage6LaravelFacts -Facts $facts } 'The Stage 6 guard accepted invalid Laravel/database facts.'
}
Assert-Stage6LaravelFacts -Facts $validLaravel

$validEnvelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{} }
$invalidHttpFacts = @(
    @{ Status = 200; Envelope = $validEnvelope },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'wrong'; errors = [pscustomobject] @{} } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{ token = @('unsafe') } } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{}; secret = 'unsafe' } }
)
foreach ($facts in $invalidHttpFacts) {
    Assert-Stage6Rejected { Assert-Stage6HttpBoundaryFacts -StatusCode $facts.Status -Envelope $facts.Envelope } 'The Stage 6 guard accepted an invalid HTTP boundary.'
}
Assert-Stage6HttpBoundaryFacts -StatusCode 401 -Envelope $validEnvelope

$apiTarget = Resolve-Stage6ApiTarget -ApiBaseUrl $approvedUrl
Assert-Stage6Rejected {
    Assert-Stage6DedicatedRuntime -ApiTarget $apiTarget -BackendContainerName 'testlabuz-app-1' | Out-Null
} 'The Stage 6 guard accepted the wrong backend container.'

if (-not $SkipLiveRuntime) {
    $runtime = Assert-Stage6DedicatedRuntime -ApiTarget $apiTarget
    Write-Output "Stage6RuntimeGuardLive: PASS target=$($runtime.ApiBaseUrl) database=$($runtime.Database)"
}

Write-Output (
    'Stage6RuntimeGuardMatrix: PASS ' +
    "($($invalidTargets.Count) targets, $($invalidContainers.Count) container identities, $($invalidMounts.Count) mount shapes, " +
    "$($invalidBindings.Count) bindings, $($invalidServers.Count) server identities, $($invalidLaravel.Count) Laravel/database facts, " +
    "$($invalidHttpFacts.Count) HTTP envelopes, wrong container; live=$(-not $SkipLiveRuntime))"
)
