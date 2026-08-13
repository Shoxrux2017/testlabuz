Set-StrictMode -Version Latest

$script:Stage2BackendContainerName = 'testlabuz-stage2-e2e-app'
$script:Stage2BackendContainerPort = '8000/tcp'

function Resolve-Stage2ApiTarget {
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
        throw 'Stage 2 E2E requires exactly http://127.0.0.1:<explicit-port>/api/v1.'
    }

    $port = [int] $match.Groups['port'].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw 'Stage 2 E2E requires an explicit port between 1 and 65535.'
    }

    try {
        $uri = [Uri] $ApiBaseUrl
    }
    catch {
        throw 'The Stage 2 E2E API target is malformed.'
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
        throw 'The Stage 2 E2E API target is outside the dedicated loopback boundary.'
    }

    [pscustomobject] @{
        BaseUrl = $ApiBaseUrl
        Port = $port
    }
}

function Assert-Stage2RuntimeFacts {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Environment,

        [Parameter(Mandatory = $true)]
        [string] $Database
    )

    if ($Environment -cne 'testing') {
        throw 'The dedicated Stage 2 runtime must use APP_ENV=testing.'
    }

    if ($Database -cne 'testlabuz_testing') {
        throw 'The dedicated Stage 2 runtime must use testlabuz_testing.'
    }
}

function Assert-Stage2DedicatedRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $ApiTarget,

        [string] $BackendContainerName = $script:Stage2BackendContainerName
    )

    if ($BackendContainerName -cne $script:Stage2BackendContainerName) {
        throw 'Stage 2 E2E may inspect only the exact dedicated backend container.'
    }

    $inspectionOutput = & docker inspect $BackendContainerName 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The dedicated Stage 2 backend container could not be inspected.'
    }

    try {
        $inspections = @($inspectionOutput | ConvertFrom-Json)
    }
    catch {
        throw 'The dedicated Stage 2 backend inspection was not valid JSON.'
    }

    if ($inspections.Count -ne 1) {
        throw 'The dedicated Stage 2 backend inspection was ambiguous.'
    }

    $inspection = $inspections[0]
    if ($inspection.Name.TrimStart('/') -cne $BackendContainerName) {
        throw 'The inspected backend container identity did not match the dedicated runtime.'
    }
    if ($inspection.State.Running -ne $true) {
        throw 'The dedicated Stage 2 backend container must already be running.'
    }

    $configuredBindings = @(
        $inspection.HostConfig.PortBindings.($script:Stage2BackendContainerPort)
    )
    $activeBindings = @(
        $inspection.NetworkSettings.Ports.($script:Stage2BackendContainerPort)
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

    $identityProbe = @'
$environment = app()->environment();
$database = (string) DB::scalar('select current_database()');
throw_unless($environment === 'testing', 'Wrong environment.');
throw_unless($database === 'testlabuz_testing', 'Wrong database.');
echo 'Stage2RuntimeIdentity:'.$environment.'|'.$database;
'@
    $identityOutput = & docker exec `
        $BackendContainerName `
        php artisan tinker `
        "--execute=$identityProbe" 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw 'The dedicated Stage 2 runtime identity probe failed closed.'
    }

    $identityText = $identityOutput -join "`n"
    $identityMatch = [regex]::Match(
        $identityText,
        'Stage2RuntimeIdentity:(?<environment>[^|\s]+)\|(?<database>[^\s";]+)'
    )
    if (-not $identityMatch.Success) {
        throw 'The dedicated Stage 2 runtime identity proof was absent.'
    }

    Assert-Stage2RuntimeFacts `
        -Environment $identityMatch.Groups['environment'].Value `
        -Database $identityMatch.Groups['database'].Value

    $statusCode = $null
    try {
        $response = Invoke-WebRequest `
            -UseBasicParsing `
            -Headers @{ Accept = 'application/json' } `
            -Uri ($ApiTarget.BaseUrl + '/auth/me') `
            -TimeoutSec 3
        $statusCode = [int] $response.StatusCode
    }
    catch {
        if ($null -ne $_.Exception.Response) {
            $statusCode = [int] $_.Exception.Response.StatusCode
        }
        else {
            throw 'The selected dedicated Stage 2 API target was not reachable.'
        }
    }

    if ($statusCode -ne 401) {
        throw 'The selected dedicated Stage 2 API did not expose the expected protected API boundary.'
    }

    [pscustomobject] @{
        ContainerName = $BackendContainerName
        ContainerId = $inspection.Id
        ApiBaseUrl = $ApiTarget.BaseUrl
        Port = $ApiTarget.Port
        Environment = 'testing'
        Database = 'testlabuz_testing'
    }
}
