param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65535)]
    [int] $ApiPort
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage5_runtime_guard.ps1')

function Assert-Stage5Rejected {
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
    "http://stage5.example.invalid:$ApiPort/api/v1",
    "http://192.0.2.5:$ApiPort/api/v1",
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
    Assert-Stage5Rejected { Resolve-Stage5ApiTarget -ApiBaseUrl $target | Out-Null } 'The Stage 5 guard accepted an invalid API target.'
}

$validContainer = @{
    InspectionCount = 1
    ContainerName = 'testlabuz-stage5-e2e-app'
    Running = $true
    AutoRemove = $false
    WorkingDirectory = '/var/www/html'
}
$invalidContainers = @(
    @{ InspectionCount = 0 },
    @{ InspectionCount = 2 },
    @{ ContainerName = 'testlabuz-app-1' },
    @{ Running = $false },
    @{ AutoRemove = $true },
    @{ WorkingDirectory = '/app' }
)
foreach ($override in $invalidContainers) {
    $facts = $validContainer.Clone()
    foreach ($name in $override.Keys) { $facts[$name] = $override[$name] }
    Assert-Stage5Rejected { Assert-Stage5ContainerFacts @facts } 'The Stage 5 guard accepted invalid container facts.'
}

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$backendSource = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'backend')).Path
$backendMount = [pscustomobject] @{ Type = 'bind'; Name = ''; Source = $backendSource; Destination = '/var/www/html'; RW = $true }
$privateMount = [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage5-e2e-private-files'; Source = '/docker/volumes/stage5'; Destination = '/var/www/html/storage/app/private'; RW = $true }
$invalidMounts = @(
    @($privateMount),
    @([pscustomobject] @{ Type = 'bind'; Name = ''; Source = (Split-Path -Parent $backendSource); Destination = '/var/www/html'; RW = $true }, $privateMount),
    @([pscustomobject] @{ Type = 'bind'; Name = ''; Source = $backendSource; Destination = '/var/www/html'; RW = $false }, $privateMount),
    @($backendMount),
    @($backendMount, [pscustomobject] @{ Type = 'volume'; Name = 'wrong-volume'; Source = '/docker/volumes/wrong'; Destination = '/var/www/html/storage/app/private'; RW = $true }),
    @($backendMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage5-e2e-private-files'; Source = '/docker/volumes/stage5'; Destination = '/var/www/html/storage/app/private'; RW = $false }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage5-e2e-private-files'; Source = '/docker/volumes/stage5'; Destination = '/alias/private'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage5-e2e-private-files'; Source = '/docker/volumes/stage5'; Destination = '/var/www/html/storage/app/public'; RW = $true })
)
foreach ($mounts in $invalidMounts) {
    Assert-Stage5Rejected { Assert-Stage5MountFacts -Mounts $mounts -ExpectedBackendSource $backendSource } 'The Stage 5 guard accepted invalid source/private mount facts.'
}
Assert-Stage5MountFacts -Mounts @($backendMount, $privateMount) -ExpectedBackendSource $backendSource

$binding = [pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] $ApiPort }
$invalidBindings = @(
    @{ Configured = @(); Active = @($binding) },
    @{ Configured = @($binding); Active = @() },
    @{ Configured = @([pscustomobject] @{ HostIp = '0.0.0.0'; HostPort = [string] $ApiPort }); Active = @($binding) },
    @{ Configured = @($binding); Active = @([pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] ($ApiPort + 1) }) },
    @{ Configured = @($binding, $binding); Active = @($binding) }
)
foreach ($facts in $invalidBindings) {
    Assert-Stage5Rejected {
        Assert-Stage5PortBindingFacts -ConfiguredBindings $facts.Configured -ActiveBindings $facts.Active -ApiPort $ApiPort
    } 'The Stage 5 guard accepted invalid port bindings.'
}
Assert-Stage5PortBindingFacts -ConfiguredBindings @($binding) -ActiveBindings @($binding) -ApiPort $ApiPort

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
    Assert-Stage5Rejected { Assert-Stage5ServerFacts @facts } 'The Stage 5 guard accepted invalid database/server facts.'
}
Assert-Stage5ServerFacts @validServer

$validLaravel = [pscustomobject] @{
    environment = 'testing'; debug = $false; database_default = 'pgsql'; connection_driver = 'pgsql'; pdo_driver = 'pgsql';
    database = 'testlabuz_testing'; pending_migrations = 0; private_disk = 'local'; private_driver = 'local';
    private_root = '/var/www/html/storage/app/private'; public_root = '/var/www/html/storage/app/public'; private_public = $false;
    file_uploads = $true; upload_max_bytes = 33554432; post_max_bytes = 41943040
}
$invalidLaravel = @(
    @{ environment = 'local' }, @{ debug = $true }, @{ database_default = 'sqlite' }, @{ connection_driver = 'mysql' },
    @{ pdo_driver = 'mysql' }, @{ database = 'testlabuz' }, @{ pending_migrations = 1 }, @{ private_disk = 'public' },
    @{ private_driver = 's3' }, @{ private_root = '/wrong/private' }, @{ public_root = '/var/www/html/storage/app/private' },
    @{ private_public = $true }, @{ file_uploads = $false }, @{ upload_max_bytes = 33554431 }, @{ post_max_bytes = 41943039 }
)
foreach ($override in $invalidLaravel) {
    $facts = $validLaravel | Select-Object *
    foreach ($name in $override.Keys) { $facts.$name = $override[$name] }
    Assert-Stage5Rejected { Assert-Stage5LaravelFacts -Facts $facts } 'The Stage 5 guard accepted invalid Laravel/storage/PHP facts.'
}
Assert-Stage5LaravelFacts -Facts $validLaravel

$invalidProbes = @(
    @{ WriteSucceeded = $false; ReadHashMatched = $true; DeleteSucceeded = $true; AbsentAfterDelete = $true },
    @{ WriteSucceeded = $true; ReadHashMatched = $false; DeleteSucceeded = $true; AbsentAfterDelete = $true },
    @{ WriteSucceeded = $true; ReadHashMatched = $true; DeleteSucceeded = $false; AbsentAfterDelete = $true },
    @{ WriteSucceeded = $true; ReadHashMatched = $true; DeleteSucceeded = $true; AbsentAfterDelete = $false }
)
foreach ($facts in $invalidProbes) {
    Assert-Stage5Rejected { Assert-Stage5PrivateProbeFacts @facts } 'The Stage 5 guard accepted a failed private-storage probe.'
}
Assert-Stage5PrivateProbeFacts -WriteSucceeded $true -ReadHashMatched $true -DeleteSucceeded $true -AbsentAfterDelete $true

$validEnvelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{} }
$invalidHttpFacts = @(
    @{ Status = 200; Envelope = $validEnvelope },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'wrong'; errors = [pscustomobject] @{} } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{ token = @('unsafe') } } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{}; secret = 'unsafe' } }
)
foreach ($facts in $invalidHttpFacts) {
    Assert-Stage5Rejected { Assert-Stage5HttpBoundaryFacts -StatusCode $facts.Status -Envelope $facts.Envelope } 'The Stage 5 guard accepted an invalid HTTP boundary.'
}
Assert-Stage5HttpBoundaryFacts -StatusCode 401 -Envelope $validEnvelope

$apiTarget = Resolve-Stage5ApiTarget -ApiBaseUrl $approvedUrl
Assert-Stage5Rejected {
    Assert-Stage5DedicatedRuntime -ApiTarget $apiTarget -BackendContainerName 'testlabuz-app-1' | Out-Null
} 'The Stage 5 guard accepted the wrong backend container.'

$unboundPort = if ($ApiPort -eq 65535) { 65534 } else { $ApiPort + 1 }
$unboundTarget = Resolve-Stage5ApiTarget -ApiBaseUrl "http://127.0.0.1:$unboundPort/api/v1"
Assert-Stage5Rejected { Assert-Stage5DedicatedRuntime -ApiTarget $unboundTarget | Out-Null } 'The Stage 5 guard accepted an unbound port.'

$runtime = Assert-Stage5DedicatedRuntime -ApiTarget $apiTarget
Write-Output (
    'Stage5RuntimeGuardMatrix: PASS ' +
    "($($invalidTargets.Count) targets, $($invalidContainers.Count) container identities, $($invalidMounts.Count) mount shapes, " +
    "$($invalidBindings.Count) bindings, $($invalidServers.Count) server identities, $($invalidLaravel.Count) Laravel/storage/PHP facts, " +
    "$($invalidProbes.Count) private probes, $($invalidHttpFacts.Count) HTTP envelopes, wrong container, unbound port, approved $($runtime.ApiBaseUrl))"
)
