Set-StrictMode -Version Latest

$script:Stage6BackendContainerName = 'testlabuz-stage6-e2e-app'
$script:Stage6BackendContainerPort = '8000/tcp'
$script:Stage6PostgresContainerName = 'testlabuz-postgres-1'
$script:Stage6PostgresImage = 'postgres:18.4'
$script:Stage6DockerNetworkName = 'testlabuz_default'
$script:Stage6BackendRoot = '/var/www/html'

function Resolve-Stage6ApiTarget {
    param([Parameter(Mandatory = $true)][string] $ApiBaseUrl)

    $match = [regex]::Match(
        $ApiBaseUrl,
        '\Ahttp://127\.0\.0\.1:(?<port>[0-9]{1,5})/api/v1\z',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $match.Success) {
        throw 'Stage 6 E2E requires exactly http://127.0.0.1:<explicit-port>/api/v1.'
    }
    $port = [int] $match.Groups['port'].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw 'Stage 6 E2E requires an explicit port between 1 and 65535.'
    }
    try {
        $uri = [Uri] $ApiBaseUrl
    }
    catch {
        throw 'The Stage 6 E2E API target is malformed.'
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
        throw 'The Stage 6 E2E API target is outside the dedicated loopback boundary.'
    }

    [pscustomobject] @{ BaseUrl = $ApiBaseUrl; Port = $port }
}

function Assert-Stage6ContainerFacts {
    param(
        [Parameter(Mandatory = $true)][int] $InspectionCount,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $ContainerName,
        [Parameter(Mandatory = $true)][bool] $Running,
        [Parameter(Mandatory = $true)][bool] $AutoRemove,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $WorkingDirectory
    )

    if ($InspectionCount -ne 1 -or $ContainerName -cne $script:Stage6BackendContainerName) {
        throw 'The dedicated Stage 6 backend container identity is missing or ambiguous.'
    }
    if (-not $Running) { throw 'The dedicated Stage 6 backend container must be running.' }
    if ($AutoRemove) { throw 'The dedicated Stage 6 backend container must be restartable.' }
    if ($WorkingDirectory -cne $script:Stage6BackendRoot) {
        throw 'The dedicated Stage 6 backend working directory is unsafe.'
    }
}

function Assert-Stage6MountFacts {
    param(
        [Parameter(Mandatory = $true)][object[]] $Mounts,
        [Parameter(Mandatory = $true)][string] $ExpectedBackendSource
    )

    $resolvedExpected = [IO.Path]::GetFullPath($ExpectedBackendSource).TrimEnd('\', '/')
    $backendMounts = @($Mounts | Where-Object { $_.Destination -ceq $script:Stage6BackendRoot })
    if ($backendMounts.Count -ne 1) {
        throw 'The exact Stage 6 backend source bind is missing or ambiguous.'
    }
    $backendMount = $backendMounts[0]
    $resolvedSource = [IO.Path]::GetFullPath([string] $backendMount.Source).TrimEnd('\', '/')
    if (
        [string] $backendMount.Type -cne 'bind' -or
        [bool] $backendMount.RW -ne $true -or
        -not $resolvedSource.Equals($resolvedExpected, [StringComparison]::OrdinalIgnoreCase)
    ) {
        throw 'The Stage 6 backend source bind does not own the current repository backend.'
    }
}

function Assert-Stage6PortBindingFacts {
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
            throw 'The selected Stage 6 API port is not actively bound exactly once to loopback.'
        }
    }
}

function Assert-Stage6ServerFacts {
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
        throw 'The dedicated Stage 6 runtime has an unapproved database server target.'
    }
    if ($PostgresContainerName -cne $script:Stage6PostgresContainerName -or $PostgresImage -cne $script:Stage6PostgresImage) {
        throw 'The dedicated Stage 6 runtime has an unapproved PostgreSQL identity.'
    }
    if (-not $BackendNetworkPresent -or -not $PostgresNetworkPresent -or -not $PostgresRunning) {
        throw 'The approved Stage 6 PostgreSQL server/network is unavailable.'
    }
}

function Assert-Stage6LaravelFacts {
    param([Parameter(Mandatory = $true)][psobject] $Facts)

    if (
        [string] $Facts.environment -cne 'testing' -or
        [bool] $Facts.debug -ne $false -or
        [string] $Facts.database_default -cne 'pgsql' -or
        [string] $Facts.connection_driver -cne 'pgsql' -or
        [string] $Facts.pdo_driver -cne 'pgsql' -or
        [string] $Facts.database -cne 'testlabuz_testing' -or
        [int] $Facts.pending_migrations -ne 0
    ) {
        throw 'The Stage 6 Laravel/database runtime identity is unsafe.'
    }
}

function Assert-Stage6HttpBoundaryFacts {
    param(
        [Parameter(Mandatory = $true)][int] $StatusCode,
        [Parameter(Mandatory = $true)][object] $Envelope
    )

    if ($StatusCode -ne 401) { throw 'The Stage 6 HTTP protected boundary returned the wrong status.' }
    $properties = @($Envelope.PSObject.Properties.Name)
    $allowed = @('message', 'code', 'errors', 'request_id')
    if (
        [string] $Envelope.code -cne 'authentication_required' -or
        $null -eq $Envelope.errors -or
        @($Envelope.errors.PSObject.Properties).Count -ne 0 -or
        @($properties | Where-Object { $_ -cnotin $allowed }).Count -ne 0 -or
        @(@('message', 'code', 'errors') | Where-Object { $_ -cnotin $properties }).Count -ne 0
    ) {
        throw 'The Stage 6 HTTP protected boundary returned an unsafe envelope.'
    }
}

function Get-Stage6ErrorResponseBody {
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

function Invoke-Stage6HttpBoundaryProbe {
    param([Parameter(Mandatory = $true)][psobject] $ApiTarget)

    $statusCode = $null
    $body = $null
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Headers @{ Accept = 'application/json' } -Uri ($ApiTarget.BaseUrl + '/auth/me') -TimeoutSec 5
        $statusCode = [int] $response.StatusCode
        $body = [string] $response.Content
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw 'The selected Stage 6 API target was not reachable.' }
        $statusCode = [int] $_.Exception.Response.StatusCode
        $body = Get-Stage6ErrorResponseBody -Exception $_.Exception
    }
    try { $envelope = $body | ConvertFrom-Json } catch { throw 'The Stage 6 HTTP protected boundary returned invalid JSON.' }
    Assert-Stage6HttpBoundaryFacts -StatusCode $statusCode -Envelope $envelope
}

function Assert-Stage6DedicatedRuntime {
    param(
        [Parameter(Mandatory = $true)][psobject] $ApiTarget,
        [string] $BackendContainerName = $script:Stage6BackendContainerName
    )

    if ($BackendContainerName -cne $script:Stage6BackendContainerName) {
        throw 'Stage 6 E2E may inspect only the exact dedicated backend container.'
    }
    $inspectionOutput = & docker inspect $BackendContainerName 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'The dedicated Stage 6 backend container could not be inspected.' }
    try { $inspections = @($inspectionOutput | ConvertFrom-Json) } catch { throw 'The Stage 6 backend inspection was invalid.' }
    $inspection = if ($inspections.Count -eq 1) { $inspections[0] } else { $null }
    Assert-Stage6ContainerFacts `
        -InspectionCount $inspections.Count `
        -ContainerName $(if ($null -eq $inspection) { '' } else { [string] $inspection.Name.TrimStart('/') }) `
        -Running $(if ($null -eq $inspection) { $false } else { [bool] $inspection.State.Running }) `
        -AutoRemove $(if ($null -eq $inspection) { $true } else { [bool] $inspection.HostConfig.AutoRemove }) `
        -WorkingDirectory $(if ($null -eq $inspection) { '' } else { [string] $inspection.Config.WorkingDir })

    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $backendSource = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'backend')).Path
    Assert-Stage6MountFacts -Mounts @($inspection.Mounts) -ExpectedBackendSource $backendSource
    Assert-Stage6PortBindingFacts `
        -ConfiguredBindings @($inspection.HostConfig.PortBindings.($script:Stage6BackendContainerPort)) `
        -ActiveBindings @($inspection.NetworkSettings.Ports.($script:Stage6BackendContainerPort)) `
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
            throw "The dedicated Stage 6 backend container has an unsafe $name value."
        }
    }

    $postgresOutput = & docker inspect $script:Stage6PostgresContainerName 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'The approved Stage 6 PostgreSQL container could not be inspected.' }
    try { $postgresInspections = @($postgresOutput | ConvertFrom-Json) } catch { throw 'The Stage 6 PostgreSQL inspection was invalid.' }
    if ($postgresInspections.Count -ne 1) { throw 'The approved Stage 6 PostgreSQL identity was ambiguous.' }
    $postgres = $postgresInspections[0]
    Assert-Stage6ServerFacts `
        -DatabaseHost ([string] $containerEnvironment['DB_HOST']) `
        -DatabasePort ([string] $containerEnvironment['DB_PORT']) `
        -PostgresContainerName ([string] $postgres.Name.TrimStart('/')) `
        -PostgresImage ([string] $postgres.Config.Image) `
        -BackendNetworkPresent ($null -ne $inspection.NetworkSettings.Networks.($script:Stage6DockerNetworkName)) `
        -PostgresNetworkPresent ($null -ne $postgres.NetworkSettings.Networks.($script:Stage6DockerNetworkName)) `
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
    'pending_migrations' => count(array_diff($expectedMigrations, $ranMigrations)),
];
echo 'Stage6RuntimeFacts:'.base64_encode(json_encode($facts, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
'@
    $runtimeOutput = & docker exec $BackendContainerName php artisan tinker "--execute=$runtimeProgram" 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'The dedicated Stage 6 Laravel/database runtime probe failed closed.' }
    $match = [regex]::Match(($runtimeOutput -join "`n"), 'Stage6RuntimeFacts:(?<payload>[A-Za-z0-9+/=]+)')
    if (-not $match.Success) { throw 'The dedicated Stage 6 runtime identity proof was absent.' }
    try {
        $factsJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($match.Groups['payload'].Value))
        $facts = $factsJson | ConvertFrom-Json
    }
    catch { throw 'The dedicated Stage 6 runtime identity proof was invalid.' }
    Assert-Stage6LaravelFacts -Facts $facts
    Invoke-Stage6HttpBoundaryProbe -ApiTarget $ApiTarget

    [pscustomobject] @{
        ContainerName = $BackendContainerName
        ContainerId = [string] $inspection.Id
        ApiBaseUrl = $ApiTarget.BaseUrl
        Port = $ApiTarget.Port
        Environment = 'testing'
        Database = 'testlabuz_testing'
        ConnectionDriver = 'pgsql'
        PostgresContainerName = $script:Stage6PostgresContainerName
        DockerNetworkName = $script:Stage6DockerNetworkName
    }
}
