param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage9_api_scenarios.ps1')

$script:checks = 0
function Confirm-Stage9Reject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "integration-harness defect: API security verifier accepted $Label." }
    $script:checks++
}
function Confirm-Stage9Accept { param([scriptblock] $Check) & $Check | Out-Null; $script:checks++ }
function Copy-Stage9Synthetic { param($Value) ConvertTo-Json -InputObject $Value -Depth 50 -Compress | ConvertFrom-Json }
function New-Stage9Response { param([int] $Status, $Json, [byte[]] $Bytes = $null, [hashtable] $Headers = @{}) [pscustomobject] @{ StatusCode = $Status; Json = $Json; Text = $null; Bytes = $Bytes; Headers = $Headers } }
function New-Stage9ErrorBody { param([string] $Code, $Errors = ([pscustomobject] @{}), [string] $Message = 'Request failed.') [pscustomobject] @{ message = $Message; code = $Code; errors = $Errors } }

# ---------------------------------------------------------------- exact error envelopes
$notFound = New-Stage9Response 404 (New-Stage9ErrorBody resource_not_found)
Confirm-Stage9Accept { Assert-Stage9ApiError $notFound 404 resource_not_found }
Confirm-Stage9Reject 'wrong status' { Assert-Stage9ApiError $notFound 403 resource_not_found }
Confirm-Stage9Reject 'wrong machine code' { Assert-Stage9ApiError (New-Stage9Response 404 (New-Stage9ErrorBody forbidden)) 404 resource_not_found }
Confirm-Stage9Reject 'a foreign submission returned with 200' { Assert-Stage9ApiError (New-Stage9Response 200 ([pscustomobject] @{ data = [pscustomobject] @{ id = 'foreign' } })) 404 resource_not_found }
Confirm-Stage9Reject 'missing errors field' { Assert-Stage9ApiError (New-Stage9Response 404 ([pscustomobject] @{ message = 'x'; code = 'resource_not_found' })) 404 resource_not_found }
Confirm-Stage9Reject 'blank message' { Assert-Stage9ApiError (New-Stage9Response 404 (New-Stage9ErrorBody resource_not_found -Message ' ')) 404 resource_not_found }
$extra = New-Stage9ErrorBody resource_not_found; $extra | Add-Member meta 'x'
Confirm-Stage9Reject 'extra envelope field' { Assert-Stage9ApiError (New-Stage9Response 404 $extra) 404 resource_not_found }
Confirm-Stage9Reject 'non-empty errors on 409' { Assert-Stage9ApiError (New-Stage9Response 409 (New-Stage9ErrorBody automatic_checking_pending ([pscustomobject] @{ answers = @('x') }))) 409 automatic_checking_pending }
Confirm-Stage9Accept { Assert-Stage9ApiError (New-Stage9Response 409 (New-Stage9ErrorBody automatic_checking_pending)) 409 automatic_checking_pending }
$validation = New-Stage9ErrorBody validation_failed ([pscustomobject] @{ 'answers.0.awarded_points' = @('The awarded points must not exceed the Question points.') })
Confirm-Stage9Accept { Assert-Stage9ApiError (New-Stage9Response 422 $validation) 422 validation_failed -AllowedFields @('answers.0.awarded_points') -RequiredFields @('answers.0.awarded_points') }
Confirm-Stage9Reject 'validation naming another field' { Assert-Stage9ApiError (New-Stage9Response 422 $validation) 422 validation_failed -AllowedFields @('answers.0.feedback') -RequiredFields @('answers.0.feedback') }
Confirm-Stage9Reject 'validation without field errors' { Assert-Stage9ApiError (New-Stage9Response 422 (New-Stage9ErrorBody validation_failed)) 422 validation_failed -AllowedFields @('body') }
Confirm-Stage9Reject 'validation message that is not a string array' { Assert-Stage9ApiError (New-Stage9Response 422 (New-Stage9ErrorBody validation_failed ([pscustomobject] @{ body = 'text' }))) 422 validation_failed -AllowedFields @('body') -RequiredFields @('body') }

# ---------------------------------------------------------------- success envelopes
Confirm-Stage9Accept { Assert-Stage9ApiSuccess (New-Stage9Response 200 ([pscustomobject] @{ data = [pscustomobject] @{ id = 'x' } })) }
Confirm-Stage9Accept { Assert-Stage9ApiSuccess (New-Stage9Response 200 ([pscustomobject] @{ data = @([pscustomobject] @{ id = 'x' }, [pscustomobject] @{ id = 'y' }) })) 200 collection }
Confirm-Stage9Reject 'resource where a collection is expected' { Assert-Stage9ApiSuccess (New-Stage9Response 200 ([pscustomobject] @{ data = [pscustomobject] @{ id = 'x' } })) 200 collection }
Confirm-Stage9Reject 'missing data envelope' { Assert-Stage9ApiSuccess (New-Stage9Response 200 ([pscustomobject] @{ id = 'x' })) }
Confirm-Stage9Reject 'unexpected status' { Assert-Stage9ApiSuccess (New-Stage9Response 201 ([pscustomobject] @{ data = [pscustomobject] @{ id = 'x' } })) }
Confirm-Stage9Reject 'login without a bearer token' { Assert-Stage9ApiSuccess (New-Stage9Response 200 ([pscustomobject] @{ data = [pscustomobject] @{ token = ''; token_type = 'Bearer' } })) 200 login }

# ---------------------------------------------------------------- Student privacy
$visible = [pscustomobject] @{ data = [pscustomobject] @{ score_visible = $true; official_score = [pscustomobject] @{ normalized_score = 73.85; attempt_number = 1 }
        attempt_results = @([pscustomobject] @{ attempt_id = 'a'; attempt_number = 1; status = 'checked'; result = [pscustomobject] @{ visible = $true; normalized_score = 73.85 } })
        answers = @([pscustomobject] @{ question_id = 'q'; feedback = 'Clear reasoning.' }) } }
Confirm-Stage9Accept { Assert-Stage9NoProtectedKeys $visible }
# Independent copy of contract section 11.4 plus the Stage 8 key-and-storage list; the harness list must hold every one.
$contractProtected = @('awarded_points', 'checking_status', 'checked_by', 'checked_by_user_id', 'checked_at', 'is_correct', 'correct_value', 'accepted_answers',
    'match_key', 'correct_position', 'earned_points', 'official_attempt_id', 'selection_policy_code', 'selected_at', 'review_due_at', 'review_overdue',
    'accepted_text', 'checking_mode', 'configuration', 'client_key', 'storage_key', 'storage_disk', 'checksum_sha256')
foreach ($key in $contractProtected) {
    $leak = ConvertTo-Json -InputObject $visible -Depth 20 -Compress | ConvertFrom-Json
    $leak.data.attempt_results[0] | Add-Member $key 'x'
    Confirm-Stage9Reject "Student response disclosing $key" { Assert-Stage9NoProtectedKeys $leak }
}
Confirm-Stage9Accept { Assert-Stage9NoResultKeys ([pscustomobject] @{ id = 'b'; status = 'active'; timing = [pscustomobject] @{ mode = 'synchronized' } }) 'active' }
foreach ($key in @('result', 'normalized_score', 'feedback', 'score', 'score_visible', 'official_score')) {
    $item = [pscustomobject] @{ id = 'b'; attempts = [pscustomobject] @{ normal_used = 1 } }
    $item.attempts | Add-Member $key $null
    Confirm-Stage9Reject "active Blitz read carrying $key" { Assert-Stage9NoResultKeys $item 'active' }
}

# ---------------------------------------------------------------- score comparisons
Confirm-Stage9Accept { Assert-Stage9Score ([decimal] 73.85) 73.85 'score' }
Confirm-Stage9Accept { Assert-Stage9Score 95 95 'score' }
Confirm-Stage9Reject 'score off by a hundredth' { Assert-Stage9Score ([decimal] 73.84) 73.85 'score' }
Confirm-Stage9Reject 'hidden score expected' { Assert-Stage9Score 25 $null 'score' }
Confirm-Stage9Reject 'missing score' { Assert-Stage9Score $null 25 'score' }
Confirm-Stage9Accept { Assert-Stage9StudentOfficial $visible.data 73.85 1 'official' }
Confirm-Stage9Reject 'official score on another Attempt' { Assert-Stage9StudentOfficial $visible.data 73.85 2 'official' }
Confirm-Stage9Reject 'visible official score where hidden' { Assert-Stage9StudentOfficial $visible.data $null $null 'official' }
Confirm-Stage9Accept { Assert-Stage9StudentResult ([pscustomobject] @{ visible = $false; normalized_score = $null }) $false $null 'hidden' }
Confirm-Stage9Reject 'hidden result carrying a score' { Assert-Stage9StudentResult ([pscustomobject] @{ visible = $false; normalized_score = 90 }) $false $null 'hidden' }
Confirm-Stage9Reject 'visible flag where hidden' { Assert-Stage9StudentResult ([pscustomobject] @{ visible = $true; normalized_score = $null }) $false $null 'hidden' }
$ready = [pscustomobject] @{ status = 'ready'; official_attempt_id = 'att1'; attempt_number = 1; normalized_score = 25; selection_policy_code = 'highest_valid_completed'; selected_at = '2026-10-02T12:00:00Z' }
Confirm-Stage9Accept { Assert-Stage9TeacherOfficial $ready ready att1 1 25 highest_valid_completed 'ready' }
Confirm-Stage9Reject 'Teacher official read on another Attempt' { Assert-Stage9TeacherOfficial $ready ready att2 1 25 highest_valid_completed 'ready' }
$waiting = [pscustomobject] @{ status = 'waiting_for_teacher_review'; official_attempt_id = $null; attempt_number = $null; normalized_score = $null; selection_policy_code = $null; selected_at = $null }
Confirm-Stage9Accept { Assert-Stage9TeacherOfficial $waiting waiting_for_teacher_review $null $null $null $null 'waiting' }
$leaky = Copy-Stage9Synthetic $waiting; $leaky.normalized_score = 25
Confirm-Stage9Reject 'not-ready official read carrying a score' { Assert-Stage9TeacherOfficial $leaky waiting_for_teacher_review $null $null $null $null 'waiting' }
Confirm-Stage9Reject 'not-ready official read with the wrong status' { Assert-Stage9TeacherOfficial $waiting waiting_for_replacement $null $null $null $null 'waiting' }

# ---------------------------------------------------------------- downloads
$bytes = [Text.Encoding]::ASCII.GetBytes("%PDF-1.7`nE2E S09`n%%EOF`n")
$sha = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
$fixture = [pscustomobject] @{ mime_type = 'application/pdf'; original_name = 'e2e_s09_answer.pdf'; size_bytes = $bytes.Length; sha256 = $sha }
$headers = @{ 'Content-Type' = 'application/pdf'; 'Content-Disposition' = 'attachment; filename=e2e_s09_answer.pdf'; 'X-Content-Type-Options' = 'nosniff'; 'Cache-Control' = 'no-store, private' }
Confirm-Stage9Accept { Assert-Stage9Download (New-Stage9Response 200 $null $bytes $headers) $fixture }
foreach ($case in @(@('Content-Type', 'application/octet-stream'), @('Content-Disposition', 'inline; filename=e2e_s09_answer.pdf'), @('Content-Disposition', 'attachment; filename=other.pdf'),
        @('X-Content-Type-Options', ''), @('Cache-Control', 'public, max-age=60'), @('Cache-Control', 'private'))) {
    $changed = $headers.Clone(); $changed[$case[0]] = $case[1]
    Confirm-Stage9Reject "download header $($case[0]) = '$($case[1])'" { Assert-Stage9Download (New-Stage9Response 200 $null $bytes $changed) $fixture }
}
Confirm-Stage9Reject 'download bytes differing from the fixture' { Assert-Stage9Download (New-Stage9Response 200 $null ([Text.Encoding]::ASCII.GetBytes('tampered')) $headers) $fixture }
Confirm-Stage9Reject 'download with a non-200 status' { Assert-Stage9Download (New-Stage9Response 404 $null $bytes $headers) $fixture }
Confirm-Stage9Reject 'file bytes returned to an unauthorized actor' { Assert-Stage9NoBytes (New-Stage9Response 200 $null $bytes) }
Confirm-Stage9Accept { Assert-Stage9NoBytes (New-Stage9Response 404 (New-Stage9ErrorBody resource_not_found) $null) }

# ---------------------------------------------------------------- transport safety and diagnostics
Confirm-Stage9Reject 'API request to a non-loopback target' { Invoke-Stage9ApiRequest -ApiBaseUrl 'http://example.com:18009/api/v1' -Path '/auth/me' }
Confirm-Stage9Reject 'API request outside the allowed path families' { Invoke-Stage9ApiRequest -ApiBaseUrl 'http://127.0.0.1:18009/api/v1' -Path '/institution/settings' }
Confirm-Stage9Reject 'API request path with a fragment' { Invoke-Stage9ApiRequest -ApiBaseUrl 'http://127.0.0.1:18009/api/v1' -Path '/student/homework#x' }
$redacted = Protect-Stage9Diagnostic 'Authorization: Bearer 12|abcdefghijklmnopqrstuvwxyz0123 secret-password-value' @('secret-password-value')
if ($redacted.Contains('abcdefghijklmnopqrstuvwxyz0123') -or $redacted.Contains('secret-password-value')) { throw 'integration-harness defect: diagnostics were not redacted.' }
$script:checks++
if ((New-Stage9Key 1) -cne '09000000-0000-4000-8000-000009000001' -or (New-Stage9Key 501) -cne '09000000-0000-4000-8000-000009000501') { throw 'integration-harness defect: Stage 9 key namespace changed.' }
$script:checks++

# ---------------------------------------------------------------- negative-probe discipline (stubbed transport and facts)
# The stubs live only in this verifier's script scope.
$script:probeResponse = $null
$script:factsQueue = $null
function Get-Stage9Token { param($Context, [string] $Actor) 'token' }
function Invoke-Stage9Call { param($Context, [string] $Actor, [string] $Path, [string] $Method = 'GET', $Body, [string] $Key, [string] $FilePath, [switch] $Binary, [string] $RawBody, [string] $ContentType = 'application/json') $script:probeResponse }
function Get-Stage9DatabaseFacts { param($PriorFacts) $script:factsQueue.Dequeue() }
function New-Stage9ProbeFacts { param($Rows = @(), $Records = @()) [pscustomobject] @{ tables = [pscustomobject] @{ attempt_answers = @($Rows); idempotency_records = @($Records) }; blobs = @() } }
$probeContext = [pscustomobject] @{ RejectedKeys = [Collections.Generic.List[string]]::new() }
$probe = @{ Actor = 'peer_teacher'; Method = 'GET'; Path = '/teacher/submissions/x'; Status = 404; Code = 'resource_not_found' }
$row = [pscustomobject] @{ id = 'a'; awarded_points = $null }
$script:probeResponse = New-Stage9Response 404 (New-Stage9ErrorBody resource_not_found)
$script:factsQueue = [Collections.Generic.Queue[object]]::new(@((New-Stage9ProbeFacts @($row)), (New-Stage9ProbeFacts @($row))))
Confirm-Stage9Accept { Assert-Stage9NegativeProbes $probeContext @($probe) 'stub' }
$changed = [pscustomobject] @{ id = 'a'; awarded_points = '1.00000000' }
$script:factsQueue = [Collections.Generic.Queue[object]]::new(@((New-Stage9ProbeFacts @($row)), (New-Stage9ProbeFacts @($changed))))
Confirm-Stage9Reject 'a rejected probe that changed a row' { Assert-Stage9NegativeProbes $probeContext @($probe) 'stub' }
$script:probeResponse = New-Stage9Response 200 ([pscustomobject] @{ data = [pscustomobject] @{ id = 'x' } })
$script:factsQueue = [Collections.Generic.Queue[object]]::new(@((New-Stage9ProbeFacts @($row)), (New-Stage9ProbeFacts @($row))))
Confirm-Stage9Reject 'a probe that succeeded' { Assert-Stage9NegativeProbes $probeContext @($probe) 'stub' }
$script:probeResponse = New-Stage9Response 404 (New-Stage9ErrorBody resource_not_found); $script:probeResponse.Text = '{"message":"E2E S09 Manual Student not found"}'
$script:factsQueue = [Collections.Generic.Queue[object]]::new(@((New-Stage9ProbeFacts @($row)), (New-Stage9ProbeFacts @($row))))
Confirm-Stage9Reject 'an error naming a protected identity' { Assert-Stage9NegativeProbes $probeContext @($probe) 'stub' }
$keyed = $probe.Clone(); $keyed.Key = '09000000-0000-4000-8000-000009000777'
$record = [pscustomobject] @{ idempotency_key = '09000000-0000-4000-8000-000009000777' }
$script:probeResponse = New-Stage9Response 404 (New-Stage9ErrorBody resource_not_found)
$script:factsQueue = [Collections.Generic.Queue[object]]::new(@((New-Stage9ProbeFacts @($row) @($record)), (New-Stage9ProbeFacts @($row) @($record))))
Confirm-Stage9Reject 'a rejected key that left an idempotency record' { Assert-Stage9NegativeProbes $probeContext @($keyed) 'stub' }

Write-Output "Stage9ApiSecurity pure verifier: PASS ($script:checks checks; no network or DB access)."
