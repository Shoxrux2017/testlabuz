param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage7_oracle.ps1')

$script:checks = 0
function Confirm-Stage7Reject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "integration-harness defect: Oracle verifier accepted $Label." }
    $script:checks++
}
function Copy-Stage7Synthetic { param($Value) ConvertTo-Json -InputObject $Value -Depth 50 -Compress | ConvertFrom-Json }

$attempt = [pscustomobject] @{ id = 'attempt'; status = 'submitted'; finalization_reason = 'student_submit'; submitted_at = '2026-09-11 00:00:00+00'; finalized_at = '2026-09-11 00:00:00+00'; locked_at = '2026-09-11 00:00:00+00'; earned_points = $null; normalized_score = $null; scoring_completed_at = $null }
Assert-Stage7TerminalAttempt $attempt student_submit $attempt.submitted_at
$script:checks++
foreach ($field in @('status','finalization_reason','submitted_at','finalized_at','locked_at')) {
    $bad = Copy-Stage7Synthetic $attempt; $bad.$field = 'wrong'
    Confirm-Stage7Reject "terminal $field" { Assert-Stage7TerminalAttempt $bad student_submit $attempt.submitted_at }
}
$auto = Copy-Stage7Synthetic $attempt; $auto.finalization_reason = 'homework_deadline_auto_submit'; $auto.submitted_at = $null
Assert-Stage7TerminalAttempt $auto homework_deadline_auto_submit $auto.finalized_at
Confirm-Stage7Reject 'auto-submit fabricated Student timestamp' { Assert-Stage7TerminalAttempt $attempt homework_deadline_auto_submit $attempt.finalized_at }
$answer = [pscustomobject] @{ id = 'answer'; institution_id = 'target'; checking_status = 'pending'; awarded_points = $null; feedback = $null; checked_by_user_id = $null; checked_at = $null }
Assert-Stage7Unscored $attempt @($answer)
foreach ($field in @('earned_points','normalized_score','scoring_completed_at')) {
    $bad = Copy-Stage7Synthetic $attempt; $bad.$field = 1
    Confirm-Stage7Reject "Attempt scoring $field" { Assert-Stage7Unscored $bad @($answer) }
}
foreach ($field in @('awarded_points','feedback','checked_by_user_id','checked_at','checking_status')) {
    $bad = Copy-Stage7Synthetic $answer; $bad.$field = 'unexpected'
    Confirm-Stage7Reject "answer scoring $field" { Assert-Stage7Unscored $attempt @($bad) }
}
$tables = [ordered] @{}
foreach ($table in @('answer_choice_selections','answer_text_values','answer_boolean_values','answer_matching_pairs','answer_ordering_items','answer_fill_blank_values','answer_files')) { $tables[$table] = @() }
$tables.answer_text_values = @([pscustomobject] @{ answer_id = 'answer'; text_value = "O‘zbekiston`nStudent's exact text" })
$typed = [pscustomobject] @{ tables = [pscustomobject] $tables }
Assert-Stage7TypedAnswer $typed $answer short_written @("O‘zbekiston`nStudent's exact text")
$script:checks++
Confirm-Stage7Reject 'wrong exact Unicode/newline text' { Assert-Stage7TypedAnswer $typed $answer short_written @('changed') }
$bad = Copy-Stage7Synthetic $typed; $bad.tables.answer_boolean_values = @([pscustomobject] @{ answer_id = 'answer'; boolean_value = $true })
Confirm-Stage7Reject 'wrong child table residue' { Assert-Stage7TypedAnswer $bad $answer short_written @("O‘zbekiston`nStudent's exact text") }

$pair = [pscustomobject] @{ id = 'pair'; institution_id = 'target'; topic_id = 'topic'; homework_assessment_id = 'homework'; cohort_snapshotted_at = 'cohort'; designated_at = 'designated'; locked_at = 'start'; blitz_assessment_id = $null }
$first = [pscustomobject] @{ started_at = 'start' }
Assert-Stage7Pair $pair $pair $first
$bad = Copy-Stage7Synthetic $pair; $bad.locked_at = 'second-start'
Confirm-Stage7Reject 'pair lock changed on later Attempt' { Assert-Stage7Pair $bad $pair $first }
Confirm-Stage7Reject 'fabricated recipient Attempt' { Assert-Stage7Set @('target-attempt','peer-attempt') @('target-attempt') 'recipients' }

$manifest = [pscustomobject] @{ institutions = [pscustomobject] @{ target = 'target'; foreign = 'foreign' }; homework = [pscustomobject] @{ scheduler = 'scheduler'; deadline_read = 'read'; due_teacher_close = 'due'; teacher_close = 'close' }; users = [pscustomobject] @{ student = 'student' } }
$candidate = [pscustomobject] @{ institution_id = 'target'; assessment_id = 'scheduler' }
Assert-Stage7SchedulerCandidates @($candidate) $manifest
Assert-Stage7SchedulerCandidates @() $manifest -SecondInvocation
$script:checks += 2
Confirm-Stage7Reject 'zero first scheduler candidates' { Assert-Stage7SchedulerCandidates @() $manifest }
Confirm-Stage7Reject 'two scheduler candidates' { Assert-Stage7SchedulerCandidates @($candidate,$candidate) $manifest }
foreach ($extra in @('read','due','unexpected-non-stage7')) {
    $other = [pscustomobject] @{ institution_id = 'target'; assessment_id = $extra }
    Confirm-Stage7Reject "$extra left in_progress before scheduler" { Assert-Stage7SchedulerCandidates @($candidate,$other) $manifest }
}
$badManifest = Copy-Stage7Synthetic $manifest; $badManifest.homework.scheduler = 'wrong-scheduler'
Confirm-Stage7Reject 'wrong expected scheduler Homework ID' { Assert-Stage7SchedulerCandidates @($candidate) $badManifest }
Confirm-Stage7Reject 'nonempty second scheduler candidates' { Assert-Stage7SchedulerCandidates @($candidate) $manifest -SecondInvocation }
$wrongTenant = [pscustomobject] @{ institution_id = 'foreign'; assessment_id = 'scheduler' }
Confirm-Stage7Reject 'cross-Tenant scheduler candidate' { Assert-Stage7SchedulerCandidates @($wrongTenant) $manifest }

$record = [pscustomobject] @{ institution_id = 'target'; user_id = 'student'; operation = 'student.homework.attempt.start'; idempotency_key = 'key'; result_resource_type = 'assessment_attempt'; result_resource_id = 'attempt'; response_status = 201; completed_at = 'complete'; request_fingerprint = ('a' * 64) }
Assert-Stage7IdempotencyRecord $record target student student.homework.attempt.start key attempt 201
foreach ($field in @('institution_id','user_id','operation','idempotency_key','result_resource_type','result_resource_id','request_fingerprint')) {
    $bad = Copy-Stage7Synthetic $record; $bad.$field = 'wrong'
    Confirm-Stage7Reject "idempotency $field" { Assert-Stage7IdempotencyRecord $bad target student student.homework.attempt.start key attempt 201 }
}
$bad = Copy-Stage7Synthetic $record; $bad.completed_at = $null
Confirm-Stage7Reject 'incomplete idempotency record' { Assert-Stage7IdempotencyRecord $bad target student student.homework.attempt.start key attempt 201 }
$bad = Copy-Stage7Synthetic $record; $bad.response_status = 200
Confirm-Stage7Reject 'wrong original idempotency status' { Assert-Stage7IdempotencyRecord $bad target student student.homework.attempt.start key attempt 201 }

$fixture = [pscustomobject] @{ original_name = 'replacement.pptx'; extension = 'pptx'; mime_type = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'; size_bytes = 123; checksum_sha256 = ('a' * 64) }
$file = [pscustomobject] @{ id = 'file'; institution_id = 'target'; uploaded_by_user_id = 'student'; category = 'student_submission'; removed_at = $null; storage_disk = 'private'; storage_key = 'student-submissions/target/attempt/question/blob.pptx'; original_name = $fixture.original_name; extension = $fixture.extension; mime_type = $fixture.mime_type; size_bytes = 123; checksum_sha256 = $fixture.checksum_sha256 }
$fileFacts = [pscustomobject] @{ manifest = $manifest; private_disk = 'private'; private_root = '/var/www/html/storage/app/private'; blobs = @([pscustomobject] @{ key = $file.storage_key; size = 123; checksum = $fixture.checksum_sha256; public_exists = $false }) }
Assert-Stage7File $fileFacts $file $fixture attempt question
foreach ($field in @('institution_id','uploaded_by_user_id','storage_disk','storage_key','checksum_sha256','size_bytes')) {
    $bad = Copy-Stage7Synthetic $file; $bad.$field = if ($field -ceq 'size_bytes') { 999 } else { 'wrong' }
    Confirm-Stage7Reject "file $field" { Assert-Stage7File $fileFacts $bad $fixture attempt question }
}
$bad = Copy-Stage7Synthetic $fileFacts; $bad.private_root = '/var/www/html/storage/app/public'
Confirm-Stage7Reject 'public private-root path' { Assert-Stage7File $bad $file $fixture attempt question }
$bad = Copy-Stage7Synthetic $fileFacts; $bad.blobs[0].public_exists = $true
Confirm-Stage7Reject 'public alias blob' { Assert-Stage7File $bad $file $fixture attempt question }
$beforeLink = [pscustomobject] @{ id = 'link'; file_id = 'original'; answer_id = 'answer' }
$afterLink = Copy-Stage7Synthetic $beforeLink; $afterLink.file_id = 'replacement'
Assert-Stage7ReplacementIdentity $answer $answer $beforeLink $beforeLink
Confirm-Stage7Reject 'replacement changed File ID' { Assert-Stage7ReplacementIdentity $answer $answer $beforeLink $afterLink }

# Exercise complete-table Tenant rejection before any other lifecycle/main assertion can mask it.
$allTables = @('institutions','institution_settings','users','groups','topics','group_teacher_memberships','group_student_memberships','assessments','homework_assignments','assessment_students','questions','question_choice_options','question_matching_items','question_ordering_items','question_fill_blanks','topic_result_pairs','assessment_attempts','attempt_answers','answer_choice_selections','answer_text_values','answer_boolean_values','answer_matching_pairs','answer_ordering_items','answer_fill_blank_values','answer_files','files','idempotency_records')
$emptyTables = [ordered] @{}
foreach ($table in $allTables) { $emptyTables[$table] = @() }
$emptyTables.institutions = @([pscustomobject] @{ id = 'target' },[pscustomobject] @{ id = 'foreign' })
$safe = [pscustomobject] @{ manifest = $manifest; tables = [pscustomobject] $emptyTables; blobs = @(); public_blobs = @() }
Assert-Stage7TenantRows $safe
$bad = Copy-Stage7Synthetic $safe; $bad.tables.users = @([pscustomobject] @{ id = 'user'; institution_id = 'outside' })
Confirm-Stage7Reject 'cross-Tenant fixture row' { Assert-Stage7TenantRows $bad }
$bad = Copy-Stage7Synthetic $safe
$fourth = Copy-Stage7Synthetic $attempt
$fourth | Add-Member institution_id target
$fourth | Add-Member assessment_id homework
$fourth | Add-Member assessment_student_id recipient
$fourth | Add-Member student_id student
$fourth | Add-Member attempt_number 4
Confirm-Stage7Reject 'unexpected fourth Attempt' { Assert-Stage7AttemptLimit @($fourth) }
$firstNormal = Copy-Stage7Synthetic $fourth; $firstNormal.attempt_number = 1
Assert-Stage7AttemptLimit @($firstNormal)
Confirm-Stage7Reject 'duplicate normal Attempt number' { Assert-Stage7AttemptLimit @($firstNormal,$firstNormal) }
Confirm-Stage7Reject 'restart changed persisted state' { Assert-Stage7RestartPersistence ([pscustomobject] @{ tables = @{ id = 1 }; blobs = @(); public_blobs = @(); private_disk = 'private' }) ([pscustomobject] @{ tables = @{ id = 2 }; blobs = @(); public_blobs = @(); private_disk = 'private' }) }
$cleanTables = [ordered] @{}
foreach ($table in $allTables) { $cleanTables[$table] = @() }
$clean = [pscustomobject] @{ tables = [pscustomobject] $cleanTables; blobs = @(); public_blobs = @() }
Assert-Stage7DatabaseFacts -Facts $clean -Mode Cleanup
$bad = Copy-Stage7Synthetic $clean; $bad.public_blobs = @('student-submissions/previous/owned/key')
Confirm-Stage7Reject 'cleanup private deletion hides public copy' { Assert-Stage7DatabaseFacts -Facts $bad -Mode Cleanup }

$checkpointManifest = Copy-Stage7Synthetic $manifest
$checkpointManifest.homework | Add-Member main homework
$checkpointManifest | Add-Member pair pair
$checkpointManifest | Add-Member questions ([pscustomobject] @{ main = [pscustomobject] @{ file_based = 'question' } })
$checkpointTables = [ordered] @{}
foreach ($table in $allTables) { $checkpointTables[$table] = @() }
$checkpointTables.institutions = @([pscustomobject] @{ id = 'target' },[pscustomobject] @{ id = 'foreign' })
$checkpointTables.users = @([pscustomobject] @{ id = 'student'; institution_id = 'target' })
$checkpointTables.groups = @([pscustomobject] @{ id = 'group'; institution_id = 'target' })
$checkpointTables.topics = @([pscustomobject] @{ id = 'topic'; institution_id = 'target'; group_id = 'group'; teacher_id = 'student' })
$checkpointTables.assessments = @([pscustomobject] @{ id = 'homework'; institution_id = 'target'; topic_id = 'topic'; teacher_id = 'student' })
$checkpointTables.assessment_students = @([pscustomobject] @{ id = 'recipient'; institution_id = 'target'; assessment_id = 'homework'; student_id = 'student' })
$checkpointTables.questions = @([pscustomobject] @{ id = 'question'; institution_id = 'target'; assessment_id = 'homework' })
$checkpointTables.topic_result_pairs = @($pair)
$checkpointFacts = [pscustomobject] @{ manifest = $checkpointManifest; tables = [pscustomobject] $checkpointTables; blobs = @(); public_blobs = @(); private_disk = 'private'; private_root = '/var/www/html/storage/app/private' }
$checkpointBaseline = Copy-Stage7Synthetic $checkpointFacts
$mainAttempt = [pscustomobject] @{ id = 'attempt'; institution_id = 'target'; assessment_id = 'homework'; assessment_student_id = 'recipient'; student_id = 'student'; attempt_number = 1; status = 'in_progress'; started_at = 'start' }
$checkpointFacts.tables.assessment_attempts = @($mainAttempt)
$checkpoint = [pscustomobject] @{ version = 1; checkpoint = 'first_start'; attempt_id = 'attempt'; file_id = $null }
Assert-Stage7UiCheckpoint -Checkpoint $checkpoint -Facts $checkpointFacts -Baseline $checkpointBaseline
$checkpoint.checkpoint = 'fake_file_rejected'
Assert-Stage7UiCheckpoint -Checkpoint $checkpoint -Facts $checkpointFacts -Baseline $checkpointBaseline
$fileAnswer = Copy-Stage7Synthetic $answer
$fileAnswer | Add-Member attempt_id attempt
$fileAnswer | Add-Member question_id question
$checkpointFacts.tables.attempt_answers = @($fileAnswer)
$checkpointFacts.tables.files = @($file)
$checkpointFacts.tables.answer_files = @([pscustomobject] @{ id = 'link'; institution_id = 'target'; answer_id = 'answer'; file_id = 'file' })
$checkpointFacts.blobs = @([pscustomobject] @{ key = $file.storage_key; size = $file.size_bytes; checksum = $file.checksum_sha256; public_exists = $false })
$syntheticFiles = [pscustomobject] @{ files = [pscustomobject] @{ valid_pdf = [pscustomobject] @{ original_name = $file.original_name; extension = $file.extension; mime_type = $file.mime_type; size_bytes = $file.size_bytes; sha256 = $file.checksum_sha256 } } }
$checkpoint.checkpoint = 'first_file_uploaded'; $checkpoint.file_id = 'file'
Assert-Stage7UiCheckpoint -Checkpoint $checkpoint -Facts $checkpointFacts -Baseline $checkpointBaseline -FileManifest $syntheticFiles
$uploadFacts = Copy-Stage7Synthetic $checkpointFacts
$checkpointFacts.tables.files[0].storage_key = 'student-submissions/target/attempt/question/new-blob.pptx'
$checkpointFacts.blobs[0].key = $checkpointFacts.tables.files[0].storage_key
$syntheticFiles.files | Add-Member replacement_pptx $syntheticFiles.files.valid_pdf
$checkpoint.checkpoint = 'file_replaced'
Assert-Stage7UiCheckpoint -Checkpoint $checkpoint -Facts $checkpointFacts -Baseline $checkpointBaseline -FileManifest $syntheticFiles -PriorCheckpointFacts $uploadFacts
$script:checks += 4
$bad = Copy-Stage7Synthetic $checkpointFacts; $bad.tables.answer_files[0].id = 'different-link'
Confirm-Stage7Reject 'actual replacement checkpoint changed AnswerFile ID' { Assert-Stage7UiCheckpoint -Checkpoint $checkpoint -Facts $bad -Baseline $checkpointBaseline -FileManifest $syntheticFiles -PriorCheckpointFacts $uploadFacts }
$script:clockCalls = 0
function Invoke-Stage7ContainerPhp {
    param([string] $Program, [string] $BackendContainerName)
    $script:clockCalls++
    [pscustomobject] @{ now = $(if ($script:clockCalls -eq 1) { '2026-09-11T00:00:00Z' } else { '2026-09-11T00:00:01Z' }) }
}
Wait-Stage7TimestampBoundary '2026-09-11T00:00:00Z'
if ($script:clockCalls -ne 2) { throw 'integration-harness defect: Timestamp boundary did not condition-wait for a later server second.' }
$script:checks++
Write-Output "Stage7Oracle pure verifier: PASS ($script:checks checks; no DB, API or scheduler execution)."
