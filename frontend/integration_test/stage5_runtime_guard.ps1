Set-StrictMode -Version Latest

$script:Stage5BackendContainerName = 'testlabuz-stage5-e2e-app'
$script:Stage5BackendContainerPort = '8000/tcp'
$script:Stage5PostgresContainerName = 'testlabuz-postgres-1'
$script:Stage5PostgresImage = 'postgres:18.4'
$script:Stage5DockerNetworkName = 'testlabuz_default'
$script:Stage5PrivateVolumeName = 'testlabuz-stage5-e2e-private-files'
$script:Stage5BackendRoot = '/var/www/html'
$script:Stage5PrivateRoot = '/var/www/html/storage/app/private'
$script:Stage5PublicRoot = '/var/www/html/storage/app/public'

function Resolve-Stage5ApiTarget {
    param([Parameter(Mandatory = $true)][string] $ApiBaseUrl)

    $match = [regex]::Match(
        $ApiBaseUrl,
        '\Ahttp://127\.0\.0\.1:(?<port>[0-9]{1,5})/api/v1\z',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $match.Success) {
        throw 'Stage 5 E2E requires exactly http://127.0.0.1:<explicit-port>/api/v1.'
    }
    $port = [int] $match.Groups['port'].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw 'Stage 5 E2E requires an explicit port between 1 and 65535.'
    }
    try {
        $uri = [Uri] $ApiBaseUrl
    }
    catch {
        throw 'The Stage 5 E2E API target is malformed.'
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
        throw 'The Stage 5 E2E API target is outside the dedicated loopback boundary.'
    }

    [pscustomobject] @{ BaseUrl = $ApiBaseUrl; Port = $port }
}

function Assert-Stage5ContainerFacts {
    param(
        [Parameter(Mandatory = $true)][int] $InspectionCount,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $ContainerName,
        [Parameter(Mandatory = $true)][bool] $Running,
        [Parameter(Mandatory = $true)][bool] $AutoRemove,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $WorkingDirectory
    )

    if ($InspectionCount -ne 1 -or $ContainerName -cne $script:Stage5BackendContainerName) {
        throw 'The dedicated Stage 5 backend container identity is missing or ambiguous.'
    }
    if (-not $Running) { throw 'The dedicated Stage 5 backend container must be running.' }
    if ($AutoRemove) { throw 'The dedicated Stage 5 backend container must be restartable.' }
    if ($WorkingDirectory -cne $script:Stage5BackendRoot) {
        throw 'The dedicated Stage 5 backend working directory is unsafe.'
    }
}

function Assert-Stage5MountFacts {
    param(
        [Parameter(Mandatory = $true)][object[]] $Mounts,
        [Parameter(Mandatory = $true)][string] $ExpectedBackendSource
    )

    $resolvedExpected = [IO.Path]::GetFullPath($ExpectedBackendSource).TrimEnd('\', '/')
    $backendMounts = @($Mounts | Where-Object { $_.Destination -ceq $script:Stage5BackendRoot })
    if ($backendMounts.Count -ne 1) { throw 'The exact Stage 5 backend source bind is missing or ambiguous.' }
    $backendMount = $backendMounts[0]
    $resolvedSource = [IO.Path]::GetFullPath([string] $backendMount.Source).TrimEnd('\', '/')
    if (
        [string] $backendMount.Type -cne 'bind' -or
        [bool] $backendMount.RW -ne $true -or
        -not $resolvedSource.Equals($resolvedExpected, [StringComparison]::OrdinalIgnoreCase)
    ) {
        throw 'The Stage 5 backend source bind does not own the current repository backend.'
    }

    $privateMounts = @($Mounts | Where-Object { $_.Destination -ceq $script:Stage5PrivateRoot })
    if ($privateMounts.Count -ne 1) { throw 'The exact Stage 5 private volume mount is missing or ambiguous.' }
    $privateMount = $privateMounts[0]
    if (
        [string] $privateMount.Type -cne 'volume' -or
        [string] $privateMount.Name -cne $script:Stage5PrivateVolumeName -or
        [bool] $privateMount.RW -ne $true
    ) {
        throw 'The Stage 5 private root is not owned by the approved read/write named volume.'
    }
    $privateAliases = @($Mounts | Where-Object {
        $mountName = if ($null -eq $_.PSObject.Properties['Name']) { '' } else { [string] $_.Name }
        $_.Destination -cne $script:Stage5PrivateRoot -and
        ($mountName -ceq $script:Stage5PrivateVolumeName -or [string] $_.Source -ceq [string] $privateMount.Source)
    })
    if ($privateAliases.Count -ne 0) { throw 'The Stage 5 private volume is aliased by another mount.' }
    if (@($Mounts | Where-Object {
        $mountName = if ($null -eq $_.PSObject.Properties['Name']) { '' } else { [string] $_.Name }
        $_.Destination -ceq $script:Stage5PublicRoot -and $mountName -ceq $script:Stage5PrivateVolumeName
    }).Count -ne 0) {
        throw 'The Stage 5 public root aliases the private volume.'
    }
}

function Assert-Stage5PortBindingFacts {
    param(
        [Parameter(Mandatory = $true)][object[]] $ConfiguredBindings,
        [Parameter(Mandatory = $true)][object[]] $ActiveBindings,
        [Parameter(Mandatory = $true)][int] $ApiPort
    )

    foreach ($bindings in @($ConfiguredBindings, $ActiveBindings)) {
        if (
            $bindings.Count -ne 1 -or
            [string] $bindings[0].HostIp -cne '127.0.0.1' -or
            [string] $bindings[0].HostPort -cne [string] $ApiPort
        ) {
            throw 'The selected Stage 5 API port is not actively bound exactly once to loopback.'
        }
    }
}

function Assert-Stage5ServerFacts {
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
        throw 'The dedicated Stage 5 runtime has an unapproved database server target.'
    }
    if ($PostgresContainerName -cne $script:Stage5PostgresContainerName -or $PostgresImage -cne $script:Stage5PostgresImage) {
        throw 'The dedicated Stage 5 runtime has an unapproved PostgreSQL identity.'
    }
    if (-not $BackendNetworkPresent -or -not $PostgresNetworkPresent -or -not $PostgresRunning) {
        throw 'The approved Stage 5 PostgreSQL server/network is unavailable.'
    }
}

function Assert-Stage5LaravelFacts {
    param(
        [Parameter(Mandatory = $true)][psobject] $Facts
    )

    if (
        [string] $Facts.environment -cne 'testing' -or
        [bool] $Facts.debug -ne $false -or
        [string] $Facts.database_default -cne 'pgsql' -or
        [string] $Facts.connection_driver -cne 'pgsql' -or
        [string] $Facts.pdo_driver -cne 'pgsql' -or
        [string] $Facts.database -cne 'testlabuz_testing' -or
        [int] $Facts.pending_migrations -ne 0
    ) {
        throw 'The Stage 5 Laravel/database runtime identity is unsafe.'
    }
    if (
        [string] $Facts.private_disk -cne 'local' -or
        [string] $Facts.private_driver -cne 'local' -or
        [string] $Facts.private_root -cne $script:Stage5PrivateRoot -or
        [string] $Facts.public_root -cne $script:Stage5PublicRoot -or
        [string] $Facts.private_root -ceq [string] $Facts.public_root -or
        [bool] $Facts.private_public -ne $false
    ) {
        throw 'The Stage 5 Laravel private/public storage identity is unsafe.'
    }
    if (
        [bool] $Facts.file_uploads -ne $true -or
        [int64] $Facts.upload_max_bytes -lt 33554432 -or
        [int64] $Facts.post_max_bytes -lt 41943040
    ) {
        throw 'The Stage 5 live PHP upload transport has insufficient headroom.'
    }
}

function Assert-Stage5PrivateProbeFacts {
    param(
        [Parameter(Mandatory = $true)][bool] $WriteSucceeded,
        [Parameter(Mandatory = $true)][bool] $ReadHashMatched,
        [Parameter(Mandatory = $true)][bool] $DeleteSucceeded,
        [Parameter(Mandatory = $true)][bool] $AbsentAfterDelete
    )

    if (-not $WriteSucceeded -or -not $ReadHashMatched -or -not $DeleteSucceeded -or -not $AbsentAfterDelete) {
        throw 'The Stage 5 unpredictable private-root write/read/hash/delete probe failed.'
    }
}

function Assert-Stage5HttpBoundaryFacts {
    param(
        [Parameter(Mandatory = $true)][int] $StatusCode,
        [Parameter(Mandatory = $true)][object] $Envelope
    )

    if ($StatusCode -ne 401) { throw 'The Stage 5 HTTP protected boundary returned the wrong status.' }
    $properties = @($Envelope.PSObject.Properties.Name)
    $allowed = @('message', 'code', 'errors', 'request_id')
    if (
        [string] $Envelope.code -cne 'authentication_required' -or
        $null -eq $Envelope.errors -or
        @($Envelope.errors.PSObject.Properties).Count -ne 0 -or
        @($properties | Where-Object { $_ -cnotin $allowed }).Count -ne 0 -or
        @(@('message', 'code', 'errors') | Where-Object { $_ -cnotin $properties }).Count -ne 0
    ) {
        throw 'The Stage 5 HTTP protected boundary returned an unsafe envelope.'
    }
}

function Get-Stage5ErrorResponseBody {
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

function Invoke-Stage5HttpBoundaryProbe {
    param([Parameter(Mandatory = $true)][psobject] $ApiTarget)

    $statusCode = $null
    $body = $null
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Headers @{ Accept = 'application/json' } -Uri ($ApiTarget.BaseUrl + '/auth/me') -TimeoutSec 5
        $statusCode = [int] $response.StatusCode
        $body = [string] $response.Content
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw 'The selected Stage 5 API target was not reachable.' }
        $statusCode = [int] $_.Exception.Response.StatusCode
        $body = Get-Stage5ErrorResponseBody -Exception $_.Exception
    }
    try { $envelope = $body | ConvertFrom-Json } catch { throw 'The Stage 5 HTTP protected boundary returned invalid JSON.' }
    Assert-Stage5HttpBoundaryFacts -StatusCode $statusCode -Envelope $envelope
}

function Assert-Stage5DedicatedRuntime {
    param(
        [Parameter(Mandatory = $true)][psobject] $ApiTarget,
        [string] $BackendContainerName = $script:Stage5BackendContainerName
    )

    if ($BackendContainerName -cne $script:Stage5BackendContainerName) {
        throw 'Stage 5 E2E may inspect only the exact dedicated backend container.'
    }
    $inspectionOutput = & docker inspect $BackendContainerName 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'The dedicated Stage 5 backend container could not be inspected.' }
    try { $inspections = @($inspectionOutput | ConvertFrom-Json) } catch { throw 'The Stage 5 backend inspection was invalid.' }
    $inspection = if ($inspections.Count -eq 1) { $inspections[0] } else { $null }
    Assert-Stage5ContainerFacts `
        -InspectionCount $inspections.Count `
        -ContainerName $(if ($null -eq $inspection) { '' } else { [string] $inspection.Name.TrimStart('/') }) `
        -Running $(if ($null -eq $inspection) { $false } else { [bool] $inspection.State.Running }) `
        -AutoRemove $(if ($null -eq $inspection) { $true } else { [bool] $inspection.HostConfig.AutoRemove }) `
        -WorkingDirectory $(if ($null -eq $inspection) { '' } else { [string] $inspection.Config.WorkingDir })

    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $backendSource = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'backend')).Path
    Assert-Stage5MountFacts -Mounts @($inspection.Mounts) -ExpectedBackendSource $backendSource
    Assert-Stage5PortBindingFacts `
        -ConfiguredBindings @($inspection.HostConfig.PortBindings.($script:Stage5BackendContainerPort)) `
        -ActiveBindings @($inspection.NetworkSettings.Ports.($script:Stage5BackendContainerPort)) `
        -ApiPort $ApiTarget.Port

    $containerEnvironment = @{}
    foreach ($entry in @($inspection.Config.Env)) {
        $separator = ([string] $entry).IndexOf('=')
        if ($separator -gt 0) { $containerEnvironment[$entry.Substring(0, $separator)] = $entry.Substring($separator + 1) }
    }
    $requiredEnvironment = @{
        APP_ENV = 'testing'; APP_DEBUG = 'false'; DB_CONNECTION = 'pgsql'; DB_HOST = 'postgres'; DB_PORT = '5432';
        DB_DATABASE = 'testlabuz_testing'; PRIVATE_FILES_DISK = 'local'
    }
    foreach ($name in $requiredEnvironment.Keys) {
        if ([string] $containerEnvironment[$name] -cne $requiredEnvironment[$name]) {
            throw "The dedicated Stage 5 backend container has an unsafe $name value."
        }
    }

    $postgresOutput = & docker inspect $script:Stage5PostgresContainerName 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'The approved Stage 5 PostgreSQL container could not be inspected.' }
    try { $postgresInspections = @($postgresOutput | ConvertFrom-Json) } catch { throw 'The Stage 5 PostgreSQL inspection was invalid.' }
    if ($postgresInspections.Count -ne 1) { throw 'The approved Stage 5 PostgreSQL identity was ambiguous.' }
    $postgres = $postgresInspections[0]
    Assert-Stage5ServerFacts `
        -DatabaseHost ([string] $containerEnvironment['DB_HOST']) `
        -DatabasePort ([string] $containerEnvironment['DB_PORT']) `
        -PostgresContainerName ([string] $postgres.Name.TrimStart('/')) `
        -PostgresImage ([string] $postgres.Config.Image) `
        -BackendNetworkPresent ($null -ne $inspection.NetworkSettings.Networks.($script:Stage5DockerNetworkName)) `
        -PostgresNetworkPresent ($null -ne $postgres.NetworkSettings.Networks.($script:Stage5DockerNetworkName)) `
        -PostgresRunning ([bool] $postgres.State.Running)

    $probeId = [guid]::NewGuid().ToString('N')
    $runtimeProgram = @'
$toBytes = static function (string $value): int {
    $value = trim($value);
    if ($value === '' || $value === '-1') { return -1; }
    $unit = strtolower(substr($value, -1));
    $number = (int) $value;
    return match ($unit) { 'g' => $number * 1024 * 1024 * 1024, 'm' => $number * 1024 * 1024, 'k' => $number * 1024, default => $number };
};
$migrationFiles = glob(database_path('migrations/*.php')) ?: [];
$expectedMigrations = array_map(static fn (string $path): string => pathinfo($path, PATHINFO_FILENAME), $migrationFiles);
$ranMigrations = DB::table(config('database.migrations.table', 'migrations'))->pluck('migration')->all();
$probeId = getenv('STAGE5_GUARD_PROBE_ID');
throw_unless(is_string($probeId) && preg_match('/^[a-f0-9]{32}$/D', $probeId) === 1, 'Invalid probe id.');
$probeKey = '.stage5-runtime-guard/'.$probeId.'.probe';
$probeBytes = 'testlabuz-stage5-runtime-probe:'.$probeId;
$disk = Storage::disk('local');
$write = false; $hash = false; $delete = false; $absent = false;
try {
    $write = $disk->put($probeKey, $probeBytes);
    $read = $write ? $disk->get($probeKey) : null;
    $hash = is_string($read) && hash('sha256', $read) === hash('sha256', $probeBytes);
    $delete = $disk->delete($probeKey);
    $absent = ! $disk->exists($probeKey);
} finally {
    if ($disk->exists($probeKey)) { $disk->delete($probeKey); }
}
$facts = [
    'environment' => app()->environment(),
    'debug' => config('app.debug'),
    'database_default' => config('database.default'),
    'connection_driver' => DB::connection()->getDriverName(),
    'pdo_driver' => (string) DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME),
    'database' => (string) DB::scalar('select current_database()'),
    'pending_migrations' => count(array_diff($expectedMigrations, $ranMigrations)),
    'private_disk' => config('filesystems.private_files_disk'),
    'private_driver' => config('filesystems.disks.local.driver'),
    'private_root' => config('filesystems.disks.local.root'),
    'public_root' => config('filesystems.disks.public.root'),
    'private_public' => config('filesystems.disks.local.visibility') === 'public',
    'file_uploads' => filter_var(ini_get('file_uploads'), FILTER_VALIDATE_BOOL),
    'upload_max_bytes' => $toBytes((string) ini_get('upload_max_filesize')),
    'post_max_bytes' => $toBytes((string) ini_get('post_max_size')),
    'probe_write' => $write,
    'probe_hash' => $hash,
    'probe_delete' => $delete,
    'probe_absent' => $absent,
];
echo 'Stage5RuntimeFacts:'.base64_encode(json_encode($facts, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
'@
    $runtimeOutput = & docker exec -e "STAGE5_GUARD_PROBE_ID=$probeId" $BackendContainerName php artisan tinker "--execute=$runtimeProgram" 2>&1
    $probeId = $null
    if ($LASTEXITCODE -ne 0) { throw 'The dedicated Stage 5 Laravel/private-storage runtime probe failed closed.' }
    $match = [regex]::Match(($runtimeOutput -join "`n"), 'Stage5RuntimeFacts:(?<payload>[A-Za-z0-9+/=]+)')
    if (-not $match.Success) { throw 'The dedicated Stage 5 runtime identity proof was absent.' }
    try {
        $factsJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($match.Groups['payload'].Value))
        $facts = $factsJson | ConvertFrom-Json
    }
    catch { throw 'The dedicated Stage 5 runtime identity proof was invalid.' }
    Assert-Stage5LaravelFacts -Facts $facts
    Assert-Stage5PrivateProbeFacts `
        -WriteSucceeded ([bool] $facts.probe_write) `
        -ReadHashMatched ([bool] $facts.probe_hash) `
        -DeleteSucceeded ([bool] $facts.probe_delete) `
        -AbsentAfterDelete ([bool] $facts.probe_absent)
    Invoke-Stage5HttpBoundaryProbe -ApiTarget $ApiTarget

    [pscustomobject] @{
        ContainerName = $BackendContainerName
        ContainerId = [string] $inspection.Id
        ApiBaseUrl = $ApiTarget.BaseUrl
        Port = $ApiTarget.Port
        Environment = 'testing'
        Database = 'testlabuz_testing'
        ConnectionDriver = 'pgsql'
        PostgresContainerName = $script:Stage5PostgresContainerName
        DockerNetworkName = $script:Stage5DockerNetworkName
        PrivateVolumeName = $script:Stage5PrivateVolumeName
    }
}
