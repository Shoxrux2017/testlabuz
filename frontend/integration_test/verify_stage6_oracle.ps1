param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage6_oracle.ps1')

function New-Stage6VerifierQuestion {
    param(
        [string] $Id, [string] $Type, [string] $Prompt, [decimal] $Points,
        [int] $Position, [string] $Mode = 'automatic', [object[]] $Choices = @(),
        [object[]] $TrueFalse = @(), [object[]] $ShortAnswers = @(),
        [object[]] $Matching = @(), [object[]] $Ordering = @(), [object[]] $Blanks = @()
    )
    [pscustomobject] @{
        id = $Id; type = $Type; prompt = $Prompt; points = $Points; position = $Position; checking_mode = $Mode
        choices = $Choices; true_false = $TrueFalse; short_answers = $ShortAnswers
        matching = $Matching; ordering = $Ordering; blanks = $Blanks
    }
}

function New-Stage6ValidFacts {
    $empty = @()
    $questions = @(
        (New-Stage6VerifierQuestion -Id 'q-fill' -Type 'fill_in_blank' -Prompt 'DNS converts {{host}} into an {{address}}.' -Points 2 -Position 1 -Blanks @(
            [pscustomobject] @{ key = 'host'; position = 1; answers = @('domain name') },
            [pscustomobject] @{ key = 'address'; position = 2; answers = @('IP address') }
        )),
        (New-Stage6VerifierQuestion -Id 'q-single' -Type 'single_choice' -Prompt 'What is the primary purpose of DNS?' -Points 1.5 -Position 2 -Choices @(
            [pscustomobject] @{ option_text = 'Resolves domain names'; is_correct = $true; position = 1 },
            [pscustomobject] @{ option_text = 'Compresses files'; is_correct = $false; position = 2 },
            [pscustomobject] @{ option_text = 'Encrypts all traffic'; is_correct = $false; position = 3 }
        )),
        (New-Stage6VerifierQuestion -Id 'q-multiple' -Type 'multiple_choice' -Prompt 'Select valid network protocols.' -Points 2 -Position 3 -Choices @(
            [pscustomobject] @{ option_text = 'HTTP'; is_correct = $true; position = 1 },
            [pscustomobject] @{ option_text = 'DNS'; is_correct = $true; position = 2 },
            [pscustomobject] @{ option_text = 'PNG'; is_correct = $false; position = 3 },
            [pscustomobject] @{ option_text = 'JPEG'; is_correct = $false; position = 4 }
        )),
        (New-Stage6VerifierQuestion -Id 'q-boolean' -Type 'true_false' -Prompt 'An IP address can identify a network endpoint.' -Points 1 -Position 4 -TrueFalse @([pscustomobject] @{ correct_value = $true })),
        (New-Stage6VerifierQuestion -Id 'q-short-auto' -Type 'short_written' -Prompt 'Write the abbreviation for Domain Name System.' -Points 1 -Position 5 -ShortAnswers @([pscustomobject] @{ accepted_text = 'DNS'; position = 1 })),
        (New-Stage6VerifierQuestion -Id 'q-short-manual' -Type 'short_written' -Prompt 'Describe DNS in one sentence.' -Points 2 -Position 6 -Mode 'manual'),
        (New-Stage6VerifierQuestion -Id 'q-open' -Type 'open_written' -Prompt 'Explain the steps of a DNS lookup.' -Points 3 -Position 7 -Mode 'manual'),
        (New-Stage6VerifierQuestion -Id 'q-file' -Type 'file_based' -Prompt 'Upload the completed network presentation.' -Points 4 -Position 8 -Mode 'manual'),
        (New-Stage6VerifierQuestion -Id 'q-matching' -Type 'matching' -Prompt 'Match each term to its meaning.' -Points 2 -Position 9 -Matching @(
            [pscustomobject] @{ side = 'left'; match_key = 'a'; item_text = 'DNS'; position = 1 },
            [pscustomobject] @{ side = 'right'; match_key = 'a'; item_text = 'Domain name resolution'; position = 1 },
            [pscustomobject] @{ side = 'left'; match_key = 'b'; item_text = 'IP'; position = 2 },
            [pscustomobject] @{ side = 'right'; match_key = 'b'; item_text = 'Network address'; position = 2 }
        )),
        (New-Stage6VerifierQuestion -Id 'q-ordering' -Type 'ordering' -Prompt 'Put the simplified lookup steps in order.' -Points 2 -Position 10 -Ordering @(
            [pscustomobject] @{ item_text = 'Enter domain'; correct_position = 1 },
            [pscustomobject] @{ item_text = 'Resolve address'; correct_position = 2 },
            [pscustomobject] @{ item_text = 'Contact server'; correct_position = 3 }
        ))
    )
    $mainId = 'main-homework'
    [pscustomobject] @{
        main_count = 1
        main = [pscustomobject] @{
            id = $mainId; institution_id = '06000000-0000-4000-8000-000000000101'
            topic_id = '06000000-0000-4000-c000-000000000101'; teacher_id = '06000000-0000-4000-9000-000000000201'
            type = 'homework'; title = 'E2E S06 Official Homework'; description = 'E2E S06 official draft description'
            student_instructions = 'Complete every question carefully.'; assignment_mode = 'group'; total = '20.500000'
            status = 'archived'; deadline_at = '2035-06-15T13:00:00+00:00'
            recipients = @(
                [pscustomobject] @{ student_id = '06000000-0000-4000-9000-000000000301'; assignment_source = 'group' },
                [pscustomobject] @{ student_id = '06000000-0000-4000-9000-000000000302'; assignment_source = 'group' }
            ); attempts = $empty; questions = $questions
        }
        practice_count = 1
        practice = [pscustomobject] @{
            id = 'practice-homework'; assignment_mode = 'selected_students'; status = 'archived'; total = '0.000000'
            recipients = @([pscustomobject] @{ student_id = '06000000-0000-4000-9000-000000000301'; assignment_source = 'direct' })
            questions = $empty; attempts = $empty
        }
        authoring_topic_status = 'closed'; authoring_open_homework_count = 0
        authoring_pair = [pscustomobject] @{ id = 'main-pair'; homework_assessment_id = $mainId; blitz_assessment_id = $null; cohort_snapshotted_at = '2035-06-01T00:00:00+00:00'; locked_at = $null }
        locked_pair = [pscustomobject] @{ id = 'locked-pair'; homework_assessment_id = 'locked-homework'; blitz_assessment_id = $null; cohort_snapshotted_at = '2035-01-01T00:00:00+00:00'; locked_at = '2035-01-01T00:01:00+00:00' }
        locked = [pscustomobject] @{
            total = '1.000000'
            attempts = @([pscustomobject] @{ status = 'in_progress'; submitted_at = $null; finalized_at = $null; finalization_reason = $null })
            questions = @([pscustomobject] @{ id = 'locked-question' })
        }
        fake_blitz_count = 0; rejected_homework_count = 0; temporary_question_count = 0
    }
}

function Copy-Stage6Facts {
    param([psobject] $Facts)
    $Facts | ConvertTo-Json -Depth 100 | ConvertFrom-Json
}

function Assert-Stage6OracleRejects {
    param([scriptblock] $Mutation, [string] $Label)
    $facts = Copy-Stage6Facts -Facts (New-Stage6ValidFacts)
    & $Mutation $facts
    $rejected = $false
    try { Assert-Stage6DatabasePostconditions -Facts $facts } catch { $rejected = $true }
    if (-not $rejected) { throw "Stage 6 oracle verifier accepted mutation: $Label." }
}

$valid = New-Stage6ValidFacts
Assert-Stage6DatabasePostconditions -Facts $valid
if ($null -ne $valid.locked_pair.blitz_assessment_id) { throw 'The valid locked fixture did not exercise null Blitz.' }

$mutations = [ordered] @{
    'missing main Homework' = { param($f) $f.main_count = 0 }
    'duplicate main Homework' = { param($f) $f.main_count = 2 }
    'wrong tenant' = { param($f) $f.main.institution_id = 'foreign' }
    'wrong description' = { param($f) $f.main.description = 'wrong' }
    'wrong student instructions' = { param($f) $f.main.student_instructions = 'wrong' }
    'wrong Question count' = { param($f) $f.main.questions = @($f.main.questions | Select-Object -First 9) }
    'non-contiguous positions' = { param($f) $f.main.questions[9].position = 11 }
    'wrong total' = { param($f) $f.main.total = '21.000000' }
    'foreign recipient leakage' = { param($f) $f.main.recipients += [pscustomobject] @{ student_id = '06000000-0000-4000-9000-000000000503'; assignment_source = 'group' } }
    'ended recipient leakage' = { param($f) $f.main.recipients[1].student_id = '06000000-0000-4000-9000-000000000303' }
    'inactive recipient leakage' = { param($f) $f.main.recipients[1].student_id = '06000000-0000-4000-9000-000000000304' }
    'fabricated Attempt' = { param($f) $f.main.attempts = @([pscustomobject] @{ status = 'in_progress' }) }
    'fabricated Blitz' = { param($f) $f.fake_blitz_count = 1 }
    'non-null main Blitz' = { param($f) $f.authoring_pair.blitz_assessment_id = 'fake-blitz' }
    'locked pair missing cohort' = { param($f) $f.locked_pair.cohort_snapshotted_at = $null }
    'practice marked official' = { param($f) $f.authoring_pair.homework_assessment_id = $f.practice.id }
    'temporary Question retained' = { param($f) $f.temporary_question_count = 1 }
    'Topic remains active' = { param($f) $f.authoring_topic_status = 'active' }
    'typed Single Choice corruption' = { param($f) ($f.main.questions | Where-Object type -eq 'single_choice')[0].choices[0].is_correct = $false }
    'manual Short Written answer leakage' = { param($f) ($f.main.questions | Where-Object { $_.type -eq 'short_written' -and $_.checking_mode -eq 'manual' })[0].short_answers = @([pscustomobject] @{ accepted_text = 'unsafe' }) }
    'Fill in Blank corruption' = { param($f) ($f.main.questions | Where-Object type -eq 'fill_in_blank')[0].blanks[0].answers = @('wrong') }
}
foreach ($entry in $mutations.GetEnumerator()) {
    Assert-Stage6OracleRejects -Mutation $entry.Value -Label $entry.Key
}

$badOraclePath = Join-Path ([IO.Path]::GetTempPath()) 'stage6-oracle.json'
$rejectedPath = $false
try { Assert-Stage6OraclePath -Path $badOraclePath | Out-Null } catch { $rejectedPath = $true }
if (-not $rejectedPath) { throw 'Stage 6 oracle accepted an uncontrolled host path.' }
$nestedOraclePath = Join-Path (Join-Path ([IO.Path]::GetTempPath()) 'nested') ('testlabuz-stage6-oracle-' + ('a' * 32) + '.json')
$rejectedNestedPath = $false
try { Assert-Stage6OraclePath -Path $nestedOraclePath | Out-Null } catch { $rejectedNestedPath = $true }
if (-not $rejectedNestedPath) { throw 'Stage 6 oracle accepted a nested host path.' }

Write-Output "Stage6OracleVerifier: PASS (valid null-Blitz facts plus $($mutations.Count) rejected mutations and path boundaries)"
