Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage8_runtime_guard.ps1')

$script:Stage8ProbeWindowSeconds = 30
$script:Stage8ProbeDeadlineMarginSeconds = 60
$script:Stage8ProbeLockTypes = @('transactionid', 'tuple')

# Pure evaluation of observer samples. Only one sample may prove overlap: both waiters must be there together.
function Get-Stage8OverlapEvidence {
    param(
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]] $Samples,
        [Parameter(Mandatory = $true)][int] $BlockerPid,
        [Parameter(Mandatory = $true)][int] $ObserverPid,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $ApplicationAddress,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $Database,
        [Parameter(Mandatory = $true)][int] $WorkerCount,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string] $LockedAttemptId,
        [Parameter(Mandatory = $true)][string] $ExpectedAttemptId
    )
    if ($WorkerCount -ne 4) { throw 'integration-harness defect: Stage 8 overlap proof requires PHP_CLI_SERVER_WORKERS=4.' }
    if ($Database -cne 'testlabuz_testing') { throw 'integration-harness defect: Stage 8 observer is not scoped to testlabuz_testing.' }
    if ($ApplicationAddress -cnotmatch '\A[0-9]{1,3}(?:\.[0-9]{1,3}){3}\z') { throw 'integration-harness defect: Stage 8 application client address is unknown.' }
    if ($LockedAttemptId -cne $ExpectedAttemptId) { throw 'integration-harness defect: Stage 8 blocker holds a different Attempt than the race.' }
    if ($BlockerPid -le 0 -or $ObserverPid -le 0 -or $BlockerPid -eq $ObserverPid) { throw 'integration-harness defect: Stage 8 probe session identities are invalid.' }

    foreach ($sample in $Samples) {
        $sessions = @($sample.sessions | Where-Object { $null -ne $_ })
        $byPid = @{}
        foreach ($session in $sessions) {
            if ($byPid.ContainsKey([int] $session.pid)) { throw 'integration-harness defect: Stage 8 observer sample repeats a PID.' }
            $byPid[[int] $session.pid] = $session
        }
        $waiters = @($sessions | Where-Object {
            [int] $_.pid -ne $BlockerPid -and [int] $_.pid -ne $ObserverPid -and
            [string] $_.datname -ceq 'testlabuz_testing' -and [string] $_.client_addr -ceq $ApplicationAddress -and
            [string] $_.state -ceq 'active' -and [string] $_.wait_event_type -ceq 'Lock'
        })
        $waiterPids = @($waiters | ForEach-Object { [int] $_.pid } | Sort-Object -Unique)
        if ($waiterPids.Count -lt 2) { continue }
        $rooted = @($waiters | Where-Object {
            $waiter = $_
            $lock = @($sample.waiting_locks | Where-Object { [int] $_.pid -eq [int] $waiter.pid })
            if ($lock.Count -ne 1 -or [string] $lock[0].locktype -cnotin $script:Stage8ProbeLockTypes -or
                ([string] $lock[0].locktype -ceq 'tuple' -and [string] $lock[0].relation -cne 'assessment_attempts')) { return $false }
            # Follow the wait-for graph; every blocker must be the harness blocker or another counted waiter.
            $pending = [Collections.Generic.Queue[int]]::new(); $pending.Enqueue([int] $waiter.pid)
            $visited = [Collections.Generic.HashSet[int]]::new()
            $reachesBlocker = $false
            while ($pending.Count -gt 0) {
                $current = $pending.Dequeue()
                if (-not $visited.Add($current)) { continue }
                $blockers = @($byPid[$current].blockers | ForEach-Object { [int] $_ })
                if ($blockers.Count -eq 0) { return $false }
                foreach ($blocker in $blockers) {
                    if ($blocker -eq $BlockerPid) { $reachesBlocker = $true }
                    elseif ($blocker -in $waiterPids -and $blocker -ne $current) { $pending.Enqueue($blocker) }
                    else { return $false }
                }
            }
            $reachesBlocker
        })
        $rootedPids = @($rooted | ForEach-Object { [int] $_.pid } | Sort-Object -Unique)
        if ($rootedPids.Count -ge 2) {
            return [pscustomobject] @{
                overlap_observed = $true
                waiting_application_pids = $rootedPids
                waiting_count = $rootedPids.Count
                wait_event_type = 'Lock'
                manifest_attempt_id = $ExpectedAttemptId
                blocker_pid = $BlockerPid
                observer_pid = $ObserverPid
                observed_at = [string] $sample.observed_at
            }
        }
    }
    [pscustomobject] @{ overlap_observed = $false; waiting_application_pids = @(); waiting_count = 0; wait_event_type = $null
        manifest_attempt_id = $ExpectedAttemptId; blocker_pid = $BlockerPid; observer_pid = $ObserverPid; observed_at = $null }
}

# A race may be reported PASS only after real overlap was proven before the blocker released.
function Assert-Stage8RaceVerdict {
    param([Parameter(Mandatory = $true)][psobject] $Evidence, [AllowEmptyCollection()][Parameter(Mandatory = $true)][string[]] $Events, [Parameter(Mandatory = $true)][bool] $MarkedPass)
    if (-not $MarkedPass) { return }
    $overlap = [array]::IndexOf($Events, 'overlap_observed')
    $release = [array]::IndexOf($Events, 'blocker_released')
    if (-not [bool] $Evidence.overlap_observed -or [int] $Evidence.waiting_count -lt 2 -or @($Evidence.waiting_application_pids | Sort-Object -Unique).Count -lt 2) {
        throw 'CONCURRENCY EVIDENCE = INCOMPLETE: a race cannot PASS without two simultaneous application lock waiters.'
    }
    if ('window_timed_out' -cin $Events -or $overlap -lt 0 -or $release -lt 0 -or $release -lt $overlap -or
        [array]::IndexOf($Events, 'blocker_locked') -lt 0 -or [array]::IndexOf($Events, 'blocker_locked') -gt $overlap) {
        throw 'CONCURRENCY EVIDENCE = INCOMPLETE: blocker release/overlap order is invalid.'
    }
}

function Get-Stage8AttemptTiming {
    param([Parameter(Mandatory = $true)][string] $AttemptId)
    $program = @'
$attempt = DB::table('assessment_attempts')->where('id', $stage8Input['attempt_id'])->first(['status', 'deadline_at']);
echo json_encode(['status' => $attempt?->status, 'deadline_at' => $attempt?->deadline_at, 'now' => now()->utc()->format('Y-m-d\TH:i:s.u\Z')], JSON_THROW_ON_ERROR);
'@
    Invoke-Stage8ContainerPhp -Program $program -InputJson (@{ attempt_id = $AttemptId } | ConvertTo-Json -Compress)
}

function Start-Stage8Blocker {
    param([Parameter(Mandatory = $true)][string] $AttemptId, [int] $MaximumHoldSeconds = 120)
    $containerPath = '/tmp/testlabuz-stage8-blocker-' + [guid]::NewGuid().ToString('N') + '.php'
    $program = @'
<?php
use Illuminate\Support\Facades\DB;
require '/var/www/html/vendor/autoload.php';
$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
if (!app()->environment('testing') || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') { exit(3); }
// .NET writes a UTF-8 BOM before the first stdin line.
$attemptId = trim(preg_replace('/^\xEF\xBB\xBF/', '', (string) fgets(STDIN)));
$released = false;
DB::beginTransaction();
try {
    // Harness-only lock on the one manifest Attempt; the blocker never updates the row.
    $row = DB::selectOne('select id from assessment_attempts where id = ? for update', [$attemptId]);
    if ($row === null) { throw new RuntimeException('missing'); }
    echo json_encode(['locked' => true, 'attempt_id' => $row->id, 'pid' => (int) DB::scalar('select pg_backend_pid()')]), "\n";
    fflush(STDOUT);
    $read = [STDIN]; $write = null; $except = null;
    $ready = stream_select($read, $write, $except, (int) getenv('STAGE8_BLOCKER_MAX_SECONDS'));
    $released = $ready > 0 && trim((string) fgets(STDIN)) === 'release';
} finally {
    DB::rollBack();
    echo json_encode(['released' => true, 'on_request' => $released]), "\n";
    fflush(STDOUT);
}
'@
    $originalOutputEncoding = $OutputEncoding
    try {
        $OutputEncoding = [Text.UTF8Encoding]::new($false)
        $null = @($program | & docker exec -i $script:Stage8BackendContainerName sh -c "umask 077; set -C; cat > '$containerPath'" 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'integration-harness defect: Stage 8 blocker transport failed.' }
    }
    finally { $OutputEncoding = $originalOutputEncoding }
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command docker.exe -ErrorAction Stop).Source
    $startInfo.Arguments = "exec -i -e STAGE8_BLOCKER_MAX_SECONDS=$MaximumHoldSeconds $($script:Stage8BackendContainerName) php $containerPath"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($startInfo)
    $process.StandardInput.WriteLine($AttemptId)
    $process.StandardInput.Flush()
    $line = $process.StandardOutput.ReadLineAsync()
    if (-not $line.Wait(30000) -or $null -eq $line.Result) {
        Stop-Stage8Blocker ([pscustomobject] @{ Process = $process; ContainerPath = $containerPath })
        throw 'integration-harness defect: Stage 8 blocker did not acquire the Attempt lock in time.'
    }
    try { $ready = $line.Result | ConvertFrom-Json } catch { throw 'integration-harness defect: Stage 8 blocker returned invalid JSON.' }
    if ($ready.locked -ne $true -or [string] $ready.attempt_id -cne $AttemptId -or [int] $ready.pid -le 0) {
        Stop-Stage8Blocker ([pscustomobject] @{ Process = $process; ContainerPath = $containerPath })
        throw 'integration-harness defect: Stage 8 blocker locked the wrong Attempt.'
    }
    [pscustomobject] @{ Process = $process; ContainerPath = $containerPath; Pid = [int] $ready.pid; AttemptId = [string] $ready.attempt_id }
}

function Stop-Stage8Blocker {
    param([Parameter(Mandatory = $true)][psobject] $Blocker)
    $released = $false
    try {
        if (-not $Blocker.Process.HasExited) {
            $Blocker.Process.StandardInput.WriteLine('release')
            $Blocker.Process.StandardInput.Flush()
            $released = $Blocker.Process.WaitForExit(20000)
        }
        else { $released = $true }
    }
    finally {
        if (-not $Blocker.Process.HasExited) { $Blocker.Process.Kill(); $Blocker.Process.WaitForExit(10000) | Out-Null }
        $Blocker.Process.Dispose()
        $null = @(& docker exec $script:Stage8BackendContainerName rm -f -- $Blocker.ContainerPath 2>&1)
    }
    if (-not $released) { throw 'integration-harness defect: Stage 8 blocker did not release its transaction.' }
}

function Watch-Stage8LockOverlap {
    param([Parameter(Mandatory = $true)][int] $BlockerPid, [Parameter(Mandatory = $true)][string] $ApplicationAddress, [int] $WindowSeconds = $script:Stage8ProbeWindowSeconds, [ValidateRange(1, 2)][int] $Waiters = 2)
    $program = @'
if (!app()->environment('testing') || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') { throw new RuntimeException('observer identity'); }
$observer = (int) DB::scalar('select pg_backend_pid()');
$blocker = (int) $stage8Input['blocker_pid'];
$address = (string) $stage8Input['address'];
$deadline = microtime(true) + (int) $stage8Input['window_seconds'];
$samples = [];
$qualified = false;
do {
    DB::select('select pg_stat_clear_snapshot()');
    // Bounded facts only: identities and wait state, never query text.
    $sessions = array_map(fn ($row) => ['pid' => (int) $row->pid, 'datname' => $row->datname, 'client_addr' => $row->client_addr, 'state' => $row->state,
        'wait_event_type' => $row->wait_event_type, 'wait_event' => $row->wait_event,
        'blockers' => array_values(array_filter(array_map('intval', explode(',', trim((string) $row->blockers, '{}')))))],
        DB::select("select pid, datname, host(client_addr) as client_addr, state, wait_event_type, wait_event, pg_blocking_pids(pid)::text as blockers from pg_stat_activity where datname = current_database() and pid <> pg_backend_pid()"));
    $locks = array_map(fn ($row) => ['pid' => (int) $row->pid, 'locktype' => $row->locktype, 'relation' => $row->relation],
        DB::select("select pid, locktype, relation::regclass::text as relation from pg_locks where not granted"));
    $sample = ['observed_at' => now()->utc()->format('Y-m-d\TH:i:s.u\Z'), 'sessions' => $sessions, 'waiting_locks' => $locks];
    $waiters = array_filter($sessions, fn ($s) => $s['pid'] !== $blocker && $s['client_addr'] === $address && $s['state'] === 'active' && $s['wait_event_type'] === 'Lock');
    $samples[] = $sample;
    if (count($samples) > 40) { array_shift($samples); }
    $qualified = count($waiters) >= (int) $stage8Input['waiters'];
    if (!$qualified) { usleep(100000); }
} while (!$qualified && microtime(true) < $deadline);
echo json_encode(['observer_pid' => $observer, 'database' => (string) DB::scalar('select current_database()'), 'samples' => $samples, 'timed_out' => !$qualified], JSON_THROW_ON_ERROR);
'@
    Invoke-Stage8ContainerPhp -Program $program -InputJson (@{ blocker_pid = $BlockerPid; address = $ApplicationAddress; window_seconds = $WindowSeconds; waiters = $Waiters } | ConvertTo-Json -Compress)
}

# Each race request runs in its own PowerShell job process; the bearer token travels as a job argument, never argv.
function Start-Stage8RaceRequest {
    param([Parameter(Mandatory = $true)][hashtable] $Request, [Parameter(Mandatory = $true)][string] $Token)
    Start-Job -ScriptBlock {
        param($Request, $Token)
        Add-Type -AssemblyName System.Net.Http
        $handler = [Net.Http.HttpClientHandler]::new(); $handler.AllowAutoRedirect = $false
        $client = [Net.Http.HttpClient]::new($handler); $client.Timeout = [TimeSpan]::FromSeconds(180)
        $message = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($Request.Method), $Request.Url)
        try {
            $null = $message.Headers.TryAddWithoutValidation('Accept', 'application/json')
            $message.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
            if ($Request.Key) { $null = $message.Headers.TryAddWithoutValidation('Idempotency-Key', $Request.Key) }
            if ($Request.FilePath) {
                $multipart = [Net.Http.MultipartFormDataContent]::new()
                $multipart.Add([Net.Http.StringContent]::new('file_based'), 'type')
                $file = [Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes($Request.FilePath))
                $file.Headers.ContentType = [Net.Http.Headers.MediaTypeHeaderValue]::new('application/octet-stream')
                $multipart.Add($file, 'file', [IO.Path]::GetFileName($Request.FilePath))
                $message.Content = $multipart
            }
            elseif ($null -ne $Request.Body) {
                $message.Content = [Net.Http.StringContent]::new($Request.Body, [Text.Encoding]::UTF8, 'application/json')
            }
            $started = [DateTime]::UtcNow.ToString('o')
            $response = $client.SendAsync($message).GetAwaiter().GetResult()
            $text = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            [pscustomobject] @{ Status = [int] $response.StatusCode; Body = $text; Started = $started; Finished = [DateTime]::UtcNow.ToString('o'); ProcessId = $PID }
        }
        finally { $message.Dispose(); $client.Dispose(); $handler.Dispose(); $Token = $null }
    } -ArgumentList $Request, $Token
}

function Receive-Stage8RaceRequest {
    param([Parameter(Mandatory = $true)] $Job, [int] $TimeoutSeconds = 120)
    try {
        if (-not (Wait-Job -Job $Job -Timeout $TimeoutSeconds)) { throw 'environment/runtime defect: Stage 8 race request did not finish in time.' }
        if ($Job.State -cne 'Completed') { throw 'environment/runtime defect: Stage 8 race request process failed; payload withheld.' }
        $result = @(Receive-Job -Job $Job)
        if ($result.Count -ne 1) { throw 'integration-harness defect: Stage 8 race request returned an unexpected result.' }
        $json = $null
        if (-not [string]::IsNullOrEmpty($result[0].Body)) {
            try { $json = $result[0].Body | ConvertFrom-Json } catch { throw 'production defect: Stage 8 race response was not JSON; payload withheld.' }
        }
        [pscustomobject] @{ StatusCode = [int] $result[0].Status; Json = $json; Started = $result[0].Started; Finished = $result[0].Finished; ProcessId = [int] $result[0].ProcessId }
    }
    finally { Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue }
}

# Full Section 14.1 protocol for one race. It never forces a winner: the first request is chosen at random
# and the business oracle judges the resulting branch.
# The second request starts only once the first waits in the lock queue. The PHP built-in server can otherwise
# accept both connections in one worker and serve them one after the other, so they would never overlap.
function Invoke-Stage8OverlapProbe {
    param(
        [Parameter(Mandatory = $true)][string] $AttemptId,
        [Parameter(Mandatory = $true)][hashtable] $RequestA,
        [Parameter(Mandatory = $true)][string] $TokenA,
        [Parameter(Mandatory = $true)][hashtable] $RequestB,
        [Parameter(Mandatory = $true)][string] $TokenB,
        [Parameter(Mandatory = $true)][psobject] $Runtime
    )
    $timing = Get-Stage8AttemptTiming -AttemptId $AttemptId
    if ($timing.status -cne 'in_progress' -or $null -eq $timing.deadline_at) { throw 'integration-harness defect: Stage 8 race requires an in-progress manifest Attempt.' }
    $margin = ([DateTimeOffset] $timing.deadline_at - [DateTimeOffset] $timing.now).TotalSeconds
    if ($margin -lt $script:Stage8ProbeWindowSeconds + $script:Stage8ProbeDeadlineMarginSeconds + 30) {
        throw 'integration-harness defect: Stage 8 race Attempt is too close to its deadline for a safe overlap window; use another fixture.'
    }
    $events = [Collections.Generic.List[string]]::new()
    $blocker = $null; $jobA = $null; $jobB = $null; $observation = $null; $evidence = $null
    try {
        $blocker = Start-Stage8Blocker -AttemptId $AttemptId
        $events.Add('blocker_locked')
        $aFirst = (Get-Random -Minimum 0 -Maximum 2) -eq 0
        if ($aFirst) { $jobA = Start-Stage8RaceRequest -Request $RequestA -Token $TokenA } else { $jobB = Start-Stage8RaceRequest -Request $RequestB -Token $TokenB }
        $queued = Watch-Stage8LockOverlap -BlockerPid $blocker.Pid -ApplicationAddress $Runtime.ClientAddress -Waiters 1
        if ($queued.timed_out) { $events.Add('first_request_not_queued') } else { $events.Add('first_request_queued') }
        if ($aFirst) { $jobB = Start-Stage8RaceRequest -Request $RequestB -Token $TokenB } else { $jobA = Start-Stage8RaceRequest -Request $RequestA -Token $TokenA }
        $events.Add('requests_started')
        $observation = Watch-Stage8LockOverlap -BlockerPid $blocker.Pid -ApplicationAddress $Runtime.ClientAddress
        if ($observation.timed_out) { $events.Add('window_timed_out') }
        $evidence = Get-Stage8OverlapEvidence -Samples @($observation.samples) -BlockerPid $blocker.Pid -ObserverPid ([int] $observation.observer_pid) `
            -ApplicationAddress $Runtime.ClientAddress -Database ([string] $observation.database) -WorkerCount ([int] $Runtime.Workers) `
            -LockedAttemptId $blocker.AttemptId -ExpectedAttemptId $AttemptId
        if ($evidence.overlap_observed) { $events.Add('overlap_observed') }
    }
    finally {
        # Always release, even when the proof failed, so the real requests can finish naturally.
        if ($null -ne $blocker) { Stop-Stage8Blocker $blocker; $events.Add('blocker_released') }
    }
    $resultA = Receive-Stage8RaceRequest $jobA
    $resultB = Receive-Stage8RaceRequest $jobB
    if ($resultA.ProcessId -eq $resultB.ProcessId -or $resultA.ProcessId -eq $PID -or $resultB.ProcessId -eq $PID) {
        throw 'integration-harness defect: Stage 8 race requests did not run in independent client processes.'
    }
    try { Assert-Stage8RaceVerdict -Evidence $evidence -Events $events.ToArray() -MarkedPass $true }
    catch {
        # Bounded, non-secret diagnostics: statuses, codes and the waiter counts the observer saw.
        $seen = @(@($observation.samples) | ForEach-Object { @($_.sessions | Where-Object { $_.wait_event_type -ceq 'Lock' }).Count }) -join ','
        $codeA = if ($null -ne $resultA.Json -and $null -ne $resultA.Json.PSObject.Properties['code']) { $resultA.Json.code } else { '' }
        $codeB = if ($null -ne $resultB.Json -and $null -ne $resultB.Json.PSObject.Properties['code']) { $resultB.Json.code } else { '' }
        throw "$($_.Exception.Message) [A=$($resultA.StatusCode) $codeA; B=$($resultB.StatusCode) $codeB; samples=$(@($observation.samples).Count); lock_waiters_per_sample=$seen; events=$($events -join ',')]"
    }
    [pscustomobject] @{ Evidence = $evidence; Events = $events.ToArray(); A = $resultA; B = $resultB; FirstLaunched = $(if ($aFirst) { 'A' } else { 'B' }) }
}
