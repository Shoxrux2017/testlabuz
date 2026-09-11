param(
    [ValidateRange(1, 65535)][int] $ApiPort = 18007,
    [switch] $SkipLiveRuntime
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage7_runtime_guard.ps1')

function Assert-Stage7Rejected {
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
    "http://stage7.example.invalid:$ApiPort/api/v1",
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
    Assert-Stage7Rejected { Resolve-Stage7ApiTarget -ApiBaseUrl $target | Out-Null } 'The Stage 7 guard accepted an invalid API target.'
}

$validContainer = @{
    InspectionCount = 1
    ContainerName = 'testlabuz-stage7-e2e-app'
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
    Assert-Stage7Rejected { Assert-Stage7ContainerFacts @facts } 'The Stage 7 guard accepted invalid container facts.'
}

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$backendSource = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'backend')).Path
$backendMount = [pscustomobject] @{ Type = 'bind'; Name = ''; Source = $backendSource; Destination = '/var/www/html'; RW = $true }
$privateMount = [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage7-e2e-private-files'; Source = '/docker/volumes/stage7'; Destination = '/var/www/html/storage/app/private'; RW = $true }
$invalidMounts = @(
    @(),
    @($privateMount),
    @([pscustomobject] @{ Type = 'bind'; Name = ''; Source = (Split-Path -Parent $backendSource); Destination = '/var/www/html'; RW = $true }, $privateMount),
    @([pscustomobject] @{ Type = 'bind'; Name = ''; Source = $backendSource; Destination = '/var/www/html'; RW = $false }, $privateMount),
    @($backendMount, $backendMount, $privateMount),
    @([pscustomobject] @{ Type = 'volume'; Name = 'wrong'; Source = '/wrong'; Destination = '/var/www/html'; RW = $true }, $privateMount),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'bind'; Name = ''; Source = $backendSource; Destination = '/alias/backend'; RW = $true }),
    @($backendMount),
    @($backendMount, $privateMount, $privateMount),
    @($backendMount, [pscustomobject] @{ Type = 'volume'; Name = 'wrong'; Source = '/wrong'; Destination = '/var/www/html/storage/app/private'; RW = $true }),
    @($backendMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage7-e2e-private-files'; Source = '/docker/volumes/stage7'; Destination = '/var/www/html/storage/app/private'; RW = $false }),
    @($backendMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage7-e2e-private-files'; Source = '/docker/volumes/stage7'; Destination = '/var/www/html/storage/app/public'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage7-e2e-private-files'; Source = '/docker/volumes/stage7'; Destination = '/alias/private'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage7-e2e-private-files'; Source = '/docker/volumes/stage7'; Destination = '/var/www/html/storage/app/public'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'bind'; Name = ''; Source = '/unexpected'; Destination = '/var/www/html/storage/app/private/submissions'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'bind'; Name = ''; Source = '/unexpected'; Destination = '/var/www/html/app'; RW = $true })
)
foreach ($mounts in $invalidMounts) {
    Assert-Stage7Rejected { Assert-Stage7MountFacts -Mounts $mounts -ExpectedBackendSource $backendSource } 'The Stage 7 guard accepted invalid source mount facts.'
}
Assert-Stage7MountFacts -Mounts @($backendMount, $privateMount) -ExpectedBackendSource $backendSource
Assert-Stage7ContainerFacts @validContainer

$binding = [pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] $ApiPort }
$invalidBindings = @(
    @{ Configured = @(); Active = @($binding) },
    @{ Configured = @($binding); Active = @() },
    @{ Configured = @([pscustomobject] @{ HostIp = '0.0.0.0'; HostPort = [string] $ApiPort }); Active = @($binding) },
    @{ Configured = @($binding); Active = @([pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] ($ApiPort + 1) }) },
    @{ Configured = @($binding, $binding); Active = @($binding) }
)
foreach ($facts in $invalidBindings) {
    Assert-Stage7Rejected {
        Assert-Stage7PortBindingFacts -ConfiguredBindings $facts.Configured -ActiveBindings $facts.Active -ApiPort $ApiPort
    } 'The Stage 7 guard accepted invalid port bindings.'
}
Assert-Stage7PortBindingFacts -ConfiguredBindings @($binding) -ActiveBindings @($binding) -ApiPort $ApiPort

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
    Assert-Stage7Rejected { Assert-Stage7ServerFacts @facts } 'The Stage 7 guard accepted invalid database/server facts.'
}
Assert-Stage7ServerFacts @validServer

$validLaravel = [pscustomobject] @{
    environment = 'testing'; debug = $false; database_default = 'pgsql'; connection_driver = 'pgsql';
    pdo_driver = 'pgsql'; database = 'testlabuz_testing'; pending_migrations = 0
    database_host = 'postgres'; database_port = '5432'
    private_disk = 'local'; private_driver = 'local'; private_public = $false
    private_root = '/var/www/html/storage/app/private'; public_root = '/var/www/html/storage/app/public'
}
$invalidLaravel = @(
    @{ environment = 'local' }, @{ debug = $true }, @{ database_default = 'sqlite' },
    @{ connection_driver = 'mysql' }, @{ pdo_driver = 'mysql' }, @{ database = 'testlabuz' }, @{ database_host = 'other' }, @{ database_port = '5433' }, @{ pending_migrations = 1 },
    @{ private_disk = '' }, @{ private_disk = 'public' }, @{ private_driver = 's3' }, @{ private_public = $true },
    @{ private_root = '/var/www/html/storage/app/public' }, @{ private_root = '/var/www/html/storage/app/private/../public' },
    @{ public_root = '/var/www/html/storage/app/private' }
)
foreach ($override in $invalidLaravel) {
    $facts = $validLaravel | Select-Object *
    foreach ($name in $override.Keys) { $facts.$name = $override[$name] }
    Assert-Stage7Rejected { Assert-Stage7LaravelFacts -Facts $facts } 'The Stage 7 guard accepted invalid Laravel/database facts.'
}
Assert-Stage7LaravelFacts -Facts $validLaravel

$validEnvelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{} }
$invalidHttpFacts = @(
    @{ Status = 200; Envelope = $validEnvelope },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'wrong'; errors = [pscustomobject] @{} } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{ token = @('unsafe') } } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{}; secret = 'unsafe' } }
)
foreach ($facts in $invalidHttpFacts) {
    Assert-Stage7Rejected { Assert-Stage7HttpBoundaryFacts -StatusCode $facts.Status -Envelope $facts.Envelope } 'The Stage 7 guard accepted an invalid HTTP boundary.'
}
Assert-Stage7HttpBoundaryFacts -StatusCode 401 -Envelope $validEnvelope

$apiTarget = Resolve-Stage7ApiTarget -ApiBaseUrl $approvedUrl
Assert-Stage7Rejected {
    Invoke-Stage7ContainerPhp -BackendContainerName 'testlabuz-app-1' -Program 'echo "{}";'
} 'The Stage 7 PHP transport accepted the wrong container.'
Assert-Stage7Rejected {
    Assert-Stage7DedicatedRuntime -ApiTarget $apiTarget -BackendContainerName 'testlabuz-app-1' | Out-Null
} 'The Stage 7 guard accepted the wrong backend container.'

if (-not $SkipLiveRuntime) {
    $runtime = Assert-Stage7DedicatedRuntime -ApiTarget $apiTarget
    Write-Output "Stage7RuntimeGuardLive: PASS target=$($runtime.ApiBaseUrl) database=$($runtime.Database)"
}

Write-Output (
    'Stage7RuntimeGuardMatrix: PASS ' +
    "($($invalidTargets.Count) targets, $($invalidContainers.Count) container identities, $($invalidMounts.Count) mount shapes, " +
    "$($invalidBindings.Count) bindings, $($invalidServers.Count) server identities, $($invalidLaravel.Count) Laravel/database facts, " +
    "$($invalidHttpFacts.Count) HTTP envelopes, wrong container; live=$(-not $SkipLiveRuntime))"
)
