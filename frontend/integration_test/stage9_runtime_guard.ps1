Set-StrictMode -Version Latest

$script:Stage9BackendContainerName = 'testlabuz-stage9-e2e-app'
$script:Stage9BackendContainerPort = '8000/tcp'
$script:Stage9BackendImage = 'testlabuz-app:latest'
$script:Stage9BackendCommand = @('php', 'artisan', 'serve', '--host=0.0.0.0', '--port=8000', '--no-reload')
$script:Stage9WorkerCount = '4'
$script:Stage9PostgresContainerName = 'testlabuz-postgres-1'
$script:Stage9PostgresImage = 'postgres:18.4'
$script:Stage9DockerNetworkName = 'testlabuz_default'
$script:Stage9BackendRoot = '/var/www/html'
$script:Stage9PrivateRoot = '/var/www/html/storage/app/private'
$script:Stage9PrivateVolumeName = 'testlabuz-stage9-e2e-private-files'
$script:Stage9HarnessMutexName = 'Local\TestLabUzStage9Harness'
$script:Stage9ManualSmokeMarker = Join-Path ([IO.Path]::GetTempPath()) 'testlabuz-stage9-manual-smoke.pending'

# The runner and the manual-smoke script clean and reseed the same manifest, so only one may run at a time,
# and nothing may reseed while a prepared manual smoke is pending on the owner's device.
function Enter-Stage9HarnessLock {
    $mutex = [Threading.Mutex]::new($false, $script:Stage9HarnessMutexName)
    $acquired = $false
    try { $acquired = $mutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) {
        $mutex.Dispose()
        throw 'environment/runtime defect: another Stage 9 harness run is active on this machine.'
    }
    $mutex
}

function Exit-Stage9HarnessLock {
    param([AllowNull()] $Mutex)
    if ($null -eq $Mutex) { return }
    try { $Mutex.ReleaseMutex() } finally { $Mutex.Dispose() }
}

function Test-Stage9ManualSmokePending { Test-Path -LiteralPath $script:Stage9ManualSmokeMarker }

function Get-Stage9ManualSmokePendingMessage {
    "a prepared Android manual smoke is pending (marker $script:Stage9ManualSmokeMarker); finish it with prepare_stage9_manual_smoke.ps1 -CompleteManualSmokeAndCleanup or withdraw it with -AbandonManualSmoke."
}

$script:Stage9RequiredEnvironment = @{
    APP_ENV = 'testing'
    APP_DEBUG = 'false'
    DB_CONNECTION = 'pgsql'
    DB_HOST = 'postgres'
    DB_PORT = '5432'
    DB_DATABASE = 'testlabuz_testing'
    # Database-backed drivers would write unowned rows (cache, sessions, jobs) into testlabuz_testing.
    CACHE_STORE = 'file'
    SESSION_DRIVER = 'file'
    QUEUE_CONNECTION = 'sync'
}
$script:Stage9NamedEnvironment = @('APP_ENV', 'APP_DEBUG', 'DB_CONNECTION', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'CACHE_STORE', 'SESSION_DRIVER', 'QUEUE_CONNECTION', 'PHP_CLI_SERVER_WORKERS')

function Get-Stage9InputSecrets {
    param([string] $InputJson)
    try { $parsed = $InputJson | ConvertFrom-Json } catch { return @() }
    if ($parsed -isnot [pscustomobject]) { return @() }
    @($parsed.PSObject.Properties | ForEach-Object { [string] $_.Value } | Where-Object { $_.Length -ge 4 })
}

# Only the short wrapper/path reaches argv. The program travels over stdin into a private file; the input
# travels over php's own stdin and is never written to a file.
function Invoke-Stage9ContainerPhp {
    param(
        [Parameter(Mandatory = $true)][string] $Program,
        [string] $InputJson = '{}',
        [string] $BackendContainerName = $script:Stage9BackendContainerName,
        [ValidateRange(1, 3600)][int] $TimeoutSeconds = 300
    )
    if ($BackendContainerName -cne $script:Stage9BackendContainerName) {
        throw 'integration-harness defect: Stage 9 PHP transport requires the exact dedicated backend container.'
    }
    $containerPath = '/tmp/testlabuz-stage9-program-' + [guid]::NewGuid().ToString('N') + '.php'
    $bootstrap = @'
<?php
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
require '/var/www/html/vendor/autoload.php';
$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
// Only the harness's own fail-closed messages leave the container; every other failure stays silent.
set_exception_handler(static function (Throwable $exception): void {
    if (get_class($exception) === RuntimeException::class
        && preg_match('/\A(?:Static |Unowned )?Stage 9 [^\r\n]{0,300}\z/', $exception->getMessage()) === 1) {
        echo json_encode(['stage9_refusal' => $exception->getMessage()], JSON_THROW_ON_ERROR);
        exit(3);
    }
    exit(1);
});
$stage9Raw = (string) stream_get_contents(STDIN);
if (str_starts_with($stage9Raw, "\xEF\xBB\xBF")) { $stage9Raw = substr($stage9Raw, 3); }
$stage9Input = json_decode($stage9Raw, true, 512, JSON_THROW_ON_ERROR);
unset($stage9Raw);
'@
    $content = $bootstrap + "`n" + $Program
    $knownFailure = $null
    try {
        $originalOutputEncoding = $OutputEncoding
        try {
            $OutputEncoding = [Text.UTF8Encoding]::new($false)
            $null = @($content | & docker exec -i $BackendContainerName sh -c "umask 077; set -C; cat > '$containerPath'" 2>&1)
            if ($LASTEXITCODE -ne 0) { $knownFailure = 'environment/runtime defect: Stage 9 restricted PHP transport failed.'; throw $knownFailure }
            # timeout bounds the PHP process inside the container; stopping the docker client alone would not.
            $output = @($InputJson | & docker exec -i $BackendContainerName timeout --kill-after=10 $TimeoutSeconds php $containerPath 2>&1)
            $exitCode = $LASTEXITCODE
        }
        finally { $OutputEncoding = $originalOutputEncoding }
        if ($exitCode -eq 124 -or $exitCode -eq 137) {
            $knownFailure = "environment/runtime defect: Stage 9 container PHP timed out after $TimeoutSeconds s."
            throw $knownFailure
        }
        if ($exitCode -eq 3) {
            $refusal = $null
            try { $refusal = [string] ((($output | ForEach-Object { [string] $_ }) -join "`n") | ConvertFrom-Json).stage9_refusal } catch { $refusal = $null }
            if (-not [string]::IsNullOrWhiteSpace($refusal)) {
                foreach ($secret in @(Get-Stage9InputSecrets $InputJson)) { $refusal = $refusal.Replace($secret, '[REDACTED]') }
                $knownFailure = "environment/runtime defect: Stage 9 container PHP refused: $refusal"
                throw $knownFailure
            }
        }
        if ($exitCode -ne 0) { throw 'integration-harness defect: Stage 9 container PHP operation failed.' }
        try { return (($output -join "`n") | ConvertFrom-Json) }
        catch { $knownFailure = 'integration-harness defect: Stage 9 container PHP operation returned invalid JSON; raw output withheld.'; throw $knownFailure }
    }
    catch {
        if ($null -ne $knownFailure) { throw $knownFailure }
        throw 'integration-harness defect: Stage 9 container PHP operation failed; raw diagnostics withheld to protect inputs.'
    }
    finally {
        $content = $null; $InputJson = $null; $output = $null
        $null = @(& docker exec $BackendContainerName rm -f -- $containerPath 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: Stage 9 restricted container-script cleanup failed.' }
    }
}

function Resolve-Stage9ApiTarget {
    param([Parameter(Mandatory = $true)][string] $ApiBaseUrl)

    $match = [regex]::Match(
        $ApiBaseUrl,
        '\Ahttp://127\.0\.0\.1:(?<port>[0-9]{1,5})/api/v1\z',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $match.Success) {
        throw 'environment/runtime defect: Stage 9 E2E requires exactly http://127.0.0.1:<explicit-port>/api/v1.'
    }
    $port = [int] $match.Groups['port'].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw 'environment/runtime defect: Stage 9 E2E requires an explicit port between 1 and 65535.'
    }
    try {
        $uri = [Uri] $ApiBaseUrl
    }
    catch {
        throw 'environment/runtime defect: The Stage 9 E2E API target is malformed.'
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
        throw 'environment/runtime defect: The Stage 9 E2E API target is outside the dedicated loopback boundary.'
    }

    [pscustomobject] @{ BaseUrl = $ApiBaseUrl; Port = $port }
}

function Assert-Stage9ContainerFacts {
    param(
        [Parameter(Mandatory = $true)][int] $InspectionCount,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $ContainerName,
        [Parameter(Mandatory = $true)][bool] $Running,
        [Parameter(Mandatory = $true)][bool] $AutoRemove,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $WorkingDirectory,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $Image,
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][string[]] $Command,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $Platform,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $RestartPolicy
    )

    if ($InspectionCount -ne 1 -or $ContainerName -cne $script:Stage9BackendContainerName) {
        throw 'environment/runtime defect: The dedicated Stage 9 backend container identity is missing or ambiguous.'
    }
    if (-not $Running) { throw 'environment/runtime defect: The dedicated Stage 9 backend container must be running.' }
    if ($AutoRemove -or $RestartPolicy -cne 'no') { throw 'environment/runtime defect: The dedicated Stage 9 backend container must be restartable only on request.' }
    if ($WorkingDirectory -cne $script:Stage9BackendRoot) {
        throw 'environment/runtime defect: The dedicated Stage 9 backend working directory is unsafe.'
    }
    if ($Image -cne $script:Stage9BackendImage) { throw 'environment/runtime defect: The dedicated Stage 9 backend image is not the approved app image.' }
    if (($Command -join "`n") -cne ($script:Stage9BackendCommand -join "`n")) {
        throw 'environment/runtime defect: The dedicated Stage 9 backend must run artisan serve with --no-reload; otherwise Laravel drops PHP_CLI_SERVER_WORKERS.'
    }
    if ($Platform -cne 'linux') { throw 'environment/runtime defect: The Stage 9 concurrency runtime must be a Linux container capable of worker forking.' }
}

function Assert-Stage9MountFacts {
    param(
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]] $Mounts,
        [Parameter(Mandatory = $true)][string] $ExpectedBackendSource
    )

    $resolvedExpected = [IO.Path]::GetFullPath($ExpectedBackendSource).TrimEnd('\', '/')
    $backendMounts = @($Mounts | Where-Object { $_.Destination -ceq $script:Stage9BackendRoot })
    if ($backendMounts.Count -ne 1) {
        throw 'environment/runtime defect: The exact Stage 9 backend source bind is missing or ambiguous.'
    }
    $backendMount = $backendMounts[0]
    $resolvedSource = [IO.Path]::GetFullPath([string] $backendMount.Source).TrimEnd('\', '/')
    if (
        [string] $backendMount.Type -cne 'bind' -or
        [bool] $backendMount.RW -ne $true -or
        -not $resolvedSource.Equals($resolvedExpected, [StringComparison]::OrdinalIgnoreCase)
    ) {
        throw 'environment/runtime defect: The Stage 9 backend source bind does not own the current repository backend.'
    }
    foreach ($mount in $Mounts) {
        if ($mount -eq $backendMount) { continue }
        if ([string] $mount.Type -ceq 'bind' -and
            [IO.Path]::GetFullPath([string] $mount.Source).TrimEnd('\', '/').Equals($resolvedExpected, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'environment/runtime defect: The Stage 9 backend source has an ambiguous alias mount.'
        }
    }
    $privateMounts = @($Mounts | Where-Object { $_.Destination -ceq $script:Stage9PrivateRoot })
    if ($privateMounts.Count -ne 1) { throw 'environment/runtime defect: The Stage 9 private root mount is missing or ambiguous.' }
    $privateMount = $privateMounts[0]
    if ([string] $privateMount.Type -cne 'volume' -or
        [string] $privateMount.Name -cne $script:Stage9PrivateVolumeName -or
        [bool] $privateMount.RW -ne $true) {
        throw 'environment/runtime defect: Stage 9 private storage requires the exact read/write named volume.'
    }
    foreach ($mount in $Mounts) {
        if ($mount -eq $privateMount) { continue }
        $name = if ($null -eq $mount.PSObject.Properties['Name']) { '' } else { [string] $mount.Name }
        if ($name -ceq $script:Stage9PrivateVolumeName -or [string] $mount.Source -ceq [string] $privateMount.Source) {
            throw 'environment/runtime defect: Stage 9 private storage is exposed by an alias mount.'
        }
        if ([string] $mount.Destination -clike ($script:Stage9PrivateRoot + '/*')) {
            throw 'environment/runtime defect: An additional mount shadows the Stage 9 private volume.'
        }
        if ($mount -ne $backendMount) {
            $destination = ([string] $mount.Destination).TrimEnd('/')
            if ($destination -clike ($script:Stage9BackendRoot + '/*') -or
                $script:Stage9BackendRoot.StartsWith($destination + '/', [StringComparison]::Ordinal)) {
                throw 'environment/runtime defect: An unexpected mount shadows the current Stage 9 backend source.'
            }
        }
    }
}

function Assert-Stage9PortBindingFacts {
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
            throw 'environment/runtime defect: The selected Stage 9 API port is not actively bound exactly once to loopback.'
        }
    }
}

# Only named values are read; the full Docker environment is never printed or returned.
function Assert-Stage9ContainerEnvironment {
    param([AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]] $Environment)
    $named = @{}
    foreach ($entry in $Environment) {
        $text = [string] $entry
        $separator = $text.IndexOf('=')
        if ($separator -gt 0 -and $text.Substring(0, $separator) -cin $script:Stage9NamedEnvironment) {
            $named[$text.Substring(0, $separator)] = $text.Substring($separator + 1)
        }
    }
    foreach ($name in $script:Stage9RequiredEnvironment.Keys) {
        if ([string] $named[$name] -cne $script:Stage9RequiredEnvironment[$name]) {
            throw "environment/runtime defect: The dedicated Stage 9 backend container has an unsafe $name value."
        }
    }
    Assert-Stage9WorkerEnvironment -Value ([string] $named['PHP_CLI_SERVER_WORKERS'])
    $named
}

# Static configuration of an inspected container: everything that must hold before it may be started.
function Assert-Stage9ContainerConfiguration {
    param([Parameter(Mandatory = $true)][psobject] $Inspection, [Parameter(Mandatory = $true)][int] $ApiPort)
    Assert-Stage9ContainerFacts -InspectionCount 1 -ContainerName ([string] $Inspection.Name.TrimStart('/')) -Running $true `
        -AutoRemove ([bool] $Inspection.HostConfig.AutoRemove) -WorkingDirectory ([string] $Inspection.Config.WorkingDir) -Image ([string] $Inspection.Config.Image) `
        -Command @($Inspection.Config.Cmd | ForEach-Object { [string] $_ }) -Platform ([string] $Inspection.Platform) -RestartPolicy ([string] $Inspection.HostConfig.RestartPolicy.Name)
    Assert-Stage9MountFacts -Mounts @($Inspection.Mounts) -ExpectedBackendSource (Get-Stage9BackendSource)
    # A stopped container has no active binding yet, so only its configured binding is judged here.
    $configured = @($Inspection.HostConfig.PortBindings.($script:Stage9BackendContainerPort))
    Assert-Stage9PortBindingFacts -ConfiguredBindings $configured -ActiveBindings $configured -ApiPort $ApiPort
    if ([string] $Inspection.HostConfig.NetworkMode -cne $script:Stage9DockerNetworkName) {
        throw 'environment/runtime defect: The dedicated Stage 9 backend container is not configured on the approved Docker network.'
    }
    Assert-Stage9ContainerEnvironment -Environment @($Inspection.Config.Env)
}

# A null client address is a local socket inside the PostgreSQL container, which is foreign too.
function Assert-Stage9DatabaseExclusivity {
    param([Parameter(Mandatory = $true)] $Facts, [Parameter(Mandatory = $true)][string] $ClientAddress)
    if ($null -eq $Facts.PSObject.Properties['sessions']) { throw 'integration-harness defect: the Stage 9 session listing is missing.' }
    $foreign = @(@($Facts.sessions) | Where-Object { [string] $_.client_addr -cne $ClientAddress })
    if ($foreign.Count -ne 0) {
        throw 'environment/runtime defect: another client uses testlabuz_testing; stop it (for example a backend test run) and rerun.'
    }
}

# A run owns testlabuz_testing: any other client (a backend test run, a psql session) could wipe or change its state.
function Assert-Stage9ExclusiveDatabase {
    param([Parameter(Mandatory = $true)][string] $ClientAddress)
    if ($ClientAddress -cnotmatch '\A[0-9]{1,3}(?:\.[0-9]{1,3}){3}\z') { throw 'integration-harness defect: the Stage 9 client address is required.' }
    $program = @'
if (!app()->environment('testing') || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new RuntimeException('Stage 9 exclusive-database identity failed.');
}
$sessions = DB::select("select host(client_addr) as client_addr from pg_stat_activity where datname = current_database() and backend_type = 'client backend' and pid <> pg_backend_pid()");
echo json_encode(['sessions' => $sessions], JSON_THROW_ON_ERROR);
'@
    Assert-Stage9DatabaseExclusivity (Invoke-Stage9ContainerPhp -Program $program) $ClientAddress
    # A test run or command started inside this container shares its address, so the session check cannot see it.
    Assert-Stage9NoContainerWork -Processes @(Get-Stage9ProcessFacts)
}

function Assert-Stage9NoContainerWork {
    param([AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]] $Processes)
    $foreign = @($Processes | Where-Object { [string] $_.cmd -cmatch '(?:\A|[\s/])(?:phpunit|paratest)(?:\s|\z)' -or [string] $_.cmd -cmatch '\bartisan\s+(?!serve\b)\S' })
    if ($foreign.Count -ne 0) {
        throw 'environment/runtime defect: another workload (a test run or an artisan command) runs inside the Stage 9 container; stop it and rerun.'
    }
}

# Every stage E2E runtime uses testlabuz_testing, so a running runtime of another stage could wipe or change this run's state.
# Names are trimmed so that a stray line terminator cannot hide a conflicting runtime.
function Assert-Stage9NoOtherStageRuntime {
    param([AllowEmptyCollection()][AllowEmptyString()][AllowNull()][Parameter(Mandatory = $true)][string[]] $RunningNames)
    $others = @(@($RunningNames) | ForEach-Object { ([string] $_).Trim() } |
        Where-Object { $_ -cmatch '\Atestlabuz-stage[0-9]+-e2e-app\z' -and $_ -cne $script:Stage9BackendContainerName })
    if ($others.Count -ne 0) {
        throw "environment/runtime defect: another stage E2E runtime shares testlabuz_testing ($($others -join ', ')); stop it and rerun."
    }
}

function Assert-Stage9NoOtherStageRuntimeLive {
    $runningNames = @(& docker ps --format '{{.Names}}' 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: Docker could not list the running containers.' }
    Assert-Stage9NoOtherStageRuntime -RunningNames $runningNames
}

function Assert-Stage9ServerFacts {
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
        throw 'environment/runtime defect: The dedicated Stage 9 runtime has an unapproved database server target.'
    }
    if ($PostgresContainerName -cne $script:Stage9PostgresContainerName -or $PostgresImage -cne $script:Stage9PostgresImage) {
        throw 'environment/runtime defect: The dedicated Stage 9 runtime has an unapproved PostgreSQL identity.'
    }
    if (-not $BackendNetworkPresent -or -not $PostgresNetworkPresent -or -not $PostgresRunning) {
        throw 'environment/runtime defect: The approved Stage 9 PostgreSQL server/network is unavailable.'
    }
}

function Assert-Stage9WorkerEnvironment {
    param([AllowNull()][string] $Value)
    if ($Value -cne $script:Stage9WorkerCount) {
        throw 'environment/runtime defect: The dedicated Stage 9 runtime requires exactly PHP_CLI_SERVER_WORKERS=4.'
    }
}

function Assert-Stage9ProcessFacts {
    param([AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]] $Processes)
    # Laravel only forks the requested workers with --no-reload; the environment value alone proves nothing.
    $serve = @($Processes | Where-Object { [string] $_.cmd -ceq ($script:Stage9BackendCommand -join ' ') })
    if ($serve.Count -ne 1) { throw 'environment/runtime defect: The Stage 9 artisan serve process is missing or ambiguous.' }
    $servers = @($Processes | Where-Object { [string] $_.cmd -cmatch '\A\S*php -S 0\.0\.0\.0:8000 \S+server\.php\z' })
    $masters = @($servers | Where-Object { [int] $_.ppid -eq [int] $serve[0].pid })
    if ($masters.Count -ne 1) { throw 'environment/runtime defect: The Stage 9 PHP built-in server master is missing or ambiguous.' }
    $workers = @($servers | Where-Object { [int] $_.ppid -eq [int] $masters[0].pid })
    if ($workers.Count -ne [int] $script:Stage9WorkerCount -or $servers.Count -ne $workers.Count + 1) {
        throw 'environment/runtime defect: The Stage 9 PHP built-in server does not run exactly four forked workers.'
    }
    if (@($Processes | Where-Object { [string] $_.cmd -cmatch 'schedule:(?:run|work)' }).Count -ne 0) {
        throw 'environment/runtime defect: A Laravel scheduler runs in the Stage 9 container; the scheduled checking commands must stay guarded.'
    }
    $workers.Count
}

# The application's own database session proves both ends: its client address is the Stage 9 container
# and its server address is the approved PostgreSQL container on the same network.
function Assert-Stage9SessionCorrelation {
    param([AllowEmptyString()][string] $ClientAddress, [AllowEmptyString()][string] $ContainerAddress,
        [AllowEmptyString()][string] $ServerAddress, [AllowEmptyString()][string] $PostgresAddress)
    $ipv4 = '\A[0-9]{1,3}(?:\.[0-9]{1,3}){3}\z'
    if ($ContainerAddress -cnotmatch $ipv4 -or $ClientAddress -cne $ContainerAddress) {
        throw 'environment/runtime defect: Stage 9 application database sessions cannot be correlated to the container network address.'
    }
    if ($PostgresAddress -cnotmatch $ipv4 -or $ServerAddress -cne $PostgresAddress) {
        throw 'environment/runtime defect: The Stage 9 application is not connected to the approved PostgreSQL container.'
    }
}

function Get-Stage9ProcessFacts {
    param([string] $BackendContainerName = $script:Stage9BackendContainerName)
    # Reads only /proc/<pid>/cmdline and the PPid line of /proc/<pid>/status; process environments are never read.
    $program = @'
$processes = [];
foreach (glob('/proc/[0-9]*') ?: [] as $path) {
    $cmdline = @file_get_contents($path.'/cmdline');
    $status = @file_get_contents($path.'/status');
    if (!is_string($cmdline) || $cmdline === '' || !is_string($status) || !preg_match('/^PPid:\s+(\d+)$/m', $status, $parent)) { continue; }
    $processes[] = ['pid' => (int) basename($path), 'ppid' => (int) $parent[1], 'cmd' => trim(str_replace("\0", ' ', $cmdline))];
}
echo json_encode(['processes' => $processes], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
'@
    @((Invoke-Stage9ContainerPhp -BackendContainerName $BackendContainerName -Program $program).processes)
}

function Assert-Stage9LaravelFacts {
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
        throw 'environment/runtime defect: The Stage 9 Laravel/database runtime identity is unsafe.'
    }
    if ([string]::IsNullOrWhiteSpace([string] $Facts.private_disk) -or
        [string] $Facts.private_disk -ceq 'public' -or
        [string] $Facts.private_driver -cne 'local' -or
        [bool] $Facts.private_public -ne $false -or
        [string] $Facts.private_root -cnotmatch '\A/var/www/html/storage/app/private(?:/[^/]+)*\z' -or
        [string] $Facts.private_root -match '/(?:\.|\.\.)(?:/|$)|\\' -or
        [string] $Facts.private_root -ceq [string] $Facts.public_root) {
        throw 'environment/runtime defect: The Stage 9 configured private disk/root is unsafe.'
    }
}

function Assert-Stage9HttpBoundaryFacts {
    param(
        [Parameter(Mandatory = $true)][int] $StatusCode,
        [Parameter(Mandatory = $true)][object] $Envelope
    )

    if ($StatusCode -ne 401) { throw 'environment/runtime defect: The Stage 9 HTTP protected boundary returned the wrong status.' }
    $properties = @($Envelope.PSObject.Properties.Name)
    if (
        [string] $Envelope.code -cne 'authentication_required' -or
        $Envelope.errors -isnot [pscustomobject] -or
        $Envelope.message -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Envelope.message) -or
        $null -eq $Envelope.errors -or
        @($Envelope.errors.PSObject.Properties).Count -ne 0 -or
        @($properties | Where-Object { $_ -cnotin @('message', 'code', 'errors') }).Count -ne 0 -or
        @(@('message', 'code', 'errors') | Where-Object { $_ -cnotin $properties }).Count -ne 0
    ) {
        throw 'environment/runtime defect: The Stage 9 HTTP protected boundary returned an unsafe envelope.'
    }
}

function Get-Stage9ErrorResponseBody {
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

function Invoke-Stage9HttpBoundaryProbe {
    param([Parameter(Mandatory = $true)][psobject] $ApiTarget)

    $statusCode = $null
    $body = $null
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Headers @{ Accept = 'application/json' } -Uri ($ApiTarget.BaseUrl + '/auth/me') -TimeoutSec 5 -MaximumRedirection 0
        $statusCode = [int] $response.StatusCode
        $body = [string] $response.Content
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw 'environment/runtime defect: The selected Stage 9 API target was not reachable.' }
        $statusCode = [int] $_.Exception.Response.StatusCode
        $body = Get-Stage9ErrorResponseBody -Exception $_.Exception
    }
    try { $envelope = $body | ConvertFrom-Json } catch { throw 'integration-harness defect: The Stage 9 HTTP protected boundary returned invalid JSON.' }
    Assert-Stage9HttpBoundaryFacts -StatusCode $statusCode -Envelope $envelope
}

function Wait-Stage9HttpBoundary {
    param([Parameter(Mandatory = $true)][psobject] $ApiTarget, [int] $TimeoutSeconds = 45)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        try { Invoke-Stage9HttpBoundaryProbe -ApiTarget $ApiTarget; return }
        catch {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'environment/runtime defect: The Stage 9 backend did not reach its exact HTTP boundary in time.' }
            Start-Sleep -Milliseconds 250
        }
    } while ($true)
}

function Get-Stage9BackendSource {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'backend')).Path
}

function Assert-Stage9DedicatedRuntime {
    param(
        [Parameter(Mandatory = $true)][psobject] $ApiTarget,
        [string] $BackendContainerName = $script:Stage9BackendContainerName
    )

    if ($BackendContainerName -cne $script:Stage9BackendContainerName) {
        throw 'environment/runtime defect: Stage 9 E2E may inspect only the exact dedicated backend container.'
    }
    $validatedTarget = Resolve-Stage9ApiTarget -ApiBaseUrl $ApiTarget.BaseUrl
    if ($validatedTarget.Port -ne $ApiTarget.Port) { throw 'environment/runtime defect: The Stage 9 API target has inconsistent port facts.' }
    $inspectionOutput = & docker inspect $BackendContainerName 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: The dedicated Stage 9 backend container could not be inspected.' }
    try { $inspections = @($inspectionOutput | ConvertFrom-Json) } catch { throw 'environment/runtime defect: The Stage 9 backend inspection was invalid.' }
    Assert-Stage9NoOtherStageRuntimeLive
    $inspection = if ($inspections.Count -eq 1) { $inspections[0] } else { $null }
    Assert-Stage9ContainerFacts `
        -InspectionCount $inspections.Count `
        -ContainerName $(if ($null -eq $inspection) { '' } else { [string] $inspection.Name.TrimStart('/') }) `
        -Running $(if ($null -eq $inspection) { $false } else { [bool] $inspection.State.Running }) `
        -AutoRemove $(if ($null -eq $inspection) { $true } else { [bool] $inspection.HostConfig.AutoRemove }) `
        -WorkingDirectory $(if ($null -eq $inspection) { '' } else { [string] $inspection.Config.WorkingDir }) `
        -Image $(if ($null -eq $inspection) { '' } else { [string] $inspection.Config.Image }) `
        -Command $(if ($null -eq $inspection) { @() } else { @($inspection.Config.Cmd | ForEach-Object { [string] $_ }) }) `
        -Platform $(if ($null -eq $inspection) { '' } else { [string] $inspection.Platform }) `
        -RestartPolicy $(if ($null -eq $inspection) { '' } else { [string] $inspection.HostConfig.RestartPolicy.Name })

    $containerEnvironment = Assert-Stage9ContainerConfiguration -Inspection $inspection -ApiPort $ApiTarget.Port
    Assert-Stage9PortBindingFacts `
        -ConfiguredBindings @($inspection.HostConfig.PortBindings.($script:Stage9BackendContainerPort)) `
        -ActiveBindings @($inspection.NetworkSettings.Ports.($script:Stage9BackendContainerPort)) `
        -ApiPort $ApiTarget.Port

    $postgresOutput = & docker inspect $script:Stage9PostgresContainerName 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: The approved Stage 9 PostgreSQL container could not be inspected.' }
    try { $postgresInspections = @($postgresOutput | ConvertFrom-Json) } catch { throw 'environment/runtime defect: The Stage 9 PostgreSQL inspection was invalid.' }
    if ($postgresInspections.Count -ne 1) { throw 'environment/runtime defect: The approved Stage 9 PostgreSQL identity was ambiguous.' }
    $postgres = $postgresInspections[0]
    Assert-Stage9ServerFacts `
        -DatabaseHost ([string] $containerEnvironment['DB_HOST']) `
        -DatabasePort ([string] $containerEnvironment['DB_PORT']) `
        -PostgresContainerName ([string] $postgres.Name.TrimStart('/')) `
        -PostgresImage ([string] $postgres.Config.Image) `
        -BackendNetworkPresent ($null -ne $inspection.NetworkSettings.Networks.($script:Stage9DockerNetworkName)) `
        -PostgresNetworkPresent ($null -ne $postgres.NetworkSettings.Networks.($script:Stage9DockerNetworkName)) `
        -PostgresRunning ([bool] $postgres.State.Running)
    $containerEnvironment = $null
    $observedWorkers = Assert-Stage9ProcessFacts -Processes @(Get-Stage9ProcessFacts -BackendContainerName $BackendContainerName)

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
    'client_address' => (string) DB::scalar('select host(inet_client_addr())'),
    'server_address' => (string) DB::scalar('select host(inet_server_addr())'),
];
echo json_encode($facts, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
'@
    $facts = Invoke-Stage9ContainerPhp -BackendContainerName $BackendContainerName -Program $runtimeProgram
    Assert-Stage9LaravelFacts -Facts $facts
    $networkAddress = [string] $inspection.NetworkSettings.Networks.($script:Stage9DockerNetworkName).IPAddress
    Assert-Stage9SessionCorrelation -ClientAddress ([string] $facts.client_address) -ContainerAddress $networkAddress `
        -ServerAddress ([string] $facts.server_address) -PostgresAddress ([string] $postgres.NetworkSettings.Networks.($script:Stage9DockerNetworkName).IPAddress)
    Invoke-Stage9HttpBoundaryProbe -ApiTarget $ApiTarget

    [pscustomobject] @{
        ContainerName = $BackendContainerName
        ContainerId = [string] $inspection.Id
        ApiBaseUrl = $ApiTarget.BaseUrl
        Port = $ApiTarget.Port
        Environment = 'testing'
        Database = 'testlabuz_testing'
        ConnectionDriver = 'pgsql'
        PostgresContainerName = $script:Stage9PostgresContainerName
        DockerNetworkName = $script:Stage9DockerNetworkName
        PrivateVolumeName = $script:Stage9PrivateVolumeName
        ClientAddress = $networkAddress
        Workers = [int] $observedWorkers
    }
}

function Read-Stage9DatabasePassword {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $lines = @(Get-Content -LiteralPath (Join-Path $repositoryRoot 'docker/.env') -ErrorAction Stop | Where-Object { $_ -cmatch '\APOSTGRES_PASSWORD=' })
    if ($lines.Count -ne 1) { throw 'environment/runtime defect: docker/.env must define POSTGRES_PASSWORD exactly once.' }
    $value = $lines[0].Substring('POSTGRES_PASSWORD='.Length).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { throw 'environment/runtime defect: docker/.env POSTGRES_PASSWORD is blank.' }
    $value
}

# Creates the dedicated runtime only when absent; an existing container is never removed or reconfigured.
function Initialize-Stage9Runtime {
    param([Parameter(Mandatory = $true)][psobject] $ApiTarget)
    Assert-Stage9NoOtherStageRuntimeLive
    $existing = @(& docker ps -a --filter "name=^/$($script:Stage9BackendContainerName)$" --format '{{.Names}}' 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: Docker could not list the Stage 9 runtime.' }
    if ($existing.Count -gt 1) { throw 'environment/runtime defect: The Stage 9 runtime container identity is ambiguous.' }
    if ($existing.Count -eq 1) {
        $inspection = @(& docker inspect $script:Stage9BackendContainerName 2>$null | ConvertFrom-Json)
        if ($LASTEXITCODE -ne 0 -or $inspection.Count -ne 1) { throw 'environment/runtime defect: The existing Stage 9 runtime could not be inspected.' }
        $static = $inspection[0]
        Assert-Stage9ContainerConfiguration -Inspection $static -ApiPort $ApiTarget.Port | Out-Null
        if ([string] $static.State.Running -cne 'True') {
            & docker start $script:Stage9BackendContainerName | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: The existing Stage 9 runtime could not be started.' }
        }
        Wait-Stage9HttpBoundary -ApiTarget $ApiTarget
        return 'existing'
    }
    $volumes = @(& docker volume ls --filter "name=^$($script:Stage9PrivateVolumeName)$" --format '{{.Name}}' 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: Docker could not list the Stage 9 private volume.' }
    if ($volumes.Count -eq 0) {
        & docker volume create $script:Stage9PrivateVolumeName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: The Stage 9 private volume could not be created.' }
    }
    $previous = [Environment]::GetEnvironmentVariable('DB_PASSWORD', 'Process')
    try {
        # Passed to Docker by name only, so the value never reaches a command line.
        [Environment]::SetEnvironmentVariable('DB_PASSWORD', (Read-Stage9DatabasePassword), 'Process')
        $arguments = @('run', '-d', '--name', $script:Stage9BackendContainerName, '--network', $script:Stage9DockerNetworkName, '--restart', 'no',
            '-p', "127.0.0.1:$($ApiTarget.Port):8000", '-v', "$(Get-Stage9BackendSource):$($script:Stage9BackendRoot)",
            '-v', "$($script:Stage9PrivateVolumeName):$($script:Stage9PrivateRoot)", '-w', $script:Stage9BackendRoot,
            '-e', 'APP_ENV=testing', '-e', 'APP_DEBUG=false', '-e', "APP_URL=http://127.0.0.1:$($ApiTarget.Port)",
            '-e', 'CACHE_STORE=file', '-e', 'SESSION_DRIVER=file', '-e', 'QUEUE_CONNECTION=sync',
            '-e', 'DB_CONNECTION=pgsql', '-e', 'DB_HOST=postgres', '-e', 'DB_PORT=5432', '-e', 'DB_DATABASE=testlabuz_testing',
            '-e', 'DB_USERNAME=testlabuz', '-e', 'DB_PASSWORD', '-e', "PHP_CLI_SERVER_WORKERS=$($script:Stage9WorkerCount)",
            $script:Stage9BackendImage) + $script:Stage9BackendCommand
        & docker @arguments | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'environment/runtime defect: The Stage 9 runtime container could not be created.' }
    }
    finally { [Environment]::SetEnvironmentVariable('DB_PASSWORD', $previous, 'Process') }
    Wait-Stage9HttpBoundary -ApiTarget $ApiTarget
    'created'
}
