param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage8_api_security.ps1')

$script:checks = 0
function Confirm-Stage8Reject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "integration-harness defect: API security verifier accepted $Label." }
    $script:checks++
}
function Confirm-Stage8Accept { param([scriptblock] $Check) & $Check | Out-Null; $script:checks++ }
function New-Stage8Response { param([int] $Status, $Json, [byte[]] $Bytes = $null, [hashtable] $Headers = @{}) [pscustomobject] @{ StatusCode = $Status; Json = $Json; Bytes = $Bytes; Headers = $Headers } }
function New-Stage8ErrorBody { param([string] $Code, $Errors = ([pscustomobject] @{}), [string] $Message = 'Request failed.') [pscustomobject] @{ message = $Message; code = $Code; errors = $Errors } }

# Exact status, code and envelope.
$notFound = New-Stage8Response 404 (New-Stage8ErrorBody resource_not_found)
Confirm-Stage8Accept { Assert-Stage8ApiError $notFound 404 resource_not_found }
Confirm-Stage8Reject 'wrong status' { Assert-Stage8ApiError $notFound 409 resource_not_found }
Confirm-Stage8Reject 'wrong machine code' { Assert-Stage8ApiError (New-Stage8Response 404 (New-Stage8ErrorBody forbidden)) 404 resource_not_found }
Confirm-Stage8Reject 'accepting 403 where Student-submission privacy requires 404' { Assert-Stage8ApiError (New-Stage8Response 403 (New-Stage8ErrorBody forbidden)) 404 resource_not_found }
Confirm-Stage8Reject 'cross-Tenant success where 404 is expected' { Assert-Stage8ApiError (New-Stage8Response 200 ([pscustomobject] @{ data = [pscustomobject] @{ id = 'foreign' } })) 404 resource_not_found }
Confirm-Stage8Reject 'empty success where 404 is expected' { Assert-Stage8ApiError (New-Stage8Response 204 $null) 404 resource_not_found }
Confirm-Stage8Reject 'missing errors field' { Assert-Stage8ApiError (New-Stage8Response 404 ([pscustomobject] @{ message = 'x'; code = 'resource_not_found' })) 404 resource_not_found }
Confirm-Stage8Reject 'missing message field' { Assert-Stage8ApiError (New-Stage8Response 404 ([pscustomobject] @{ code = 'resource_not_found'; errors = [pscustomobject] @{} })) 404 resource_not_found }
Confirm-Stage8Reject 'blank message' { Assert-Stage8ApiError (New-Stage8Response 404 (New-Stage8ErrorBody resource_not_found -Message ' ')) 404 resource_not_found }
$extra = New-Stage8ErrorBody resource_not_found; $extra | Add-Member request_id 'r1'
Confirm-Stage8Reject 'extra envelope field' { Assert-Stage8ApiError (New-Stage8Response 404 $extra) 404 resource_not_found }
$meta = New-Stage8ErrorBody blitz_not_active; $meta | Add-Member meta ([pscustomobject] @{ missing_fields = @('blitz_timer_start_mode') })
Confirm-Stage8Reject 'meta on a code other than institution_settings_incomplete' { Assert-Stage8ApiError (New-Stage8Response 409 $meta) 409 blitz_not_active }
$settings = New-Stage8ErrorBody institution_settings_incomplete; $settings | Add-Member meta ([pscustomobject] @{ missing_fields = @('blitz_timer_start_mode') })
Confirm-Stage8Accept { Assert-Stage8ApiError (New-Stage8Response 409 $settings) 409 institution_settings_incomplete }
$settingsWrong = New-Stage8ErrorBody institution_settings_incomplete; $settingsWrong | Add-Member meta ([pscustomobject] @{ missing_fields = @('timezone') })
Confirm-Stage8Reject 'settings conflict naming another field' { Assert-Stage8ApiError (New-Stage8Response 409 $settingsWrong) 409 institution_settings_incomplete }
Confirm-Stage8Reject 'settings conflict without meta' { Assert-Stage8ApiError (New-Stage8Response 409 (New-Stage8ErrorBody institution_settings_incomplete)) 409 institution_settings_incomplete }
Confirm-Stage8Reject 'non-empty errors on a conflict' { Assert-Stage8ApiError (New-Stage8Response 409 (New-Stage8ErrorBody attempt_not_editable ([pscustomobject] @{ attempt = @('closed') }))) 409 attempt_not_editable }
Confirm-Stage8Reject 'non-empty errors on a privacy 404' { Assert-Stage8ApiError (New-Stage8Response 404 (New-Stage8ErrorBody resource_not_found ([pscustomobject] @{ id = @('missing') }))) 404 resource_not_found }

# Validation envelopes and Section 39 malformed vectors.
$validation = New-Stage8Response 422 (New-Stage8ErrorBody validation_failed ([pscustomobject] @{ idempotency_key = @('The idempotency key must be a valid UUID.') }))
Confirm-Stage8Accept { Assert-Stage8ApiError $validation 422 validation_failed -AllowedFields @('idempotency_key') -RequiredFields @('idempotency_key') }
Confirm-Stage8Reject 'empty validation errors for 422' { Assert-Stage8ApiError (New-Stage8Response 422 (New-Stage8ErrorBody validation_failed)) 422 validation_failed -AllowedFields @('idempotency_key') }
Confirm-Stage8Reject 'unexpected validation field' { Assert-Stage8ApiError $validation 422 validation_failed -AllowedFields @('body') }
Confirm-Stage8Reject 'validation missing the invalid field' { Assert-Stage8ApiError $validation 422 validation_failed -AllowedFields @('idempotency_key', 'body') -RequiredFields @('body') }
Confirm-Stage8Reject 'validation value not an array' { Assert-Stage8ApiError (New-Stage8Response 422 (New-Stage8ErrorBody validation_failed ([pscustomobject] @{ body = 'bad' }))) 422 validation_failed -AllowedFields @('body') }
Confirm-Stage8Reject 'validation value with a blank message' { Assert-Stage8ApiError (New-Stage8Response 422 (New-Stage8ErrorBody validation_failed ([pscustomobject] @{ body = @(' ') }))) 422 validation_failed -AllowedFields @('body') }
Confirm-Stage8Reject 'accepting 404 for a malformed vector' { Assert-Stage8ApiError $notFound 422 validation_failed -AllowedFields @('idempotency_key') }
Confirm-Stage8Reject 'accepting 409 for a malformed vector' { Assert-Stage8ApiError (New-Stage8Response 409 (New-Stage8ErrorBody idempotency_key_reused)) 422 validation_failed -AllowedFields @('idempotency_key') }

# Terminal, already-granted and replay outcomes.
Confirm-Stage8Reject 'Submit on timeout answering attempt_not_editable' { Assert-Stage8ApiError (New-Stage8Response 409 (New-Stage8ErrorBody attempt_not_editable)) 409 blitz_time_expired }
Confirm-Stage8Reject 'Submit on a submitted Attempt answering blitz_time_expired' { Assert-Stage8ApiError (New-Stage8Response 409 (New-Stage8ErrorBody blitz_time_expired)) 409 attempt_not_editable }
Confirm-Stage8Reject 'generic conflict instead of already-granted' { Assert-Stage8ApiError (New-Stage8Response 409 (New-Stage8ErrorBody business_conflict)) 409 blitz_attempt_exception_already_granted }
Confirm-Stage8Reject 'already-granted answered as key reuse' { Assert-Stage8ApiError (New-Stage8Response 409 (New-Stage8ErrorBody idempotency_key_reused)) 409 blitz_attempt_exception_already_granted }
$attempt = [pscustomobject] @{ id = 'a1'; attempt_number = 1; started_at = '2026-09-27T10:00:00Z'; deadline_at = '2026-09-27T12:00:00Z'; status = 'in_progress' }
$first = New-Stage8Response 201 ([pscustomobject] @{ data = $attempt })
Confirm-Stage8Accept { Assert-Stage8ReplayOutcome $first $first 201 @('id', 'started_at', 'deadline_at') }
$moved = [pscustomobject] @{ id = 'a1'; attempt_number = 1; started_at = '2026-09-27T10:05:00Z'; deadline_at = '2026-09-27T12:05:00Z'; status = 'in_progress' }
Confirm-Stage8Reject 'replay resetting the timer' { Assert-Stage8ReplayOutcome $first (New-Stage8Response 201 ([pscustomobject] @{ data = $moved })) 201 @('id', 'started_at', 'deadline_at') }
Confirm-Stage8Reject 'replay switching Attempts' { Assert-Stage8ReplayOutcome $first (New-Stage8Response 201 ([pscustomobject] @{ data = [pscustomobject] @{ id = 'a2'; attempt_number = 2; started_at = $attempt.started_at; deadline_at = $attempt.deadline_at } })) 201 @('id') }
Confirm-Stage8Reject 'replay changing the original status' { Assert-Stage8ReplayOutcome $first (New-Stage8Response 200 ([pscustomobject] @{ data = $attempt })) 201 @('id') }
Confirm-Stage8Reject 'key reuse not rejected' { Assert-Stage8KeyReuseOutcome (New-Stage8Response 201 ([pscustomobject] @{ data = $attempt })) }

# Student privacy: pre-Start detail, protected keys, item identifiers, protected bytes.
$timing = [pscustomobject] @{ mode = 'individual'; server_now = 'n'; synchronized_ends_at = $null; deadline_at = $null; remaining_seconds = $null }
$allowance = [pscustomobject] @{ normal_attempts = 1; normal_used = 0; in_progress_attempt_id = $null; additional_exception_granted = $false; replacement_attempt_available = $false }
$detail = [pscustomobject] @{ id = 'b'; topic = [pscustomobject] @{ id = 't'; title = 'T' }; title = 'B'; description = $null; student_instructions = 'S'; status = 'active'; duration_seconds = 60; total_possible_points = '1.000000'; timing = $timing; attempts = $allowance }
Confirm-Stage8Accept { Assert-Stage8PreStartPrivacy (New-Stage8Response 200 ([pscustomobject] @{ data = $detail })) }
$leak = $detail.PSObject.Copy(); $leak | Add-Member questions @([pscustomobject] @{ id = 'q'; prompt = 'secret' })
Confirm-Stage8Reject 'Question leakage in pre-Start detail' { Assert-Stage8PreStartPrivacy (New-Stage8Response 200 ([pscustomobject] @{ data = $leak })) }
$answers = $detail.PSObject.Copy(); $answers | Add-Member answers @()
Confirm-Stage8Reject 'answers key in pre-Start detail' { Assert-Stage8PreStartPrivacy (New-Stage8Response 200 ([pscustomobject] @{ data = $answers })) }
$nestedLeak = $detail.PSObject.Copy(); $nestedLeak.timing = [pscustomobject] @{ mode = 'individual'; server_now = 'n'; synchronized_ends_at = $null; deadline_at = $null; remaining_seconds = $null; prompt = 'secret' }
Confirm-Stage8Reject 'nested Question content in pre-Start timing' { Assert-Stage8PreStartPrivacy (New-Stage8Response 200 ([pscustomobject] @{ data = $nestedLeak })) }
foreach ($key in @('is_correct', 'correct_position', 'match_key', 'accepted_answers', 'storage_key')) {
    $payload = [pscustomobject] @{ data = [pscustomobject] @{ questions = @([pscustomobject] @{ answer_ui = [pscustomobject] @{ options = @([pscustomobject] @{ id = 'o'; text = 't'; $key = 'x' }) } }) } }
    Confirm-Stage8Reject "protected key $key in a Student response" { Assert-Stage8NoProtectedKeys $payload }
}
$nested = [pscustomobject] @{ matching = [pscustomobject] @{ left = @('L1', 'L2', 'L3'); right = @('R3', 'R1', 'R2') }; ordering = @('O4', 'O2', 'O1', 'O3') }
function New-Stage8Questions { param([string[]] $Left, [string[]] $Right, [string[]] $Order)
    @([pscustomobject] @{ type = 'matching'; answer_ui = [pscustomobject] @{ left_items = @($Left | ForEach-Object { [pscustomobject] @{ id = $_ } }); right_items = @($Right | ForEach-Object { [pscustomobject] @{ id = $_ } }) } },
      [pscustomobject] @{ type = 'ordering'; answer_ui = [pscustomobject] @{ items = @($Order | ForEach-Object { [pscustomobject] @{ id = $_ } }) } })
}
Confirm-Stage8Accept { Assert-Stage8ItemIdPrivacy (New-Stage8Questions @('L1', 'L2', 'L3') @('R3', 'R1', 'R2') @('O4', 'O2', 'O1', 'O3')) $nested }
$sortedPairs = [pscustomobject] @{ matching = [pscustomobject] @{ left = @('L1', 'L2', 'L3'); right = @('R1', 'R2', 'R3') }; ordering = @('O4', 'O2', 'O1', 'O3') }
Confirm-Stage8Reject 'Matching pairs recoverable by sorting item IDs' { Assert-Stage8ItemIdPrivacy (New-Stage8Questions @('L1', 'L2', 'L3') @('R1', 'R2', 'R3') @('O4', 'O2', 'O1', 'O3')) $sortedPairs }
$sortedOrder = [pscustomobject] @{ matching = $nested.matching; ordering = @('O1', 'O2', 'O3', 'O4') }
Confirm-Stage8Reject 'Ordering key recoverable by sorting item IDs' { Assert-Stage8ItemIdPrivacy (New-Stage8Questions @('L1', 'L2', 'L3') @('R3', 'R1', 'R2') @('O1', 'O2', 'O3', 'O4')) $sortedOrder }
Confirm-Stage8Reject 'foreign item identities' { Assert-Stage8ItemIdPrivacy (New-Stage8Questions @('L1', 'L2', 'X') @('R3', 'R1', 'R2') @('O4', 'O2', 'O1', 'O3')) $nested }
Confirm-Stage8Reject 'protected file bytes for an unauthorized actor' { Assert-Stage8NoBytes (New-Stage8Response 200 $null ([byte[]] @(37, 80, 68, 70))) }
Confirm-Stage8Accept { Assert-Stage8NoBytes (New-Stage8Response 404 (New-Stage8ErrorBody resource_not_found)) }

# Monitoring privacy.
$row = [pscustomobject] @{ student = [pscustomobject] @{ id = 's'; full_name = 'n' }; status = 'finalized'; score = $null; attempt_exception = $null }
$monitoring = [pscustomobject] @{ data = [pscustomobject] @{ blitz = [pscustomobject] @{ id = 'b' }; summary = [pscustomobject] @{ assigned = 1 }; students = @($row) } }
Confirm-Stage8Accept { Assert-Stage8MonitoringPrivacy (New-Stage8Response 200 $monitoring) }
$scored = [pscustomobject] @{ data = [pscustomobject] @{ blitz = [pscustomobject] @{ id = 'b' }; summary = [pscustomobject] @{ assigned = 1 }; students = @([pscustomobject] @{ student = $row.student; status = 'finalized'; score = 7; attempt_exception = $null }) } }
Confirm-Stage8Reject 'non-null monitoring score' { Assert-Stage8MonitoringPrivacy (New-Stage8Response 200 $scored) }
foreach ($key in @('answers', 'questions', 'file', 'storage_key')) {
    $leaky = [pscustomobject] @{ data = [pscustomobject] @{ blitz = [pscustomobject] @{ id = 'b' }; summary = [pscustomobject] @{ assigned = 1 }; students = @([pscustomobject] @{ student = $row.student; status = 'finalized'; score = $null; $key = @() }) } }
    Confirm-Stage8Reject "monitoring leaking $key" { Assert-Stage8MonitoringPrivacy (New-Stage8Response 200 $leaky) }
}

# Protected download headers and bytes.
$bytes = [Text.Encoding]::ASCII.GetBytes('%PDF-1.7 E2E S08')
$sha = [Security.Cryptography.SHA256]::Create()
try { $checksum = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
$fixture = [pscustomobject] @{ mime_type = 'application/pdf'; sha256 = $checksum; size_bytes = $bytes.Length }
$headers = @{ 'Content-Type' = 'application/pdf'; 'Content-Disposition' = 'attachment; filename="e2e_s08_answer.pdf"'; 'X-Content-Type-Options' = 'nosniff'; 'Cache-Control' = 'no-store, private' }
Confirm-Stage8Accept { Assert-Stage8Download (New-Stage8Response 200 $null $bytes $headers) $fixture }
$cacheable = $headers.Clone(); $cacheable['Cache-Control'] = 'public, max-age=60'
Confirm-Stage8Reject 'cacheable protected download' { Assert-Stage8Download (New-Stage8Response 200 $null $bytes $cacheable) $fixture }
$inline = $headers.Clone(); $inline['Content-Disposition'] = 'inline'
Confirm-Stage8Reject 'inline protected download' { Assert-Stage8Download (New-Stage8Response 200 $null $bytes $inline) $fixture }
Confirm-Stage8Reject 'protected download with other bytes' { Assert-Stage8Download (New-Stage8Response 200 $null ([Text.Encoding]::ASCII.GetBytes('%PDF-1.7 other')) $headers) $fixture }

# A negative probe may not change any manifest row.
$before = [pscustomobject] @{ tables = [pscustomobject] @{ assessment_attempts = @([pscustomobject] @{ id = 'a1'; status = 'in_progress' }); idempotency_records = @() } }
Confirm-Stage8Accept { Assert-Stage8RowsUnchanged $before $before @('assessment_attempts', 'idempotency_records') 'negative probe' }
$mutated = [pscustomobject] @{ tables = [pscustomobject] @{ assessment_attempts = @([pscustomobject] @{ id = 'a1'; status = 'submitted' }); idempotency_records = @() } }
Confirm-Stage8Reject 'unexpected persistence mutation for a negative probe' { Assert-Stage8RowsUnchanged $before $mutated @('assessment_attempts', 'idempotency_records') 'negative probe' }
$claimed = [pscustomobject] @{ tables = [pscustomobject] @{ assessment_attempts = $before.tables.assessment_attempts; idempotency_records = @([pscustomobject] @{ idempotency_key = '08000000-0000-4000-8000-000009000123' }) } }
Confirm-Stage8Reject 'rejected probe leaving an idempotency claim' { Assert-Stage8NoIdempotencyRecord $claimed '08000000-0000-4000-8000-000009000123' }
$safe = Protect-Stage8Diagnostic 'Authorization: Bearer 12|abcdefghijklmnopqrstuvwxyz0123 secret-password' @('secret-password')
if ($safe -match 'abcdefghijklmnopqrstuvwxyz|secret-password') { throw 'integration-harness defect: Diagnostic redaction leaked a secret.' }
$script:checks++
if ((New-Stage8Key 7) -cne '08000000-0000-4000-8000-000009000007') { throw 'integration-harness defect: Stage 8 keys leave the reserved namespace.' }
$script:checks++
Write-Output "Stage8ApiSecurity pure verifier: PASS ($script:checks checks; no secret-bearing request executed)."
