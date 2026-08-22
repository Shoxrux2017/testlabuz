Set-StrictMode -Version Latest

$script:Stage4BackendContainerName = 'testlabuz-stage4-e2e-app'
$script:Stage4BackendContainerPort = '8000/tcp'
$script:Stage4PostgresContainerName = 'testlabuz-postgres-1'
$script:Stage4DockerNetworkName = 'testlabuz_default'
$script:Stage4DatabaseHost = 'postgres'

function Resolve-Stage4ApiTarget {
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
        throw 'Stage 4 E2E requires exactly http://127.0.0.1:<explicit-port>/api/v1.'
    }

    $port = [int] $match.Groups['port'].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw 'Stage 4 E2E requires an explicit port between 1 and 65535.'
    }

    try {
        $uri = [Uri] $ApiBaseUrl
    }
    catch {
        throw 'The Stage 4 E2E API target is malformed.'
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
        throw 'The Stage 4 E2E API target is outside the dedicated loopback boundary.'
    }

    [pscustomobject] @{
        BaseUrl = $ApiBaseUrl
        Port = $port
    }
}

function Assert-Stage4RuntimeFacts {
    param(
        [Parameter(Mandatory = $true)][string] $Environment,
        [Parameter(Mandatory = $true)][string] $Database,
        [Parameter(Mandatory = $true)][string] $ConnectionDriver,
        [Parameter(Mandatory = $true)][string] $PdoDriver
    )

    if ($Environment -cne 'testing') {
        throw 'The dedicated Stage 4 runtime must use APP_ENV=testing.'
    }
    if ($Database -cne 'testlabuz_testing') {
        throw 'The dedicated Stage 4 runtime must use testlabuz_testing.'
    }
    if ($ConnectionDriver -cne 'pgsql' -or $PdoDriver -cne 'pgsql') {
        throw 'The dedicated Stage 4 runtime must use Laravel pgsql and PDO pgsql.'
    }
}

function Assert-Stage4ServerFacts {
    param(
        [Parameter(Mandatory = $true)][string] $DatabaseHost,
        [Parameter(Mandatory = $true)][string] $PostgresContainerName,
        [Parameter(Mandatory = $true)][string] $PostgresImage,
        [Parameter(Mandatory = $true)][bool] $BackendNetworkPresent,
        [Parameter(Mandatory = $true)][bool] $PostgresNetworkPresent,
        [Parameter(Mandatory = $true)][bool] $PostgresRunning
    )

    if ($DatabaseHost -cne $script:Stage4DatabaseHost) {
        throw 'The dedicated Stage 4 runtime has an unapproved database server host.'
    }
    if ($PostgresContainerName -cne $script:Stage4PostgresContainerName) {
        throw 'The dedicated Stage 4 runtime has an unapproved PostgreSQL container.'
    }
    if (-not $PostgresImage.StartsWith('postgres:', [StringComparison]::Ordinal)) {
        throw 'The dedicated Stage 4 runtime has an unapproved PostgreSQL image.'
    }
    if (-not $BackendNetworkPresent -or -not $PostgresNetworkPresent -or -not $PostgresRunning) {
        throw 'The approved Stage 4 PostgreSQL server/network is unavailable.'
    }
}

function Assert-Stage4PortBindingFacts {
    param(
        [Parameter(Mandatory = $true)][object[]] $ConfiguredBindings,
        [Parameter(Mandatory = $true)][object[]] $ActiveBindings,
        [Parameter(Mandatory = $true)][int] $ApiPort
    )

    foreach ($bindings in @($ConfiguredBindings, $ActiveBindings)) {
        if (
            $bindings.Count -ne 1 -or
            $bindings[0].HostIp -cne '127.0.0.1' -or
            $bindings[0].HostPort -cne [string] $ApiPort
        ) {
            throw 'The selected API port is not bound exactly once to loopback.'
        }
    }
}

function Assert-Stage4DedicatedRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $ApiTarget,

        [string] $BackendContainerName = $script:Stage4BackendContainerName
    )

    if ($BackendContainerName -cne $script:Stage4BackendContainerName) {
        throw 'Stage 4 E2E may inspect only the exact dedicated backend container.'
    }

    $inspectionOutput = & docker inspect $BackendContainerName 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The dedicated Stage 4 backend container could not be inspected.'
    }
    try {
        $inspections = @($inspectionOutput | ConvertFrom-Json)
    }
    catch {
        throw 'The dedicated Stage 4 backend inspection was not valid JSON.'
    }
    if ($inspections.Count -ne 1) {
        throw 'The dedicated Stage 4 backend inspection was ambiguous.'
    }

    $inspection = $inspections[0]
    if ($inspection.Name.TrimStart('/') -cne $BackendContainerName) {
        throw 'The inspected backend identity did not match the dedicated Stage 4 container.'
    }
    if ($inspection.State.Running -ne $true) {
        throw 'The dedicated Stage 4 backend container must already be running.'
    }

    $configuredBindings = @($inspection.HostConfig.PortBindings.($script:Stage4BackendContainerPort))
    $activeBindings = @($inspection.NetworkSettings.Ports.($script:Stage4BackendContainerPort))
    Assert-Stage4PortBindingFacts `
        -ConfiguredBindings $configuredBindings `
        -ActiveBindings $activeBindings `
        -ApiPort $ApiTarget.Port

    $containerEnvironment = @{}
    foreach ($entry in @($inspection.Config.Env)) {
        $separator = $entry.IndexOf('=')
        if ($separator -gt 0) {
            $containerEnvironment[$entry.Substring(0, $separator)] = $entry.Substring($separator + 1)
        }
    }
    $requiredEnvironment = @{
        APP_ENV = 'testing'
        DB_CONNECTION = 'pgsql'
        DB_DATABASE = 'testlabuz_testing'
        DB_HOST = $script:Stage4DatabaseHost
    }
    foreach ($name in $requiredEnvironment.Keys) {
        if ($containerEnvironment[$name] -cne $requiredEnvironment[$name]) {
            throw "The dedicated Stage 4 backend container has an unsafe $name value."
        }
    }

    $backendNetworkPresent = $null -ne $inspection.NetworkSettings.Networks.($script:Stage4DockerNetworkName)
    $postgresInspectionOutput = & docker inspect $script:Stage4PostgresContainerName 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The approved local PostgreSQL container could not be inspected.'
    }
    try {
        $postgresInspections = @($postgresInspectionOutput | ConvertFrom-Json)
    }
    catch {
        throw 'The approved PostgreSQL inspection was not valid JSON.'
    }
    if ($postgresInspections.Count -ne 1) {
        throw 'The approved PostgreSQL inspection was ambiguous.'
    }
    $postgresInspection = $postgresInspections[0]
    Assert-Stage4ServerFacts `
        -DatabaseHost $containerEnvironment['DB_HOST'] `
        -PostgresContainerName $postgresInspection.Name.TrimStart('/') `
        -PostgresImage ([string] $postgresInspection.Config.Image) `
        -BackendNetworkPresent $backendNetworkPresent `
        -PostgresNetworkPresent ($null -ne $postgresInspection.NetworkSettings.Networks.($script:Stage4DockerNetworkName)) `
        -PostgresRunning ([bool] $postgresInspection.State.Running)

    $identityProbe = @'
$environment = app()->environment();
$database = (string) DB::scalar('select current_database()');
$connectionDriver = DB::connection()->getDriverName();
$pdoDriver = (string) DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME);
throw_unless($environment === 'testing', 'Wrong environment.');
throw_unless($database === 'testlabuz_testing', 'Wrong database.');
throw_unless($connectionDriver === 'pgsql', 'Wrong Laravel database driver.');
throw_unless($pdoDriver === 'pgsql', 'Wrong PDO driver.');
echo 'Stage4RuntimeIdentity:'.$environment.'|'.$database.'|'.$connectionDriver.'|'.$pdoDriver;
'@
    $identityOutput = & docker exec `
        $BackendContainerName `
        php artisan tinker `
        "--execute=$identityProbe" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'The dedicated Stage 4 runtime identity probe failed closed.'
    }
    $identityMatch = [regex]::Match(
        ($identityOutput -join "`n"),
        'Stage4RuntimeIdentity:(?<environment>[^|\s]+)\|(?<database>[^|\s]+)\|(?<connection>[^|\s]+)\|(?<pdo>[^\s";]+)'
    )
    if (-not $identityMatch.Success) {
        throw 'The dedicated Stage 4 runtime identity proof was absent.'
    }
    Assert-Stage4RuntimeFacts `
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
        if ($null -eq $_.Exception.Response) {
            throw 'The selected dedicated Stage 4 API target was not reachable.'
        }
        $statusCode = [int] $_.Exception.Response.StatusCode
    }
    if ($statusCode -ne 401) {
        throw 'The selected dedicated Stage 4 API did not expose the expected protected boundary.'
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
        PostgresContainerName = $script:Stage4PostgresContainerName
        DockerNetworkName = $script:Stage4DockerNetworkName
    }
}
