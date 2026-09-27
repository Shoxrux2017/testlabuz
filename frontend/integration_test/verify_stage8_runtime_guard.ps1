param(
    [ValidateRange(1, 65535)][int] $ApiPort = 18008,
    [switch] $SkipLiveRuntime
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage8_runtime_guard.ps1')

function Assert-Stage8Rejected {
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
    "http://stage8.example.invalid:$ApiPort/api/v1",
    "http://192.0.2.8:$ApiPort/api/v1",
    "http://user:pass@127.0.0.1:$ApiPort/api/v1",
    "http://127.0.0.1:$ApiPort/api/v1?unsafe=true",
    "http://127.0.0.1:$ApiPort/api/v1#unsafe",
    "http://127.0.0.1:$ApiPort/api/v2",
    "http://127.0.0.1:$ApiPort/api",
    'http://127.0.0.1/api/v1',
    "http://127.0.0.1:$ApiPort/api/v1/",
    'http://127.0.0.1:0/api/v1',
    'http://127.0.0.1:65536/api/v1',
    'not-a-url'
)
foreach ($target in $invalidTargets) {
    Assert-Stage8Rejected { Resolve-Stage8ApiTarget -ApiBaseUrl $target | Out-Null } 'The Stage 8 guard accepted an invalid API target.'
}
Resolve-Stage8ApiTarget -ApiBaseUrl $approvedUrl | Out-Null

$validContainer = @{
    InspectionCount = 1
    ContainerName = 'testlabuz-stage8-e2e-app'
    Running = $true
    AutoRemove = $false
    WorkingDirectory = '/var/www/html'
    Image = 'testlabuz-app:latest'
    Command = @('php', 'artisan', 'serve', '--host=0.0.0.0', '--port=8000', '--no-reload')
    Platform = 'linux'
    RestartPolicy = 'no'
}
$invalidContainers = @(
    @{ InspectionCount = 0 }, @{ InspectionCount = 2 }, @{ ContainerName = 'testlabuz-app-1' }, @{ ContainerName = 'testlabuz-stage7-e2e-app' },
    @{ Running = $false }, @{ AutoRemove = $true }, @{ RestartPolicy = 'always' }, @{ WorkingDirectory = '/app' }, @{ Image = 'php:8.4-cli' },
    @{ Command = @('php', 'artisan', 'serve', '--host=0.0.0.0', '--port=8000') },
    @{ Command = @('php', 'artisan', 'serve', '--host=0.0.0.0', '--port=8000', '--no-reload', '--tries=1') },
    @{ Command = @() }, @{ Platform = 'windows' }, @{ Platform = '' }
)
foreach ($override in $invalidContainers) {
    $facts = $validContainer.Clone()
    foreach ($name in $override.Keys) { $facts[$name] = $override[$name] }
    Assert-Stage8Rejected { Assert-Stage8ContainerFacts @facts } 'The Stage 8 guard accepted invalid container facts.'
}
Assert-Stage8ContainerFacts @validContainer

$backendSource = Get-Stage8BackendSource
$backendMount = [pscustomobject] @{ Type = 'bind'; Name = ''; Source = $backendSource; Destination = '/var/www/html'; RW = $true }
$privateMount = [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage8-e2e-private-files'; Source = '/docker/volumes/stage8'; Destination = '/var/www/html/storage/app/private'; RW = $true }
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
    @($backendMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage7-e2e-private-files'; Source = '/docker/volumes/stage7'; Destination = '/var/www/html/storage/app/private'; RW = $true }),
    @($backendMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage8-e2e-private-files'; Source = '/docker/volumes/stage8'; Destination = '/var/www/html/storage/app/private'; RW = $false }),
    @($backendMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage8-e2e-private-files'; Source = '/docker/volumes/stage8'; Destination = '/var/www/html/storage/app/public'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage8-e2e-private-files'; Source = '/docker/volumes/stage8'; Destination = '/alias/private'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'volume'; Name = 'testlabuz-stage8-e2e-private-files'; Source = '/docker/volumes/stage8'; Destination = '/var/www/html/public/files'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'bind'; Name = ''; Source = '/unexpected'; Destination = '/var/www/html/storage/app/private/submissions'; RW = $true }),
    @($backendMount, $privateMount, [pscustomobject] @{ Type = 'bind'; Name = ''; Source = '/unexpected'; Destination = '/var/www/html/app'; RW = $true })
)
foreach ($mounts in $invalidMounts) {
    Assert-Stage8Rejected { Assert-Stage8MountFacts -Mounts $mounts -ExpectedBackendSource $backendSource } 'The Stage 8 guard accepted invalid source/private mount facts.'
}
Assert-Stage8MountFacts -Mounts @($backendMount, $privateMount) -ExpectedBackendSource $backendSource

$binding = [pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] $ApiPort }
$invalidBindings = @(
    @{ Configured = @(); Active = @($binding) },
    @{ Configured = @($binding); Active = @() },
    @{ Configured = @([pscustomobject] @{ HostIp = '0.0.0.0'; HostPort = [string] $ApiPort }); Active = @($binding) },
    @{ Configured = @([pscustomobject] @{ HostIp = ''; HostPort = [string] $ApiPort }); Active = @($binding) },
    @{ Configured = @($binding); Active = @([pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] ($ApiPort + 1) }) },
    @{ Configured = @($binding, $binding); Active = @($binding) },
    @{ Configured = @($binding); Active = @($binding, [pscustomobject] @{ HostIp = '::'; HostPort = [string] $ApiPort }) }
)
foreach ($facts in $invalidBindings) {
    Assert-Stage8Rejected {
        Assert-Stage8PortBindingFacts -ConfiguredBindings $facts.Configured -ActiveBindings $facts.Active -ApiPort $ApiPort
    } 'The Stage 8 guard accepted invalid port bindings.'
}
Assert-Stage8PortBindingFacts -ConfiguredBindings @($binding) -ActiveBindings @($binding) -ApiPort $ApiPort

$validServer = @{
    DatabaseHost = 'postgres'; DatabasePort = '5432'; PostgresContainerName = 'testlabuz-postgres-1';
    PostgresImage = 'postgres:18.4'; BackendNetworkPresent = $true; PostgresNetworkPresent = $true; PostgresRunning = $true
}
$invalidServers = @(
    @{ DatabaseHost = 'remote-postgres' }, @{ DatabaseHost = '127.0.0.1' }, @{ DatabasePort = '5433' }, @{ PostgresContainerName = 'baraka-bozor-db-1' },
    @{ PostgresImage = 'postgres:18.3' }, @{ PostgresImage = 'postgres:17-alpine' }, @{ BackendNetworkPresent = $false }, @{ PostgresNetworkPresent = $false }, @{ PostgresRunning = $false }
)
foreach ($override in $invalidServers) {
    $facts = $validServer.Clone()
    foreach ($name in $override.Keys) { $facts[$name] = $override[$name] }
    Assert-Stage8Rejected { Assert-Stage8ServerFacts @facts } 'The Stage 8 guard accepted invalid database/server facts.'
}
Assert-Stage8ServerFacts @validServer

$invalidWorkers = @($null, '', '1', '2', '8', ' 4', '4 ', 'four')
foreach ($value in $invalidWorkers) {
    Assert-Stage8Rejected { Assert-Stage8WorkerEnvironment -Value $value } 'The Stage 8 guard accepted a missing/wrong PHP_CLI_SERVER_WORKERS value.'
}
Assert-Stage8WorkerEnvironment -Value '4'

$serverScript = '/usr/local/bin/php -S 0.0.0.0:8000 /var/www/html/vendor/laravel/framework/src/Illuminate/Foundation/Console/../resources/server.php'
function New-Stage8ProcessSet {
    param([int] $Workers = 4, [string] $ServeCommand = 'php artisan serve --host=0.0.0.0 --port=8000 --no-reload', [switch] $DetachedMaster, [switch] $Scheduler, [switch] $SecondMaster)
    $set = [Collections.Generic.List[object]]::new()
    $set.Add([pscustomobject] @{ pid = 1; ppid = 0; cmd = $ServeCommand })
    $set.Add([pscustomobject] @{ pid = 10; ppid = $(if ($DetachedMaster) { 99 } else { 1 }); cmd = $serverScript })
    for ($i = 0; $i -lt $Workers; $i++) { $set.Add([pscustomobject] @{ pid = 20 + $i; ppid = 10; cmd = $serverScript }) }
    if ($SecondMaster) { $set.Add([pscustomobject] @{ pid = 30; ppid = 1; cmd = $serverScript }) }
    if ($Scheduler) { $set.Add([pscustomobject] @{ pid = 40; ppid = 0; cmd = 'php artisan schedule:work' }) }
    $set.Add([pscustomobject] @{ pid = 50; ppid = 0; cmd = 'php /tmp/testlabuz-stage8-program-0123456789abcdef0123456789abcdef.php' })
    $set.ToArray()
}
$invalidProcessSets = @(
    @(New-Stage8ProcessSet -Workers 0),
    @(New-Stage8ProcessSet -Workers 1),
    @(New-Stage8ProcessSet -Workers 3),
    @(New-Stage8ProcessSet -Workers 5),
    @(New-Stage8ProcessSet -ServeCommand 'php artisan serve --host=0.0.0.0 --port=8000'),
    @(New-Stage8ProcessSet -DetachedMaster),
    @(New-Stage8ProcessSet -SecondMaster),
    @(New-Stage8ProcessSet -Scheduler),
    @()
)
foreach ($processes in $invalidProcessSets) {
    Assert-Stage8Rejected { Assert-Stage8ProcessFacts -Processes $processes } 'The Stage 8 guard accepted a non-forking or unguarded concurrency runtime.'
}
if ((Assert-Stage8ProcessFacts -Processes @(New-Stage8ProcessSet)) -ne 4) { throw 'The Stage 8 guard did not report the observed worker count.' }

$validSession = @{ ClientAddress = '172.19.0.3'; ContainerAddress = '172.19.0.3'; ServerAddress = '172.19.0.2'; PostgresAddress = '172.19.0.2' }
$invalidSessions = @(
    @{ ClientAddress = '172.19.0.9' }, @{ ClientAddress = '' }, @{ ContainerAddress = '' }, @{ ContainerAddress = 'fe80::1' },
    @{ ServerAddress = '172.19.0.7' }, @{ ServerAddress = '' }, @{ PostgresAddress = '' }
)
foreach ($override in $invalidSessions) {
    $facts = $validSession.Clone()
    foreach ($name in $override.Keys) { $facts[$name] = $override[$name] }
    Assert-Stage8Rejected { Assert-Stage8SessionCorrelation @facts } 'The Stage 8 guard accepted an uncorrelated database session.'
}
Assert-Stage8SessionCorrelation @validSession

# Static configuration judged before a stopped container may start.
function New-Stage8Inspection {
    param([hashtable] $Override = @{})
    $environment = [Collections.Generic.List[string]]::new()
    foreach ($entry in @('APP_ENV=testing', 'APP_DEBUG=false', 'DB_CONNECTION=pgsql', 'DB_HOST=postgres', 'DB_PORT=5432', 'DB_DATABASE=testlabuz_testing', 'PHP_CLI_SERVER_WORKERS=4', 'DB_PASSWORD=never-returned')) {
        $name = $entry.Substring(0, $entry.IndexOf('='))
        if ($Override.ContainsKey("env:$name")) { if ($null -ne $Override["env:$name"]) { $environment.Add("$name=$($Override["env:$name"])") } } else { $environment.Add($entry) }
    }
    $bindings = if ($Override.ContainsKey('Bindings')) { $Override['Bindings'] } else { @([pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] $ApiPort }) }
    [pscustomobject] @{
        Name = '/testlabuz-stage8-e2e-app'
        Platform = 'linux'
        State = [pscustomobject] @{ Running = $false }
        Config = [pscustomobject] @{ WorkingDir = '/var/www/html'; Image = 'testlabuz-app:latest'; Cmd = @('php', 'artisan', 'serve', '--host=0.0.0.0', '--port=8000', '--no-reload'); Env = $environment.ToArray() }
        HostConfig = [pscustomobject] @{
            AutoRemove = $false
            RestartPolicy = [pscustomobject] @{ Name = 'no' }
            NetworkMode = $(if ($Override.ContainsKey('NetworkMode')) { $Override['NetworkMode'] } else { 'testlabuz_default' })
            PortBindings = [pscustomobject] @{ '8000/tcp' = $bindings }
        }
        Mounts = @($backendMount, $privateMount)
    }
}
$invalidConfigurations = @(
    @{ Bindings = @([pscustomobject] @{ HostIp = '0.0.0.0'; HostPort = [string] $ApiPort }) }, @{ Bindings = @() },
    @{ Bindings = @([pscustomobject] @{ HostIp = '127.0.0.1'; HostPort = [string] ($ApiPort + 1) }) },
    @{ 'env:DB_DATABASE' = 'testlabuz' }, @{ 'env:DB_DATABASE' = 'testlabuz_demo' }, @{ 'env:APP_ENV' = 'local' }, @{ 'env:DB_HOST' = 'remote' },
    @{ 'env:PHP_CLI_SERVER_WORKERS' = $null }, @{ 'env:PHP_CLI_SERVER_WORKERS' = '1' }, @{ 'env:APP_DEBUG' = $null },
    @{ NetworkMode = 'bridge' }, @{ NetworkMode = 'host' }, @{ NetworkMode = '' }
)
foreach ($override in $invalidConfigurations) {
    Assert-Stage8Rejected { Assert-Stage8ContainerConfiguration -Inspection (New-Stage8Inspection $override) -ApiPort $ApiPort | Out-Null } 'The Stage 8 guard accepted a stopped container with an unsafe static configuration.'
}
$named = Assert-Stage8ContainerConfiguration -Inspection (New-Stage8Inspection) -ApiPort $ApiPort
if ($named.ContainsKey('DB_PASSWORD') -or $named['DB_DATABASE'] -cne 'testlabuz_testing') { throw 'The Stage 8 guard returned an environment value it must never read.' }

$own = [pscustomobject] @{ client_addr = '172.19.0.3' }
Assert-Stage8DatabaseExclusivity ([pscustomobject] @{ sessions = @() }) '172.19.0.3'
Assert-Stage8DatabaseExclusivity ([pscustomobject] @{ sessions = @($own, $own) }) '172.19.0.3'
$invalidExclusivity = @(
    [pscustomobject] @{ sessions = @([pscustomobject] @{ client_addr = '172.19.0.9' }) },
    [pscustomobject] @{ sessions = @($own, [pscustomobject] @{ client_addr = $null }) },
    [pscustomobject] @{ sessions = @([pscustomobject] @{ client_addr = '172.19.0.30' }) },
    [pscustomobject] @{}
)
foreach ($facts in $invalidExclusivity) {
    Assert-Stage8Rejected { Assert-Stage8DatabaseExclusivity $facts '172.19.0.3' } 'The Stage 8 guard accepted another client on testlabuz_testing.'
}

$validLaravel = [pscustomobject] @{
    environment = 'testing'; debug = $false; database_default = 'pgsql'; connection_driver = 'pgsql';
    pdo_driver = 'pgsql'; database = 'testlabuz_testing'; pending_migrations = 0
    database_host = 'postgres'; database_port = '5432'
    private_disk = 'local'; private_driver = 'local'; private_public = $false
    private_root = '/var/www/html/storage/app/private'; public_root = '/var/www/html/storage/app/public'
}
$invalidLaravel = @(
    @{ environment = 'local' }, @{ environment = 'production' }, @{ debug = $true }, @{ database_default = 'sqlite' },
    @{ connection_driver = 'mysql' }, @{ pdo_driver = 'mysql' }, @{ database = 'testlabuz' }, @{ database = 'testlabuz_demo' },
    @{ database_host = 'other' }, @{ database_port = '5433' }, @{ pending_migrations = 1 },
    @{ private_disk = '' }, @{ private_disk = 'public' }, @{ private_driver = 's3' }, @{ private_public = $true },
    @{ private_root = '/var/www/html/storage/app/public' }, @{ private_root = '/var/www/html/storage/app/private/../public' },
    @{ public_root = '/var/www/html/storage/app/private' }
)
foreach ($override in $invalidLaravel) {
    $facts = $validLaravel | Select-Object *
    foreach ($name in $override.Keys) { $facts.$name = $override[$name] }
    Assert-Stage8Rejected { Assert-Stage8LaravelFacts -Facts $facts } 'The Stage 8 guard accepted invalid Laravel/database facts.'
}
Assert-Stage8LaravelFacts -Facts $validLaravel

$validEnvelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{} }
$invalidHttpFacts = @(
    @{ Status = 200; Envelope = $validEnvelope },
    @{ Status = 500; Envelope = [pscustomobject] @{ message = 'Server error.'; code = 'server_error'; errors = [pscustomobject] @{} } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'wrong'; errors = [pscustomobject] @{} } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = ''; code = 'authentication_required'; errors = [pscustomobject] @{} } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{ token = @('unsafe') } } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required'; errors = [pscustomobject] @{}; request_id = 'unexpected' } },
    @{ Status = 401; Envelope = [pscustomobject] @{ message = 'Authentication is required.'; code = 'authentication_required' } }
)
foreach ($facts in $invalidHttpFacts) {
    Assert-Stage8Rejected { Assert-Stage8HttpBoundaryFacts -StatusCode $facts.Status -Envelope $facts.Envelope } 'The Stage 8 guard accepted an invalid HTTP boundary.'
}
Assert-Stage8HttpBoundaryFacts -StatusCode 401 -Envelope $validEnvelope

$apiTarget = Resolve-Stage8ApiTarget -ApiBaseUrl $approvedUrl
foreach ($wrong in @('testlabuz-app-1', 'testlabuz-stage7-e2e-app', 'testlabuz-demo-app')) {
    Assert-Stage8Rejected { Invoke-Stage8ContainerPhp -BackendContainerName $wrong -Program 'echo "{}";' } 'The Stage 8 PHP transport accepted the wrong container.'
    Assert-Stage8Rejected { Assert-Stage8DedicatedRuntime -ApiTarget $apiTarget -BackendContainerName $wrong | Out-Null } 'The Stage 8 guard accepted the wrong backend container.'
}

if (-not $SkipLiveRuntime) {
    $runtime = Assert-Stage8DedicatedRuntime -ApiTarget $apiTarget
    Assert-Stage8ExclusiveDatabase -ClientAddress $runtime.ClientAddress
    # Transport: input over stdin, safe refusals pass through redacted, everything else stays generic, time is bounded.
    if ((Invoke-Stage8ContainerPhp -Program 'echo json_encode(["echo" => $stage8Input["value"]], JSON_THROW_ON_ERROR);' -InputJson '{"value":"stage8-stdin-probe"}').echo -cne 'stage8-stdin-probe') {
        throw 'The Stage 8 PHP transport did not deliver its input over stdin.'
    }
    $messages = @{}
    $probes = @{
        refusal = @{ Program = 'throw new RuntimeException("Stage 8 verifier refusal probe.");'; Input = '{}'; Timeout = 60 }
        redacted = @{ Program = 'throw new RuntimeException("Stage 8 verifier echoes " . $stage8Input["password"] . ".");'; Input = '{"password":"stage8-canary-secret"}'; Timeout = 60 }
        generic = @{ Program = 'throw new LogicException("stage8-canary-internal");'; Input = '{}'; Timeout = 60 }
        subclass = @{ Program = 'throw new UnexpectedValueException("Stage 8 subclass must stay generic.");'; Input = '{}'; Timeout = 60 }
        timeout = @{ Program = 'sleep(5); echo "{}";'; Input = '{}'; Timeout = 1 }
    }
    foreach ($name in $probes.Keys) {
        try { Invoke-Stage8ContainerPhp -Program $probes[$name].Program -InputJson $probes[$name].Input -TimeoutSeconds $probes[$name].Timeout | Out-Null; $messages[$name] = '' }
        catch { $messages[$name] = $_.Exception.Message }
    }
    if ($messages.refusal -cne 'Stage 8 container PHP refused: Stage 8 verifier refusal probe.' -or
        $messages.redacted -cne 'Stage 8 container PHP refused: Stage 8 verifier echoes [REDACTED].' -or
        $messages.generic -cnotlike 'Stage 8 container PHP operation failed*' -or $messages.generic -clike '*canary*' -or
        $messages.subclass -cnotlike 'Stage 8 container PHP operation failed*' -or
        $messages.timeout -cnotlike 'environment/runtime defect: Stage 8 container PHP timed out*') {
        throw 'The Stage 8 PHP transport reported a failure unsafely or not at all.'
    }
    Write-Output "Stage8RuntimeGuardLive: PASS target=$($runtime.ApiBaseUrl) database=$($runtime.Database) workers=$($runtime.Workers) client=$($runtime.ClientAddress) exclusive=True transport=5"
}

Write-Output (
    'Stage8RuntimeGuardMatrix: PASS ' +
    "($($invalidTargets.Count) targets, $($invalidContainers.Count) container identities, $($invalidMounts.Count) mount shapes, " +
    "$($invalidBindings.Count) bindings, $($invalidServers.Count) server identities, $($invalidWorkers.Count) worker values, " +
    "$($invalidProcessSets.Count) process sets, $($invalidSessions.Count) session correlations, $($invalidConfigurations.Count) static configurations, $($invalidExclusivity.Count) exclusivity facts, " +
    "$($invalidLaravel.Count) Laravel/database facts, $($invalidHttpFacts.Count) HTTP envelopes, " +
    "3 wrong containers; live=$(-not $SkipLiveRuntime))"
)
