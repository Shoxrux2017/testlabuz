param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage7_api_security.ps1')
$script:checks = 0
function Confirm-Stage7ApiReject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "integration-harness defect: API verifier accepted $Label." }
    $script:checks++
}
function Copy-Stage7ApiSynthetic { param($Value) ConvertTo-Json -InputObject $Value -Depth 50 -Compress | ConvertFrom-Json }
function New-Stage7SyntheticError {
    param([int] $Status, [string] $Code, $Errors = [pscustomobject] @{})
    [pscustomobject] @{ StatusCode = $Status; Json = [pscustomobject] @{ message = 'Safe message'; code = $Code; errors = $Errors } }
}

foreach ($mapping in @(@(401,'authentication_required'),@(403,'forbidden'),@(404,'resource_not_found'),@(409,'attempt_not_editable'),@(409,'attempts_exhausted'),@(409,'deadline_passed'))) {
    $response = New-Stage7SyntheticError $mapping[0] $mapping[1]
    Assert-Stage7ApiError $response $mapping[0] $mapping[1]
    $script:checks++
    Confirm-Stage7ApiReject "wrong status for $($mapping[1])" { Assert-Stage7ApiError $response 200 $mapping[1] }
    Confirm-Stage7ApiReject "wrong code for $($mapping[1])" { Assert-Stage7ApiError $response $mapping[0] wrong_code }
}
$validation = New-Stage7SyntheticError 422 validation_failed ([pscustomobject] @{ idempotency_key = @('Required') })
Assert-Stage7ApiError $validation 422 validation_failed @('idempotency_key')
Confirm-Stage7ApiReject 'missing validation errors' { Assert-Stage7ApiError $validation 422 validation_failed @('body') }
Confirm-Stage7ApiReject 'unexpected validation disclosure' { Assert-Stage7ApiError $validation 422 validation_failed }
$bad = New-Stage7SyntheticError 401 authentication_required
$bad.Json | Add-Member trace @('internal.php')
Confirm-Stage7ApiReject 'exception/error envelope extra fields' { Assert-Stage7ApiError $bad 401 authentication_required }
$bad = New-Stage7SyntheticError 401 authentication_required @()
Confirm-Stage7ApiReject 'errors array instead of object' { Assert-Stage7ApiError $bad 401 authentication_required }
$bad = New-Stage7SyntheticError 422 validation_failed ([pscustomobject] @{ body = 'not-an-array' })
Confirm-Stage7ApiReject 'validation message not array' { Assert-Stage7ApiError $bad 422 validation_failed @('body') }

$success = [pscustomobject] @{ StatusCode = 201; Json = [pscustomobject] @{ data = [pscustomobject] @{ id = 'attempt'; status = 'in_progress'; answers = @(); questions = @() } } }
Assert-Stage7ApiSuccess $success 201
Assert-Stage7IdempotentResponse $success (Copy-Stage7ApiSynthetic $success) 201
$script:checks += 2
Confirm-Stage7ApiReject 'missing success envelope' { Assert-Stage7ApiSuccess ([pscustomobject] @{ StatusCode = 200; Json = [pscustomobject] @{ id = 'attempt' } }) }
$bad = Copy-Stage7ApiSynthetic $success; $bad.Json.data = @()
Confirm-Stage7ApiReject 'resource data array' { Assert-Stage7ApiSuccess $bad 201 }
$bad = Copy-Stage7ApiSynthetic $success; $bad.Json.data.id = 'second-attempt'
Confirm-Stage7ApiReject 'Start replay changed Attempt' { Assert-Stage7IdempotentResponse $success $bad 201 }
$bad = Copy-Stage7ApiSynthetic $success; $bad.StatusCode = 200
Confirm-Stage7ApiReject 'Start replay changed logical status' { Assert-Stage7IdempotentResponse $success $bad 201 }
$submitted = [pscustomobject] @{ StatusCode = 200; Json = [pscustomobject] @{ data = [pscustomobject] @{ id = 'attempt'; finalized_at = '2026-09-11T01:00:00Z'; status = 'submitted' } } }
$bad = Copy-Stage7ApiSynthetic $submitted; $bad.Json.data.finalized_at = '2026-09-11T02:00:00Z'
Confirm-Stage7ApiReject 'Submit replay timestamp rewrite' { Assert-Stage7IdempotentResponse $submitted $bad 200 }
$collection = [pscustomobject] @{ StatusCode = 200; Json = [pscustomobject] @{ data = @(); meta = [pscustomobject] @{ pagination = [pscustomobject] @{ total = 0 } } } }
Assert-Stage7ApiSuccess $collection 200 collection
$empty = [pscustomobject] @{ StatusCode = 204; Json = $null }
Assert-Stage7ApiSuccess $empty 204 empty
$login = [pscustomobject] @{ StatusCode = 200; Json = [pscustomobject] @{ data = [pscustomobject] @{ token = 'synthetic-token'; token_type = 'Bearer' } } }
Assert-Stage7ApiSuccess $login 200 login
$bad = Copy-Stage7ApiSynthetic $login; $bad.Json.data.token_type = 'Basic'
Confirm-Stage7ApiReject 'wrong login token type' { Assert-Stage7ApiSuccess $bad 200 login }

$safe = [pscustomobject] @{ data = [pscustomobject] @{ questions = @([pscustomobject] @{ answer_ui = [pscustomobject] @{ max_selections = 2 }; answers = @([pscustomobject] @{ text = 'Student text' }) }) } }
Assert-Stage7NoProtectedKeys $safe
foreach ($key in @('is_correct','correct_value','accepted_answers','correct_position','match_key','checking_mode','configuration','client_key','storage_key','storage_disk','checksum_sha256')) {
    $nested = Copy-Stage7ApiSynthetic $safe
    $nested.data.questions[0].answers[0] | Add-Member $key 'protected'
    Confirm-Stage7ApiReject "recursive $key leak" { Assert-Stage7NoProtectedKeys $nested }
}
$redacted = Protect-Stage7Diagnostic 'Authorization: Bearer synthetic-bearer; password=synthetic-password' @('synthetic-password')
if ($redacted.Contains('synthetic-bearer') -or $redacted.Contains('synthetic-password') -or -not $redacted.Contains('[REDACTED]')) { throw 'integration-harness defect: Token/secret redaction failed.' }
$script:checks++

$bytes = [Text.Encoding]::UTF8.GetBytes('safe deterministic bytes')
$hasher = [Security.Cryptography.SHA256]::Create()
try { $sha = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $hasher.Dispose() }
$fixture = [pscustomobject] @{ mime_type = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'; size_bytes = $bytes.Length; sha256 = $sha }
$download = [pscustomobject] @{ StatusCode = 200; Bytes = $bytes; Headers = @{ 'Content-Type' = $fixture.mime_type; 'Content-Disposition' = 'attachment; filename="replacement.pptx"'; 'Cache-Control' = 'no-store, private'; 'X-Content-Type-Options' = 'nosniff' } }
Assert-Stage7Download $download $fixture
$script:checks++
foreach ($header in @('Content-Type','Content-Disposition','Cache-Control','X-Content-Type-Options')) {
    $bad = [pscustomobject] @{ StatusCode = 200; Bytes = $bytes; Headers = $download.Headers.Clone() }
    $bad.Headers[$header] = 'wrong'
    Confirm-Stage7ApiReject "protected download $header" { Assert-Stage7Download $bad $fixture }
}
$bad = [pscustomobject] @{ StatusCode = 200; Bytes = [Text.Encoding]::UTF8.GetBytes('changed'); Headers = $download.Headers.Clone() }
Confirm-Stage7ApiReject 'changed protected bytes/checksum' { Assert-Stage7Download $bad $fixture }
$bad = [pscustomobject] @{ StatusCode = 200; Bytes = $bytes; Headers = $download.Headers.Clone() }; $bad.Headers['Cache-Control'] = 'private, public, no-store'
Confirm-Stage7ApiReject 'public cache directive despite private/no-store' { Assert-Stage7Download $bad $fixture }

$answerTables = [ordered] @{}
foreach ($table in @('attempt_answers','answer_choice_selections','answer_text_values','answer_boolean_values','answer_matching_pairs','answer_ordering_items','answer_fill_blank_values','answer_files','files')) { $answerTables[$table] = @() }
$answerTables.attempt_answers = @([pscustomobject] @{ id = 'answer'; attempt_id = 'attempt'; updated_at = 'stable' })
$answerTables.answer_text_values = @([pscustomobject] @{ answer_id = 'answer'; text_value = 'exact saved text'; updated_at = 'stable' })
$beforeSubmit = [pscustomobject] @{ tables = [pscustomobject] $answerTables; blobs = @(); public_blobs = @() }
Assert-Stage7SubmitAnswersPreserved $beforeSubmit (Copy-Stage7ApiSynthetic $beforeSubmit) attempt
$bad = Copy-Stage7ApiSynthetic $beforeSubmit; $bad.tables.answer_text_values[0].text_value = 'changed on Submit'
Confirm-Stage7ApiReject 'Submit changes normalized answer while parent is unchanged' { Assert-Stage7SubmitAnswersPreserved $beforeSubmit $bad attempt }
$bad = Copy-Stage7ApiSynthetic $beforeSubmit; $bad.tables.attempt_answers[0].updated_at = 'rewritten'
Confirm-Stage7ApiReject 'Submit rewrites saved-answer timestamp' { Assert-Stage7SubmitAnswersPreserved $beforeSubmit $bad attempt }

# Parsing does not execute requests, PHP programs, Docker, auth, or scheduler calls.
foreach ($file in @('stage7_api_security.ps1','stage7_oracle.ps1')) {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $file), [ref] $tokens, [ref] $errors)
    if (@($errors).Count -ne 0) { throw "integration-harness defect: $file parse errors." }
}
Write-Output "Stage7ApiSecurity pure verifier: PASS ($script:checks checks; no API, DB, Docker or scheduler execution)."
