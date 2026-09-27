Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage8_api_security.ps1')

function New-Stage8StartRequest {
    param([string] $Key, [string] $Intent, [string] $AttemptId)
    $body = if ($Intent -ceq 'resume') { [pscustomobject] @{ intent = 'resume'; attempt_id = $AttemptId } } else { [pscustomobject] @{ intent = $Intent } }
    $request = [pscustomobject] @{ Key = $Key; Body = $body }
    Assert-Stage8StartRequest $request
    $request
}

function Invoke-Stage8Start {
    param($Context, [string] $Actor, [string] $BlitzId, $Request)
    Invoke-Stage8Call $Context $Actor "/student/blitz/$BlitzId/attempts" POST -Key $Request.Key -Body $Request.Body
}

function Invoke-Stage8Submit { param($Context, [string] $Actor, [string] $AttemptId, [string] $Key) Invoke-Stage8Call $Context $Actor "/student/attempts/$AttemptId/submit" POST -Key $Key -Body @{} }

function Invoke-Stage8Answer { param($Context, [string] $Actor, [string] $AttemptId, [string] $QuestionId, $Body) Invoke-Stage8Call $Context $Actor "/student/attempts/$AttemptId/answers/$QuestionId" PUT -Body $Body }

function Invoke-Stage8Grant {
    param($Context, [string] $Actor, [string] $BlitzId, [string] $StudentId, [string] $Key, [string] $Reason, [string] $ReasonType = 'technical')
    Invoke-Stage8Call $Context $Actor "/teacher/blitz/$BlitzId/students/$StudentId/attempt-exception" POST -Key $Key -Body @{ reason_type = $ReasonType; reason = $Reason }
}

function Invoke-Stage8Activate { param($Context, [string] $Actor, [string] $BlitzId, [string] $Key) Invoke-Stage8Call $Context $Actor "/teacher/blitz/$BlitzId/activate" POST -Key $Key -Body @{} }

function Get-Stage8StudentAttempts { param($Facts, [string] $BlitzId, [string] $StudentId) @(Get-Stage8Rows $Facts assessment_attempts assessment_id $BlitzId | Where-Object student_id -CEQ $StudentId | Sort-Object { [int] $_.attempt_number }) }

function Assert-Stage8Rejection {
    param($Response, [int] $Status, [string] $Code, $Context, [string] $Key)
    Assert-Stage8ApiError $Response $Status $Code
    if ($Key) { $Context.RejectedKeys.Add($Key) }
}

# Sections 34.1.4A-34.1.6, 38, 41-43, 62-63: the Start/Submit/grant matrices on isolated individual fixtures.
function Invoke-Stage8ExecutionMatrix {
    param($Context)
    $m = $Context.Manifest
    $matrix = $m.assessments.matrix
    $student = [string] $m.users.d_matrix
    $n = 300
    $key = { $script:stage8ExecutionKey++; New-Stage8Key $script:stage8ExecutionKey }
    $script:stage8ExecutionKey = $n

    $detail = Invoke-Stage8Call $Context d_matrix "/student/blitz/$matrix"
    Assert-Stage8PreStartPrivacy $detail
    if ($detail.Json.data.timing.mode -cne 'individual' -or $null -ne $detail.Json.data.timing.deadline_at -or $null -ne $detail.Json.data.timing.remaining_seconds) { throw 'production defect: Individual pre-Start detail exposed an effective deadline.' }
    $before = Get-Stage8Facts
    if (@(Get-Stage8StudentAttempts $before $matrix $student).Count -ne 0) { throw 'production defect: Opening the Blitz detail created an Attempt.' }

    $k1 = New-Stage8StartRequest (& $key) start_normal
    $first = Invoke-Stage8Start $Context d_matrix $matrix $k1
    Assert-Stage8ApiSuccess $first 201
    Assert-Stage8NoProtectedKeys $first.Json
    if (@($first.Json.data.questions).Count -ne 9 -or [int] $first.Json.data.attempt_number -ne 1) { throw 'production defect: Start did not return Attempt #1 with its nine safe Questions.' }
    Assert-Stage8ItemIdPrivacy @($first.Json.data.questions) $m.nested.matrix
    $attempt1 = [string] $first.Json.data.id
    $facts = Get-Stage8Facts
    $history = Assert-Stage8AttemptHistory $facts $matrix $student
    if ($history.Attempts.Count -ne 1) { throw 'production defect: Fresh Start created other than exactly #1.' }
    Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $facts $k1.Key student.blitz.attempt.start) $m.institutions.individual $student student.blitz.attempt.start $k1.Key assessment_attempt $attempt1 201
    $stable = @('id', 'attempt_number', 'started_at', 'deadline_at')
    Assert-Stage8ReplayOutcome $first (Invoke-Stage8Start $Context d_matrix $matrix $k1) 201 $stable
    $newNormal = New-Stage8StartRequest (& $key) start_normal
    Assert-Stage8ReplayOutcome $first (Invoke-Stage8Start $Context d_matrix $matrix $newNormal) 200 $stable
    $kr = New-Stage8StartRequest (& $key) resume $attempt1
    $resume = Invoke-Stage8Start $Context d_matrix $matrix $kr
    Assert-Stage8ReplayOutcome $first $resume 200 $stable
    Assert-Stage8ReplayOutcome $first (Invoke-Stage8Start $Context d_matrix $matrix $kr) 200 $stable
    $sameKey = @(
        [pscustomobject] @{ Key = $kr.Key; Body = [pscustomobject] @{ intent = 'resume'; attempt_id = [string] $m.attempts.checked_1 } },
        [pscustomobject] @{ Key = $kr.Key; Body = [pscustomobject] @{ intent = 'start_normal' } },
        [pscustomobject] @{ Key = $kr.Key; Body = [pscustomobject] @{ intent = 'start_replacement' } },
        [pscustomobject] @{ Key = $k1.Key; Body = [pscustomobject] @{ intent = 'resume'; attempt_id = $attempt1 } })
    $beforeReuse = Get-Stage8Facts
    foreach ($request in $sameKey) { Assert-Stage8KeyReuseOutcome (Invoke-Stage8Start $Context d_matrix $matrix $request) }
    Assert-Stage8RowsUnchanged $beforeReuse (Get-Stage8Facts) @('assessment_attempts', 'idempotency_records', 'blitz_attempt_exceptions') 'key reuse with a changed Start request'

    # Foreign, other-Student and other-Blitz Resume targets are privacy-safe 404s with fresh keys.
    $peerStart = Invoke-Stage8Start $Context d_matrix_peer $matrix (New-Stage8StartRequest (& $key) start_normal)
    Assert-Stage8ApiSuccess $peerStart 201
    $otherStart = Invoke-Stage8Start $Context d_matrix $m.assessments.matrix_other (New-Stage8StartRequest (& $key) start_normal)
    Assert-Stage8ApiSuccess $otherStart 201
    $beforeForeign = Get-Stage8Facts
    foreach ($target in @([string] $peerStart.Json.data.id, [string] $otherStart.Json.data.id, [string] $m.attempts.checked_1)) {
        $request = New-Stage8StartRequest (& $key) resume $target
        Assert-Stage8Rejection (Invoke-Stage8Start $Context d_matrix $matrix $request) 404 resource_not_found $Context $request.Key
    }
    Assert-Stage8NoSwitch $beforeForeign (Get-Stage8Facts) $matrix $student $null $attempt1

    # Section 63: every non-file type plus a file persists canonically; clearable answers leave no placeholder.
    $q = $m.questions.matrix; $nested = $m.nested.matrix
    $short = "O$([char]0x2018)zbekiston - E2E S08 API"
    $open = "E2E S08 first line`nStudent's second line"
    $answers = [ordered] @{
        single_choice = @{ body = @{ type = 'single_choice'; selected_option_ids = @($nested.single_choice[1]) }; expected = @($nested.single_choice[1]) }
        multiple_choice = @{ body = @{ type = 'multiple_choice'; selected_option_ids = @($nested.multiple_choice[0], $nested.multiple_choice[2]) }; expected = @($nested.multiple_choice[0], $nested.multiple_choice[2]) }
        true_false = @{ body = @{ type = 'true_false'; value = $true }; expected = @($true) }
        short_written = @{ body = @{ type = 'short_written'; text = $short }; expected = @($short) }
        open_written = @{ body = @{ type = 'open_written'; text = $open }; expected = @($open) }
        matching = @{ body = @{ type = 'matching'; pairs = @(@{ left_item_id = $nested.matching.left[0]; right_item_id = $nested.matching.right[1] }) }; expected = @("$($nested.matching.left[0]):$($nested.matching.right[1])") }
        ordering = @{ body = @{ type = 'ordering'; items = @(@{ item_id = $nested.ordering[1]; position = 1 }, @{ item_id = $nested.ordering[0]; position = 2 }) }; expected = @("$($nested.ordering[1]):1", "$($nested.ordering[0]):2") }
        fill_in_blank = @{ body = @{ type = 'fill_in_blank'; values = @(@{ blank_id = $nested.fill_in_blank.blanks[0]; text = 'E2E S08 blank' }) }; expected = @("$($nested.fill_in_blank.blanks[0]):E2E S08 blank") }
    }
    foreach ($type in $answers.Keys) {
        $response = Invoke-Stage8Answer $Context d_matrix $attempt1 $q.$type $answers[$type].body
        Assert-Stage8ApiSuccess $response
        Assert-Stage8NoProtectedKeys $response.Json
    }
    $upload = Invoke-Stage8Call $Context d_matrix "/student/attempts/$attempt1/answers/$($q.file_based)" PUT -FilePath $Context.Files.Files['answer_pdf'].path
    Assert-Stage8ApiSuccess $upload
    $saved = Get-Stage8Facts
    $savedAnswers = Assert-Stage8AnswerSet $saved $attempt1 @($q.PSObject.Properties.Value)
    foreach ($type in $answers.Keys) { Assert-Stage8TypedAnswer $saved @($savedAnswers | Where-Object question_id -CEQ $q.$type)[0] $type $answers[$type].expected }
    $fileRow = Get-Stage8Row $saved files ([string] $upload.Json.data.answer.file.id)
    Assert-Stage8File $saved $fileRow (Get-Stage8FileExpectation $Context.Files answer_pdf) (Get-Stage8Row $saved assessment_attempts $attempt1) $q.file_based
    foreach ($clear in @(@{ type = 'short_written'; body = @{ type = 'short_written'; text = '' } }, @{ type = 'multiple_choice'; body = @{ type = 'multiple_choice'; selected_option_ids = @() } }, @{ type = 'matching'; body = @{ type = 'matching'; pairs = @() } })) {
        Assert-Stage8ApiSuccess (Invoke-Stage8Answer $Context d_matrix $attempt1 $q.($clear.type) $clear.body)
    }
    $cleared = Get-Stage8Facts
    Assert-Stage8AnswerSet $cleared $attempt1 @($q.PSObject.Properties | Where-Object { $_.Name -cnotin @('short_written', 'multiple_choice', 'matching') } | ForEach-Object Value) | Out-Null
    Assert-Stage8NoOrphanBlob $cleared

    $ks = & $key
    $submitted = Invoke-Stage8Submit $Context d_matrix $attempt1 $ks
    Assert-Stage8ApiSuccess $submitted
    $afterSubmit = Get-Stage8Facts
    $attempt1Row = Get-Stage8Row $afterSubmit assessment_attempts $attempt1
    Assert-Stage8TerminalAttempt $attempt1Row student_submit ([string] $attempt1Row.submitted_at)
    Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $afterSubmit $ks student.blitz.attempt.submit) $m.institutions.individual $student student.blitz.attempt.submit $ks assessment_attempt $attempt1 200
    Wait-Stage8TimestampBoundary ([string] $attempt1Row.updated_at)
    Assert-Stage8ReplayOutcome $submitted (Invoke-Stage8Submit $Context d_matrix $attempt1 $ks) 200 @('id', 'status', 'submitted_at', 'finalized_at', 'finalization_reason')
    Assert-Stage8RowsUnchanged $afterSubmit (Get-Stage8Facts) @('assessment_attempts') 'Submit replay'
    $terminalProbes = @(
        @{ Call = { param($k) Invoke-Stage8Submit $Context d_matrix $attempt1 $k }; Code = 'attempt_not_editable' },
        @{ Call = { param($k) Invoke-Stage8Start $Context d_matrix $matrix (New-Stage8StartRequest $k resume $attempt1) }; Code = 'attempt_not_editable' },
        @{ Call = { param($k) Invoke-Stage8Start $Context d_matrix $matrix (New-Stage8StartRequest $k start_normal) }; Code = 'attempts_exhausted' })
    foreach ($probe in $terminalProbes) { $k = & $key; Assert-Stage8Rejection (& $probe.Call $k) 409 $probe.Code $Context $k }
    Assert-Stage8RowsUnchanged $afterSubmit (Get-Stage8Facts) @('assessment_attempts', 'blitz_attempt_exceptions') 'terminal #1 rejections'

    # Section 43: grant idempotency; the grant never creates #2.
    $reason = 'E2E S08 device lost power during the Blitz'
    $kg = & $key
    $grant = Invoke-Stage8Grant $Context individual_teacher $matrix $student $kg $reason
    Assert-Stage8ApiSuccess $grant 201
    $granted = Get-Stage8Facts
    $history = Assert-Stage8AttemptHistory $granted $matrix $student
    if ($history.Attempts.Count -ne 1) { throw 'production defect: The grant created a replacement Attempt.' }
    Assert-Stage8Exception $history.Exception $attempt1 $null technical $reason ([string] $m.users.individual_teacher)
    Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $granted $kg teacher.blitz.attempt_exception.grant) $m.institutions.individual ([string] $m.users.individual_teacher) teacher.blitz.attempt_exception.grant $kg blitz_attempt_exception ([string] $grant.Json.data.id) 201
    Assert-Stage8ReplayOutcome $grant (Invoke-Stage8Grant $Context individual_teacher $matrix $student $kg $reason) 201 @('id')
    Assert-Stage8KeyReuseOutcome (Invoke-Stage8Grant $Context individual_teacher $matrix $student $kg 'E2E S08 another reason')
    Assert-Stage8KeyReuseOutcome (Invoke-Stage8Grant $Context individual_teacher $matrix ([string] $m.users.d_matrix_peer) $kg $reason)
    Assert-Stage8KeyReuseOutcome (Invoke-Stage8Grant $Context individual_teacher $m.assessments.matrix_other $student $kg $reason)
    $kg2 = & $key
    Assert-Stage8Rejection (Invoke-Stage8Grant $Context individual_teacher $matrix $student $kg2 $reason) 409 blitz_attempt_exception_already_granted $Context $kg2
    Assert-Stage8RowsUnchanged $granted (Get-Stage8Facts) @('assessment_attempts', 'blitz_attempt_exceptions') 'grant replay and rejected grants'

    # A stale Resume or a normal Start never switches to or creates the replacement.
    $beforeStale = Get-Stage8Facts
    $stale = New-Stage8StartRequest (& $key) resume $attempt1
    $staleResponse = Invoke-Stage8Start $Context d_matrix $matrix $stale
    Assert-Stage8Rejection $staleResponse 409 attempt_not_editable $Context $stale.Key
    $k = & $key; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_matrix $matrix (New-Stage8StartRequest $k start_normal)) 409 attempts_exhausted $Context $k
    $k1Replay = Invoke-Stage8Start $Context d_matrix $matrix $k1
    Assert-Stage8ApiSuccess $k1Replay 201
    if ([string] $k1Replay.Json.data.id -cne $attempt1) { throw 'production defect: A completed start_normal replay returned #2.' }
    Assert-Stage8NoSwitch $beforeStale (Get-Stage8Facts) $matrix $student $staleResponse $attempt1

    $k2 = New-Stage8StartRequest (& $key) start_replacement
    $replacement = Invoke-Stage8Start $Context d_matrix $matrix $k2
    Assert-Stage8ApiSuccess $replacement 201
    $attempt2 = [string] $replacement.Json.data.id
    if ([int] $replacement.Json.data.attempt_number -ne 2) { throw 'production defect: start_replacement did not create #2.' }
    $afterReplacement = Get-Stage8Facts
    $history = Assert-Stage8AttemptHistory $afterReplacement $matrix $student
    if ($history.Attempts.Count -ne 2) { throw 'production defect: Replacement history mismatch.' }
    Assert-Stage8ReplayOutcome $replacement (Invoke-Stage8Start $Context d_matrix $matrix $k2) 201 $stable
    Assert-Stage8ReplayOutcome $replacement (Invoke-Stage8Start $Context d_matrix $matrix (New-Stage8StartRequest (& $key) start_replacement)) 200 $stable
    $kr2 = New-Stage8StartRequest (& $key) resume $attempt2
    Assert-Stage8ReplayOutcome $replacement (Invoke-Stage8Start $Context d_matrix $matrix $kr2) 200 $stable
    $beforeReuse = Get-Stage8Facts
    Assert-Stage8KeyReuseOutcome (Invoke-Stage8Start $Context d_matrix $matrix ([pscustomobject] @{ Key = $kr.Key; Body = [pscustomobject] @{ intent = 'start_replacement' } }))
    Assert-Stage8KeyReuseOutcome (Invoke-Stage8Submit $Context d_matrix $attempt2 $ks)
    Assert-Stage8RowsUnchanged $beforeReuse (Get-Stage8Facts) @('assessment_attempts', 'idempotency_records', 'blitz_attempt_exceptions') 'key reuse against replacement #2'
    $ks2 = & $key
    Assert-Stage8ApiSuccess (Invoke-Stage8Answer $Context d_matrix $attempt2 $q.short_written @{ type = 'short_written'; text = 'E2E S08 replacement answer' })
    Assert-Stage8ApiSuccess (Invoke-Stage8Submit $Context d_matrix $attempt2 $ks2)
    $final = Get-Stage8Facts
    Assert-Stage8AttemptHistory $final $matrix $student | Out-Null
    Assert-Stage8TerminalAttempt (Get-Stage8Row $final assessment_attempts $attempt2) student_submit ([string] (Get-Stage8Row $final assessment_attempts $attempt2).submitted_at)

    # Timed-out and due targets: blitz_time_expired, with only canonical timeout reconciliation committed.
    $timeoutBlitz = $m.assessments.matrix_timeout
    $timeoutStart = Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz (New-Stage8StartRequest (& $key) start_normal)
    Assert-Stage8ApiSuccess $timeoutStart 201
    $timeoutAttempt = [string] $timeoutStart.Json.data.id
    Wait-Stage8ServerPast ([string] $timeoutStart.Json.data.deadline_at)
    $dueResume = New-Stage8StartRequest (& $key) resume $timeoutAttempt
    Assert-Stage8Rejection (Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz $dueResume) 409 blitz_time_expired $Context $dueResume.Key
    $timedOut = Get-Stage8Facts
    Assert-Stage8TerminalAttempt (Get-Stage8Row $timedOut assessment_attempts $timeoutAttempt) timeout_auto_submit ''
    foreach ($probe in @(
            { param($k) Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz (New-Stage8StartRequest $k resume $timeoutAttempt) },
            { param($k) Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz (New-Stage8StartRequest $k start_normal) },
            { param($k) Invoke-Stage8Submit $Context d_timeout_resume $timeoutAttempt $k })) {
        $k = & $key; Assert-Stage8Rejection (& $probe $k) 409 blitz_time_expired $Context $k
    }
    Assert-Stage8RowsUnchanged $timedOut (Get-Stage8Facts) @('assessment_attempts') 'timed-out target rejections'
    $timeoutStudent = [string] $m.users.d_timeout_resume
    Assert-Stage8ApiSuccess (Invoke-Stage8Grant $Context individual_teacher $timeoutBlitz $timeoutStudent (& $key) 'E2E S08 connection dropped before the deadline') 201
    $timeoutGranted = Get-Stage8Facts
    $staleTimeout = New-Stage8StartRequest (& $key) resume $timeoutAttempt
    $staleTimeoutResponse = Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz $staleTimeout
    Assert-Stage8Rejection $staleTimeoutResponse 409 blitz_time_expired $Context $staleTimeout.Key
    $k = & $key; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz (New-Stage8StartRequest $k start_normal)) 409 attempts_exhausted $Context $k
    $k = & $key; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz (New-Stage8StartRequest $k resume $attempt1)) 404 resource_not_found $Context $k
    Assert-Stage8NoSwitch $timeoutGranted (Get-Stage8Facts) $timeoutBlitz $timeoutStudent $staleTimeoutResponse $timeoutAttempt
    Assert-Stage8RowsUnchanged $timeoutGranted (Get-Stage8Facts) @('assessment_attempts', 'blitz_attempt_exceptions') 'stale and foreign Resume after the exception'
    $timeoutReplacement = Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz (New-Stage8StartRequest (& $key) start_replacement)
    Assert-Stage8ApiSuccess $timeoutReplacement 201
    $timeoutAttempt2 = [string] $timeoutReplacement.Json.data.id
    if ([int] $timeoutReplacement.Json.data.attempt_number -ne 2) { throw 'production defect: start_replacement after a timed-out #1 did not create #2.' }
    Wait-Stage8ServerPast ([string] $timeoutReplacement.Json.data.deadline_at)
    $dueResume2 = New-Stage8StartRequest (& $key) resume $timeoutAttempt2
    Assert-Stage8Rejection (Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz $dueResume2) 409 blitz_time_expired $Context $dueResume2.Key
    $timedOut2 = Get-Stage8Facts
    Assert-Stage8TerminalAttempt (Get-Stage8Row $timedOut2 assessment_attempts $timeoutAttempt2) timeout_auto_submit ''
    if ((Assert-Stage8AttemptHistory $timedOut2 $timeoutBlitz $timeoutStudent).Attempts.Count -ne 2) { throw 'production defect: Timed-out replacement history is not exactly #1 and #2.' }
    $k = & $key; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz (New-Stage8StartRequest $k start_replacement)) 409 blitz_time_expired $Context $k
    $k = & $key; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_timeout_resume $timeoutBlitz (New-Stage8StartRequest $k start_normal)) 409 attempts_exhausted $Context $k
    Assert-Stage8RowsUnchanged $timedOut2 (Get-Stage8Facts) @('assessment_attempts', 'blitz_attempt_exceptions') 'timed-out replacement rejections'
    $lateStart = Invoke-Stage8Start $Context d_late_submit $m.assessments.matrix_late_submit (New-Stage8StartRequest (& $key) start_normal)
    Assert-Stage8ApiSuccess $lateStart 201
    $lateAttempt = [string] $lateStart.Json.data.id
    Wait-Stage8ServerPast ([string] $lateStart.Json.data.deadline_at)
    $k = & $key
    Assert-Stage8Rejection (Invoke-Stage8Submit $Context d_late_submit $lateAttempt $k) 409 blitz_time_expired $Context $k
    $lateFacts = Get-Stage8Facts
    Assert-Stage8TerminalAttempt (Get-Stage8Row $lateFacts assessment_attempts $lateAttempt) timeout_auto_submit ''
    foreach ($seeded in @(@{ Actor = 'd_waiting'; Attempt = [string] $m.attempts.waiting_1 }, @{ Actor = 'd_checked'; Attempt = [string] $m.attempts.checked_1 })) {
        $k = & $key; Assert-Stage8Rejection (Invoke-Stage8Submit $Context $seeded.Actor $seeded.Attempt $k) 409 attempt_not_editable $Context $k
    }
    $k = & $key; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_waiting $m.assessments.forward_status (New-Stage8StartRequest $k resume ([string] $m.attempts.waiting_1))) 409 attempt_not_editable $Context $k
    $end = Get-Stage8Facts
    Assert-Stage8RowsUnchanged $lateFacts $end @('assessment_attempts') 'forward-compatible terminal rejections'
    foreach ($rejected in $Context.RejectedKeys) { Assert-Stage8NoIdempotencyRecord $end $rejected }
    Assert-Stage8NoStageNineScoring $end
    $evidence = [pscustomobject] @{ student = $student; attempt1 = $attempt1; attempt2 = $attempt2; start_normal = $k1; resume1 = $kr; start_replacement = $k2; resume2 = $kr2
        submit1 = $ks; submit2 = $ks2; grant = $kg; grant_reason = $reason; exception = [string] $grant.Json.data.id; timed_out = $timeoutAttempt; timed_out_replacement = $timeoutAttempt2
        late_submit = $lateAttempt; file_id = [string] $fileRow.id }
    Add-Stage8Evidence $Context 'execution_matrix' $evidence
    $evidence
}

# Section 40: activation durable idempotency and historical replay after Close.
function Invoke-Stage8ActivationIdempotency {
    param($Context)
    $m = $Context.Manifest
    $blitz = $m.assessments.activation_idem
    $k = New-Stage8Key 400
    $first = Invoke-Stage8Activate $Context individual_teacher $blitz $k
    Assert-Stage8ApiSuccess $first
    $facts = Get-Stage8Facts
    $row = Get-Stage8Row $facts blitz_tasks $blitz assessment_id
    Assert-Stage8BlitzLifecycle $row active individual 7200
    Assert-Stage8IdempotencyRecord (Get-Stage8IdempotencyRecord $facts $k teacher.blitz.activate) $m.institutions.individual ([string] $m.users.individual_teacher) teacher.blitz.activate $k blitz $blitz 200
    Wait-Stage8TimestampBoundary ([string] $row.activated_at)
    Assert-Stage8ReplayOutcome $first (Invoke-Stage8Activate $Context individual_teacher $blitz $k) 200 @('id', 'status', 'activated_at')
    Assert-Stage8Equal (Get-Stage8Row (Get-Stage8Facts) blitz_tasks $blitz assessment_id) $row 'activation replay writes nothing'
    $beforeReuse = Get-Stage8Facts
    Assert-Stage8KeyReuseOutcome (Invoke-Stage8Activate $Context individual_teacher $m.assessments.activation_idem_other $k)
    Assert-Stage8RowsUnchanged $beforeReuse (Get-Stage8Facts) @('blitz_tasks', 'assessment_students', 'idempotency_records') 'activation key reused on another Blitz'
    Assert-Stage8ApiSuccess (Invoke-Stage8Call $Context individual_teacher "/teacher/blitz/$blitz/close" POST -Body @{})
    $afterClose = Invoke-Stage8Activate $Context individual_teacher $blitz $k
    Assert-Stage8ApiSuccess $afterClose
    if ($afterClose.Json.data.status -cne 'closed' -or (ConvertTo-Stage8Instant $afterClose.Json.data.activated_at) -ne (ConvertTo-Stage8Instant $first.Json.data.activated_at)) { throw 'production defect: Activation replay after Close is not the historical current resource.' }
    $evidence = [pscustomobject] @{ blitz = $blitz; key = $k; activated_at = [string] $row.activated_at }
    Add-Stage8Evidence $Context 'activation_idempotency' $evidence
    $evidence
}

# Section 46: a replacement may start after the synchronized common end and gets its own full duration.
function Invoke-Stage8SyncReplacement {
    param($Context)
    $m = $Context.Manifest
    $blitz = $m.assessments.sync_replacement
    $student = [string] $m.users.sync_replacement
    Assert-Stage8ApiSuccess (Invoke-Stage8Activate $Context teacher $blitz (New-Stage8Key 420))
    $first = Invoke-Stage8Start $Context sync_replacement $blitz (New-Stage8StartRequest (New-Stage8Key 421) start_normal)
    Assert-Stage8ApiSuccess $first 201
    Assert-Stage8ApiSuccess (Invoke-Stage8Submit $Context sync_replacement ([string] $first.Json.data.id) (New-Stage8Key 422))
    $activated = Get-Stage8Row (Get-Stage8Facts) blitz_tasks $blitz assessment_id
    Assert-Stage8BlitzLifecycle $activated active synchronized 8
    Wait-Stage8ServerPast ([string] $activated.synchronized_ends_at)
    Assert-Stage8ApiSuccess (Invoke-Stage8Grant $Context teacher $blitz $student (New-Stage8Key 423) 'E2E S08 technical issue before the common end') 201
    $replacement = Invoke-Stage8Start $Context sync_replacement $blitz (New-Stage8StartRequest (New-Stage8Key 424) start_replacement)
    Assert-Stage8ApiSuccess $replacement 201
    $attempt2 = [string] $replacement.Json.data.id
    Assert-Stage8ApiSuccess (Invoke-Stage8Answer $Context sync_replacement $attempt2 $m.questions.sync_replacement.short_written @{ type = 'short_written'; text = 'E2E S08 after the common end' })
    Assert-Stage8ApiSuccess (Invoke-Stage8Submit $Context sync_replacement $attempt2 (New-Stage8Key 425))
    $k = New-Stage8Key 426; Assert-Stage8Rejection (Invoke-Stage8Start $Context sync_replacement $blitz (New-Stage8StartRequest $k start_normal)) 409 attempts_exhausted $Context $k
    $facts = Get-Stage8Facts
    $history = Assert-Stage8AttemptHistory $facts $blitz $student
    if ($history.Attempts.Count -ne 2 -or (ConvertTo-Stage8Instant $history.Attempts[1].started_at) -le (ConvertTo-Stage8Instant $activated.synchronized_ends_at) -or
        (ConvertTo-Stage8Instant $history.Attempts[1].deadline_at) -le (ConvertTo-Stage8Instant $activated.synchronized_ends_at)) { throw 'production defect: Replacement after the common end did not get its own full duration.' }
    Assert-Stage8Equal (Get-Stage8Row $facts blitz_tasks $blitz assessment_id).synchronized_ends_at $activated.synchronized_ends_at 'replacement leaves the common end unchanged'
    Assert-Stage8AnswerSet $facts $attempt2 @([string] $m.questions.sync_replacement.short_written) | Out-Null
    Add-Stage8Evidence $Context 'synchronized_replacement_after_common_end' ([pscustomobject] @{ blitz = $blitz; attempt2 = $attempt2; common_end = [string] $activated.synchronized_ends_at })
}

# Section 47: individual timing gives every Start its own full duration and no common end.
function Invoke-Stage8IndividualTiming {
    param($Context)
    $m = $Context.Manifest
    $blitz = $m.assessments.individual_timing
    Assert-Stage8ApiSuccess (Invoke-Stage8Activate $Context individual_teacher $blitz (New-Stage8Key 440))
    $detail = Invoke-Stage8Call $Context d_first "/student/blitz/$blitz"
    Assert-Stage8PreStartPrivacy $detail
    if ($null -ne $detail.Json.data.timing.deadline_at -or $null -ne $detail.Json.data.timing.remaining_seconds) { throw 'production defect: Individual pre-Start detail has an effective deadline.' }
    $first = Invoke-Stage8Start $Context d_first $blitz (New-Stage8StartRequest (New-Stage8Key 441) start_normal)
    Assert-Stage8ApiSuccess $first 201
    Wait-Stage8TimestampBoundary ([string] $first.Json.data.started_at)
    $second = Invoke-Stage8Start $Context d_second $blitz (New-Stage8StartRequest (New-Stage8Key 442) start_normal)
    Assert-Stage8ApiSuccess $second 201
    Assert-Stage8ApiSuccess (Invoke-Stage8Submit $Context d_first ([string] $first.Json.data.id) (New-Stage8Key 443))
    Assert-Stage8ApiSuccess (Invoke-Stage8Grant $Context individual_teacher $blitz ([string] $m.users.d_first) (New-Stage8Key 444) 'E2E S08 individual technical issue') 201
    $replacement = Invoke-Stage8Start $Context d_first $blitz (New-Stage8StartRequest (New-Stage8Key 445) start_replacement)
    Assert-Stage8ApiSuccess $replacement 201
    $facts = Get-Stage8Facts
    Assert-Stage8BlitzLifecycle (Get-Stage8Row $facts blitz_tasks $blitz assessment_id) active individual 7200
    $firstHistory = Assert-Stage8AttemptHistory $facts $blitz ([string] $m.users.d_first)
    $secondHistory = Assert-Stage8AttemptHistory $facts $blitz ([string] $m.users.d_second)
    if ($firstHistory.Attempts.Count -ne 2 -or $secondHistory.Attempts.Count -ne 1 -or
        (ConvertTo-Stage8Instant $secondHistory.Attempts[0].deadline_at) -le (ConvertTo-Stage8Instant $firstHistory.Attempts[0].deadline_at)) { throw 'production defect: A later individual Start did not receive its own full duration.' }
    Add-Stage8Evidence $Context 'individual_timing' ([pscustomobject] @{ blitz = $blitz; first = $firstHistory.Attempts[0].id; replacement = $firstHistory.Attempts[1].id; second = $secondHistory.Attempts[0].id })
}

# Section 47A.1: a selected-Student Blitz cannot become official but still runs as practice.
function Invoke-Stage8SelectedPractice {
    param($Context)
    $m = $Context.Manifest
    $blitz = $m.assessments.practice_blitz
    $before = Get-Stage8Facts
    $designation = Invoke-Stage8Call $Context teacher "/teacher/topics/$($m.topics.practice)/result-pair" PUT -Body @{ homework_assessment_id = $m.assessments.practice_homework; blitz_assessment_id = $blitz }
    Assert-Stage8ApiError $designation 409 official_task_requires_group_assignment
    Assert-Stage8RowsUnchanged $before (Get-Stage8Facts) @('topic_result_pairs', 'assessment_students', 'assessment_attempts', 'idempotency_records') 'rejected selected-Student designation'
    $k = New-Stage8Key 460
    Assert-Stage8ApiSuccess (Invoke-Stage8Activate $Context teacher $blitz $k)
    $activated = Get-Stage8Facts
    Assert-Stage8Recipients $activated $blitz @([string] $m.users.practice_member) 'selected practice'
    Assert-Stage8Equal @($activated.tables.topic_result_pairs) @($before.tables.topic_result_pairs) 'practice activation leaves the official pair'
    $start = Invoke-Stage8Start $Context practice_member $blitz (New-Stage8StartRequest (New-Stage8Key 461) start_normal)
    Assert-Stage8ApiSuccess $start 201
    Assert-Stage8ApiSuccess (Invoke-Stage8Submit $Context practice_member ([string] $start.Json.data.id) (New-Stage8Key 462))
    $outsider = New-Stage8StartRequest (New-Stage8Key 463) start_normal
    Assert-Stage8Rejection (Invoke-Stage8Call $Context practice_outsider "/student/blitz/$blitz") 404 resource_not_found $Context $null
    Assert-Stage8Rejection (Invoke-Stage8Start $Context practice_outsider $blitz $outsider) 404 resource_not_found $Context $outsider.Key
    $facts = Get-Stage8Facts
    if (@(Get-Stage8StudentAttempts $facts $blitz ([string] $m.users.practice_outsider)).Count -ne 0) { throw 'production defect: A non-recipient Student started the practice Blitz.' }
    Add-Stage8Evidence $Context 'selected_practice_official_denial' ([pscustomobject] @{ blitz = $blitz; pair = $m.pairs.practice; attempt = [string] $start.Json.data.id })
}

# Sections 47A.2-47A.3: Blitz-first official activity establishes the cohort and still admits the Homework.
function Invoke-Stage8BlitzFirst {
    param($Context)
    $m = $Context.Manifest
    $blitz = $m.assessments.bf_blitz; $homework = $m.assessments.bf_homework
    $cohort = @([string] $m.users.bf_one, [string] $m.users.bf_two)
    $before = Get-Stage8Facts
    $pairBefore = Get-Stage8Row $before topic_result_pairs $m.pairs.blitz_first
    if ($null -ne $pairBefore.cohort_snapshotted_at -or $null -ne $pairBefore.locked_at) { throw 'integration-harness defect: Blitz-first pair baseline is not empty.' }
    Assert-Stage8ApiSuccess (Invoke-Stage8Activate $Context teacher $blitz (New-Stage8Key 480))
    $activated = Get-Stage8Facts
    $blitzRow = Get-Stage8Row $activated blitz_tasks $blitz assessment_id
    Assert-Stage8CohortEstablished (Get-Stage8Row $activated topic_result_pairs $m.pairs.blitz_first) $blitzRow $activated $cohort $homework
    if (@(Get-Stage8Rows $activated assessment_attempts assessment_id $blitz).Count -ne 0) { throw 'production defect: Activation created a Student Attempt.' }
    $start = Invoke-Stage8Start $Context bf_one $blitz (New-Stage8StartRequest (New-Stage8Key 481) start_normal)
    Assert-Stage8ApiSuccess $start 201
    $afterBlitzStart = Get-Stage8Facts
    $pairAfterBlitz = Get-Stage8Row $afterBlitzStart topic_result_pairs $m.pairs.blitz_first
    if (@(Get-Stage8Rows $afterBlitzStart assessment_attempts assessment_id $homework).Count -ne 0) { throw 'production defect: Blitz Start created a Homework Attempt.' }
    $activation = Invoke-Stage8Call $Context teacher "/teacher/homework/$homework/activate" POST -Body @{}
    Wait-Stage8TimestampBoundary ([string] $pairAfterBlitz.updated_at)
    $homeworkStart = Invoke-Stage8Call $Context bf_one "/student/homework/$homework/attempts" POST -Key (New-Stage8Key 482) -Body @{}
    $final = Get-Stage8Facts
    Assert-Stage8BlitzFirstHomework $activation $homeworkStart $pairAfterBlitz (Get-Stage8Row $final topic_result_pairs $m.pairs.blitz_first) (Get-Stage8Row $afterBlitzStart assessment_attempts ([string] $start.Json.data.id)) $final $homework $cohort
    Assert-Stage8Equal @(Get-Stage8Rows $final assessment_attempts assessment_id $blitz) @(Get-Stage8Rows $afterBlitzStart assessment_attempts assessment_id $blitz) 'Homework Start leaves the Blitz history'
    Add-Stage8Evidence $Context 'blitz_first_cohort_and_homework' ([pscustomobject] @{ blitz = $blitz; homework = $homework; blitz_attempt = [string] $start.Json.data.id; homework_attempt = [string] $homeworkStart.Json.data.id })
}

# Section 47A.4: an unset Institution timer mode blocks activation atomically.
function Invoke-Stage8UnsetTimer {
    param($Context)
    $m = $Context.Manifest
    $blitz = $m.assessments.unset
    $k = New-Stage8Key 500
    $before = Get-Stage8Facts
    if ($null -ne (Get-Stage8Row $before institution_settings $m.institutions.unset institution_id).blitz_timer_start_mode) { throw 'integration-harness defect: The unset-timer Institution has a timer mode.' }
    Assert-Stage8BlitzLifecycle (Get-Stage8Row $before blitz_tasks $blitz assessment_id) draft $null 600
    if (@(Get-Stage8Rows $before assessment_students assessment_id $blitz).Count -ne 0) { throw 'integration-harness defect: The unset-timer Blitz already has activation recipients.' }
    Assert-Stage8Rejection (Invoke-Stage8Activate $Context unset_teacher $blitz $k) 409 institution_settings_incomplete $Context $k
    Assert-Stage8NoActivationWrites $before (Get-Stage8Facts) $blitz $k
    Add-Stage8Evidence $Context 'unset_timer_activation_rollback' ([pscustomobject] @{ blitz = $blitz; key = $k })
}

# Sections 47A.5-47A.6: writes after the deadline never change the frozen Attempt.
function Invoke-Stage8LateWrites {
    param($Context)
    $m = $Context.Manifest
    $typedStart = Invoke-Stage8Start $Context d_late_typed $m.assessments.late_typed (New-Stage8StartRequest (New-Stage8Key 510) start_normal)
    Assert-Stage8ApiSuccess $typedStart 201
    $typedAttempt = [string] $typedStart.Json.data.id
    $typedQuestion = [string] $m.questions.late_typed.short_written
    Assert-Stage8ApiSuccess (Invoke-Stage8Answer $Context d_late_typed $typedAttempt $typedQuestion @{ type = 'short_written'; text = 'E2E S08 saved before the deadline' })
    $fileStart = Invoke-Stage8Start $Context d_late_file $m.assessments.late_file (New-Stage8StartRequest (New-Stage8Key 511) start_normal)
    Assert-Stage8ApiSuccess $fileStart 201
    $fileAttempt = [string] $fileStart.Json.data.id
    $fileQuestion = [string] $m.questions.late_file.file_based
    Assert-Stage8ApiSuccess (Invoke-Stage8Call $Context d_late_file "/student/attempts/$fileAttempt/answers/$fileQuestion" PUT -FilePath $Context.Files.Files['answer_pdf'].path)
    Wait-Stage8ServerPast ([string] $typedStart.Json.data.deadline_at)
    $before = Get-Stage8Facts
    Assert-Stage8ApiError (Invoke-Stage8Answer $Context d_late_typed $typedAttempt $typedQuestion @{ type = 'short_written'; text = 'E2E S08 late write' }) 409 blitz_time_expired
    $afterTyped = Get-Stage8Facts
    Assert-Stage8TerminalAttempt (Get-Stage8Row $afterTyped assessment_attempts $typedAttempt) timeout_auto_submit ''
    Assert-Stage8LateWriteUnchanged $before $afterTyped $typedAttempt
    Assert-Stage8TypedAnswer $afterTyped @(Get-Stage8Rows $afterTyped attempt_answers attempt_id $typedAttempt)[0] short_written @('E2E S08 saved before the deadline')
    Wait-Stage8ServerPast ([string] $fileStart.Json.data.deadline_at)
    $beforeFile = Get-Stage8Facts
    Assert-Stage8ApiError (Invoke-Stage8Call $Context d_late_file "/student/attempts/$fileAttempt/answers/$fileQuestion" PUT -FilePath $Context.Files.Files['replacement_docx'].path) 409 blitz_time_expired
    $afterFile = Get-Stage8Facts
    Assert-Stage8TerminalAttempt (Get-Stage8Row $afterFile assessment_attempts $fileAttempt) timeout_auto_submit ''
    Assert-Stage8LateWriteUnchanged $beforeFile $afterFile $fileAttempt
    $answer = @(Get-Stage8Rows $afterFile attempt_answers attempt_id $fileAttempt)[0]
    $file = Get-Stage8Row $afterFile files (Get-Stage8Row $afterFile answer_files $answer.id answer_id).file_id
    Assert-Stage8File $afterFile $file (Get-Stage8FileExpectation $Context.Files answer_pdf) (Get-Stage8Row $afterFile assessment_attempts $fileAttempt) $fileQuestion
    Add-Stage8Evidence $Context 'late_writes' ([pscustomobject] @{ typed_attempt = $typedAttempt; file_attempt = $fileAttempt; file = $file.id })
}

function Get-Stage8RaceValue {
    param([AllowNull()] $Value, [string] $Written, [string] $Prior)
    if ($null -ne $Value -and [string] $Value -ceq $Written) { 'written' } elseif ($null -ne $Value -and [string] $Value -ceq $Prior) { 'prior' } else { 'other' }
}

# The Submit response is built inside the Submit transaction, so it shows exactly what was frozen.
function Get-Stage8FrozenAnswer {
    param($SubmitResponse, [string] $QuestionId)
    if ([int] $SubmitResponse.StatusCode -ne 200 -or $null -eq $SubmitResponse.Json) { return $null }
    $states = @($SubmitResponse.Json.data.answers | Where-Object { [string] $_.question_id -ceq $QuestionId })
    if ($states.Count -ne 1) { throw 'production defect: The Submit response does not carry exactly one frozen state for the raced Question.' }
    $states[0].answer
}

# Sections 47A.7-47A.8: real write-vs-Submit races, proven simultaneous inside PostgreSQL first.
function Invoke-Stage8Races {
    param($Context)
    $m = $Context.Manifest
    $base = $Context.ApiBaseUrl
    $results = [ordered] @{}
    $typedStart = Invoke-Stage8Start $Context d_race_typed $m.assessments.race_typed (New-Stage8StartRequest (New-Stage8Key 530) start_normal)
    Assert-Stage8ApiSuccess $typedStart 201
    $typedAttempt = [string] $typedStart.Json.data.id
    $typedQuestion = [string] $m.questions.race_typed.short_written
    Assert-Stage8ApiSuccess (Invoke-Stage8Answer $Context d_race_typed $typedAttempt $typedQuestion @{ type = 'short_written'; text = 'E2E S08 race prior' })
    $submitKey = New-Stage8Key 531
    $probe = Invoke-Stage8OverlapProbe -AttemptId $typedAttempt -Runtime $Context.Runtime `
        -RequestA @{ Method = 'PUT'; Url = "$base/student/attempts/$typedAttempt/answers/$typedQuestion"; Body = (@{ type = 'short_written'; text = 'E2E S08 race written' } | ConvertTo-Json -Compress) } -TokenA (Get-Stage8Token $Context d_race_typed -Fresh) `
        -RequestB @{ Method = 'POST'; Url = "$base/student/attempts/$typedAttempt/submit"; Key = $submitKey; Body = '{}' } -TokenB (Get-Stage8Token $Context d_race_typed -Fresh)
    $facts = Get-Stage8Facts
    $answer = @(Get-Stage8Rows $facts attempt_answers attempt_id $typedAttempt)[0]
    $text = [string] @($facts.tables.answer_text_values | Where-Object answer_id -CEQ $answer.id)[0].text_value
    $value = Get-Stage8RaceValue $text 'E2E S08 race written' 'E2E S08 race prior'
    $frozen = Get-Stage8FrozenAnswer $probe.B $typedQuestion
    $frozenValue = Get-Stage8RaceValue $(if ($null -ne $frozen) { $frozen.text }) 'E2E S08 race written' 'E2E S08 race prior'
    $branch = Assert-Stage8RaceBranch $probe.A $probe.B $facts $typedAttempt $typedQuestion $value $frozenValue
    if (@($facts.tables.idempotency_records | Where-Object { $_.operation -ceq 'student.blitz.attempt.submit' -and $_.result_resource_id -ceq $typedAttempt }).Count -ne 1) { throw 'production defect: Typed race did not leave exactly one Submit result.' }
    $results.typed = [pscustomobject] @{ attempt = $typedAttempt; branch = $branch; first_launched = $probe.FirstLaunched; evidence = $probe.Evidence }

    $fileStart = Invoke-Stage8Start $Context d_race_file $m.assessments.race_file (New-Stage8StartRequest (New-Stage8Key 532) start_normal)
    Assert-Stage8ApiSuccess $fileStart 201
    $fileAttempt = [string] $fileStart.Json.data.id
    $fileQuestion = [string] $m.questions.race_file.file_based
    $priorUpload = Invoke-Stage8Call $Context d_race_file "/student/attempts/$fileAttempt/answers/$fileQuestion" PUT -FilePath $Context.Files.Files['answer_pdf'].path
    Assert-Stage8ApiSuccess $priorUpload
    $fileKey = New-Stage8Key 533
    $probe = Invoke-Stage8OverlapProbe -AttemptId $fileAttempt -Runtime $Context.Runtime `
        -RequestA @{ Method = 'PUT'; Url = "$base/student/attempts/$fileAttempt/answers/$fileQuestion"; FilePath = $Context.Files.Files['replacement_docx'].path } -TokenA (Get-Stage8Token $Context d_race_file -Fresh) `
        -RequestB @{ Method = 'POST'; Url = "$base/student/attempts/$fileAttempt/submit"; Key = $fileKey; Body = '{}' } -TokenB (Get-Stage8Token $Context d_race_file -Fresh)
    $facts = Get-Stage8Facts
    $answer = @(Get-Stage8Rows $facts attempt_answers attempt_id $fileAttempt)[0]
    $file = Get-Stage8Row $facts files (Get-Stage8Row $facts answer_files $answer.id answer_id).file_id
    $value = Get-Stage8RaceValue $file.checksum_sha256 $Context.Files.Files['replacement_docx'].sha256 $Context.Files.Files['answer_pdf'].sha256
    # Each upload is a new File row, so the frozen File id names the branch exactly.
    $writtenFileId = if ([int] $probe.A.StatusCode -eq 200) { [string] $probe.A.Json.data.answer.file.id } else { '' }
    $frozen = Get-Stage8FrozenAnswer $probe.B $fileQuestion
    $frozenValue = Get-Stage8RaceValue $(if ($null -ne $frozen) { $frozen.file.id }) $writtenFileId ([string] $priorUpload.Json.data.answer.file.id)
    $branch = Assert-Stage8RaceBranch $probe.A $probe.B $facts $fileAttempt $fileQuestion $value $frozenValue
    if ([string] $file.id -cne $(if ($value -ceq 'written') { $writtenFileId } else { [string] $priorUpload.Json.data.answer.file.id })) { throw 'production defect: The persisted raced File is not the one its branch uploaded.' }
    if (@($facts.tables.idempotency_records | Where-Object { $_.operation -ceq 'student.blitz.attempt.submit' -and $_.result_resource_id -ceq $fileAttempt }).Count -ne 1) { throw 'production defect: File race did not leave exactly one Submit result.' }
    $fixture = if ($value -ceq 'written') { 'replacement_docx' } else { 'answer_pdf' }
    Assert-Stage8File $facts $file (Get-Stage8FileExpectation $Context.Files $fixture) (Get-Stage8Row $facts assessment_attempts $fileAttempt) $fileQuestion
    $results.file = [pscustomobject] @{ attempt = $fileAttempt; branch = $branch; first_launched = $probe.FirstLaunched; evidence = $probe.Evidence }
    Add-Stage8Evidence $Context 'write_vs_submit_races' ([pscustomobject] $results)
}

# Section 59: Teacher Close finalizes future Attempts as closed and due ones at their deadline.
function Invoke-Stage8TeacherClose {
    param($Context, $Execution)
    $m = $Context.Manifest
    $blitz = $m.assessments.close
    $future = Invoke-Stage8Start $Context d_close_future $blitz (New-Stage8StartRequest (New-Stage8Key 550) start_normal)
    Assert-Stage8ApiSuccess $future 201
    $futureAttempt = [string] $future.Json.data.id
    Assert-Stage8ApiSuccess (Invoke-Stage8Call $Context individual_teacher "/teacher/blitz/$blitz/close" POST -Body @{})
    $closed = Get-Stage8Facts
    $blitzRow = Get-Stage8Row $closed blitz_tasks $blitz assessment_id
    Assert-Stage8BlitzLifecycle $blitzRow closed individual 600
    Assert-Stage8TerminalAttempt (Get-Stage8Row $closed assessment_attempts $m.attempts.close_due_1) timeout_auto_submit ''
    Assert-Stage8TerminalAttempt (Get-Stage8Row $closed assessment_attempts $futureAttempt) task_closed_auto_finalize ([string] $blitzRow.closed_at)
    if (@(Get-Stage8StudentAttempts $closed $blitz ([string] $m.users.d_close_never)).Count -ne 0) { throw 'production defect: Close fabricated an Attempt for a never-started Student.' }
    Wait-Stage8TimestampBoundary ([string] $blitzRow.closed_at)
    Assert-Stage8ApiSuccess (Invoke-Stage8Call $Context individual_teacher "/teacher/blitz/$blitz/close" POST -Body @{})
    Assert-Stage8RowsUnchanged $closed (Get-Stage8Facts) @('blitz_tasks', 'assessment_attempts') 'repeated Close'
    $k = New-Stage8Key 551; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_close_future $blitz (New-Stage8StartRequest $k resume $futureAttempt)) 409 blitz_not_active $Context $k
    $k = New-Stage8Key 552; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_close_never $blitz (New-Stage8StartRequest $k start_normal)) 409 blitz_not_active $Context $k
    $k = New-Stage8Key 553; Assert-Stage8Rejection (Invoke-Stage8Submit $Context d_close_future $futureAttempt $k) 409 attempt_not_editable $Context $k
    Assert-Stage8ApiError (Invoke-Stage8Answer $Context d_close_future $futureAttempt $m.questions.close.short_written @{ type = 'short_written'; text = 'E2E S08 after Close' }) 409 blitz_not_active
    Assert-Stage8ApiError (Invoke-Stage8Call $Context individual_teacher "/teacher/blitz/$blitz/monitoring") 409 task_closed
    $futureReplay = Invoke-Stage8Start $Context d_close_future $blitz (New-Stage8StartRequest (New-Stage8Key 550) start_normal)
    Assert-Stage8ApiSuccess $futureReplay 201
    if ([string] $futureReplay.Json.data.id -cne $futureAttempt -or $futureReplay.Json.data.status -cne 'submitted' -or $futureReplay.Json.data.finalization_reason -cne 'task_closed_auto_finalize') { throw 'production defect: A completed Start replay after Close is not the current finalized Attempt.' }
    Assert-Stage8RowsUnchanged $closed (Get-Stage8Facts) @('assessment_attempts', 'attempt_answers', 'idempotency_records') 'requests after Close'

    # The execution matrix Blitz is closed too, so its completed Start and grant keys replay on a closed Blitz.
    $matrix = $m.assessments.matrix
    Assert-Stage8ApiSuccess (Invoke-Stage8Call $Context individual_teacher "/teacher/blitz/$matrix/close" POST -Body @{})
    $matrixClosed = Get-Stage8Facts
    Assert-Stage8BlitzLifecycle (Get-Stage8Row $matrixClosed blitz_tasks $matrix assessment_id) closed individual 7200
    foreach ($pair in @(@{ Request = $Execution.start_normal; Status = 201; Attempt = $Execution.attempt1 }, @{ Request = $Execution.resume1; Status = 200; Attempt = $Execution.attempt1 },
            @{ Request = $Execution.start_replacement; Status = 201; Attempt = $Execution.attempt2 }, @{ Request = $Execution.resume2; Status = 200; Attempt = $Execution.attempt2 })) {
        $response = Invoke-Stage8Start $Context d_matrix $matrix $pair.Request
        Assert-Stage8ApiSuccess $response $pair.Status
        if ([string] $response.Json.data.id -cne $pair.Attempt) { throw 'production defect: A Start replay after Close switched Attempts.' }
    }
    $grantReplay = Invoke-Stage8Grant $Context individual_teacher $matrix $Execution.student $Execution.grant $Execution.grant_reason
    Assert-Stage8ApiSuccess $grantReplay 201
    if ([string] $grantReplay.Json.data.id -cne $Execution.exception) { throw 'production defect: A grant replay after Close returned another exception.' }
    $k = New-Stage8Key 554; Assert-Stage8Rejection (Invoke-Stage8Start $Context d_matrix $matrix (New-Stage8StartRequest $k start_normal)) 409 blitz_not_active $Context $k
    $k = New-Stage8Key 555; Assert-Stage8Rejection (Invoke-Stage8Grant $Context individual_teacher $matrix ([string] $m.users.d_matrix_peer) $k 'E2E S08 after Close') 409 blitz_attempt_exception_not_allowed $Context $k
    Assert-Stage8RowsUnchanged $matrixClosed (Get-Stage8Facts) @('assessment_attempts', 'blitz_attempt_exceptions', 'idempotency_records', 'blitz_tasks') 'replays and rejections on the closed matrix Blitz'
    Add-Stage8Evidence $Context 'teacher_close' ([pscustomobject] @{ blitz = $blitz; closed_at = [string] $blitzRow.closed_at; future = $futureAttempt; due = [string] $m.attempts.close_due_1 })
}

# Section 60: monitoring reconciles due Attempts first and projects the exact roster without scores.
function Invoke-Stage8MonitoringApi {
    param($Context)
    $m = $Context.Manifest
    $blitz = $m.assessments.monitoring
    $path = "/teacher/blitz/$blitz/monitoring"
    $first = Invoke-Stage8Call $Context individual_teacher $path
    Assert-Stage8MonitoringPrivacy $first
    $facts = Get-Stage8Facts
    Assert-Stage8TerminalAttempt (Get-Stage8Row $facts assessment_attempts $m.attempts.mon_due_1) timeout_auto_submit ''
    $summary = $first.Json.data.summary
    Assert-Stage8Equal @([int] $summary.assigned, [int] $summary.not_started, [int] $summary.in_progress, [int] $summary.finalized, [int] $summary.attempt_exceptions_granted) @(5, 3, 0, 2, 1) 'monitoring summary partition'
    $rows = @{}
    foreach ($row in @($first.Json.data.students)) { $rows[[string] $row.student.id] = $row }
    Assert-Stage8Set @($rows.Keys) @('mon_due', 'mon_exception', 'mon_never', 'mon_inactive', 'mon_submitted' | ForEach-Object { [string] $m.users.$_ }) 'monitoring roster including the inactive historical recipient'
    $exceptionRow = $rows[[string] $m.users.mon_exception]
    if ($exceptionRow.status -cne 'not_started' -or $null -eq $exceptionRow.attempt_exception) { throw 'production defect: An unused exception does not project not_started.' }
    if ($rows[[string] $m.users.mon_due].status -cne 'finalized' -or $rows[[string] $m.users.mon_due].finalization_reason -cne 'timeout_auto_submit') { throw 'production defect: Monitoring did not reconcile the due Attempt before responding.' }
    $replacement = Invoke-Stage8Start $Context mon_exception $blitz (New-Stage8StartRequest (New-Stage8Key 570) start_replacement)
    Assert-Stage8ApiSuccess $replacement 201
    $second = Invoke-Stage8Call $Context individual_teacher $path
    Assert-Stage8MonitoringPrivacy $second
    $current = @($second.Json.data.students | Where-Object { [string] $_.student.id -ceq [string] $m.users.mon_exception })[0]
    if ($current.status -cne 'in_progress' -or [int] $current.attempt_number -ne 2) { throw 'production defect: Monitoring did not make replacement #2 current.' }
    Assert-Stage8ApiSuccess (Invoke-Stage8Submit $Context mon_exception ([string] $replacement.Json.data.id) (New-Stage8Key 571))
    Add-Stage8Evidence $Context 'monitoring_api' ([pscustomobject] @{ blitz = $blitz; replacement = [string] $replacement.Json.data.id })
}

# Section 44: the global Scheduler runs twice, each time only after a fresh ownership scan.
function Invoke-Stage8SchedulerPhase {
    param($Context)
    $m = $Context.Manifest
    $first = Invoke-Stage8GuardedScheduler -Invocation First
    $facts = Get-Stage8Facts
    Assert-Stage8TerminalAttempt (Get-Stage8Row $facts assessment_attempts $m.attempts.sched_due_1) timeout_auto_submit ''
    $future = Get-Stage8Row $facts assessment_attempts $m.attempts.sched_future_2
    if ($future.status -cne 'in_progress') { throw 'production defect: The Scheduler timed out a future replacement #2 at the common end.' }
    Assert-Stage8BlitzLifecycle (Get-Stage8Row $facts blitz_tasks $m.assessments.scheduler assessment_id) active synchronized ([int] $m.scheduler_duration)
    Assert-Stage8AttemptHistory $facts $m.assessments.scheduler ([string] $m.users.sched_future) | Out-Null
    Wait-Stage8TimestampBoundary ([string] (Get-Stage8Row $facts assessment_attempts $m.attempts.sched_due_1).updated_at)
    $second = Invoke-Stage8GuardedScheduler -Invocation Second
    Assert-Stage8RowsUnchanged $facts (Get-Stage8Facts) @('assessment_attempts', 'blitz_tasks') 'second Scheduler invocation'
    Add-Stage8Evidence $Context 'guarded_scheduler' ([pscustomobject] @{ first = $first.Counts; second = $second.Counts; due = [string] $m.attempts.sched_due_1; future = [string] $m.attempts.sched_future_2 })
}

# Section 65: after a backend restart every completed request replays with its exact original tuple.
function Get-Stage8MonitoringState {
    param($Context)
    $response = Invoke-Stage8Call $Context teacher "/teacher/blitz/$($Context.Manifest.assessments.scheduler)/monitoring"
    Assert-Stage8MonitoringPrivacy $response
    # Logical state only: the clock-derived fields move between two reads.
    [pscustomobject] @{ summary = $response.Json.data.summary; students = @($response.Json.data.students | ForEach-Object {
        [pscustomobject] @{ id = $_.student.id; status = $_.status; attempt_number = $_.attempt_number; started_at = $_.started_at; deadline_at = $_.deadline_at
            finalization_reason = $_.finalization_reason; exception = ($null -ne $_.attempt_exception) } }) }
}

function Invoke-Stage8PostRestartReplays {
    param($Context, $Execution, $Activation, $UiEvidence, $MonitoringBefore)
    $m = $Context.Manifest
    $before = Get-Stage8Facts
    $matrix = $m.assessments.matrix
    # PowerShell names are case-insensitive, so the replay response must not reuse $Activation.
    $activationReplay = Invoke-Stage8Activate $Context individual_teacher $Activation.blitz $Activation.key
    Assert-Stage8ApiSuccess $activationReplay
    if ($activationReplay.Json.data.status -cne 'closed') { throw 'production defect: Post-restart activation replay lost the historical lifecycle.' }
    foreach ($pair in @(@{ Request = $Execution.start_normal; Status = 201; Attempt = $Execution.attempt1 }, @{ Request = $Execution.resume1; Status = 200; Attempt = $Execution.attempt1 },
            @{ Request = $Execution.start_replacement; Status = 201; Attempt = $Execution.attempt2 }, @{ Request = $Execution.resume2; Status = 200; Attempt = $Execution.attempt2 })) {
        Assert-Stage8StartRequest $pair.Request
        $response = Invoke-Stage8Start $Context d_matrix $matrix $pair.Request
        Assert-Stage8ApiSuccess $response $pair.Status
        if ([string] $response.Json.data.id -cne $pair.Attempt) { throw 'production defect: A post-restart Start replay switched Attempts.' }
    }
    Assert-Stage8ApiSuccess (Invoke-Stage8Submit $Context d_matrix $Execution.attempt1 $Execution.submit1)
    $grant = Invoke-Stage8Grant $Context individual_teacher $matrix $Execution.student $Execution.grant $Execution.grant_reason
    Assert-Stage8ApiSuccess $grant 201
    if ([string] $grant.Json.data.id -cne $Execution.exception) { throw 'production defect: Post-restart grant replay returned another exception.' }
    Assert-Stage8Equal (Get-Stage8MonitoringState $Context) $MonitoringBefore 'monitoring logical state after restart'
    $download = Invoke-Stage8Call $Context student "/files/$($UiEvidence.file_id)/download" -Binary
    Assert-Stage8Download $download $Context.Files.Files['answer_pdf']
    $after = Get-Stage8Facts
    Assert-Stage8Equal $after.tables $before.tables 'post-restart replays change nothing'
    Assert-Stage8Equal $after.blobs $before.blobs 'post-restart private files unchanged'
    Add-Stage8Evidence $Context 'post_restart_replays' ([pscustomobject] @{ activation = $Activation.key; start_replays = 4; submit = $Execution.submit1; grant = $Execution.grant })
}
