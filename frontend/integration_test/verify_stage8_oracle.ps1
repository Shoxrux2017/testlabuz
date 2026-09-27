param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage8_oracle.ps1')
. (Join-Path $PSScriptRoot 'stage8_concurrency_probe.ps1')

$script:checks = 0
function Confirm-Stage8Reject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "integration-harness defect: Oracle verifier accepted $Label." }
    $script:checks++
}
function Confirm-Stage8Accept { param([scriptblock] $Check) & $Check | Out-Null; $script:checks++ }
function Copy-Stage8Synthetic { param($Value) ConvertTo-Json -InputObject $Value -Depth 50 -Compress | ConvertFrom-Json }
function New-Stage8Tables { param([hashtable] $Rows = @{})
    $tables = [ordered] @{}
    foreach ($table in @('institutions', 'users', 'groups', 'topics', 'assessments', 'blitz_tasks', 'homework_assignments', 'assessment_students', 'questions', 'topic_result_pairs', 'assessment_attempts', 'blitz_attempt_exceptions', 'attempt_answers', 'answer_choice_selections', 'answer_text_values', 'answer_boolean_values', 'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files', 'files', 'idempotency_records')) {
        $tables[$table] = if ($Rows.ContainsKey($table)) { @($Rows[$table]) } else { @() }
    }
    [pscustomobject] $tables
}

# Blitz lifecycle and timer shape.
$sync = [pscustomobject] @{ assessment_id = 'blitz'; institution_id = 'target'; status = 'active'; duration_seconds = 600; timer_start_mode_snapshot = 'synchronized'
    activated_at = '2026-09-27 10:00:00+00'; synchronized_ends_at = '2026-09-27 10:10:00+00'; activated_by_user_id = 'teacher'; closed_at = $null; archived_at = $null; scheduled_at = $null }
Confirm-Stage8Accept { Assert-Stage8BlitzLifecycle $sync active synchronized 600 }
$bad = Copy-Stage8Synthetic $sync; $bad.activated_at = $null
Confirm-Stage8Reject 'activated Blitz without activation instant' { Assert-Stage8BlitzLifecycle $bad active synchronized 600 }
$bad = Copy-Stage8Synthetic $sync; $bad.status = 'closed'
Confirm-Stage8Reject 'wrong Blitz lifecycle status' { Assert-Stage8BlitzLifecycle $bad active synchronized 600 }
$bad = Copy-Stage8Synthetic $sync; $bad.synchronized_ends_at = '2026-09-27 10:09:59+00'
Confirm-Stage8Reject 'wrong synchronized common end' { Assert-Stage8BlitzLifecycle $bad active synchronized 600 }
$individual = Copy-Stage8Synthetic $sync; $individual.timer_start_mode_snapshot = 'individual'; $individual.synchronized_ends_at = $null
Confirm-Stage8Accept { Assert-Stage8BlitzLifecycle $individual active individual 600 }
$bad = Copy-Stage8Synthetic $individual; $bad.synchronized_ends_at = '2026-09-27 10:10:00+00'
Confirm-Stage8Reject 'individual common end non-null' { Assert-Stage8BlitzLifecycle $bad active individual 600 }
$draft = [pscustomobject] @{ status = 'draft'; duration_seconds = 600; timer_start_mode_snapshot = $null; activated_at = '2026-09-27 10:00:00+00'; synchronized_ends_at = $null; activated_by_user_id = $null; scheduled_at = $null; archived_at = $null }
Confirm-Stage8Reject 'draft Blitz with activation timing' { Assert-Stage8BlitzLifecycle $draft draft $null 600 }
$scheduled = [pscustomobject] @{ status = 'scheduled'; duration_seconds = 600; timer_start_mode_snapshot = $null; activated_at = $null; synchronized_ends_at = $null; activated_by_user_id = $null; scheduled_at = '2026-09-29 04:00:00+00'; archived_at = $null }
Confirm-Stage8Accept { Assert-Stage8BlitzLifecycle $scheduled scheduled $null 600 }
$bad = Copy-Stage8Synthetic $scheduled; $bad.scheduled_at = $null
Confirm-Stage8Reject 'scheduled Blitz without scheduled_at' { Assert-Stage8BlitzLifecycle $bad scheduled $null 600 }
$archived = Copy-Stage8Synthetic $scheduled; $archived.status = 'archived'
Confirm-Stage8Reject 'archived Blitz without archived_at' { Assert-Stage8BlitzLifecycle $archived archived $null 600 }
$archived.archived_at = '2026-09-27 10:30:00+00'
Confirm-Stage8Accept { Assert-Stage8BlitzLifecycle $archived archived $null 600 }

# Official pair and cohort.
$pair = [pscustomobject] @{ id = 'pair'; institution_id = 'target'; topic_id = 'topic'; homework_assessment_id = 'homework'; blitz_assessment_id = 'blitz'; cohort_snapshotted_at = 'c'; locked_at = 'l'; updated_at = 'u' }
$pairBaseline = Copy-Stage8Synthetic $pair; $pairBaseline.blitz_assessment_id = $null
Confirm-Stage8Accept { Assert-Stage8OfficialPair $pair $pairBaseline 'blitz' }
foreach ($field in @('homework_assessment_id', 'cohort_snapshotted_at', 'locked_at')) {
    $bad = Copy-Stage8Synthetic $pair; $bad.$field = 'changed'
    Confirm-Stage8Reject "official pair $field mismatch" { Assert-Stage8OfficialPair $bad $pairBaseline 'blitz' }
}
Confirm-Stage8Reject 'official pair wrong Blitz' { Assert-Stage8OfficialPair $pair $pairBaseline 'other' }
$recipientFacts = [pscustomobject] @{ tables = (New-Stage8Tables @{ assessment_students = @([pscustomobject] @{ id = 'r1'; assessment_id = 'blitz'; student_id = 'a1' }, [pscustomobject] @{ id = 'r2'; assessment_id = 'blitz'; student_id = 'a2' }) }) }
Confirm-Stage8Accept { Assert-Stage8Recipients $recipientFacts blitz @('a1', 'a2') 'frozen' }
Confirm-Stage8Reject 'extra recipient (current member outside the frozen cohort)' { Assert-Stage8Recipients $recipientFacts blitz @('a1') 'frozen' }
Confirm-Stage8Reject 'missing recipient' { Assert-Stage8Recipients $recipientFacts blitz @('a1', 'a2', 'a3') 'frozen' }
$established = [pscustomobject] @{ cohort_snapshotted_at = '2026-09-27 10:00:00+00'; locked_at = $null }
$activatedBlitz = [pscustomobject] @{ assessment_id = 'blitz'; activated_at = '2026-09-27 10:00:00+00' }
Confirm-Stage8Accept { Assert-Stage8CohortEstablished $established $activatedBlitz $recipientFacts @('a1', 'a2') 'homework' }
$bad = Copy-Stage8Synthetic $established; $bad.cohort_snapshotted_at = $null
Confirm-Stage8Reject 'first official Blitz activation failing to establish cohort' { Assert-Stage8CohortEstablished $bad $activatedBlitz $recipientFacts @('a1', 'a2') 'homework' }
$bad = Copy-Stage8Synthetic $established; $bad.locked_at = '2026-09-27 10:00:00+00'
Confirm-Stage8Reject 'activation alone locking the pair' { Assert-Stage8CohortEstablished $bad $activatedBlitz $recipientFacts @('a1', 'a2') 'homework' }
$withHomework = Copy-Stage8Synthetic $recipientFacts; $withHomework.tables.assessment_students += [pscustomobject] @{ id = 'r3'; assessment_id = 'homework'; student_id = 'a1' }
Confirm-Stage8Reject 'Homework recipients fabricated at Blitz activation' { Assert-Stage8CohortEstablished $established $activatedBlitz $withHomework @('a1', 'a2') 'homework' }

# Attempt history, exceptions, deadlines.
$historyBlitz = [pscustomobject] @{ assessment_id = 'blitz'; institution_id = 'target'; timer_start_mode_snapshot = 'synchronized'; duration_seconds = 600; synchronized_ends_at = '2026-09-27 10:10:00+00' }
$first = [pscustomobject] @{ id = 'n1'; institution_id = 'target'; assessment_id = 'blitz'; assessment_student_id = 'r1'; student_id = 'a1'; attempt_number = 1; status = 'submitted'
    started_at = '2026-09-27 10:01:00+00'; deadline_at = '2026-09-27 10:10:00+00'; official_score_eligible = $false }
$second = [pscustomobject] @{ id = 'n2'; institution_id = 'target'; assessment_id = 'blitz'; assessment_student_id = 'r1'; student_id = 'a1'; attempt_number = 2; status = 'in_progress'
    started_at = '2026-09-27 10:20:00+00'; deadline_at = '2026-09-27 10:30:00+00'; official_score_eligible = $true }
$exception = [pscustomobject] @{ id = 'e1'; assessment_id = 'blitz'; student_id = 'a1'; institution_id = 'target'; invalidated_attempt_id = 'n1'; replacement_attempt_id = 'n2'; reason_type = 'technical'; reason = 'why'; granted_by_user_id = 'teacher'; granted_at = '2026-09-27 10:15:00+00' }
function New-Stage8HistoryFacts { param([object[]] $Attempts, [object[]] $Exceptions)
    [pscustomobject] @{ tables = (New-Stage8Tables @{ blitz_tasks = @($historyBlitz); assessment_students = @([pscustomobject] @{ id = 'r1'; assessment_id = 'blitz'; student_id = 'a1'; institution_id = 'target' }); assessment_attempts = $Attempts; blitz_attempt_exceptions = $Exceptions }) }
}
Confirm-Stage8Accept { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($first, $second) @($exception)) blitz a1 }
$third = Copy-Stage8Synthetic $second; $third.id = 'n3'; $third.attempt_number = 3
Confirm-Stage8Reject 'Attempt #3' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($first, $second, $third) @($exception)) blitz a1 }
Confirm-Stage8Reject 'replacement #2 without exception' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($first, $second) @()) blitz a1 }
$eligibleFirst = Copy-Stage8Synthetic $first; $eligibleFirst.official_score_eligible = $true
Confirm-Stage8Reject 'invalidated #1 still eligible' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($eligibleFirst, $second) @($exception)) blitz a1 }
$ineligibleSecond = Copy-Stage8Synthetic $second; $ineligibleSecond.official_score_eligible = $false
Confirm-Stage8Reject 'replacement #2 not eligible' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($first, $ineligibleSecond) @($exception)) blitz a1 }
$lonelyIneligible = Copy-Stage8Synthetic $first
Confirm-Stage8Reject '#1 ineligible without exception' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($lonelyIneligible) @()) blitz a1 }
$commonEndSecond = Copy-Stage8Synthetic $second; $commonEndSecond.deadline_at = '2026-09-27 10:10:00+00'
Confirm-Stage8Reject 'replacement deadline using common end instead of own start+duration' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($first, $commonEndSecond) @($exception)) blitz a1 }
$wrongLink = Copy-Stage8Synthetic $exception; $wrongLink.replacement_attempt_id = 'other'
Confirm-Stage8Reject 'wrong exception link' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($first, $second) @($wrongLink)) blitz a1 }
$wrongInvalidated = Copy-Stage8Synthetic $exception; $wrongInvalidated.invalidated_attempt_id = 'n2'
Confirm-Stage8Reject 'exception invalidating the wrong Attempt' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($first, $second) @($wrongInvalidated)) blitz a1 }
$earlySecond = Copy-Stage8Synthetic $second; $earlySecond.started_at = '2026-09-27 10:14:00+00'; $earlySecond.deadline_at = '2026-09-27 10:24:00+00'
Confirm-Stage8Reject 'replacement started before its grant' { Assert-Stage8AttemptHistory (New-Stage8HistoryFacts @($first, $earlySecond) @($exception)) blitz a1 }
Confirm-Stage8Accept { Assert-Stage8Exception $exception n1 n2 technical why teacher }
Confirm-Stage8Reject 'wrong exception reason' { Assert-Stage8Exception $exception n1 n2 technical 'other' teacher }
Confirm-Stage8Reject 'wrong exception grantor' { Assert-Stage8Exception $exception n1 n2 technical why 'someone' }

# Terminal semantics.
$submitted = [pscustomobject] @{ status = 'submitted'; finalization_reason = 'student_submit'; submitted_at = '2026-09-27 10:05:00+00'; finalized_at = '2026-09-27 10:05:00+00'; locked_at = '2026-09-27 10:05:00+00'; deadline_at = '2026-09-27 10:10:00+00' }
Confirm-Stage8Accept { Assert-Stage8TerminalAttempt $submitted student_submit '2026-09-27 10:05:00+00' }
$bad = Copy-Stage8Synthetic $submitted; $bad.finalization_reason = 'task_closed_auto_finalize'
Confirm-Stage8Reject 'wrong terminal reason' { Assert-Stage8TerminalAttempt $bad student_submit '2026-09-27 10:05:00+00' }
$timeout = [pscustomobject] @{ status = 'timed_out_finalized'; finalization_reason = 'timeout_auto_submit'; submitted_at = $null; finalized_at = '2026-09-27 10:10:00+00'; locked_at = '2026-09-27 10:10:00+00'; deadline_at = '2026-09-27 10:10:00+00' }
Confirm-Stage8Accept { Assert-Stage8TerminalAttempt $timeout timeout_auto_submit '' }
$bad = Copy-Stage8Synthetic $timeout; $bad.finalized_at = '2026-09-27 10:11:37+00'; $bad.locked_at = '2026-09-27 10:11:37+00'
Confirm-Stage8Reject 'timeout finalized at Scheduler time instead of deadline' { Assert-Stage8TerminalAttempt $bad timeout_auto_submit '' }
$bad = Copy-Stage8Synthetic $timeout; $bad.submitted_at = '2026-09-27 10:10:00+00'
Confirm-Stage8Reject 'timeout fabricating submitted_at' { Assert-Stage8TerminalAttempt $bad timeout_auto_submit '' }
$closed = [pscustomobject] @{ status = 'submitted'; finalization_reason = 'task_closed_auto_finalize'; submitted_at = $null; finalized_at = '2026-09-27 10:07:00+00'; locked_at = '2026-09-27 10:07:00+00'; deadline_at = '2026-09-27 10:10:00+00' }
Confirm-Stage8Accept { Assert-Stage8TerminalAttempt $closed task_closed_auto_finalize '2026-09-27 10:07:00+00' }
Confirm-Stage8Reject 'Teacher close at the wrong instant' { Assert-Stage8TerminalAttempt $closed task_closed_auto_finalize '2026-09-27 10:08:00+00' }
$late = Copy-Stage8Synthetic $submitted; $late.submitted_at = '2026-09-27 10:10:00+00'; $late.finalized_at = $late.submitted_at; $late.locked_at = $late.submitted_at
Confirm-Stage8Reject 'explicit Submit at the deadline' { Assert-Stage8TerminalAttempt $late student_submit '2026-09-27 10:10:00+00' }

# Answers, scoring and files.
$answer = [pscustomobject] @{ id = 'ans'; attempt_id = 'n1'; question_id = 'q1'; institution_id = 'target'; checking_status = 'pending'; awarded_points = $null; feedback = $null; checked_by_user_id = $null; checked_at = $null; updated_at = '2026-09-27 10:04:00+00' }
$unscored = [pscustomobject] @{ id = 'n1'; earned_points = $null; normalized_score = $null; scoring_completed_at = $null; status = 'submitted'; finalization_reason = 'student_submit'; submitted_at = '2026-09-27 10:05:00+00'; finalized_at = '2026-09-27 10:05:00+00'; locked_at = '2026-09-27 10:05:00+00'; deadline_at = '2026-09-27 10:10:00+00' }
$answerFacts = [pscustomobject] @{ tables = (New-Stage8Tables @{ assessment_attempts = @($unscored); attempt_answers = @($answer); answer_text_values = @([pscustomobject] @{ answer_id = 'ans'; text_value = 'E2E S08 typed' }) }); blobs = @(); public_blobs = @() }
Confirm-Stage8Accept { Assert-Stage8AnswerSet $answerFacts n1 @('q1') }
Confirm-Stage8Reject 'fabricated unanswered answer row' { Assert-Stage8AnswerSet $answerFacts n1 @() }
Confirm-Stage8Accept { Assert-Stage8TypedAnswer $answerFacts $answer short_written @('E2E S08 typed') }
Confirm-Stage8Reject 'wrong typed value' { Assert-Stage8TypedAnswer $answerFacts $answer short_written @('changed') }
foreach ($field in @('earned_points', 'normalized_score', 'scoring_completed_at')) {
    $bad = Copy-Stage8Synthetic $unscored; $bad.$field = 1
    Confirm-Stage8Reject "non-null Attempt $field" { Assert-Stage8Unscored $bad @($answer) }
}
foreach ($field in @('awarded_points', 'feedback', 'checked_by_user_id', 'checked_at', 'checking_status')) {
    $bad = Copy-Stage8Synthetic $answer; $bad.$field = 'unexpected'
    Confirm-Stage8Reject "answer checking $field" { Assert-Stage8Unscored $unscored @($bad) }
}
$fileAttempt = [pscustomobject] @{ id = 'n1'; institution_id = 'target'; student_id = 'a1' }
$expectedFile = [pscustomobject] @{ original_name = 'e2e_s08_answer.pdf'; extension = 'pdf'; mime_type = 'application/pdf'; size_bytes = 100; checksum_sha256 = ('a' * 64) }
$file = [pscustomobject] @{ id = 'f1'; institution_id = 'target'; uploaded_by_user_id = 'a1'; category = 'student_submission'; removed_at = $null; storage_disk = 'local'
    storage_key = 'student-submissions/target/n1/q1/blob.pdf'; original_name = 'e2e_s08_answer.pdf'; extension = 'pdf'; mime_type = 'application/pdf'; size_bytes = 100; checksum_sha256 = ('a' * 64) }
$fileFacts = [pscustomobject] @{ private_disk = 'local'; private_root = '/var/www/html/storage/app/private'; blobs = @([pscustomobject] @{ key = $file.storage_key; size = 100; checksum = ('a' * 64); public_exists = $false }) }
Confirm-Stage8Accept { Assert-Stage8File $fileFacts $file $expectedFile $fileAttempt q1 }
$bad = Copy-Stage8Synthetic $fileFacts; $bad.blobs[0].public_exists = $true
Confirm-Stage8Reject 'public/private file mismatch (public copy)' { Assert-Stage8File $bad $file $expectedFile $fileAttempt q1 }
$bad = Copy-Stage8Synthetic $file; $bad.storage_disk = 'public'
Confirm-Stage8Reject 'public/private file mismatch (public disk)' { Assert-Stage8File $fileFacts $bad $expectedFile $fileAttempt q1 }
$bad = Copy-Stage8Synthetic $file; $bad.storage_key = 'public/n1/blob.pdf'
Confirm-Stage8Reject 'file outside the submission namespace' { Assert-Stage8File $fileFacts $bad $expectedFile $fileAttempt q1 }
$bad = Copy-Stage8Synthetic $file; $bad.uploaded_by_user_id = 'a2'
Confirm-Stage8Reject 'file uploaded by another Student' { Assert-Stage8File $fileFacts $bad $expectedFile $fileAttempt q1 }
$orphanFacts = [pscustomobject] @{ tables = (New-Stage8Tables @{ files = @($file); answer_files = @([pscustomobject] @{ answer_id = 'ans'; file_id = 'f1' }) }); public_blobs = @()
    blobs = @([pscustomobject] @{ key = $file.storage_key }, [pscustomobject] @{ key = 'student-submissions/target/n1/q1/staged-loser.docx' }) }
Confirm-Stage8Reject 'file loser leaving an uncompensated staged blob' { Assert-Stage8NoOrphanBlob $orphanFacts }
$cleanOrphan = Copy-Stage8Synthetic $orphanFacts; $cleanOrphan.blobs = @([pscustomobject] @{ key = $file.storage_key })
Confirm-Stage8Accept { Assert-Stage8NoOrphanBlob $cleanOrphan }

# Idempotency metadata and Start request identity.
$record = [pscustomobject] @{ institution_id = 'target'; user_id = 'a1'; operation = 'student.blitz.attempt.start'; idempotency_key = '08000000-0000-4000-8000-000009000001'
    result_resource_type = 'assessment_attempt'; result_resource_id = 'n1'; response_status = 201; completed_at = 'done'; request_fingerprint = ('b' * 64) }
Confirm-Stage8Accept { Assert-Stage8IdempotencyRecord $record target a1 student.blitz.attempt.start '08000000-0000-4000-8000-000009000001' assessment_attempt n1 201 }
foreach ($field in @('institution_id', 'user_id', 'operation', 'idempotency_key', 'result_resource_type', 'result_resource_id', 'request_fingerprint')) {
    $bad = Copy-Stage8Synthetic $record; $bad.$field = 'wrong'
    Confirm-Stage8Reject "idempotency $field" { Assert-Stage8IdempotencyRecord $bad target a1 student.blitz.attempt.start '08000000-0000-4000-8000-000009000001' assessment_attempt n1 201 }
}
$bad = Copy-Stage8Synthetic $record; $bad.response_status = 200
Confirm-Stage8Reject 'wrong original idempotency status' { Assert-Stage8IdempotencyRecord $bad target a1 student.blitz.attempt.start '08000000-0000-4000-8000-000009000001' assessment_attempt n1 201 }
$bad = Copy-Stage8Synthetic $record; $bad.completed_at = $null
Confirm-Stage8Reject 'incomplete idempotency claim' { Assert-Stage8IdempotencyRecord $bad target a1 student.blitz.attempt.start '08000000-0000-4000-8000-000009000001' assessment_attempt n1 201 }
$key = '08000000-0000-4000-8000-000009000002'
$normal = [pscustomobject] @{ Key = $key; Body = [pscustomobject] @{ intent = 'start_normal' } }
$resume = [pscustomobject] @{ Key = $key; Body = [pscustomobject] @{ intent = 'resume'; attempt_id = '08000000-0000-4000-8000-000003000001' } }
Confirm-Stage8Accept { Assert-Stage8StartRequest $normal }
Confirm-Stage8Accept { Assert-Stage8StartRequest $resume }
Confirm-Stage8Reject 'Start request missing intent body' { Assert-Stage8StartRequest ([pscustomobject] @{ Key = $key; Body = [pscustomobject] @{} }) }
Confirm-Stage8Reject 'Start request with an unknown intent' { Assert-Stage8StartRequest ([pscustomobject] @{ Key = $key; Body = [pscustomobject] @{ intent = 'start' } }) }
Confirm-Stage8Reject 'start_normal carrying attempt_id' { Assert-Stage8StartRequest ([pscustomobject] @{ Key = $key; Body = [pscustomobject] @{ intent = 'start_normal'; attempt_id = '08000000-0000-4000-8000-000003000001' } }) }
Confirm-Stage8Reject 'Resume without attempt_id' { Assert-Stage8StartRequest ([pscustomobject] @{ Key = $key; Body = [pscustomobject] @{ intent = 'resume' } }) }
Confirm-Stage8Accept { Assert-Stage8StartReplay $resume $resume }
$dropped = [pscustomobject] @{ Key = $key; Body = [pscustomobject] @{ intent = 'start_normal' } }
Confirm-Stage8Reject 'Resume replay dropping original attempt_id' { Assert-Stage8StartReplay $resume $dropped }
$changed = [pscustomobject] @{ Key = $key; Body = [pscustomobject] @{ intent = 'resume'; attempt_id = '08000000-0000-4000-8000-000003000002' } }
Confirm-Stage8Reject 'Resume replay changing original attempt_id' { Assert-Stage8StartReplay $resume $changed }
Confirm-Stage8Reject 'replay with another key' { Assert-Stage8StartReplay $resume ([pscustomobject] @{ Key = '08000000-0000-4000-8000-000009000003'; Body = $resume.Body }) }
Confirm-Stage8Accept { Assert-Stage8KeyReuseOutcome ([pscustomobject] @{ StatusCode = 409; Json = [pscustomobject] @{ message = 'Reused.'; code = 'idempotency_key_reused'; errors = [pscustomobject] @{} } }) }
Confirm-Stage8Reject 'key reuse with non-empty errors' { Assert-Stage8KeyReuseOutcome ([pscustomobject] @{ StatusCode = 409; Json = [pscustomobject] @{ message = 'Reused.'; code = 'idempotency_key_reused'; errors = [pscustomobject] @{ key = @('x') } } }) }
Confirm-Stage8Reject 'key reuse with an extra envelope field' { Assert-Stage8KeyReuseOutcome ([pscustomobject] @{ StatusCode = 409; Json = [pscustomobject] @{ message = 'Reused.'; code = 'idempotency_key_reused'; errors = [pscustomobject] @{}; data = 1 } }) }
Confirm-Stage8Reject 'same Start key changing intent returning the stored Attempt' { Assert-Stage8KeyReuseOutcome ([pscustomobject] @{ StatusCode = 200; Json = [pscustomobject] @{ data = [pscustomobject] @{ id = 'n1' } } }) }
Confirm-Stage8Reject 'same Start key changing intent with another conflict' { Assert-Stage8KeyReuseOutcome ([pscustomobject] @{ StatusCode = 409; Json = [pscustomobject] @{ code = 'attempt_not_editable' } }) }

# Stale Resume and no-switch.
$beforeSwitch = New-Stage8HistoryFacts @($first) @()
$afterSwitch = New-Stage8HistoryFacts @($first, $second) @($exception)
Confirm-Stage8Accept { Assert-Stage8NoSwitch $beforeSwitch $beforeSwitch blitz a1 ([pscustomobject] @{ StatusCode = 409; Json = [pscustomobject] @{ code = 'attempt_not_editable' } }) n1 }
Confirm-Stage8Reject 'stale Resume creating replacement #2' { Assert-Stage8NoSwitch $beforeSwitch $afterSwitch blitz a1 $null n1 }
Confirm-Stage8Reject 'stale Resume switching to another Attempt' { Assert-Stage8NoSwitch $beforeSwitch $beforeSwitch blitz a1 ([pscustomobject] @{ StatusCode = 200; Json = [pscustomobject] @{ data = [pscustomobject] @{ id = 'n2' } } }) n1 }

# Stage-level API outcomes.
$pairFacts = [pscustomobject] @{ tables = (New-Stage8Tables @{ topic_result_pairs = @($pair) }) }
$pairChanged = Copy-Stage8Synthetic $pairFacts; $pairChanged.tables.topic_result_pairs[0].blitz_assessment_id = 'selected'
Confirm-Stage8Accept { Assert-Stage8RowsUnchanged $pairFacts $pairFacts @('topic_result_pairs') 'failed designation' }
Confirm-Stage8Reject 'selected-Student official designation mutating the pair' { Assert-Stage8RowsUnchanged $pairFacts $pairChanged @('topic_result_pairs') 'failed designation' }
$pairAfterBlitz = [pscustomobject] @{ locked_at = '2026-09-27 10:01:00+00'; updated_at = '2026-09-27 10:01:00+00'; homework_assessment_id = 'homework'; blitz_assessment_id = 'blitz'; cohort_snapshotted_at = '2026-09-27 10:00:00+00' }
$blitzAttempt = [pscustomobject] @{ started_at = '2026-09-27 10:01:00+00' }
$homeworkFacts = [pscustomobject] @{ tables = (New-Stage8Tables @{ assessment_students = @([pscustomobject] @{ assessment_id = 'homework'; student_id = 'a1' }, [pscustomobject] @{ assessment_id = 'homework'; student_id = 'a2' }) }) }
$okActivation = [pscustomobject] @{ StatusCode = 200 }
$okStart = [pscustomobject] @{ StatusCode = 201; Json = [pscustomobject] @{ data = [pscustomobject] @{ attempt_number = 1 } } }
Confirm-Stage8Accept { Assert-Stage8BlitzFirstHomework $okActivation $okStart $pairAfterBlitz $pairAfterBlitz $blitzAttempt $homeworkFacts homework @('a1', 'a2') }
Confirm-Stage8Reject 'Blitz-first lock rejecting Homework activation' { Assert-Stage8BlitzFirstHomework ([pscustomobject] @{ StatusCode = 409 }) $okStart $pairAfterBlitz $pairAfterBlitz $blitzAttempt $homeworkFacts homework @('a1', 'a2') }
Confirm-Stage8Reject 'Blitz-first lock rejecting Homework Start' { Assert-Stage8BlitzFirstHomework $okActivation ([pscustomobject] @{ StatusCode = 409; Json = [pscustomobject] @{ code = 'business_conflict' } }) $pairAfterBlitz $pairAfterBlitz $blitzAttempt $homeworkFacts homework @('a1', 'a2') }
$churned = Copy-Stage8Synthetic $pairAfterBlitz; $churned.updated_at = '2026-09-27 10:05:00+00'
Confirm-Stage8Reject 'Homework Start churning pair.updated_at' { Assert-Stage8BlitzFirstHomework $okActivation $okStart $pairAfterBlitz $churned $blitzAttempt $homeworkFacts homework @('a1', 'a2') }
Confirm-Stage8Reject 'Homework cohort differing from the Blitz cohort' { Assert-Stage8BlitzFirstHomework $okActivation $okStart $pairAfterBlitz $pairAfterBlitz $blitzAttempt $homeworkFacts homework @('a1') }
$activationBefore = [pscustomobject] @{ tables = (New-Stage8Tables @{ blitz_tasks = @([pscustomobject] @{ assessment_id = 'unset'; status = 'draft' }); topic_result_pairs = @($pair) }) }
Confirm-Stage8Accept { Assert-Stage8NoActivationWrites $activationBefore $activationBefore unset '08000000-0000-4000-8000-000009000009' }
$activationAfter = Copy-Stage8Synthetic $activationBefore; $activationAfter.tables.assessment_students = @([pscustomobject] @{ assessment_id = 'unset'; student_id = 'c1' })
Confirm-Stage8Reject 'null timer-mode activation leaving recipients' { Assert-Stage8NoActivationWrites $activationBefore $activationAfter unset '08000000-0000-4000-8000-000009000009' }
$activationAfter = Copy-Stage8Synthetic $activationBefore; $activationAfter.tables.idempotency_records = @([pscustomobject] @{ idempotency_key = '08000000-0000-4000-8000-000009000009' })
Confirm-Stage8Reject 'null timer-mode activation leaving an idempotency claim' { Assert-Stage8NoActivationWrites $activationBefore $activationAfter unset '08000000-0000-4000-8000-000009000009' }
$activationAfter = Copy-Stage8Synthetic $activationBefore; $activationAfter.tables.blitz_tasks[0].status = 'active'
Confirm-Stage8Reject 'null timer-mode activation changing lifecycle' { Assert-Stage8NoActivationWrites $activationBefore $activationAfter unset '08000000-0000-4000-8000-000009000009' }
$activationAfter = Copy-Stage8Synthetic $activationBefore; $activationAfter.tables.topic_result_pairs[0].cohort_snapshotted_at = 'new'
Confirm-Stage8Reject 'null timer-mode activation writing the cohort' { Assert-Stage8NoActivationWrites $activationBefore $activationAfter unset '08000000-0000-4000-8000-000009000009' }

# Late writes and races.
$lateBefore = [pscustomobject] @{ tables = (New-Stage8Tables @{ attempt_answers = @($answer); answer_text_values = @([pscustomobject] @{ answer_id = 'ans'; text_value = 'frozen' }) }); blobs = @(); public_blobs = @() }
Confirm-Stage8Accept { Assert-Stage8LateWriteUnchanged $lateBefore $lateBefore n1 }
$lateAfter = Copy-Stage8Synthetic $lateBefore; $lateAfter.tables.answer_text_values[0].text_value = 'late'
Confirm-Stage8Reject 'late typed write altering the frozen answer' { Assert-Stage8LateWriteUnchanged $lateBefore $lateAfter n1 }
$fileBefore = [pscustomobject] @{ tables = (New-Stage8Tables @{ attempt_answers = @($answer); answer_files = @([pscustomobject] @{ answer_id = 'ans'; file_id = 'f1' }); files = @($file) }); blobs = @([pscustomobject] @{ key = $file.storage_key; checksum = 'A' }); public_blobs = @() }
Confirm-Stage8Accept { Assert-Stage8LateWriteUnchanged $fileBefore $fileBefore n1 }
$fileAfter = Copy-Stage8Synthetic $fileBefore; $fileAfter.tables.files[0].checksum_sha256 = ('c' * 64)
Confirm-Stage8Reject 'late file write altering the frozen File' { Assert-Stage8LateWriteUnchanged $fileBefore $fileAfter n1 }
$fileAfter = Copy-Stage8Synthetic $fileBefore; $fileAfter.blobs += [pscustomobject] @{ key = 'student-submissions/target/n1/q1/late.docx'; checksum = 'B' }
Confirm-Stage8Reject 'late file write leaving a staged blob' { Assert-Stage8LateWriteUnchanged $fileBefore $fileAfter n1 }
$raceAttempt = [pscustomobject] @{ id = 'n1'; status = 'submitted'; finalization_reason = 'student_submit'; submitted_at = '2026-09-27 10:05:00+00'; finalized_at = '2026-09-27 10:05:00+00'; locked_at = '2026-09-27 10:05:00+00'; deadline_at = '2026-09-27 11:00:00+00' }
$raceFacts = [pscustomobject] @{ tables = (New-Stage8Tables @{ assessment_attempts = @($raceAttempt); attempt_answers = @($answer) }); blobs = @(); public_blobs = @() }
$ok = [pscustomobject] @{ StatusCode = 200; Json = $null }
$notEditable = [pscustomobject] @{ StatusCode = 409; Json = [pscustomobject] @{ code = 'attempt_not_editable' } }
if ((Assert-Stage8RaceBranch $ok $ok $raceFacts n1 q1 written written A) -cne 'write_first' -or (Assert-Stage8RaceBranch $notEditable $ok $raceFacts n1 q1 prior prior B) -cne 'submit_first') { throw 'integration-harness defect: Oracle verifier rejected a valid race branch.' }
$script:checks += 2
Confirm-Stage8Reject 'write 200 but persisted pre-race value' { Assert-Stage8RaceBranch $ok $ok $raceFacts n1 q1 prior prior A }
Confirm-Stage8Reject 'write 409 but persisted raced value' { Assert-Stage8RaceBranch $notEditable $ok $raceFacts n1 q1 written written B }
Confirm-Stage8Reject 'race value matching neither branch' { Assert-Stage8RaceBranch $ok $ok $raceFacts n1 q1 other other A }
Confirm-Stage8Reject 'race write with another conflict code' { Assert-Stage8RaceBranch ([pscustomobject] @{ StatusCode = 409; Json = [pscustomobject] @{ code = 'blitz_time_expired' } }) $ok $raceFacts n1 q1 prior prior B }
Confirm-Stage8Reject 'race Submit failing' { Assert-Stage8RaceBranch $ok ([pscustomobject] @{ StatusCode = 409; Json = $null }) $raceFacts n1 q1 written written A }
$postFreeze = Copy-Stage8Synthetic $raceFacts; $postFreeze.tables.attempt_answers[0].updated_at = '2026-09-27 10:06:00+00'
Confirm-Stage8Reject 'answer write committed after the Submit freeze (later second)' { Assert-Stage8RaceBranch $ok $ok $postFreeze n1 q1 written written A }
Confirm-Stage8Reject 'write 200 persisted after a Submit whose frozen snapshot shows the prior value (same second)' { Assert-Stage8RaceBranch $ok $ok $raceFacts n1 q1 written prior A }
Confirm-Stage8Reject 'Submit-first branch whose frozen snapshot differs' { Assert-Stage8RaceBranch $notEditable $ok $raceFacts n1 q1 prior written B }
Confirm-Stage8Reject 'write won although the Submit was queued first' { Assert-Stage8RaceBranch $ok $ok $raceFacts n1 q1 written written B }
Confirm-Stage8Reject 'Submit won although the write was queued first' { Assert-Stage8RaceBranch $notEditable $ok $raceFacts n1 q1 prior prior A }

# Concurrency evidence is re-checked here as part of the race oracle.
$attemptId = '08000000-0000-4000-8000-000003000099'
$probeContext = @{ BlockerPid = 77; ObserverPid = 88; ApplicationAddress = '172.19.0.3'; Database = 'testlabuz_testing'; WorkerCount = 4; LockedAttemptId = $attemptId; ExpectedAttemptId = $attemptId }
$sample = [pscustomobject] @{ observed_at = 'x'; sessions = @(
        [pscustomobject] @{ pid = 77; datname = 'testlabuz_testing'; client_addr = '172.19.0.3'; state = 'idle in transaction'; wait_event_type = 'Client'; blockers = @() },
        [pscustomobject] @{ pid = 101; datname = 'testlabuz_testing'; client_addr = '172.19.0.3'; state = 'active'; wait_event_type = 'Lock'; blockers = @(77) },
        [pscustomobject] @{ pid = 102; datname = 'testlabuz_testing'; client_addr = '172.19.0.3'; state = 'active'; wait_event_type = 'Lock'; blockers = @(101) })
    waiting_locks = @([pscustomobject] @{ pid = 101; locktype = 'transactionid'; relation = $null }, [pscustomobject] @{ pid = 102; locktype = 'tuple'; relation = 'assessment_attempts' }) }
$evidence = Get-Stage8OverlapEvidence -Samples @($sample) @probeContext
if (-not $evidence.overlap_observed) { throw 'integration-harness defect: Oracle verifier rejected valid overlap evidence.' }
$script:checks++
function Test-Stage8Overlap { param([string] $Label, $Samples, [hashtable] $Overrides = @{})
    $arguments = $probeContext.Clone(); foreach ($k in $Overrides.Keys) { $arguments[$k] = $Overrides[$k] }
    Confirm-Stage8Reject $Label { $result = Get-Stage8OverlapEvidence -Samples $Samples @arguments; if (-not $result.overlap_observed) { throw 'incomplete' } }
}
$single = Copy-Stage8Synthetic $sample; $single.sessions = @($single.sessions[0], $single.sessions[1])
Test-Stage8Overlap 'concurrency evidence with fewer than 2 application waiters' @($single)
$apart1 = Copy-Stage8Synthetic $single
$apart2 = Copy-Stage8Synthetic $sample; $apart2.sessions = @($apart2.sessions[0], $apart2.sessions[2]); $apart2.sessions[1].blockers = @(77)
Test-Stage8Overlap 'concurrency waiters never simultaneous' @($apart1, $apart2)
$counted = Copy-Stage8Synthetic $sample; $counted.sessions[2].pid = 88; $counted.waiting_locks[1].pid = 88
Test-Stage8Overlap 'concurrency evidence counting the observer' @($counted)
$unrelated = Copy-Stage8Synthetic $sample; $unrelated.sessions[2].client_addr = '172.19.0.7'
Test-Stage8Overlap 'concurrency evidence counting an unrelated session' @($unrelated)
$noLock = Copy-Stage8Synthetic $sample; $noLock.sessions[1].wait_event_type = 'IPC'
Test-Stage8Overlap 'concurrency evidence without wait_event_type Lock' @($noLock)
Test-Stage8Overlap 'concurrency evidence with a single worker' @($sample) @{ WorkerCount = 1 }
Confirm-Stage8Reject '47A.7/47A.8 marked PASS with overlap_observed=false' {
    Assert-Stage8RaceVerdict -Evidence (Get-Stage8OverlapEvidence -Samples @($single) @probeContext) -Events @('blocker_locked', 'requests_started', 'blocker_released') -MarkedPass $true
}
foreach ($value in @($null, '', '1', '8')) { Confirm-Stage8Reject "PHP_CLI_SERVER_WORKERS=$value" { Assert-Stage8WorkerEnvironment -Value $value } }

# Global Scheduler guard.
$owners = [pscustomobject] @{ scheduler = 'target'; other = 'target'; foreignowned = 'foreign' }
$schedulerOnly = [pscustomobject] @{ candidates = @([pscustomobject] @{ institution_id = 'target'; assessment_id = 'scheduler' })
    superset = @([pscustomobject] @{ institution_id = 'target'; assessment_id = 'scheduler'; attempt_id = 'due'; due = $true }, [pscustomobject] @{ institution_id = 'target'; assessment_id = 'scheduler'; attempt_id = 'future'; due = $false })
    owners = $owners; scheduler = [pscustomobject] @{ assessment_id = 'scheduler'; institution_id = 'target' } }
Confirm-Stage8Accept { Assert-Stage8SchedulerSafeToRun -Facts $schedulerOnly -Invocation First }
$empty = Copy-Stage8Synthetic $schedulerOnly; $empty.candidates = @(); $empty.superset = @($empty.superset[1])
Confirm-Stage8Accept { Assert-Stage8SchedulerSafeToRun -Facts $empty -Invocation Second }
$bad = Copy-Stage8Synthetic $schedulerOnly; $bad.candidates += [pscustomobject] @{ institution_id = 'target'; assessment_id = 'not-manifest' }
Confirm-Stage8Reject 'Scheduler candidate outside the manifest' { Assert-Stage8SchedulerSafeToRun -Facts $bad -Invocation First }
$bad = Copy-Stage8Synthetic $schedulerOnly; $bad.candidates[0].institution_id = 'foreign'
Confirm-Stage8Reject 'manifest Scheduler assessment with the wrong Institution' { Assert-Stage8SchedulerSafeToRun -Facts $bad -Invocation First }
$bad = Copy-Stage8Synthetic $empty; $bad.superset += [pscustomobject] @{ institution_id = 'target'; assessment_id = 'not-manifest'; attempt_id = 'x'; due = $false }
Confirm-Stage8Reject 'TOCTOU superset with a future non-manifest active in-progress Attempt' { Assert-Stage8SchedulerSafeToRun -Facts $bad -Invocation Second }
$bad = Copy-Stage8Synthetic $schedulerOnly; $bad.candidates += [pscustomobject] @{ institution_id = 'target'; assessment_id = 'other' }
Confirm-Stage8Reject 'first invocation with an extra manifest candidate' { Assert-Stage8SchedulerSafeToRun -Facts $bad -Invocation First }
Confirm-Stage8Reject 'second invocation with a remaining candidate' { Assert-Stage8SchedulerSafeToRun -Facts $schedulerOnly -Invocation Second }
$bad = Copy-Stage8Synthetic $schedulerOnly; $bad.superset = @($bad.superset[0])
Confirm-Stage8Reject 'first invocation without a future in-progress Attempt' { Assert-Stage8SchedulerSafeToRun -Facts $bad -Invocation First }
$sentinel = [pscustomobject] @{ rows = [pscustomobject] @{ blitz_tasks = @([pscustomobject] @{ assessment_id = 's'; status = 'closed' }) }; blob = [pscustomobject] @{ key = 'k'; sha256 = 'h' } }
$script:invocations = 0
$invoker = { $script:invocations++; [pscustomobject] @{ ExitCode = 0; Output = 'Candidates: 1; finalized attempts: 1; failures: 0.' } }
foreach ($unsafe in @(
        @{ Label = 'guard invoking the command after a non-manifest candidate'; Facts = $(Copy-Stage8Synthetic $schedulerOnly | ForEach-Object { $_.candidates += [pscustomobject] @{ institution_id = 'target'; assessment_id = 'not-manifest' }; $_ }) },
        @{ Label = 'guard invoking the command after a TOCTOU non-manifest Attempt'; Facts = $(Copy-Stage8Synthetic $schedulerOnly | ForEach-Object { $_.superset += [pscustomobject] @{ institution_id = 'target'; assessment_id = 'not-manifest'; attempt_id = 'x'; due = $false }; $_ }) })) {
    $facts = $unsafe.Facts
    Confirm-Stage8Reject $unsafe.Label { Invoke-Stage8GuardedScheduler -Invocation First -FactsProvider { $facts } -SentinelProvider { $sentinel } -Invoker $invoker | Out-Null }
    if ($script:invocations -ne 0) { throw 'integration-harness defect: Scheduler command ran after the guard rejected its facts.' }
}
$result = Invoke-Stage8GuardedScheduler -Invocation First -FactsProvider { $schedulerOnly } -SentinelProvider { $sentinel } -Invoker $invoker
if ($script:invocations -ne 1 -or $result.Counts.candidates -ne 1) { throw 'integration-harness defect: Guarded Scheduler did not run on a valid fact set.' }
$script:checks++
$script:sentinelCalls = 0
$changing = { $script:sentinelCalls++; if ($script:sentinelCalls -eq 1) { $sentinel } else { [pscustomobject] @{ rows = [pscustomobject] @{ blitz_tasks = @([pscustomobject] @{ assessment_id = 's'; status = 'active' }) }; blob = $sentinel.blob } } }
Confirm-Stage8Reject 'unrelated Scheduler sentinel changed after the command' { Invoke-Stage8GuardedScheduler -Invocation First -FactsProvider { $schedulerOnly } -SentinelProvider $changing -Invoker $invoker | Out-Null }
Confirm-Stage8Reject 'Scheduler output count differing from the guarded set' { Invoke-Stage8GuardedScheduler -Invocation First -FactsProvider { $schedulerOnly } -SentinelProvider { $sentinel } -Invoker { [pscustomobject] @{ ExitCode = 0; Output = 'Candidates: 2; finalized attempts: 2; failures: 0.' } } | Out-Null }
Confirm-Stage8Reject 'first Scheduler invocation finalizing fewer due Attempts' { Invoke-Stage8GuardedScheduler -Invocation First -FactsProvider { $schedulerOnly } -SentinelProvider { $sentinel } -Invoker { [pscustomobject] @{ ExitCode = 0; Output = 'Candidates: 1; finalized attempts: 0; failures: 0.' } } | Out-Null }
Confirm-Stage8Reject 'second Scheduler invocation finalizing again' { Invoke-Stage8GuardedScheduler -Invocation Second -FactsProvider { $empty } -SentinelProvider { $sentinel } -Invoker { [pscustomobject] @{ ExitCode = 0; Output = 'Candidates: 0; finalized attempts: 1; failures: 0.' } } | Out-Null }
Confirm-Stage8Reject 'Scheduler failures reported' { Invoke-Stage8GuardedScheduler -Invocation First -FactsProvider { $schedulerOnly } -SentinelProvider { $sentinel } -Invoker { [pscustomobject] @{ ExitCode = 1; Output = 'Candidates: 1; finalized attempts: 0; failures: 1.' } } | Out-Null }

# Cleanup scope, disk identity and runner order.
$cleanFacts = [pscustomobject] @{ tables = (New-Stage8Tables); blobs = @(); public_blobs = @(); sentinels = $sentinel }
Confirm-Stage8Accept { Assert-Stage8CleanupFacts $cleanFacts $sentinel }
$bad = Copy-Stage8Synthetic $cleanFacts; $bad.sentinels.blob.sha256 = 'changed'
Confirm-Stage8Reject 'cleanup touching the unrelated private-file sentinel' { Assert-Stage8CleanupFacts $bad $sentinel }
$bad = Copy-Stage8Synthetic $cleanFacts; $bad.sentinels.rows.blitz_tasks = @()
Confirm-Stage8Reject 'prior-manifest cleanup deleting a non-manifest DB sentinel' { Assert-Stage8CleanupFacts $bad $sentinel }
$bad = Copy-Stage8Synthetic $cleanFacts; $bad.tables.assessment_attempts = @([pscustomobject] @{ id = 'left' })
Confirm-Stage8Reject 'cleanup leaving an owned Attempt' { Assert-Stage8CleanupFacts $bad $sentinel }
$bad = Copy-Stage8Synthetic $cleanFacts; $bad.blobs = @([pscustomobject] @{ key = 'left' })
Confirm-Stage8Reject 'cleanup leaving an owned blob' { Assert-Stage8CleanupFacts $bad $sentinel }
Confirm-Stage8Accept { Assert-Stage8CleanupDiskIdentity ([pscustomobject] @{ cleaned = $true; disk = 'local'; root = '/var/www/html/storage/app/private' }) }
Confirm-Stage8Reject 'prior-manifest cleanup on the isolated seeder-test disk' { Assert-Stage8CleanupDiskIdentity ([pscustomobject] @{ cleaned = $true; disk = 'stage8_seeder_test'; root = '/var/www/html/storage/app/private/e2e-s08-seeder-test-42' }) }
Confirm-Stage8Reject 'prior-manifest cleanup not confirmed' { Assert-Stage8CleanupDiskIdentity ([pscustomobject] @{ cleaned = $false; disk = 'local'; root = '/var/www/html/storage/app/private' }) }
$plan = @('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'seeder_test', 'fresh_seed', 'baseline_oracle', 'windows_flow', 'api_scenarios', 'guarded_scheduler', 'restart', 'final_cleanup')
Confirm-Stage8Accept { Assert-Stage8RunnerPlan $plan }
$tail = @('windows_flow', 'api_scenarios', 'guarded_scheduler', 'restart', 'final_cleanup')
Confirm-Stage8Reject 'runner plan with Stage8E2eSeederTest before prior-manifest cleanup' { Assert-Stage8RunnerPlan (@('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'seeder_test', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'fresh_seed', 'baseline_oracle') + $tail) }
Confirm-Stage8Reject 'runner plan with fresh seed before prior-cleanup verification' { Assert-Stage8RunnerPlan (@('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'fresh_seed', 'prior_cleanup_oracle', 'seeder_test', 'baseline_oracle') + $tail) }
Confirm-Stage8Reject 'runner plan with baseline before prior-cleanup verification' { Assert-Stage8RunnerPlan (@('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'baseline_oracle', 'prior_cleanup_oracle', 'seeder_test', 'fresh_seed') + $tail) }
Confirm-Stage8Reject 'runner plan with the Scheduler before the baseline' { Assert-Stage8RunnerPlan @('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'seeder_test', 'fresh_seed', 'guarded_scheduler', 'baseline_oracle') }
Confirm-Stage8Reject 'retry plan requiring the previous final cleanup' { Assert-Stage8RunnerPlan (@('requires_previous_cleanup') + $plan) }
Confirm-Stage8Reject 'runner plan without prior-manifest cleanup' { Assert-Stage8RunnerPlan @('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'seeder_test', 'fresh_seed', 'baseline_oracle') }

$script:clockCalls = 0
function Invoke-Stage8ContainerPhp {
    param([string] $Program, [string] $InputJson, [string] $BackendContainerName)
    $script:clockCalls++
    [pscustomobject] @{ now = $(if ($script:clockCalls -eq 1) { '2026-09-27T00:00:00Z' } else { '2026-09-27T00:00:01Z' }) }
}
Wait-Stage8TimestampBoundary '2026-09-27T00:00:00Z'
if ($script:clockCalls -ne 2) { throw 'integration-harness defect: Timestamp boundary did not condition-wait for a later server second.' }
$script:checks++
Write-Output "Stage8Oracle pure verifier: PASS ($script:checks checks; no DB, API or Scheduler execution)."
