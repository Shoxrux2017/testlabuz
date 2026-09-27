param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage8_concurrency_probe.ps1')

$script:checks = 0
function Confirm-Stage8Reject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "integration-harness defect: Concurrency verifier accepted $Label." }
    $script:checks++
}
function Copy-Stage8Synthetic { param($Value) ConvertTo-Json -InputObject $Value -Depth 50 -Compress | ConvertFrom-Json }

$attempt = '08000000-0000-4000-8000-000003000099'
$address = '172.19.0.3'
function New-Stage8Session { param([int] $ProcessId, [int[]] $Blockers = @(), [string] $Address = '172.19.0.3', [string] $Type = 'Lock', [string] $State = 'active', [string] $Database = 'testlabuz_testing')
    [pscustomobject] @{ pid = $ProcessId; datname = $Database; client_addr = $Address; state = $State; wait_event_type = $Type; wait_event = 'transactionid'; blockers = $Blockers }
}
function New-Stage8Sample { param([object[]] $Sessions, [object[]] $Locks)
    [pscustomobject] @{ observed_at = '2026-09-27T12:00:00.000000Z'; sessions = $Sessions; waiting_locks = $Locks }
}
$blockerSession = New-Stage8Session 77 @() -Type 'Client' -State 'idle in transaction'
$validSample = New-Stage8Sample @($blockerSession, (New-Stage8Session 101 @(77)), (New-Stage8Session 102 @(101))) @(
    [pscustomobject] @{ pid = 101; locktype = 'transactionid'; relation = $null },
    [pscustomobject] @{ pid = 102; locktype = 'tuple'; relation = 'assessment_attempts' })
$context = @{ BlockerPid = 77; ObserverPid = 88; ApplicationAddress = $address; Database = 'testlabuz_testing'; WorkerCount = 4; LockedAttemptId = $attempt; ExpectedAttemptId = $attempt }

$valid = Get-Stage8OverlapEvidence -Samples @($validSample) @context
if (-not $valid.overlap_observed -or $valid.waiting_count -ne 2 -or (@($valid.waiting_application_pids) -join ',') -cne '101,102' -or $valid.blocker_pid -ne 77 -or $valid.manifest_attempt_id -cne $attempt) {
    throw 'integration-harness defect: Concurrency verifier rejected a valid tuple-queue overlap sample.'
}
$bothOnBlocker = New-Stage8Sample @($blockerSession, (New-Stage8Session 101 @(77)), (New-Stage8Session 102 @(77, 101))) @(
    [pscustomobject] @{ pid = 101; locktype = 'transactionid'; relation = $null },
    [pscustomobject] @{ pid = 102; locktype = 'transactionid'; relation = $null })
if (-not (Get-Stage8OverlapEvidence -Samples @($bothOnBlocker) @context).overlap_observed) { throw 'integration-harness defect: Concurrency verifier rejected a valid direct-queue overlap sample.' }
$script:checks += 2

function Test-Stage8Incomplete { param([string] $Label, [object[]] $Samples, [hashtable] $Overrides = @{})
    $arguments = $context.Clone(); foreach ($key in $Overrides.Keys) { $arguments[$key] = $Overrides[$key] }
    $rejected = $false
    try { $rejected = -not (Get-Stage8OverlapEvidence -Samples $Samples @arguments).overlap_observed } catch { $rejected = $true }
    if (-not $rejected) { throw "integration-harness defect: Concurrency verifier accepted $Label." }
    $script:checks++
}

Test-Stage8Incomplete 'worker count missing' @($validSample) @{ WorkerCount = 0 }
Test-Stage8Incomplete 'worker count 1' @($validSample) @{ WorkerCount = 1 }
Test-Stage8Incomplete 'worker count 8' @($validSample) @{ WorkerCount = 8 }
Test-Stage8Incomplete 'observer database testlabuz' @($validSample) @{ Database = 'testlabuz' }
Test-Stage8Incomplete 'wrong application client address' @($validSample) @{ ApplicationAddress = '172.19.0.9' }
Test-Stage8Incomplete 'missing application client address' @($validSample) @{ ApplicationAddress = '' }
Test-Stage8Incomplete 'manifest Attempt mismatch' @($validSample) @{ LockedAttemptId = '08000000-0000-4000-8000-000003000098' }
Test-Stage8Incomplete 'blocker equals observer' @($validSample) @{ ObserverPid = 77 }
Test-Stage8Incomplete 'no samples (timeout)' @()

$one = New-Stage8Sample @($blockerSession, (New-Stage8Session 101 @(77))) @([pscustomobject] @{ pid = 101; locktype = 'transactionid'; relation = $null })
Test-Stage8Incomplete 'waiting_count < 2' @($one)
$duplicate = Copy-Stage8Synthetic $validSample; $duplicate.sessions[2].pid = 101; $duplicate.waiting_locks[1].pid = 101
Test-Stage8Incomplete 'duplicate waiter PID counted twice' @($duplicate)
$blockerCounted = New-Stage8Sample @((New-Stage8Session 77 @()), (New-Stage8Session 101 @(77))) @([pscustomobject] @{ pid = 101; locktype = 'transactionid'; relation = $null }, [pscustomobject] @{ pid = 77; locktype = 'transactionid'; relation = $null })
Test-Stage8Incomplete 'waiter PID equals blocker' @($blockerCounted)
$observerCounted = New-Stage8Sample @($blockerSession, (New-Stage8Session 101 @(77)), (New-Stage8Session 88 @(101))) @(
    [pscustomobject] @{ pid = 101; locktype = 'transactionid'; relation = $null }, [pscustomobject] @{ pid = 88; locktype = 'tuple'; relation = 'assessment_attempts' })
Test-Stage8Incomplete 'waiter PID equals observer' @($observerCounted)
$notLock = Copy-Stage8Synthetic $validSample; $notLock.sessions[2].wait_event_type = 'IO'
Test-Stage8Incomplete 'wait_event_type != Lock' @($notLock)
$idle = Copy-Stage8Synthetic $validSample; $idle.sessions[1].state = 'idle'
Test-Stage8Incomplete 'waiter not active' @($idle)
$first = New-Stage8Sample @($blockerSession, (New-Stage8Session 101 @(77))) @([pscustomobject] @{ pid = 101; locktype = 'transactionid'; relation = $null })
$second = New-Stage8Sample @($blockerSession, (New-Stage8Session 102 @(77))) @([pscustomobject] @{ pid = 102; locktype = 'transactionid'; relation = $null })
Test-Stage8Incomplete 'waiters in different samples but never together' @($first, $second)
$foreignRoot = Copy-Stage8Synthetic $validSample; $foreignRoot.sessions[1].blockers = @(55)
Test-Stage8Incomplete 'blocking chain not rooted in approved blocker' @($foreignRoot)
$cycle = Copy-Stage8Synthetic $validSample; $cycle.sessions[1].blockers = @(102)
Test-Stage8Incomplete 'blocking cycle without blocker' @($cycle)
$unrelatedAddress = Copy-Stage8Synthetic $validSample; $unrelatedAddress.sessions[2].client_addr = '172.19.0.4'
Test-Stage8Incomplete 'unrelated database session counted' @($unrelatedAddress)
$otherDatabase = Copy-Stage8Synthetic $validSample; $otherDatabase.sessions[2].datname = 'testlabuz_demo'
Test-Stage8Incomplete 'other database session counted' @($otherDatabase)
$otherRelation = Copy-Stage8Synthetic $validSample; $otherRelation.waiting_locks[1].relation = 'topics'
Test-Stage8Incomplete 'waiter queued on another relation' @($otherRelation)
$advisory = Copy-Stage8Synthetic $validSample; $advisory.waiting_locks[0].locktype = 'advisory'
Test-Stage8Incomplete 'waiter queued on another lock type' @($advisory)

$events = @('blocker_locked', 'first_request_queued', 'requests_started', 'overlap_observed', 'blocker_released')
Assert-Stage8RaceVerdict -Evidence $valid -Events $events -MarkedPass $true
$script:checks++
$none = Get-Stage8OverlapEvidence -Samples @($one) @context
Assert-Stage8RaceVerdict -Evidence $none -Events @('blocker_locked', 'requests_started', 'blocker_released') -MarkedPass $false
Confirm-Stage8Reject 'overlap_observed=false while race marked PASS' { Assert-Stage8RaceVerdict -Evidence $none -Events @('blocker_locked', 'requests_started', 'blocker_released') -MarkedPass $true }
Confirm-Stage8Reject 'timeout reached but PASS emitted' { Assert-Stage8RaceVerdict -Evidence $valid -Events @('blocker_locked', 'first_request_queued', 'requests_started', 'window_timed_out', 'overlap_observed', 'blocker_released') -MarkedPass $true }
Confirm-Stage8Reject 'blocker released before overlap evidence' { Assert-Stage8RaceVerdict -Evidence $valid -Events @('blocker_locked', 'first_request_queued', 'requests_started', 'blocker_released', 'overlap_observed') -MarkedPass $true }
Confirm-Stage8Reject 'blocker never released' { Assert-Stage8RaceVerdict -Evidence $valid -Events @('blocker_locked', 'first_request_queued', 'requests_started', 'overlap_observed') -MarkedPass $true }
Confirm-Stage8Reject 'first request never proven queued' { Assert-Stage8RaceVerdict -Evidence $valid -Events @('blocker_locked', 'first_request_not_queued', 'requests_started', 'overlap_observed', 'blocker_released') -MarkedPass $true }
Confirm-Stage8Reject 'second request started before the first was queued' { Assert-Stage8RaceVerdict -Evidence $valid -Events @('blocker_locked', 'requests_started', 'first_request_queued', 'overlap_observed', 'blocker_released') -MarkedPass $true }
Confirm-Stage8Reject 'overlap before blocker lock' { Assert-Stage8RaceVerdict -Evidence $valid -Events @('overlap_observed', 'blocker_locked', 'blocker_released') -MarkedPass $true }
$forged = Copy-Stage8Synthetic $valid; $forged.waiting_application_pids = @(101, 101)
Confirm-Stage8Reject 'forged evidence with one distinct PID' { Assert-Stage8RaceVerdict -Evidence $forged -Events $events -MarkedPass $true }
$forged = Copy-Stage8Synthetic $valid; $forged.waiting_count = 1
Confirm-Stage8Reject 'forged evidence with waiting_count 1' { Assert-Stage8RaceVerdict -Evidence $forged -Events $events -MarkedPass $true }

Write-Output "Stage8ConcurrencyProbe pure verifier: PASS ($script:checks checks; no DB, HTTP or blocker execution)."
