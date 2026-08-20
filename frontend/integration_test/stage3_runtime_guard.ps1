Set-StrictMode -Version Latest

$script:Stage3BackendContainerName = 'testlabuz-stage3-e2e-app'
$script:Stage3BackendContainerPort = '8000/tcp'
$script:Stage3PostgresContainerName = 'testlabuz-postgres-1'
$script:Stage3DockerNetworkName = 'testlabuz_default'
$script:Stage3DatabaseHost = 'postgres'

function Resolve-Stage3ApiTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ApiBaseUrl
    )

    $match = [regex]::Match(
        $ApiBaseUrl,
        '\Ahttp://127\.0\.0\.1:(?<port>[0-9]{1,5})/api/v1\z',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )

    if (-not $match.Success) {
        throw 'Stage 3 E2E requires exactly http://127.0.0.1:<explicit-port>/api/v1.'
    }

    $port = [int] $match.Groups['port'].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw 'Stage 3 E2E requires an explicit port between 1 and 65535.'
    }

    try {
        $uri = [Uri] $ApiBaseUrl
    }
    catch {
        throw 'The Stage 3 E2E API target is malformed.'
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
        throw 'The Stage 3 E2E API target is outside the dedicated loopback boundary.'
    }

    [pscustomobject] @{
        BaseUrl = $ApiBaseUrl
        Port = $port
    }
}

function Assert-Stage3RuntimeFacts {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Environment,

        [Parameter(Mandatory = $true)]
        [string] $Database,

        [Parameter(Mandatory = $true)]
        [string] $ConnectionDriver,

        [Parameter(Mandatory = $true)]
        [string] $PdoDriver
    )

    if ($Environment -cne 'testing') {
        throw 'The dedicated Stage 3 runtime must use APP_ENV=testing.'
    }

    if ($Database -cne 'testlabuz_testing') {
        throw 'The dedicated Stage 3 runtime must use testlabuz_testing.'
    }

    if ($ConnectionDriver -cne 'pgsql' -or $PdoDriver -cne 'pgsql') {
        throw 'The dedicated Stage 3 runtime must use Laravel pgsql and PDO pgsql.'
    }
}

function Assert-Stage3DedicatedRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $ApiTarget,

        [string] $BackendContainerName = $script:Stage3BackendContainerName
    )

    if ($BackendContainerName -cne $script:Stage3BackendContainerName) {
        throw 'Stage 3 E2E may inspect only the exact dedicated backend container.'
    }

    $inspectionOutput = & docker inspect $BackendContainerName 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The dedicated Stage 3 backend container could not be inspected.'
    }

    try {
        $inspections = @($inspectionOutput | ConvertFrom-Json)
    }
    catch {
        throw 'The dedicated Stage 3 backend inspection was not valid JSON.'
    }

    if ($inspections.Count -ne 1) {
        throw 'The dedicated Stage 3 backend inspection was ambiguous.'
    }

    $inspection = $inspections[0]
    if ($inspection.Name.TrimStart('/') -cne $BackendContainerName) {
        throw 'The inspected backend container identity did not match the dedicated runtime.'
    }
    if ($inspection.State.Running -ne $true) {
        throw 'The dedicated Stage 3 backend container must already be running.'
    }

    $configuredBindings = @(
        $inspection.HostConfig.PortBindings.($script:Stage3BackendContainerPort)
    )
    $activeBindings = @(
        $inspection.NetworkSettings.Ports.($script:Stage3BackendContainerPort)
    )

    foreach ($bindings in @($configuredBindings, $activeBindings)) {
        if (
            $bindings.Count -ne 1 -or
            $bindings[0].HostIp -cne '127.0.0.1' -or
            $bindings[0].HostPort -cne [string] $ApiTarget.Port
        ) {
            throw 'The selected API port is not bound exclusively to the dedicated loopback runtime.'
        }
    }

    $requiredEnvironment = @{
        APP_ENV = 'testing'
        DB_CONNECTION = 'pgsql'
        DB_DATABASE = 'testlabuz_testing'
        DB_HOST = $script:Stage3DatabaseHost
    }
    $containerEnvironment = @{}
    foreach ($entry in @($inspection.Config.Env)) {
        $separator = $entry.IndexOf('=')
        if ($separator -gt 0) {
            $containerEnvironment[$entry.Substring(0, $separator)] = $entry.Substring($separator + 1)
        }
    }
    foreach ($name in $requiredEnvironment.Keys) {
        if ($containerEnvironment[$name] -cne $requiredEnvironment[$name]) {
            throw "The dedicated Stage 3 backend container has an unsafe $name value."
        }
    }

    if ($null -eq $inspection.NetworkSettings.Networks.($script:Stage3DockerNetworkName)) {
        throw 'The dedicated Stage 3 backend is not attached to the approved local Docker network.'
    }

    $postgresInspectionOutput = & docker inspect $script:Stage3PostgresContainerName 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The approved local PostgreSQL container could not be inspected.'
    }
    $postgresInspections = @($postgresInspectionOutput | ConvertFrom-Json)
    if (
        $postgresInspections.Count -ne 1 -or
        $postgresInspections[0].Name.TrimStart('/') -cne $script:Stage3PostgresContainerName -or
        $postgresInspections[0].State.Running -ne $true -or
        $null -eq $postgresInspections[0].NetworkSettings.Networks.($script:Stage3DockerNetworkName) -or
        -not ([string] $postgresInspections[0].Config.Image).StartsWith('postgres:', [StringComparison]::Ordinal)
    ) {
        throw 'The approved local PostgreSQL target/network identity is invalid.'
    }

    $identityProbe = @'
$environment = app()->environment();
$database = (string) DB::scalar('select current_database()');
$connectionDriver = DB::connection()->getDriverName();
$pdoDriver = (string) DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME);
throw_unless($environment === 'testing', 'Wrong environment.');
throw_unless($database === 'testlabuz_testing', 'Wrong database.');
throw_unless($connectionDriver === 'pgsql', 'Wrong Laravel database driver.');
throw_unless($pdoDriver === 'pgsql', 'Wrong PDO driver.');
echo 'Stage3RuntimeIdentity:'.$environment.'|'.$database.'|'.$connectionDriver.'|'.$pdoDriver;
'@
    $identityOutput = & docker exec `
        $BackendContainerName `
        php artisan tinker `
        "--execute=$identityProbe" 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw 'The dedicated Stage 3 runtime identity probe failed closed.'
    }

    $identityText = $identityOutput -join "`n"
    $identityMatch = [regex]::Match(
        $identityText,
        'Stage3RuntimeIdentity:(?<environment>[^|\s]+)\|(?<database>[^|\s]+)\|(?<connection>[^|\s]+)\|(?<pdo>[^\s";]+)'
    )
    if (-not $identityMatch.Success) {
        throw 'The dedicated Stage 3 runtime identity proof was absent.'
    }

    Assert-Stage3RuntimeFacts `
        -Environment $identityMatch.Groups['environment'].Value `
        -Database $identityMatch.Groups['database'].Value `
        -ConnectionDriver $identityMatch.Groups['connection'].Value `
        -PdoDriver $identityMatch.Groups['pdo'].Value

    $statusCode = $null
    try {
        $response = Invoke-WebRequest `
            -UseBasicParsing `
            -Headers @{ Accept = 'application/json' } `
            -Uri ($ApiTarget.BaseUrl + '/auth/me') `
            -TimeoutSec 5
        $statusCode = [int] $response.StatusCode
    }
    catch {
        if ($null -ne $_.Exception.Response) {
            $statusCode = [int] $_.Exception.Response.StatusCode
        }
        else {
            throw 'The selected dedicated Stage 3 API target was not reachable.'
        }
    }

    if ($statusCode -ne 401) {
        throw 'The selected dedicated Stage 3 API did not expose the expected protected API boundary.'
    }

    [pscustomobject] @{
        ContainerName = $BackendContainerName
        ContainerId = $inspection.Id
        ApiBaseUrl = $ApiTarget.BaseUrl
        Port = $ApiTarget.Port
        Environment = 'testing'
        Database = 'testlabuz_testing'
        ConnectionDriver = 'pgsql'
        PdoDriver = 'pgsql'
        PostgresContainerName = $script:Stage3PostgresContainerName
        DockerNetworkName = $script:Stage3DockerNetworkName
    }
}
