param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage9_oracle.ps1')

$script:checks = 0
function Confirm-Stage9Reject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "integration-harness defect: Oracle verifier accepted $Label." }
    $script:checks++
}
function Confirm-Stage9Accept { param([scriptblock] $Check) & $Check | Out-Null; $script:checks++ }
function Copy-Stage9Synthetic { param($Value) ConvertTo-Json -InputObject $Value -Depth 50 -Compress | ConvertFrom-Json }
function New-Stage9Facts {
    param([hashtable] $Rows = @{}, $Blobs = @(), $Manifest = $null)
    $tables = [ordered] @{}
    foreach ($table in @('institutions', 'users', 'groups', 'topics', 'assessments', 'blitz_tasks', 'homework_assignments', 'assessment_students', 'questions', 'topic_result_pairs',
            'assessment_attempts', 'blitz_attempt_exceptions', 'official_task_scores', 'attempt_answers', 'answer_choice_selections', 'answer_text_values', 'answer_boolean_values',
            'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files', 'files', 'idempotency_records', 'personal_access_tokens')) {
        $tables[$table] = if ($Rows.ContainsKey($table)) { @($Rows[$table]) } else { @() }
    }
    # Built directly: a Windows PowerShell JSON round trip turns nested empty arrays into objects.
    [pscustomobject] @{ manifest = $Manifest; tables = [pscustomobject] $tables; blobs = @($Blobs); public_blobs = @(); private_disk = 'local'; private_root = '/var/www/html/storage/app/private'; sentinels = $null }
}

# ---------------------------------------------------------------- answers and Attempt scores
$answer = [pscustomobject] @{ id = 'ans1'; institution_id = 'inst'; attempt_id = 'att1'; question_id = 'q1'; checking_status = 'auto_checked'; awarded_points = '2.00000000'; feedback = $null
    checked_by_user_id = $null; checked_at = '2026-10-02 12:00:00+00'; created_at = '2026-10-02 11:59:00+00'; updated_at = '2026-10-02 11:59:00+00' }
$facts = New-Stage9Facts @{ attempt_answers = @($answer) }
Confirm-Stage9Accept { Assert-Stage9Answer $facts att1 q1 auto_checked '2.00000000' $null $null 'auto' }
Confirm-Stage9Reject 'wrong awarded points' { Assert-Stage9Answer $facts att1 q1 auto_checked '2.00000001' $null $null 'auto' }
Confirm-Stage9Reject 'equal value in another decimal form' { Assert-Stage9Answer $facts att1 q1 auto_checked '2.0' $null $null 'auto' }
Confirm-Stage9Reject 'wrong checking status' { Assert-Stage9Answer $facts att1 q1 teacher_checked '2.00000000' $null $null 'auto' }
Confirm-Stage9Reject 'missing answer row' { Assert-Stage9Answer $facts att1 q2 auto_checked '2.00000000' $null $null 'auto' }
$bad = Copy-Stage9Synthetic $answer; $bad.checked_by_user_id = 'teacher'
Confirm-Stage9Reject 'automatic answer naming a reviewer' { Assert-Stage9Answer (New-Stage9Facts @{ attempt_answers = @($bad) }) att1 q1 auto_checked '2.00000000' $null 'teacher' 'auto' }
$bad = Copy-Stage9Synthetic $answer; $bad.checked_at = $null
Confirm-Stage9Reject 'checked answer without checked_at' { Assert-Stage9Answer (New-Stage9Facts @{ attempt_answers = @($bad) }) att1 q1 auto_checked '2.00000000' $null $null 'auto' }
$waiting = Copy-Stage9Synthetic $answer; $waiting.checking_status = 'waiting_for_teacher_review'; $waiting.awarded_points = $null; $waiting.checked_at = $null
Confirm-Stage9Accept { Assert-Stage9Answer (New-Stage9Facts @{ attempt_answers = @($waiting) }) att1 q1 waiting_for_teacher_review $null $null $null 'waiting' }
$bad = Copy-Stage9Synthetic $waiting; $bad.checked_at = '2026-10-02 12:00:00+00'
Confirm-Stage9Reject 'waiting answer with checked_at' { Assert-Stage9Answer (New-Stage9Facts @{ attempt_answers = @($bad) }) att1 q1 waiting_for_teacher_review $null $null $null 'waiting' }
$reviewed = Copy-Stage9Synthetic $answer; $reviewed.checking_status = 'teacher_checked'; $reviewed.awarded_points = '4.50000000'; $reviewed.feedback = 'Clear reasoning.'; $reviewed.checked_by_user_id = 'teacher'
Confirm-Stage9Accept { Assert-Stage9Answer (New-Stage9Facts @{ attempt_answers = @($reviewed) }) att1 q1 teacher_checked '4.50000000' 'Clear reasoning.' teacher 'reviewed' }
Confirm-Stage9Reject 'wrong feedback' { Assert-Stage9Answer (New-Stage9Facts @{ attempt_answers = @($reviewed) }) att1 q1 teacher_checked '4.50000000' 'Clear reasoning' teacher 'reviewed' }
Confirm-Stage9Reject 'wrong reviewer' { Assert-Stage9Answer (New-Stage9Facts @{ attempt_answers = @($reviewed) }) att1 q1 teacher_checked '4.50000000' 'Clear reasoning.' peer 'reviewed' }

$attempt = [pscustomobject] @{ id = 'att1'; status = 'checked'; earned_points = '16.75000000'; normalized_score = '83.75000000'; scoring_completed_at = '2026-10-02 12:00:00+00' }
Confirm-Stage9Accept { Assert-Stage9AttemptScore $attempt checked '16.75000000' '83.75000000' 'checked' }
Confirm-Stage9Reject 'wrong normalized score' { Assert-Stage9AttemptScore $attempt checked '16.75000000' '83.80000000' 'checked' }
Confirm-Stage9Reject 'unrounded sum instead of stored values' { Assert-Stage9AttemptScore ([pscustomobject] @{ status = 'checked'; earned_points = '1.66666666'; normalized_score = '55.55555556'; scoring_completed_at = 'x' }) checked '1.66666666' '55.55555533' 'sum' }
$bad = Copy-Stage9Synthetic $attempt; $bad.scoring_completed_at = $null
Confirm-Stage9Reject 'checked Attempt without scoring time' { Assert-Stage9AttemptScore $bad checked '16.75000000' '83.75000000' 'checked' }
Confirm-Stage9Reject 'waiting Attempt with a score' { Assert-Stage9AttemptScore ([pscustomobject] @{ status = 'waiting_for_teacher_review'; earned_points = '1.00000000'; normalized_score = '5.00000000'; scoring_completed_at = $null }) waiting_for_teacher_review $null $null 'waiting' }

# ---------------------------------------------------------------- official rows
$official = [pscustomobject] @{ id = 'off1'; institution_id = 'inst'; assessment_id = 'hw'; student_id = 'stu'; official_attempt_id = 'att1'; normalized_score = '83.75000000'
    selection_policy_code = 'highest_valid_completed'; selected_by_user_id = $null; selected_at = '2026-10-02 12:00:00+00' }
$facts = New-Stage9Facts @{ official_task_scores = @($official) }
Confirm-Stage9Accept { Assert-Stage9OfficialRow $facts hw stu att1 '83.75000000' highest_valid_completed 'ready' }
Confirm-Stage9Reject 'official row on another Attempt' { Assert-Stage9OfficialRow $facts hw stu att2 '83.75000000' highest_valid_completed 'ready' }
Confirm-Stage9Reject 'official row with another policy' { Assert-Stage9OfficialRow $facts hw stu att1 '83.75000000' valid_normal_blitz 'ready' }
Confirm-Stage9Reject 'official row with another score' { Assert-Stage9OfficialRow $facts hw stu att1 '83.80000000' highest_valid_completed 'ready' }
$bad = Copy-Stage9Synthetic $official; $bad.selected_by_user_id = 'teacher'
Confirm-Stage9Reject 'official row selected by a user' { Assert-Stage9OfficialRow (New-Stage9Facts @{ official_task_scores = @($bad) }) hw stu att1 '83.75000000' highest_valid_completed 'ready' }
Confirm-Stage9Reject 'missing official row' { Assert-Stage9OfficialRow (New-Stage9Facts) hw stu att1 '83.75000000' highest_valid_completed 'ready' }
Confirm-Stage9Accept { Assert-Stage9NoOfficialRow (New-Stage9Facts) hw stu 'none' }
Confirm-Stage9Reject 'withdrawn official row still present' { Assert-Stage9NoOfficialRow $facts hw stu 'withdrawn' }

# ---------------------------------------------------------------- freeze and answer timestamps
$frozenAttempt = [pscustomobject] @{ id = 'att1'; institution_id = 'inst'; status = 'submitted'; started_at = '2026-10-02 11:00:00+00'; deadline_at = $null; submitted_at = '2026-10-02 11:05:00+00'
    finalized_at = '2026-10-02 11:05:00+00'; finalization_reason = 'student_submit'; locked_at = '2026-10-02 11:05:00+00'; possible_points = '20.000000'; attempt_number = 1 }
$text = [pscustomobject] @{ answer_id = 'ans1'; institution_id = 'inst'; text_value = 'Answer'; created_at = '2026-10-02 11:59:00+00'; updated_at = '2026-10-02 11:59:00+00' }
$before = New-Stage9Facts @{ assessment_attempts = @($frozenAttempt); attempt_answers = @($answer); answer_text_values = @($text) }
$checkedAttempt = Copy-Stage9Synthetic $frozenAttempt; $checkedAttempt.status = 'checked'
$after = New-Stage9Facts @{ assessment_attempts = @($checkedAttempt); attempt_answers = @($reviewed); answer_text_values = @($text) }
Confirm-Stage9Accept { Assert-Stage9FreezeAndAnswersKept $before $after @('att1') 'checking' }
$bad = Copy-Stage9Synthetic $checkedAttempt; $bad.finalized_at = '2026-10-02 12:00:00+00'
Confirm-Stage9Reject 'checking rewriting finalized_at' { Assert-Stage9FreezeAndAnswersKept $before (New-Stage9Facts @{ assessment_attempts = @($bad); attempt_answers = @($reviewed); answer_text_values = @($text) }) @('att1') 'checking' }
$bad = Copy-Stage9Synthetic $checkedAttempt; $bad.finalization_reason = 'timeout_auto_submit'
Confirm-Stage9Reject 'checking rewriting the finalization reason' { Assert-Stage9FreezeAndAnswersKept $before (New-Stage9Facts @{ assessment_attempts = @($bad); attempt_answers = @($reviewed); answer_text_values = @($text) }) @('att1') 'checking' }
$bumped = Copy-Stage9Synthetic $reviewed; $bumped.updated_at = '2026-10-02 12:00:00+00'
Confirm-Stage9Reject 'review bumping attempt_answers.updated_at' { Assert-Stage9FreezeAndAnswersKept $before (New-Stage9Facts @{ assessment_attempts = @($checkedAttempt); attempt_answers = @($bumped); answer_text_values = @($text) }) @('att1') 'review' }
$changedText = Copy-Stage9Synthetic $text; $changedText.text_value = 'Changed'
Confirm-Stage9Reject 'review changing the Student answer value' { Assert-Stage9FreezeAndAnswersKept $before (New-Stage9Facts @{ assessment_attempts = @($checkedAttempt); attempt_answers = @($reviewed); answer_text_values = @($changedText) }) @('att1') 'review' }

# ---------------------------------------------------------------- changed-table scope and sessions
$user = [pscustomobject] @{ id = 'teacher'; institution_id = 'inst'; role = 'teacher'; full_name = 'E2E S09 Teacher'; last_login_at = $null; updated_at = '2020-01-01 00:00:00+00' }
$loggedIn = Copy-Stage9Synthetic $user; $loggedIn.last_login_at = '2026-10-02 12:00:00+00'; $loggedIn.updated_at = '2026-10-02 12:00:00+00'
$renamed = Copy-Stage9Synthetic $loggedIn; $renamed.full_name = 'Someone else'
Confirm-Stage9Accept { Assert-Stage9OnlySessionsChanged (New-Stage9Facts @{ users = @($user) }) (New-Stage9Facts @{ users = @($loggedIn) }) 'sign-in' }
Confirm-Stage9Reject 'a user change beyond the sign-in' { Assert-Stage9OnlySessionsChanged (New-Stage9Facts @{ users = @($user) }) (New-Stage9Facts @{ users = @($renamed) }) 'sign-in' }
$homeworkRow = [pscustomobject] @{ assessment_id = 'hw'; institution_id = 'inst'; review_due_at = $null }
$homeworkChanged = Copy-Stage9Synthetic $homeworkRow; $homeworkChanged.review_due_at = '2026-10-09 13:00:00+00'
Confirm-Stage9Accept { Assert-Stage9OnlyTablesChanged (New-Stage9Facts @{ homework_assignments = @($homeworkRow) }) (New-Stage9Facts @{ homework_assignments = @($homeworkChanged) }) @('homework_assignments') 'deadline' }
Confirm-Stage9Reject 'an undeclared table change' { Assert-Stage9OnlyTablesChanged (New-Stage9Facts @{ homework_assignments = @($homeworkRow) }) (New-Stage9Facts @{ homework_assignments = @($homeworkChanged) }) @('attempt_answers') 'deadline' }
Confirm-Stage9Reject 'a private blob change' { Assert-Stage9OnlyTablesChanged (New-Stage9Facts) (New-Stage9Facts -Blobs @([pscustomobject] @{ key = 'k'; size = 1; checksum = 'c'; public_exists = $false })) @() 'blob' }

# ---------------------------------------------------------------- Tenant rows
$manifest = [pscustomobject] @{ institutions = [pscustomobject] @{ auto = 'inst'; manual = 'other' } }
$tenantRows = @{
    institutions = @([pscustomobject] @{ id = 'inst'; institution_id = $null }, [pscustomobject] @{ id = 'other'; institution_id = $null })
    users = @([pscustomobject] @{ id = 'stu'; institution_id = 'inst'; role = 'student' }, [pscustomobject] @{ id = 'teacher'; institution_id = 'inst'; role = 'teacher' }, [pscustomobject] @{ id = 'foreign'; institution_id = 'other'; role = 'teacher' })
    assessments = @([pscustomobject] @{ id = 'hw'; institution_id = 'inst'; topic_id = 'topic'; teacher_id = 'teacher' })
    topics = @([pscustomobject] @{ id = 'topic'; institution_id = 'inst'; group_id = 'group'; teacher_id = 'teacher' })
    groups = @([pscustomobject] @{ id = 'group'; institution_id = 'inst' })
    assessment_attempts = @([pscustomobject] @{ id = 'att1'; institution_id = 'inst'; assessment_id = 'hw'; assessment_student_id = 'rec'; student_id = 'stu' })
    assessment_students = @([pscustomobject] @{ id = 'rec'; institution_id = 'inst'; assessment_id = 'hw'; student_id = 'stu' })
    official_task_scores = @($official)
    attempt_answers = @($reviewed)
    questions = @([pscustomobject] @{ id = 'q1'; institution_id = 'inst'; assessment_id = 'hw' })
}
Confirm-Stage9Accept { Assert-Stage9TenantRows (New-Stage9Facts $tenantRows -Manifest $manifest) }
$foreignOfficial = Copy-Stage9Synthetic $official; $foreignOfficial.institution_id = 'other'
$rows = $tenantRows.Clone(); $rows.official_task_scores = @($foreignOfficial)
Confirm-Stage9Reject 'cross-Tenant official row' { Assert-Stage9TenantRows (New-Stage9Facts $rows -Manifest $manifest) }
$foreignReview = Copy-Stage9Synthetic $reviewed; $foreignReview.checked_by_user_id = 'foreign'
$rows = $tenantRows.Clone(); $rows.attempt_answers = @($foreignReview)
Confirm-Stage9Reject 'answer reviewed by a foreign Teacher' { Assert-Stage9TenantRows (New-Stage9Facts $rows -Manifest $manifest) }
$studentReview = Copy-Stage9Synthetic $reviewed; $studentReview.checked_by_user_id = 'stu'
$rows = $tenantRows.Clone(); $rows.attempt_answers = @($studentReview)
Confirm-Stage9Reject 'answer reviewed by a Student' { Assert-Stage9TenantRows (New-Stage9Facts $rows -Manifest $manifest) }

# ---------------------------------------------------------------- blobs, idempotency, cleanup, checkout, plan
$file = [pscustomobject] @{ id = 'file1'; storage_key = 'student-submissions/inst/att1/q5/x.pdf' }
$link = [pscustomobject] @{ id = 'link1'; answer_id = 'ans1'; file_id = 'file1' }
$blob = [pscustomobject] @{ key = 'student-submissions/inst/att1/q5/x.pdf'; size = 10; checksum = 'c'; public_exists = $false }
Confirm-Stage9Accept { Assert-Stage9NoOrphanBlob (New-Stage9Facts @{ files = @($file); answer_files = @($link) } -Blobs @($blob)) }
Confirm-Stage9Reject 'orphan private blob' { Assert-Stage9NoOrphanBlob (New-Stage9Facts @{ files = @($file); answer_files = @($link) } -Blobs @($blob, [pscustomobject] @{ key = 'student-submissions/inst/att1/q5/y.pdf'; size = 1; checksum = 'd'; public_exists = $false })) }
Confirm-Stage9Reject 'unlinked File row' { Assert-Stage9NoOrphanBlob (New-Stage9Facts @{ files = @($file) } -Blobs @($blob)) }
$record = [pscustomobject] @{ institution_id = 'inst'; user_id = 'teacher'; operation = 'teacher.blitz.attempt_exception.grant'; idempotency_key = '09000000-0000-4000-8000-000009000001'
    result_resource_type = 'blitz_attempt_exception'; result_resource_id = 'exc1'; response_status = 201; completed_at = '2026-10-02 12:00:00+00'; request_fingerprint = ('a' * 64) }
Confirm-Stage9Accept { Assert-Stage9IdempotencyRecord $record inst teacher teacher.blitz.attempt_exception.grant '09000000-0000-4000-8000-000009000001' blitz_attempt_exception exc1 201 }
Confirm-Stage9Reject 'grant record on another resource' { Assert-Stage9IdempotencyRecord $record inst teacher teacher.blitz.attempt_exception.grant '09000000-0000-4000-8000-000009000001' blitz_attempt_exception exc2 201 }
$incomplete = Copy-Stage9Synthetic $record; $incomplete.completed_at = $null
Confirm-Stage9Reject 'incomplete grant record' { Assert-Stage9IdempotencyRecord $incomplete inst teacher teacher.blitz.attempt_exception.grant '09000000-0000-4000-8000-000009000001' blitz_attempt_exception exc1 201 }
Confirm-Stage9Reject 'rejected key with a record' { Assert-Stage9NoIdempotencyRecord (New-Stage9Facts @{ idempotency_records = @($record) }) '09000000-0000-4000-8000-000009000001' }
Confirm-Stage9Accept { Assert-Stage9NoIdempotencyRecord (New-Stage9Facts) '09000000-0000-4000-8000-000009000001' }

$sentinel = [pscustomobject] @{ rows = [pscustomobject] @{ institutions = @([pscustomobject] @{ id = 's1' }) }; blob = [pscustomobject] @{ key = 'k'; sha256 = 'x' } }
$clean = New-Stage9Facts; $clean.sentinels = $sentinel
Confirm-Stage9Accept { Assert-Stage9CleanupFacts $clean $sentinel }
$left = New-Stage9Facts @{ official_task_scores = @($official) }; $left.sentinels = $sentinel
Confirm-Stage9Reject 'cleanup leaving an official row' { Assert-Stage9CleanupFacts $left $sentinel }
$message = $null; try { Assert-Stage9CleanupFacts $left $sentinel } catch { $message = $_.Exception.Message }
if ($message -notlike 'integration-harness defect:*') { throw 'integration-harness defect: a cleanup leftover was not classified as a harness defect.' }
$script:checks++
$changedSentinel = Copy-Stage9Synthetic $sentinel; $changedSentinel.blob.sha256 = 'y'
$touched = New-Stage9Facts; $touched.sentinels = $changedSentinel
Confirm-Stage9Reject 'cleanup touching the sentinel' { Assert-Stage9CleanupFacts $touched $sentinel }
Confirm-Stage9Reject 'uncaptured sentinel' { Assert-Stage9SentinelsUnchanged $null $sentinel 'x' }
Confirm-Stage9Accept { Assert-Stage9CleanupDiskIdentity ([pscustomobject] @{ cleaned = $true; disk = 'local'; root = '/var/www/html/storage/app/private' }) }
Confirm-Stage9Reject 'cleanup on the seeder-test disk' { Assert-Stage9CleanupDiskIdentity ([pscustomobject] @{ cleaned = $true; disk = 'stage9_seeder_test'; root = '/var/www/html/storage/app/private/e2e-s09-seeder-test-1' }) }
$sha = 'a' * 40
Confirm-Stage9Accept { Assert-Stage9AuditedCheckout ([pscustomobject] @{ Sha = $sha; Clean = $true }) ([pscustomobject] @{ Sha = $sha; Clean = $true }) }
Confirm-Stage9Reject 'dirty checkout at start' { Assert-Stage9AuditedCheckout ([pscustomobject] @{ Sha = $sha; Clean = $false }) }
Confirm-Stage9Reject 'checkout changed during the run' { Assert-Stage9AuditedCheckout ([pscustomobject] @{ Sha = $sha; Clean = $true }) ([pscustomobject] @{ Sha = ('b' * 40); Clean = $true }) }
Confirm-Stage9Reject 'checkout dirty before PASS' { Assert-Stage9AuditedCheckout ([pscustomobject] @{ Sha = $sha; Clean = $true }) ([pscustomobject] @{ Sha = $sha; Clean = $false }) }
$plan = @('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'seeder_test', 'fresh_seed', 'baseline_oracle', 'test_files',
    'api_setup', 'review_transport', 'scheduled_checking', 'windows_flow', 'post_ui_api', 'post_flow_oracle', 'restart', 'post_restart_oracle', 'final_cleanup', 'cleanup_oracle')
Confirm-Stage9Accept { Assert-Stage9RunnerPlan $plan }
Confirm-Stage9Reject 'seeder test before prior cleanup' { Assert-Stage9RunnerPlan (@('runtime_guard', 'pure_verifiers', 'sentinel_capture', 'seeder_test', 'prior_manifest_cleanup', 'prior_cleanup_oracle', 'fresh_seed') + $plan[7..18]) }
Confirm-Stage9Reject 'scheduled checking before the review error probes' { Assert-Stage9RunnerPlan ($plan[0..9] + @('scheduled_checking', 'review_transport') + $plan[12..18]) }
Confirm-Stage9Reject 'UI flow before scheduled checking' { Assert-Stage9RunnerPlan ($plan[0..10] + @('windows_flow', 'scheduled_checking') + $plan[13..18]) }
Confirm-Stage9Reject 'plan without restart' { Assert-Stage9RunnerPlan ($plan | Where-Object { $_ -cne 'restart' }) }
Confirm-Stage9Reject 'retry requiring the previous final cleanup' { Assert-Stage9RunnerPlan (@('requires_previous_cleanup') + $plan) }

# ---------------------------------------------------------------- scheduled-command guard
$owners = [pscustomobject] @{ 'hw-deadline' = 'inst'; 'blitz-timeout' = 'inst'; 'hw-backfill' = 'inst' }
$safe = [pscustomobject] @{ homework = @([pscustomobject] @{ institution_id = 'inst'; assessment_id = 'hw-deadline' }); blitz = @([pscustomobject] @{ institution_id = 'inst'; assessment_id = 'blitz-timeout' })
    frozen = @([pscustomobject] @{ id = 'att-a'; institution_id = 'inst'; assessment_id = 'hw-backfill' }, [pscustomobject] @{ id = 'att-b'; institution_id = 'inst'; assessment_id = 'hw-backfill' })
    in_progress = @(); pair_checked = @(); official = @(); owners = $owners }
$expected = @{ homework = @('hw-deadline'); blitz = @('blitz-timeout'); frozen = @('att-a', 'att-b') }
Confirm-Stage9Accept { Assert-Stage9ScheduleSafeToRun $safe $expected }
foreach ($set in @('homework', 'blitz', 'frozen', 'in_progress', 'pair_checked', 'official')) {
    $unsafe = Copy-Stage9Synthetic $safe
    $unsafe.$set = @($unsafe.$set) + @([pscustomobject] @{ id = 'foreign-row'; institution_id = 'inst'; assessment_id = 'foreign-assessment' })
    Confirm-Stage9Reject "a non-Stage-9 $set row" { Assert-Stage9ScheduleSafeToRun $unsafe $expected }
}
$wrongInstitution = Copy-Stage9Synthetic $safe; $wrongInstitution.frozen[0].institution_id = 'other'
Confirm-Stage9Reject 'a Stage 9 candidate with the wrong Institution' { Assert-Stage9ScheduleSafeToRun $wrongInstitution $expected }
Confirm-Stage9Reject 'a missing expected candidate' { Assert-Stage9ScheduleSafeToRun $safe @{ homework = @('hw-deadline'); blitz = @('blitz-timeout'); frozen = @('att-a', 'att-b', 'att-c') } }
Confirm-Stage9Reject 'an extra candidate' { Assert-Stage9ScheduleSafeToRun $safe @{ homework = @(); blitz = @('blitz-timeout'); frozen = @('att-a', 'att-b') } }

$sentinelFacts = [pscustomobject] @{ rows = [pscustomobject] @{ institutions = @([pscustomobject] @{ id = 's1' }) }; blob = [pscustomobject] @{ key = 'k'; sha256 = 'x' } }
$script:invocations = 0
$okInvoker = { param($Name) $script:invocations++; [pscustomobject] @{ ExitCode = 0; Output = "Candidates: 2; checked attempts: 2; failures: 0.`nOfficial scores repaired: 1; failures: 0." } }
$lines = @('Candidates: 2; checked attempts: 2; failures: 0.', 'Official scores repaired: 1; failures: 0.')
Confirm-Stage9Accept { Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates $expected -ExpectedLines $lines -FactsProvider { $safe } -SentinelProvider { $sentinelFacts } -Invoker $okInvoker }
$script:invocations = 0
$foreign = Copy-Stage9Synthetic $safe; $foreign.frozen = @($foreign.frozen) + @([pscustomobject] @{ id = 'x'; institution_id = 'inst'; assessment_id = 'foreign' })
Confirm-Stage9Reject 'a command over foreign candidates' { Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates $expected -ExpectedLines $lines -FactsProvider { $foreign } -SentinelProvider { $sentinelFacts } -Invoker $okInvoker | Out-Null }
if ($script:invocations -ne 0) { throw 'integration-harness defect: the guarded command ran after an unsafe fact set.' }
$script:checks++
Confirm-Stage9Reject 'different repair count' { Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates $expected -ExpectedLines @('Candidates: 2; checked attempts: 2; failures: 0.', 'Official scores repaired: 0; failures: 0.') -FactsProvider { $safe } -SentinelProvider { $sentinelFacts } -Invoker $okInvoker | Out-Null }
Confirm-Stage9Reject 'a missing repair line' { Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates $expected -ExpectedLines $lines -FactsProvider { $safe } -SentinelProvider { $sentinelFacts } -Invoker { param($Name) [pscustomobject] @{ ExitCode = 0; Output = 'Candidates: 2; checked attempts: 2; failures: 0.' } } | Out-Null }
Confirm-Stage9Reject 'an extra output line' { Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates $expected -ExpectedLines $lines -FactsProvider { $safe } -SentinelProvider { $sentinelFacts } -Invoker { param($Name) [pscustomobject] @{ ExitCode = 0; Output = "Deprecated: x`nCandidates: 2; checked attempts: 2; failures: 0.`nOfficial scores repaired: 1; failures: 0." } } | Out-Null }
Confirm-Stage9Reject 'reported failures with exit 1' { Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates $expected -ExpectedLines $lines -FactsProvider { $safe } -SentinelProvider { $sentinelFacts } -Invoker { param($Name) [pscustomobject] @{ ExitCode = 1; Output = "Candidates: 2; checked attempts: 1; failures: 1.`nOfficial scores repaired: 1; failures: 0." } } | Out-Null }
foreach ($code in @(124, 137)) {
    $message = $null
    try { Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates $expected -ExpectedLines $lines -FactsProvider { $safe } -SentinelProvider { $sentinelFacts } -Invoker { param($Name) [pscustomobject] @{ ExitCode = $code; Output = '' } } | Out-Null }
    catch { $message = $_.Exception.Message }
    if ($message -notlike 'environment/runtime defect:*timed out*') { throw "integration-harness defect: exit $code was not classified as a command timeout." }
    $script:checks++
}
$script:sentinelCalls = 0
$changing = { $script:sentinelCalls++; if ($script:sentinelCalls -gt 1) { $copy = Copy-Stage9Synthetic $sentinelFacts; $copy.blob.sha256 = 'y'; $copy } else { $sentinelFacts } }
Confirm-Stage9Reject 'a command touching the unrelated sentinel' { Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates $expected -ExpectedLines $lines -FactsProvider { $safe } -SentinelProvider $changing -Invoker $okInvoker | Out-Null }

$list = [pscustomobject] @{ ExitCode = 0; Output = "  * * * * *  php artisan homework:reconcile-deadlines .... Next Due: 1 minute from now`n  * * * * *  php artisan blitz:reconcile-timeouts ...... Next Due: 1 minute from now`n  * * * * *  php artisan attempts:check-frozen ......... Next Due: 1 minute from now" }
Confirm-Stage9Accept { Assert-Stage9ScheduleList $list }
Confirm-Stage9Reject 'schedule without the checking sweep' { Assert-Stage9ScheduleList ([pscustomobject] @{ ExitCode = 0; Output = ($list.Output -split "`n" | Select-Object -First 2) -join "`n" }) }
Confirm-Stage9Reject 'checking sweep not every minute' { Assert-Stage9ScheduleList ([pscustomobject] @{ ExitCode = 0; Output = $list.Output.Replace('* * * * *  php artisan attempts:check-frozen', '*/5 * * * *  php artisan attempts:check-frozen') }) }

$empty = Copy-Stage9Synthetic $safe; $empty.homework = @(); $empty.blitz = @(); $empty.frozen = @()
$runOutput = "  2026-10-02 12:00:00 Running ['artisan' homework:reconcile-deadlines] .. 80ms DONE`n  2026-10-02 12:00:00 Running ['artisan' blitz:reconcile-timeouts] .. 70ms DONE`n  2026-10-02 12:00:00 Running ['artisan' attempts:check-frozen] .. 90ms DONE"
Confirm-Stage9Accept { Invoke-Stage9GuardedScheduleRun -FactsProvider { $empty } -SentinelProvider { $sentinelFacts } -Invoker { [pscustomobject] @{ ExitCode = 0; Output = $runOutput } } }
$script:invocations = 0
Confirm-Stage9Reject 'schedule:run while a command has candidates' { Invoke-Stage9GuardedScheduleRun -FactsProvider { $safe } -SentinelProvider { $sentinelFacts } -Invoker { $script:invocations++; [pscustomobject] @{ ExitCode = 0; Output = $runOutput } } | Out-Null }
if ($script:invocations -ne 0) { throw 'integration-harness defect: schedule:run ran while a command still had candidates.' }
$script:checks++
Confirm-Stage9Reject 'schedule:run reporting a failed command' { Invoke-Stage9GuardedScheduleRun -FactsProvider { $empty } -SentinelProvider { $sentinelFacts } -Invoker { [pscustomobject] @{ ExitCode = 0; Output = $runOutput + "`n  2026-10-02 12:00:00 Running ['artisan' homework:reconcile-deadlines] .. 10ms FAIL" } } | Out-Null }
Confirm-Stage9Reject 'schedule:run skipping a command' { Invoke-Stage9GuardedScheduleRun -FactsProvider { $empty } -SentinelProvider { $sentinelFacts } -Invoker { [pscustomobject] @{ ExitCode = 0; Output = ($runOutput -split "`n" | Select-Object -First 2) -join "`n" } } | Out-Null }
$message = $null; try { Invoke-Stage9GuardedScheduleRun -FactsProvider { $empty } -SentinelProvider { $sentinelFacts } -Invoker { [pscustomobject] @{ ExitCode = 0; Output = ($runOutput -split "`n" | Select-Object -First 2) -join "`n" } } | Out-Null } catch { $message = $_.Exception.Message }
if ($message -notlike 'environment/runtime defect:*mutex*') { throw 'integration-harness defect: a skipped scheduled command was not classified as a stale-mutex environment defect.' }
$script:checks++

# ---------------------------------------------------------------- every Stage 9 script parses
# A script that only the owner runs (the Android smoke) must not first fail on a syntax error during the smoke.
foreach ($scriptFile in @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*stage9*.ps1')) {
    $parseErrors = $null
    [void] [Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref] $null, [ref] $parseErrors)
    if (@($parseErrors).Count -ne 0) { throw "integration-harness defect: $($scriptFile.Name) does not parse: $($parseErrors[0].Message)" }
    $script:checks++
}

Write-Output "Stage9Oracle pure verifier: PASS ($script:checks checks; no DB, API or scheduled-command execution)."
