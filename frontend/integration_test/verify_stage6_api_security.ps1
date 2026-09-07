param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage6_api_security.ps1')

function New-Stage6ErrorResponse {
    param([int] $Status, [string] $Code, [psobject] $Errors = ([pscustomobject] @{}), [string] $Extra = '')
    $json = [pscustomobject] @{ message = 'Expected message'; code = $Code; errors = $Errors; request_id = 'request-id' }
    if ($Extra) { Add-Member -InputObject $json -NotePropertyName $Extra -NotePropertyValue 'unsafe' }
    [pscustomobject] @{ StatusCode = $Status; Json = $json; Raw = ($json | ConvertTo-Json -Depth 10 -Compress) }
}

function Assert-Stage6VerifierRejects {
    param([scriptblock] $Action, [string] $Label)
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw "Stage 6 API verifier accepted $Label." }
}

foreach ($case in @(
    @{ Status = 401; Code = 'authentication_required' },
    @{ Status = 403; Code = 'forbidden' },
    @{ Status = 404; Code = 'resource_not_found' },
    @{ Status = 409; Code = 'official_task_requires_group_assignment' },
    @{ Status = 409; Code = 'result_pair_locked' },
    @{ Status = 409; Code = 'business_conflict' },
    @{ Status = 409; Code = 'deadline_passed' }
)) {
    Assert-Stage6ApiError -Response (New-Stage6ErrorResponse -Status $case.Status -Code $case.Code) -ExpectedStatus $case.Status -ExpectedCode $case.Code
}
$validation = New-Stage6ErrorResponse -Status 422 -Code 'validation_failed' -Errors ([pscustomobject] @{ student_ids = @('Invalid selection.') })
Assert-Stage6ApiError -Response $validation -ExpectedStatus 422 -ExpectedCode 'validation_failed' -ErrorField 'student_ids'

Assert-Stage6VerifierRejects { Assert-Stage6ApiError -Response (New-Stage6ErrorResponse -Status 200 -Code 'authentication_required') -ExpectedStatus 401 -ExpectedCode 'authentication_required' } 'wrong status'
Assert-Stage6VerifierRejects { Assert-Stage6ApiError -Response (New-Stage6ErrorResponse -Status 401 -Code 'wrong') -ExpectedStatus 401 -ExpectedCode 'authentication_required' } 'wrong code'
Assert-Stage6VerifierRejects { Assert-Stage6ApiError -Response (New-Stage6ErrorResponse -Status 422 -Code 'validation_failed') -ExpectedStatus 422 -ExpectedCode 'validation_failed' -ErrorField 'student_ids' } 'missing validation field'
Assert-Stage6VerifierRejects { Assert-Stage6ApiError -Response (New-Stage6ErrorResponse -Status 404 -Code 'resource_not_found' -Extra 'resource') -ExpectedStatus 404 -ExpectedCode 'resource_not_found' } 'extra error envelope field'

$safeResponse = New-Stage6ErrorResponse -Status 404 -Code 'resource_not_found'
Assert-Stage6NoProtectedDisclosure -Response $safeResponse -ForbiddenValues @('E2E S06 Foreign Homework')
$unsafeResponse = [pscustomobject] @{ StatusCode = 404; Json = $safeResponse.Json; Raw = '{"message":"E2E S06 Foreign Homework"}' }
Assert-Stage6VerifierRejects { Assert-Stage6NoProtectedDisclosure -Response $unsafeResponse -ForbiddenValues @('E2E S06 Foreign Homework') } 'protected disclosure'

$pair = [pscustomobject] @{
    id = 'pair'; homework_assessment_id = 'homework'; blitz_assessment_id = $null
    designated_at = '2026-09-01T00:00:00Z'; locked_at = '2026-09-01T00:01:00Z'; updated_at = '2026-09-01T00:01:00Z'
}
Assert-Stage6PairNoOp -Before $pair -After ($pair | Select-Object *)
$changedPair = $pair | Select-Object *
$changedPair.updated_at = '2026-09-01T00:02:00Z'
Assert-Stage6VerifierRejects { Assert-Stage6PairNoOp -Before $pair -After $changedPair } 'same-target timestamp churn'
$blitzPair = $pair | Select-Object *
$blitzPair.blitz_assessment_id = 'fake-blitz'
Assert-Stage6VerifierRejects { Assert-Stage6PairNoOp -Before $pair -After $blitzPair } 'fabricated Blitz'

Write-Output 'Stage6ApiSecurityVerifier: PASS (8 accepted envelopes and 7 rejected boundary mutations)'
