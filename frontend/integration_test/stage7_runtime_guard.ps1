Set-StrictMode -Version Latest

$script:Stage7BackendContainerName = 'testlabuz-stage7-e2e-app'
$script:Stage7BackendContainerPort = '8000/tcp'
$script:Stage7PostgresContainerName = 'testlabuz-postgres-1'
$script:Stage7PostgresImage = 'postgres:18.4'
$script:Stage7DockerNetworkName = 'testlabuz_default'
$script:Stage7BackendRoot = '/var/www/html'
$script:Stage7PrivateRoot = '/var/www/html/storage/app/private'
$script:Stage7PrivateVolumeName = 'testlabuz-stage7-e2e-private-files'

# Only the short wrapper/path reaches argv. Program and optional inputs travel over stdin.
function Invoke-Stage7ContainerPhp {
    param(
        [Parameter(Mandatory = $true)][string] $Program,
        [string] $InputJson = '{}',
        [string] $BackendContainerName = $script:Stage7BackendContainerName
    )
    if ($BackendContainerName -cne $script:Stage7BackendContainerName) {
        throw 'Stage 7 PHP transport requires the exact dedicated backend container.'
    }
    $containerPath = '/tmp/testlabuz-stage7-program-' + [guid]::NewGuid().ToString('N') + '.php'
    $encodedInput = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($InputJson))
    $bootstrap = @'
<?php
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
require '/var/www/html/vendor/autoload.php';
$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
'@
    $content = $bootstrap + "`n" + '$stage7Input = json_decode(base64_decode(' + "'$encodedInput'" + '), true, 512, JSON_THROW_ON_ERROR);' + "`n" + $Program
    try {
        $originalOutputEncoding = $OutputEncoding
        try {
            $OutputEncoding = [Text.UTF8Encoding]::new($false)
            $null = @($content | & docker exec -i $BackendContainerName sh -c "umask 077; set -C; cat > '$containerPath'" 2>&1)
            if ($LASTEXITCODE -ne 0) { throw 'Stage 7 restricted PHP transport failed.' }
        }
        finally { $OutputEncoding = $originalOutputEncoding }
        $output = @(& docker exec $BackendContainerName php $containerPath 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'Stage 7 container PHP operation failed; raw output withheld.' }
        try { return (($output -join "`n") | ConvertFrom-Json) }
        catch { throw 'Stage 7 container PHP operation returned invalid JSON; raw output withheld.' }
    }
    catch { throw 'Stage 7 container PHP operation failed; raw diagnostics withheld to protect inputs.' }
    finally {
        $content = $null; $encodedInput = $null; $InputJson = $null; $output = $null
        $null = @(& docker exec $BackendContainerName rm -f -- $containerPath 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'Stage 7 restricted container-script cleanup failed.' }
    }
}

function Resolve-Stage7ApiTarget {
    param([Parameter(Mandatory = $true)][string] $ApiBaseUrl)

    $match = [regex]::Match(
        $ApiBaseUrl,
        '\Ahttp://127\.0\.0\.1:(?<port>[0-9]{1,5})/api/v1\z',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $match.Success) {
        throw 'Stage 7 E2E requires exactly http://127.0.0.1:<explicit-port>/api/v1.'
    }
    $port = [int] $match.Groups['port'].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw 'Stage 7 E2E requires an explicit port between 1 and 65535.'
    }
    try {
        $uri = [Uri] $ApiBaseUrl
    }
    catch {
        throw 'The Stage 7 E2E API target is malformed.'
    }
    if (
        -not $uri.IsAbsoluteUri -or
        $uri.Scheme -cne 'http' -or
        $uri.Host -cne '127.0.0.1' -or
        $uri.Port -ne $port -or
        $uri.AbsolutePath -cne '/api/v1' -or
        $uri.UserInfo -ne '' -or
        $uri.Query -ne '' -or
        $uri.Fragment -ne ''
    ) {
        throw 'The Stage 7 E2E API target is outside the dedicated loopback boundary.'
    }

    [pscustomobject] @{ BaseUrl = $ApiBaseUrl; Port = $port }
}

function Assert-Stage7ContainerFacts {
    param(
        [Parameter(Mandatory = $true)][int] $InspectionCount,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $ContainerName,
        [Parameter(Mandatory = $true)][bool] $Running,
        [Parameter(Mandatory = $true)][bool] $AutoRemove,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $WorkingDirectory
    )

    if ($InspectionCount -ne 1 -or $ContainerName -cne $script:Stage7BackendContainerName) {
        throw 'The dedicated Stage 7 backend container identity is missing or ambiguous.'
    }
    if (-not $Running) { throw 'The dedicated Stage 7 backend container must be running.' }
    if ($AutoRemove) { throw 'The dedicated Stage 7 backend container must be restartable.' }
    if ($WorkingDirectory -cne $script:Stage7BackendRoot) {
        throw 'The dedicated Stage 7 backend working directory is unsafe.'
    }
}

function Assert-Stage7MountFacts {
    param(
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]] $Mounts,
        [Parameter(Mandatory = $true)][string] $ExpectedBackendSource
    )

    $resolvedExpected = [IO.Path]::GetFullPath($ExpectedBackendSource).TrimEnd('\', '/')
    $backendMounts = @($Mounts | Where-Object { $_.Destination -ceq $script:Stage7BackendRoot })
    if ($backendMounts.Count -ne 1) {
        throw 'The exact Stage 7 backend source bind is missing or ambiguous.'
    }
    $backendMount = $backendMounts[0]
    $resolvedSource = [IO.Path]::GetFullPath([string] $backendMount.Source).TrimEnd('\', '/')
    if (
        [string] $backendMount.Type -cne 'bind' -or
        [bool] $backendMount.RW -ne $true -or
        -not $resolvedSource.Equals($resolvedExpected, [StringComparison]::OrdinalIgnoreCase)
    ) {
        throw 'The Stage 7 backend source bind does not own the current repository backend.'
    }
    foreach ($mount in $Mounts) {
        if ($mount -eq $backendMount) { continue }
        if ([string] $mount.Type -ceq 'bind' -and
            [IO.Path]::GetFullPath([string] $mount.Source).TrimEnd('\', '/').Equals($resolvedExpected, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'The Stage 7 backend source has an ambiguous alias mount.'
        }
    }
    $privateMounts = @($Mounts | Where-Object { $_.Destination -ceq $script:Stage7PrivateRoot })
    if ($privateMounts.Count -ne 1) { throw 'The Stage 7 private root mount is missing or ambiguous.' }
    $privateMount = $privateMounts[0]
    if ([string] $privateMount.Type -cne 'volume' -or
        [string] $privateMount.Name -cne $script:Stage7PrivateVolumeName -or
        [bool] $privateMount.RW -ne $true) {
        throw 'Stage 7 private storage requires the exact read/write named volume.'
    }
    foreach ($mount in $Mounts) {
        if ($mount -eq $privateMount) { continue }
        $name = if ($null -eq $mount.PSObject.Properties['Name']) { '' } else { [string] $mount.Name }
        if ($name -ceq $script:Stage7PrivateVolumeName -or [string] $mount.Source -ceq [string] $privateMount.Source) {
            throw 'Stage 7 private storage is exposed by an alias mount.'
        }
        if ([string] $mount.Destination -clike ($script:Stage7PrivateRoot + '/*')) {
            throw 'An additional mount shadows the Stage 7 private volume.'
        }
        if ($mount -ne $backendMount) {
            $destination = ([string] $mount.Destination).TrimEnd('/')
            if ($destination -clike ($script:Stage7BackendRoot + '/*') -or
                $script:Stage7BackendRoot.StartsWith($destination + '/', [StringComparison]::Ordinal)) {
                throw 'An unexpected mount shadows the current Stage 7 backend source.'
            }
        }
    }
}

function Assert-Stage7PortBindingFacts {
    param(
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]] $ConfiguredBindings,
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]] $ActiveBindings,
        [Parameter(Mandatory = $true)][int] $ApiPort
    )

    foreach ($bindings in @($ConfiguredBindings, $ActiveBindings)) {
        if (
            $bindings.Count -ne 1 -or
            [string] $bindings[0].HostIp -cne '127.0.0.1' -or
            [string] $bindings[0].HostPort -cne [string] $ApiPort
        ) {
            throw 'The selected Stage 7 API port is not actively bound exactly once to loopback.'
        }
    }
}

function Assert-Stage7ServerFacts {
    param(
        [Parameter(Mandatory = $true)][string] $DatabaseHost,
        [Parameter(Mandatory = $true)][string] $DatabasePort,
        [Parameter(Mandatory = $true)][string] $PostgresContainerName,
        [Parameter(Mandatory = $true)][string] $PostgresImage,
        [Parameter(Mandatory = $true)][bool] $BackendNetworkPresent,
        [Parameter(Mandatory = $true)][bool] $PostgresNetworkPresent,
        [Parameter(Mandatory = $true)][bool] $PostgresRunning
    )

    if ($DatabaseHost -cne 'postgres' -or $DatabasePort -cne '5432') {
        throw 'The dedicated Stage 7 runtime has an unapproved database server target.'
    }
    if ($PostgresContainerName -cne $script:Stage7PostgresContainerName -or $PostgresImage -cne $script:Stage7PostgresImage) {
        throw 'The dedicated Stage 7 runtime has an unapproved PostgreSQL identity.'
    }
    if (-not $BackendNetworkPresent -or -not $PostgresNetworkPresent -or -not $PostgresRunning) {
        throw 'The approved Stage 7 PostgreSQL server/network is unavailable.'
    }
}

function Assert-Stage7LaravelFacts {
    param([Parameter(Mandatory = $true)][psobject] $Facts)

    if (
        [string] $Facts.environment -cne 'testing' -or
        [bool] $Facts.debug -ne $false -or
        [string] $Facts.database_default -cne 'pgsql' -or
        [string] $Facts.connection_driver -cne 'pgsql' -or
        [string] $Facts.pdo_driver -cne 'pgsql' -or
        [string] $Facts.database -cne 'testlabuz_testing' -or
        [string] $Facts.database_host -cne 'postgres' -or
        [string] $Facts.database_port -cne '5432' -or
        [int] $Facts.pending_migrations -ne 0
    ) {
        throw 'The Stage 7 Laravel/database runtime identity is unsafe.'
    }
    if ([string]::IsNullOrWhiteSpace([string] $Facts.private_disk) -or
        [string] $Facts.private_disk -ceq 'public' -or
        [string] $Facts.private_driver -cne 'local' -or
        [bool] $Facts.private_public -ne $false -or
        [string] $Facts.private_root -cnotmatch '\A/var/www/html/storage/app/private(?:/[^/]+)*\z' -or
        [string] $Facts.private_root -match '/(?:\.|\.\.)(?:/|$)|\\' -or
        [string] $Facts.private_root -ceq [string] $Facts.public_root) {
        throw 'The Stage 7 configured private disk/root is unsafe.'
    }
}

function Assert-Stage7HttpBoundaryFacts {
    param(
        [Parameter(Mandatory = $true)][int] $StatusCode,
        [Parameter(Mandatory = $true)][object] $Envelope
    )

    if ($StatusCode -ne 401) { throw 'The Stage 7 HTTP protected boundary returned the wrong status.' }
    $properties = @($Envelope.PSObject.Properties.Name)
    $allowed = @('message', 'code', 'errors', 'request_id')
    if (
        [string] $Envelope.code -cne 'authentication_required' -or
        $Envelope.errors -isnot [pscustomobject] -or
        $Envelope.message -isnot [string] -or
        $null -eq $Envelope.errors -or
        @($Envelope.errors.PSObject.Properties).Count -ne 0 -or
        @($properties | Where-Object { $_ -cnotin $allowed }).Count -ne 0 -or
        @(@('message', 'code', 'errors') | Where-Object { $_ -cnotin $properties }).Count -ne 0
    ) {
        throw 'The Stage 7 HTTP protected boundary returned an unsafe envelope.'
    }
}

function Get-Stage7ErrorResponseBody {
    param([Parameter(Mandatory = $true)][object] $Exception)

    $response = $Exception.Response
    if ($null -eq $response) { return $null }
    $contentProperty = $response.PSObject.Properties['Content']
    if ($null -ne $contentProperty -and $null -ne $contentProperty.Value) {
        return $contentProperty.Value.ReadAsStringAsync().GetAwaiter().GetResult()
    }
    if ($null -eq $response.PSObject.Methods['GetResponseStream']) { return $null }
    $stream = $response.GetResponseStream()
    if ($null -eq $stream) { return $null }
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Invoke-Stage7HttpBoundaryProbe {
    param([Parameter(Mandatory = $true)][psobject] $ApiTarget)

    $statusCode = $null
    $body = $null
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Headers @{ Accept = 'application/json' } -Uri ($ApiTarget.BaseUrl + '/auth/me') -TimeoutSec 5 -MaximumRedirection 0
        $statusCode = [int] $response.StatusCode
        $body = [string] $response.Content
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw 'The selected Stage 7 API target was not reachable.' }
        $statusCode = [int] $_.Exception.Response.StatusCode
        $body = Get-Stage7ErrorResponseBody -Exception $_.Exception
    }
    try { $envelope = $body | ConvertFrom-Json } catch { throw 'The Stage 7 HTTP protected boundary returned invalid JSON.' }
    Assert-Stage7HttpBoundaryFacts -StatusCode $statusCode -Envelope $envelope
}

function Assert-Stage7DedicatedRuntime {
    param(
        [Parameter(Mandatory = $true)][psobject] $ApiTarget,
        [string] $BackendContainerName = $script:Stage7BackendContainerName
    )

    if ($BackendContainerName -cne $script:Stage7BackendContainerName) {
        throw 'Stage 7 E2E may inspect only the exact dedicated backend container.'
    }
    $validatedTarget = Resolve-Stage7ApiTarget -ApiBaseUrl $ApiTarget.BaseUrl
    if ($validatedTarget.Port -ne $ApiTarget.Port) { throw 'The Stage 7 API target has inconsistent port facts.' }
    $inspectionOutput = & docker inspect $BackendContainerName 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'The dedicated Stage 7 backend container could not be inspected.' }
    try { $inspections = @($inspectionOutput | ConvertFrom-Json) } catch { throw 'The Stage 7 backend inspection was invalid.' }
    $inspection = if ($inspections.Count -eq 1) { $inspections[0] } else { $null }
    Assert-Stage7ContainerFacts `
        -InspectionCount $inspections.Count `
        -ContainerName $(if ($null -eq $inspection) { '' } else { [string] $inspection.Name.TrimStart('/') }) `
        -Running $(if ($null -eq $inspection) { $false } else { [bool] $inspection.State.Running }) `
        -AutoRemove $(if ($null -eq $inspection) { $true } else { [bool] $inspection.HostConfig.AutoRemove }) `
        -WorkingDirectory $(if ($null -eq $inspection) { '' } else { [string] $inspection.Config.WorkingDir })

    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $backendSource = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'backend')).Path
    Assert-Stage7MountFacts -Mounts @($inspection.Mounts) -ExpectedBackendSource $backendSource
    Assert-Stage7PortBindingFacts `
        -ConfiguredBindings @($inspection.HostConfig.PortBindings.($script:Stage7BackendContainerPort)) `
        -ActiveBindings @($inspection.NetworkSettings.Ports.($script:Stage7BackendContainerPort)) `
        -ApiPort $ApiTarget.Port

    $containerEnvironment = @{}
    foreach ($entry in @($inspection.Config.Env)) {
        $separator = ([string] $entry).IndexOf('=')
        if ($separator -gt 0) {
            $containerEnvironment[$entry.Substring(0, $separator)] = $entry.Substring($separator + 1)
        }
    }
    $requiredEnvironment = @{
        APP_ENV = 'testing'
        APP_DEBUG = 'false'
        DB_CONNECTION = 'pgsql'
        DB_HOST = 'postgres'
        DB_PORT = '5432'
        DB_DATABASE = 'testlabuz_testing'
    }
    foreach ($name in $requiredEnvironment.Keys) {
        if ([string] $containerEnvironment[$name] -cne $requiredEnvironment[$name]) {
            throw "The dedicated Stage 7 backend container has an unsafe $name value."
        }
    }

    $postgresOutput = & docker inspect $script:Stage7PostgresContainerName 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'The approved Stage 7 PostgreSQL container could not be inspected.' }
    try { $postgresInspections = @($postgresOutput | ConvertFrom-Json) } catch { throw 'The Stage 7 PostgreSQL inspection was invalid.' }
    if ($postgresInspections.Count -ne 1) { throw 'The approved Stage 7 PostgreSQL identity was ambiguous.' }
    $postgres = $postgresInspections[0]
    Assert-Stage7ServerFacts `
        -DatabaseHost ([string] $containerEnvironment['DB_HOST']) `
        -DatabasePort ([string] $containerEnvironment['DB_PORT']) `
        -PostgresContainerName ([string] $postgres.Name.TrimStart('/')) `
        -PostgresImage ([string] $postgres.Config.Image) `
        -BackendNetworkPresent ($null -ne $inspection.NetworkSettings.Networks.($script:Stage7DockerNetworkName)) `
        -PostgresNetworkPresent ($null -ne $postgres.NetworkSettings.Networks.($script:Stage7DockerNetworkName)) `
        -PostgresRunning ([bool] $postgres.State.Running)

    $runtimeProgram = @'
$migrationFiles = glob(database_path('migrations/*.php')) ?: [];
$expectedMigrations = array_map(static fn (string $path): string => pathinfo($path, PATHINFO_FILENAME), $migrationFiles);
$ranMigrations = DB::table(config('database.migrations.table', 'migrations'))->pluck('migration')->all();
$facts = [
    'environment' => app()->environment(),
    'debug' => config('app.debug'),
    'database_default' => config('database.default'),
    'connection_driver' => DB::connection()->getDriverName(),
    'pdo_driver' => (string) DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME),
    'database' => (string) DB::scalar('select current_database()'),
    'database_host' => config('database.connections.pgsql.host'),
    'database_port' => (string) config('database.connections.pgsql.port'),
    'pending_migrations' => count(array_diff($expectedMigrations, $ranMigrations)),
    'private_disk' => config('filesystems.private_files_disk'),
    'private_driver' => config('filesystems.disks.'.config('filesystems.private_files_disk').'.driver'),
    'private_root' => realpath((string) config('filesystems.disks.'.config('filesystems.private_files_disk').'.root')) ?: '',
    'public_root' => realpath((string) config('filesystems.disks.public.root')) ?: '',
    'private_public' => config('filesystems.disks.'.config('filesystems.private_files_disk').'.visibility') === 'public',
];
echo json_encode($facts, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
'@
    $facts = Invoke-Stage7ContainerPhp -BackendContainerName $BackendContainerName -Program $runtimeProgram
    Assert-Stage7LaravelFacts -Facts $facts
    Invoke-Stage7HttpBoundaryProbe -ApiTarget $ApiTarget

    [pscustomobject] @{
        ContainerName = $BackendContainerName
        ContainerId = [string] $inspection.Id
        ApiBaseUrl = $ApiTarget.BaseUrl
        Port = $ApiTarget.Port
        Environment = 'testing'
        Database = 'testlabuz_testing'
        ConnectionDriver = 'pgsql'
        PostgresContainerName = $script:Stage7PostgresContainerName
        DockerNetworkName = $script:Stage7DockerNetworkName
        PrivateVolumeName = $script:Stage7PrivateVolumeName
    }
}
