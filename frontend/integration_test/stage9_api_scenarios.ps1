Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage9_api_security.ps1')

# ---------------------------------------------------------------- production calls

function Start-Stage9Homework {
    param($Context, [string] $Actor, [string] $HomeworkId, [string] $Key)
    $response = Invoke-Stage9Call $Context $Actor "/student/homework/$HomeworkId/attempts" POST -Key $Key -Body @{}
    Assert-Stage9ApiSuccess $response 201
    [string] $response.Json.data.id
}

function Start-Stage9Blitz {
    param($Context, [string] $Actor, [string] $BlitzId, [string] $Key, [ValidateSet('start_normal', 'start_replacement')][string] $Intent = 'start_normal')
    $response = Invoke-Stage9Call $Context $Actor "/student/blitz/$BlitzId/attempts" POST -Key $Key -Body @{ intent = $Intent }
    Assert-Stage9ApiSuccess $response 201
    [string] $response.Json.data.id
}

function Save-Stage9Answer {
    param($Context, [string] $Actor, [string] $AttemptId, [string] $QuestionId, $Body)
    $response = Invoke-Stage9Call $Context $Actor "/student/attempts/$AttemptId/answers/$QuestionId" PUT -Body $Body
    Assert-Stage9ApiSuccess $response
    $response.Json.data
}

function Save-Stage9File {
    param($Context, [string] $Actor, [string] $AttemptId, [string] $QuestionId)
    $response = Invoke-Stage9Call $Context $Actor "/student/attempts/$AttemptId/answers/$QuestionId" PUT -FilePath $Context.Files.Files['answer_pdf'].path
    Assert-Stage9ApiSuccess $response
    $response.Json.data
}

# The Submit response is built before checking runs, so it keeps the frozen Stage 7/8 status.
function Submit-Stage9Attempt {
    param($Context, [string] $Actor, [string] $AttemptId, [string] $Key, [string] $Message)
    $response = Invoke-Stage9Call $Context $Actor "/student/attempts/$AttemptId/submit" POST -Key $Key -Body @{}
    Assert-Stage9ApiSuccess $response
    if ([string] $response.Json.data.status -cne 'submitted' -or [string] $response.Json.message -cne $Message) { throw 'production defect: Stage 9 Submit response changed its frozen Stage 7/8 shape.' }
    $response.Json.data
}

function Get-Stage9Choice { param($Context, [string] $Assessment, [string] $Label, [int[]] $Positions) @($Positions | ForEach-Object { [string] $Context.Manifest.nested.$Assessment.$Label[$_ - 1] }) }

function Get-Stage9SubmissionAnswers {
    param($Context, [string] $Teacher, [string] $SubmissionId)
    $response = Invoke-Stage9Call $Context $Teacher "/teacher/submissions/$SubmissionId"
    Assert-Stage9ApiSuccess $response
    $answers = @{}
    foreach ($entry in @($response.Json.data.questions)) { if ($null -ne $entry.answer) { $answers[[string] $entry.question.id] = [string] $entry.answer.id } }
    $answers
}

function Save-Stage9Review {
    param($Context, [string] $Teacher, [string] $SubmissionId, [object[]] $Items)
    $response = Invoke-Stage9Call $Context $Teacher "/teacher/submissions/$SubmissionId/review" PUT -Body @{ answers = $Items }
    Assert-Stage9ApiSuccess $response
    if ([string] $response.Json.message -cne 'Submission review saved successfully.') { throw 'production defect: Stage 9 review save message changed.' }
    $response.Json.data
}

function Get-Stage9TeacherOfficial {
    param($Context, [string] $Teacher, [string] $AssessmentId, [string] $StudentId)
    $response = Invoke-Stage9Call $Context $Teacher "/teacher/assessments/$AssessmentId/students/$StudentId/official-score"
    Assert-Stage9ApiSuccess $response
    $response.Json.data
}

function Assert-Stage9Score {
    param([AllowNull()] $Actual, [AllowNull()] $Expected, [string] $Label)
    if ($null -eq $Expected) { if ($null -ne $Actual) { throw "production defect: Stage 9 $Label must be null." }; return }
    if ($null -eq $Actual -or ([decimal] [string] $Actual) -ne ([decimal] [string] $Expected)) { throw "production defect: Stage 9 $Label is $Actual, expected $Expected." }
}

function Assert-Stage9TeacherOfficial {
    param($Data, [string] $Status, [AllowNull()][string] $AttemptId, [AllowNull()] $AttemptNumber, [AllowNull()] $Score, [AllowNull()][string] $Policy, [string] $Label)
    if ([string] $Data.status -cne $Status -or [string] $Data.official_attempt_id -cne [string] $AttemptId -or
        [string] $Data.selection_policy_code -cne [string] $Policy -or [string] $Data.attempt_number -cne [string] $AttemptNumber) { throw "production defect: Stage 9 Teacher official read mismatch: $Label." }
    Assert-Stage9Score $Data.normalized_score $Score "Teacher official score ($Label)"
    if (($Status -ceq 'ready') -ne ($null -ne $Data.selected_at)) { throw "production defect: Stage 9 Teacher official read selected_at mismatch: $Label." }
}

function Assert-Stage9StudentOfficial {
    param($Homework, [AllowNull()] $Score, [AllowNull()] $AttemptNumber, [string] $Label)
    if ($null -eq $Score) { if ($null -ne $Homework.official_score) { throw "production defect: Stage 9 Student official score must be hidden: $Label." }; return }
    if ($null -eq $Homework.official_score -or [int] $Homework.official_score.attempt_number -ne $AttemptNumber) { throw "production defect: Stage 9 Student official score mismatch: $Label." }
    Assert-Stage9Score $Homework.official_score.normalized_score $Score "Student official score ($Label)"
}

function Assert-Stage9StudentResult {
    param($Result, [bool] $Visible, [AllowNull()] $Score, [string] $Label)
    if ($Result.visible -ne $Visible) { throw "production defect: Stage 9 Student result visibility mismatch: $Label." }
    Assert-Stage9Score $Result.normalized_score $Score "Student result ($Label)"
}

function Assert-Stage9NoResultKeys {
    param([AllowNull()] $Value, [string] $Label)
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return }
    if ($Value -is [array]) { foreach ($item in $Value) { Assert-Stage9NoResultKeys $item $Label }; return }
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.Name -cin @('result', 'normalized_score', 'feedback', 'score', 'score_visible', 'official_score')) { throw "production defect: P1 Stage 9 active Blitz read carries $($property.Name): $Label." }
        Assert-Stage9NoResultKeys $property.Value $Label
    }
}

function Wait-Stage9Checked { param([string] $AttemptId, [string] $Status) Wait-Stage9AttemptStatus -AttemptId $AttemptId -Status $Status }

# ---------------------------------------------------------------- section 9.1 API setup and trigger checking

function Invoke-Stage9FreezeTriggerChecking {
    param($Context)
    $m = $Context.Manifest
    $hw = [string] $m.assessments.review_hw
    $q = $m.questions.review_hw
    $attempt = Start-Stage9Homework $Context student $hw (New-Stage9Key 101)
    $saved = @(
        (Save-Stage9Answer $Context student $attempt $q.q1 @{ type = 'single_choice'; selected_option_ids = @(Get-Stage9Choice $Context review_hw q1 @(2)) }),
        (Save-Stage9Answer $Context student $attempt $q.q2 @{ type = 'multiple_choice'; selected_option_ids = @(Get-Stage9Choice $Context review_hw q2 @(1, 3, 4)) }),
        (Save-Stage9Answer $Context student $attempt $q.q3 @{ type = 'short_written'; text = 'Photosynthesis needs light.' }),
        (Save-Stage9Answer $Context student $attempt $q.q4 @{ type = 'open_written'; text = 'Open written answer for review.' }),
        (Save-Stage9File $Context student $attempt $q.q5)
    )
    $submit = Submit-Stage9Attempt $Context student $attempt (New-Stage9Key 102) 'Homework submitted successfully.'
    Wait-Stage9Checked $attempt waiting_for_teacher_review
    $facts = Get-Stage9DatabaseFacts
    $teacher = [string] $m.users.teacher
    Assert-Stage9Answer $facts $attempt $q.q1 auto_checked '2.00000000' $null $null 'review Q1' | Out-Null
    Assert-Stage9Answer $facts $attempt $q.q2 auto_checked '2.00000000' $null $null 'review Q2 (2 of 3 correct)' | Out-Null
    foreach ($label in @('q3', 'q4', 'q5')) { Assert-Stage9Answer $facts $attempt $q.$label waiting_for_teacher_review $null $null $null "review $label" | Out-Null }
    $row = Get-Stage9Row $facts assessment_attempts $attempt
    Assert-Stage9AttemptScore $row waiting_for_teacher_review $null $null 'review #1 after trigger'
    Assert-Stage9SameInstant $row.finalized_at $submit.finalized_at 'checking keeps finalized_at'
    if ([string] $row.finalization_reason -cne 'student_submit' -or [string] $row.possible_points -cne '20.000000') { throw 'production defect: Stage 9 checking changed the Homework freeze.' }
    foreach ($answer in @($saved)) {
        $persisted = @(Get-Stage9Rows $facts attempt_answers attempt_id $attempt | Where-Object question_id -CEQ ([string] $answer.question_id))
        if ($persisted.Count -ne 1) { throw 'integration-harness defect: Stage 9 saved answer is missing.' }
        Assert-Stage9SameInstant $persisted[0].updated_at $answer.updated_at 'checking keeps the answer updated_at'
    }
    Assert-Stage9NoOfficialRow $facts $hw ([string] $m.users.student) 'review #1 waits for review'
    $fileId = [string] $saved[4].answer.file.id
    Assert-Stage9File $facts (Get-Stage9Row $facts files $fileId) (Get-Stage9FileExpectation $Context.Files answer_pdf) $row ([string] $q.q5)
    Assert-Stage9IdempotencyRecord (Get-Stage9IdempotencyRecord $facts (New-Stage9Key 101) student.homework.attempt.start) $m.institutions.auto ([string] $m.users.student) student.homework.attempt.start (New-Stage9Key 101) assessment_attempt $attempt 201
    $read = Invoke-Stage9StudentRead $Context student "/student/attempts/$attempt"
    if ([string] $read.data.status -cne 'waiting_for_teacher_review') { throw 'production defect: Stage 9 Student Attempt read does not show the checked state.' }
    Assert-Stage9StudentResult $read.data.result $false $null 'review #1 waiting'
    $answers = Get-Stage9SubmissionAnswers $Context teacher $attempt
    $Context.Runtime.review_attempt_id = $attempt
    $Context.Runtime.review_file_id = $fileId
    $Context.Runtime.review_answer_ids = [ordered] @{ q3 = $answers[[string] $q.q3]; q4 = $answers[[string] $q.q4]; q5 = $answers[[string] $q.q5] }
    $Context.Runtime.review_auto_answer_ids = [ordered] @{ q1 = $answers[[string] $q.q1]; q2 = $answers[[string] $q.q2] }
    Add-Stage9Evidence $Context 'freeze_trigger_checking' ([pscustomobject] @{ attempt = $attempt; file = $fileId; teacher = $teacher })
}

function Invoke-Stage9HomeworkOvertake {
    param($Context)
    $m = $Context.Manifest
    $hw = [string] $m.assessments.review_hw
    $q = $m.questions.review_hw
    $classmate = [string] $m.users.classmate
    $first = Start-Stage9Homework $Context classmate $hw (New-Stage9Key 103)
    Save-Stage9Answer $Context classmate $first $q.q1 @{ type = 'single_choice'; selected_option_ids = @(Get-Stage9Choice $Context review_hw q1 @(2)) } | Out-Null
    Save-Stage9Answer $Context classmate $first $q.q2 @{ type = 'multiple_choice'; selected_option_ids = @(Get-Stage9Choice $Context review_hw q2 @(1, 3, 5)) } | Out-Null
    Submit-Stage9Attempt $Context classmate $first (New-Stage9Key 104) 'Homework submitted successfully.' | Out-Null
    Wait-Stage9Checked $first checked
    $facts = Get-Stage9DatabaseFacts
    Assert-Stage9AttemptScore (Get-Stage9Row $facts assessment_attempts $first) checked '5.00000000' '25.00000000' 'classmate #1'
    $firstOfficial = Assert-Stage9OfficialRow $facts $hw $classmate $first '25.00000000' highest_valid_completed 'classmate #1 official by the trigger'
    Assert-Stage9TeacherOfficial (Get-Stage9TeacherOfficial $Context teacher $hw $classmate) ready $first 1 25 highest_valid_completed 'classmate #1'
    Assert-Stage9StudentOfficial (Invoke-Stage9StudentRead $Context classmate "/student/homework/$hw").data 25 1 'classmate #1'

    Wait-Stage9TimestampBoundary ([string] $firstOfficial.selected_at)
    $second = Start-Stage9Homework $Context classmate $hw (New-Stage9Key 105)
    Save-Stage9Answer $Context classmate $second $q.q1 @{ type = 'single_choice'; selected_option_ids = @(Get-Stage9Choice $Context review_hw q1 @(2)) } | Out-Null
    Save-Stage9Answer $Context classmate $second $q.q2 @{ type = 'multiple_choice'; selected_option_ids = @(Get-Stage9Choice $Context review_hw q2 @(1, 3, 5)) } | Out-Null
    Save-Stage9Answer $Context classmate $second $q.q4 @{ type = 'open_written'; text = 'Second attempt answer.' } | Out-Null
    Submit-Stage9Attempt $Context classmate $second (New-Stage9Key 106) 'Homework submitted successfully.' | Out-Null
    Wait-Stage9Checked $second waiting_for_teacher_review
    $waiting = Get-Stage9DatabaseFacts
    # Upper bound (2 + 3 + 5) / 20 = 50 > 25: the ready score becomes not ready until #2 is reviewed.
    Assert-Stage9NoOfficialRow $waiting $hw $classmate 'classmate #2 could overtake'
    Assert-Stage9Equal (Get-Stage9Row $waiting assessment_attempts $first) (Get-Stage9Row $facts assessment_attempts $first) 'classmate #1 unchanged while #2 waits'
    Assert-Stage9TeacherOfficial (Get-Stage9TeacherOfficial $Context teacher $hw $classmate) waiting_for_teacher_review $null $null $null $null 'classmate #2 waiting'
    Assert-Stage9StudentOfficial (Invoke-Stage9StudentRead $Context classmate "/student/homework/$hw").data $null $null 'classmate #2 waiting'

    $answers = Get-Stage9SubmissionAnswers $Context teacher $second
    Save-Stage9Review $Context teacher $second @(@{ answer_id = $answers[[string] $q.q4]; awarded_points = 1; feedback = $null }) | Out-Null
    $final = Get-Stage9DatabaseFacts
    Assert-Stage9Answer $final $second $q.q4 teacher_checked '1.00000000' $null ([string] $m.users.teacher) 'classmate #2 Q4' | Out-Null
    Assert-Stage9AttemptScore (Get-Stage9Row $final assessment_attempts $second) checked '6.00000000' '30.00000000' 'classmate #2'
    $official = Assert-Stage9OfficialRow $final $hw $classmate $second '30.00000000' highest_valid_completed 'classmate #2 overtakes'
    if ((ConvertTo-Stage9Instant $official.selected_at) -le (ConvertTo-Stage9Instant $firstOfficial.selected_at)) { throw 'production defect: Stage 9 official selected_at did not advance with the new Attempt.' }
    $read = (Invoke-Stage9StudentRead $Context classmate "/student/homework/$hw").data
    Assert-Stage9StudentOfficial $read 30 2 'classmate #2'
    $results = @($read.attempt_results)
    if ($results.Count -ne 2 -or [string] $results[0].attempt_id -cne $first -or [string] $results[1].attempt_id -cne $second) { throw 'production defect: Stage 9 classmate attempt_results mismatch.' }
    Assert-Stage9StudentResult $results[0].result $true 25 'classmate #1 result'
    Assert-Stage9StudentResult $results[1].result $true 30 'classmate #2 result'
    $Context.Runtime.classmate_attempt_ids = @($first, $second)
    Add-Stage9Evidence $Context 'homework_overtake' ([pscustomobject] @{ first = $first; second = $second })
}

function Invoke-Stage9BlitzReviewOfficial {
    param($Context)
    $m = $Context.Manifest
    $blitz = [string] $m.assessments.exception_blitz
    $q = $m.questions.exception_blitz
    $student = [string] $m.users.student
    $attempt = Start-Stage9Blitz $Context student $blitz (New-Stage9Key 107)
    Save-Stage9Answer $Context student $attempt $q.q1 @{ type = 'single_choice'; selected_option_ids = @(Get-Stage9Choice $Context exception_blitz q1 @(1)) } | Out-Null
    Save-Stage9Answer $Context student $attempt $q.q2 @{ type = 'open_written'; text = 'Blitz answer one.' } | Out-Null
    Submit-Stage9Attempt $Context student $attempt (New-Stage9Key 108) 'Blitz attempt submitted successfully.' | Out-Null
    Wait-Stage9Checked $attempt waiting_for_teacher_review
    $facts = Get-Stage9DatabaseFacts
    Assert-Stage9Answer $facts $attempt $q.q1 auto_checked '4.00000000' $null $null 'Blitz #1 Q1' | Out-Null
    Assert-Stage9Answer $facts $attempt $q.q2 waiting_for_teacher_review $null $null $null 'Blitz #1 Q2' | Out-Null
    $answers = Get-Stage9SubmissionAnswers $Context teacher $attempt
    Save-Stage9Review $Context teacher $attempt @(@{ answer_id = $answers[[string] $q.q2]; awarded_points = 3; feedback = 'Blitz feedback one.' }) | Out-Null
    $final = Get-Stage9DatabaseFacts
    Assert-Stage9AttemptScore (Get-Stage9Row $final assessment_attempts $attempt) checked '7.00000000' '70.00000000' 'Blitz #1'
    Assert-Stage9OfficialRow $final $blitz $student $attempt '70.00000000' valid_normal_blitz 'Blitz #1 official' | Out-Null
    # S09-D5: while the Blitz is active the Student sees no score, feedback or result.
    # A submitted #1 without an exception leaves the active list (Stage 8 rule); no active read carries a result.
    Assert-Stage9NoResultKeys (Invoke-Stage9StudentRead $Context student '/student/blitz/active').data 'active list'
    Assert-Stage9NoResultKeys (Invoke-Stage9StudentRead $Context student "/student/blitz/$blitz").data 'active detail'
    $finished = Invoke-Stage9StudentRead $Context student '/student/blitz/finished'
    if (@($finished.data | Where-Object { [string] $_.id -ceq $blitz }).Count -ne 0) { throw 'production defect: Stage 9 finished Blitz list shows an active Blitz.' }
    $Context.Runtime.exception_attempt_1_id = $attempt
    $Context.Runtime.exception_answer_1_q2 = $answers[[string] $q.q2]
    Add-Stage9Evidence $Context 'blitz_review_official' ([pscustomobject] @{ attempt = $attempt })
}

function Invoke-Stage9ManualReleaseHidden {
    param($Context)
    $m = $Context.Manifest
    $hw = [string] $m.assessments.manual_hw
    $q = $m.questions.manual_hw
    $student = [string] $m.users.manual_student
    $attempt = Start-Stage9Homework $Context manual_student $hw (New-Stage9Key 109)
    Save-Stage9Answer $Context manual_student $attempt $q.q1 @{ type = 'single_choice'; selected_option_ids = @(Get-Stage9Choice $Context manual_hw q1 @(3)) } | Out-Null
    Save-Stage9Answer $Context manual_student $attempt $q.q2 @{ type = 'open_written'; text = 'Manual institution answer.' } | Out-Null
    Submit-Stage9Attempt $Context manual_student $attempt (New-Stage9Key 110) 'Homework submitted successfully.' | Out-Null
    Wait-Stage9Checked $attempt waiting_for_teacher_review
    $answers = Get-Stage9SubmissionAnswers $Context manual_teacher $attempt
    Save-Stage9Review $Context manual_teacher $attempt @(@{ answer_id = $answers[[string] $q.q2]; awarded_points = 4; feedback = 'Hidden feedback.' }) | Out-Null
    $facts = Get-Stage9DatabaseFacts
    Assert-Stage9AttemptScore (Get-Stage9Row $facts assessment_attempts $attempt) checked '9.00000000' '90.00000000' 'manual #1'
    Assert-Stage9OfficialRow $facts $hw $student $attempt '90.00000000' highest_valid_completed 'manual #1 official' | Out-Null
    Assert-Stage9TeacherOfficial (Get-Stage9TeacherOfficial $Context manual_teacher $hw $student) ready $attempt 1 90 highest_valid_completed 'manual #1'
    $Context.Runtime.manual_attempt_id = $attempt
    $Context.Runtime.manual_answer_q2 = $answers[[string] $q.q2]
    Assert-Stage9ManualHidden $Context
    Add-Stage9Evidence $Context 'manual_release_hidden' ([pscustomobject] @{ attempt = $attempt })
}

# The manual_teacher release mode keeps the Student result, feedback and official score hidden (S09-D3).
function Assert-Stage9ManualHidden {
    param($Context)
    $m = $Context.Manifest
    $hw = [string] $m.assessments.manual_hw
    $attempt = [string] $Context.Runtime.manual_attempt_id
    $list = Invoke-Stage9StudentRead $Context manual_student "/student/homework?topic_id=$($m.topics.manual)"
    $item = @($list.data | Where-Object { [string] $_.id -ceq $hw })
    if ($item.Count -ne 1 -or $item[0].score_visible -ne $false) { throw 'production defect: Stage 9 manual-release list item exposes a score.' }
    Assert-Stage9StudentOfficial $item[0] $null $null 'manual list'
    $detail = (Invoke-Stage9StudentRead $Context manual_student "/student/homework/$hw").data
    if ($detail.score_visible -ne $false -or @($detail.attempt_results).Count -ne 1 -or [string] $detail.attempt_results[0].status -cne 'checked') { throw 'production defect: Stage 9 manual-release detail mismatch.' }
    Assert-Stage9StudentOfficial $detail $null $null 'manual detail'
    Assert-Stage9StudentResult $detail.attempt_results[0].result $false $null 'manual detail result'
    $read = (Invoke-Stage9StudentRead $Context manual_student "/student/attempts/$attempt").data
    Assert-Stage9StudentResult $read.result $false $null 'manual Attempt read'
    if (@($read.answers | Where-Object { $null -ne $_.feedback }).Count -ne 0) { throw 'production defect: P1 Stage 9 manual-release Attempt read exposes Teacher feedback.' }
}

function Invoke-Stage9ApiSetup {
    param($Context)
    Invoke-Stage9FreezeTriggerChecking $Context
    Invoke-Stage9HomeworkOvertake $Context
    Invoke-Stage9BlitzReviewOfficial $Context
    Invoke-Stage9ManualReleaseHidden $Context
}

# ---------------------------------------------------------------- section 9.3 scheduled checking

function Invoke-Stage9ScheduledChecking {
    param($Context, [Parameter(Mandatory = $true)][string] $ClientAddress)
    $m = $Context.Manifest
    $a = $m.attempts
    Assert-Stage9ScheduleList (Invoke-Stage9ArtisanCommand -Command 'schedule:list')
    $before = Get-Stage9DatabaseFacts
    $frozen = @([string] $a.backfill_hw_1, [string] $a.backfill_blitz_1)
    $outputs = [ordered] @{}
    Assert-Stage9ExclusiveDatabase -ClientAddress $ClientAddress
    $outputs['homework:reconcile-deadlines'] = (Invoke-Stage9GuardedCommand -Command 'homework:reconcile-deadlines' -ExpectedCandidates @{ homework = @([string] $m.assessments.deadline_hw); blitz = @([string] $m.assessments.timeout_blitz); frozen = $frozen } -ExpectedLines @('Candidates: 1; finalized attempts: 1; failures: 0.')).Output
    Write-Host "Stage9ScheduledCommand: PASS homework:reconcile-deadlines"
    Assert-Stage9ExclusiveDatabase -ClientAddress $ClientAddress
    $outputs['blitz:reconcile-timeouts'] = (Invoke-Stage9GuardedCommand -Command 'blitz:reconcile-timeouts' -ExpectedCandidates @{ homework = @(); blitz = @([string] $m.assessments.timeout_blitz); frozen = $frozen } -ExpectedLines @('Candidates: 1; finalized attempts: 1; failures: 0.')).Output
    Write-Host "Stage9ScheduledCommand: PASS blitz:reconcile-timeouts"
    Assert-Stage9ExclusiveDatabase -ClientAddress $ClientAddress
    $outputs['attempts:check-frozen'] = (Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates @{ homework = @(); blitz = @(); frozen = $frozen } -ExpectedLines @('Candidates: 2; checked attempts: 2; failures: 0.', 'Official scores repaired: 1; failures: 0.')).Output
    Write-Host "Stage9ScheduledCommand: PASS attempts:check-frozen"
    $after = Get-Stage9DatabaseFacts
    $q = $m.questions
    $expected = [ordered] @{ q1 = '2.00000000'; q2 = '1.00000000'; q3 = '1.00000000'; q4 = '2.00000000'; q5 = '1.50000000'; q6 = '1.00000000'; q7 = '1.33333333' }
    foreach ($label in $expected.Keys) { Assert-Stage9Answer $after $a.backfill_hw_1 $q.backfill_hw.$label auto_checked $expected[$label] $null $null "backfill Homework $label" | Out-Null }
    Assert-Stage9Answer $after $a.backfill_hw_1 $q.backfill_hw.q8 waiting_for_teacher_review $null $null $null 'backfill Homework Q8' | Out-Null
    if (@(Get-Stage9Rows $after attempt_answers attempt_id $a.backfill_hw_1 | Where-Object question_id -CEQ $q.backfill_hw.q9).Count -ne 0) { throw 'production defect: Stage 9 checking fabricated an answer for an unanswered Question.' }
    Assert-Stage9AttemptScore (Get-Stage9Row $after assessment_attempts $a.backfill_hw_1) waiting_for_teacher_review $null $null 'backfill Homework'
    # 2/3 must round half-up to 0.66666667 (truncation gives 0.66666666); no ordering item is in place.
    foreach ($pair in @(@('q1', '0.66666667'), @('q2', '0.00000000'), @('q3', '1.00000000'))) { Assert-Stage9Answer $after $a.backfill_blitz_1 $q.backfill_blitz.($pair[0]) auto_checked $pair[1] $null $null "backfill Blitz $($pair[0])" | Out-Null }
    # The score comes from the stored rounded points (1.66666667 -> 55.55555567), not from 5/9 (55.55555556) or truncation (55.55555533).
    Assert-Stage9AttemptScore (Get-Stage9Row $after assessment_attempts $a.backfill_blitz_1) checked '1.66666667' '55.55555567' 'backfill Blitz'
    Assert-Stage9OfficialRow $after $m.assessments.backfill_blitz $m.users.backfill_student $a.backfill_blitz_1 '55.55555567' valid_normal_blitz 'backfill Blitz official' | Out-Null
    Assert-Stage9OfficialRow $after $m.assessments.repair_hw $m.users.repair_student $a.repair_hw_1 '100.00000000' highest_valid_completed 'repaired official row' | Out-Null
    Assert-Stage9Equal (Get-Stage9Row $after assessment_attempts $a.repair_hw_1) (Get-Stage9Row $before assessment_attempts $a.repair_hw_1) 'repair leaves the checked Attempt'
    Assert-Stage9FreezeAndAnswersKept $before $after @($frozen) 'scheduled checking'
    # The reconcilers freeze these two, so only their answers must stay as the Student saved them.
    Assert-Stage9AnswerRowsKept $before $after @([string] $a.deadline_hw_1, [string] $a.timeout_blitz_1) 'reconciliation and checking'
    foreach ($case in @(@('deadline_hw_1', 'homework_deadline_auto_submit', '3.00000000', '75.00000000', 'deadline_hw'), @('timeout_blitz_1', 'timeout_auto_submit', '2.00000000', '50.00000000', 'timeout_blitz'))) {
        $row = Get-Stage9Row $after assessment_attempts $a.($case[0])
        $was = Get-Stage9Row $before assessment_attempts $a.($case[0])
        Assert-Stage9AttemptScore $row checked $case[2] $case[3] $case[0]
        if ([string] $row.finalization_reason -cne $case[1] -or $null -ne $row.submitted_at) { throw "production defect: Stage 9 $($case[0]) was not finalized by its reconciler." }
        Assert-Stage9SameInstant $row.finalized_at $was.deadline_at "$($case[0]) finalized at its deadline"
        Assert-Stage9SameInstant $row.locked_at $was.deadline_at "$($case[0]) locked at its deadline"
        Assert-Stage9Answer $after $a.($case[0]) $q.($case[4]).q1 auto_checked $(if ($case[0] -ceq 'deadline_hw_1') { '3.00000000' } else { '2.00000000' }) $null $null "$($case[0]) Q1" | Out-Null
        Assert-Stage9NoOfficialRow $after $m.assessments.($case[4]) $row.student_id "$($case[0]) is practice"
    }
    Assert-Stage9ExclusiveDatabase -ClientAddress $ClientAddress
    $outputs['attempts:check-frozen (again)'] = (Invoke-Stage9GuardedCommand -Command 'attempts:check-frozen' -ExpectedCandidates @{ homework = @(); blitz = @(); frozen = @() } -ExpectedLines @('Candidates: 0; checked attempts: 0; failures: 0.', 'Official scores repaired: 0; failures: 0.')).Output
    Write-Host "Stage9ScheduledCommand: PASS attempts:check-frozen (again)"
    Assert-Stage9ExclusiveDatabase -ClientAddress $ClientAddress
    $outputs['schedule:run'] = Invoke-Stage9GuardedScheduleRun
    Write-Host 'Stage9ScheduledCommand: PASS schedule:run'
    Assert-Stage9ExclusiveDatabase -ClientAddress $ClientAddress
    Assert-Stage9Equal (Get-Stage9DatabaseFacts).tables $after.tables 'the second check and schedule:run change nothing'
    Add-Stage9Evidence $Context 'scheduled_checking' ([pscustomobject] @{ outputs = $outputs })
    $outputs
}

# ---------------------------------------------------------------- runner actions inside the UI flow

# Checkpoint exception_granted: judge the UI grant, then take and review replacement #2 through the API.
function Invoke-Stage9ReplacementAfterGrant {
    param($Context, $Facts)
    $m = $Context.Manifest
    $blitz = [string] $m.assessments.exception_blitz
    $student = [string] $m.users.student
    $first = [string] $Context.Runtime.exception_attempt_1_id
    $exceptions = @(Get-Stage9Rows $Facts blitz_attempt_exceptions assessment_id $blitz)
    if ($exceptions.Count -ne 1 -or $exceptions[0].student_id -cne $student -or $exceptions[0].invalidated_attempt_id -cne $first -or $null -ne $exceptions[0].replacement_attempt_id -or
        $exceptions[0].granted_by_user_id -cne $m.users.teacher -or $exceptions[0].reason -cne 'Power outage during the Blitz.') { throw 'production defect: Stage 9 UI grant did not persist the exact exception.' }
    if ((Get-Stage9Row $Facts assessment_attempts $first).official_score_eligible -ne $false) { throw 'production defect: Stage 9 grant left Blitz #1 eligible.' }
    Assert-Stage9NoOfficialRow $Facts $blitz $student 'grant withdraws the official Blitz score'
    Assert-Stage9IdempotencyRecord (Get-Stage9IdempotencyRecord $Facts (New-Stage9Key 1) teacher.blitz.attempt_exception.grant) $m.institutions.auto ([string] $m.users.teacher) teacher.blitz.attempt_exception.grant (New-Stage9Key 1) blitz_attempt_exception ([string] $exceptions[0].id) 201
    Assert-Stage9TeacherOfficial (Get-Stage9TeacherOfficial $Context teacher $blitz $student) waiting_for_replacement $null $null $null $null 'after the grant'
    # S09-D5: the Blitz is back in the Student's active list while an action is available, next to the checked #1.
    Assert-Stage9ActiveBlitzHidesResults $Context $blitz 'after the grant'
    $q = $m.questions.exception_blitz
    $second = Start-Stage9Blitz $Context student $blitz (New-Stage9Key 111) start_replacement
    Save-Stage9Answer $Context student $second $q.q1 @{ type = 'single_choice'; selected_option_ids = @(Get-Stage9Choice $Context exception_blitz q1 @(1)) } | Out-Null
    Save-Stage9Answer $Context student $second $q.q2 @{ type = 'open_written'; text = 'Replacement answer.' } | Out-Null
    Assert-Stage9ActiveBlitzHidesResults $Context $blitz 'during replacement #2'
    Submit-Stage9Attempt $Context student $second (New-Stage9Key 112) 'Blitz attempt submitted successfully.' | Out-Null
    Wait-Stage9Checked $second waiting_for_teacher_review
    $answers = Get-Stage9SubmissionAnswers $Context teacher $second
    Save-Stage9Review $Context teacher $second @(@{ answer_id = $answers[[string] $q.q2]; awarded_points = 5.5; feedback = 'Replacement feedback.' }) | Out-Null
    $final = Get-Stage9DatabaseFacts
    Assert-Stage9AttemptScore (Get-Stage9Row $final assessment_attempts $second) checked '9.50000000' '95.00000000' 'replacement #2'
    $official = Assert-Stage9OfficialRow $final $blitz $student $second '95.00000000' approved_blitz_exception_replacement 'replacement official'
    if ((Get-Stage9Row $final blitz_attempt_exceptions ([string] $exceptions[0].id)).replacement_attempt_id -cne $second) { throw 'production defect: Stage 9 exception does not link replacement #2.' }
    $Context.Runtime.exception_attempt_2_id = $second
    # With #2 checked and nothing left to do, the still-active Blitz leaves the active list (Stage 8 rule) and stays out of finished.
    if (@((Invoke-Stage9StudentRead $Context student '/student/blitz/active').data | Where-Object { [string] $_.id -ceq $blitz }).Count -ne 0) { throw 'production defect: Stage 9 active Blitz list keeps a Blitz with no action left.' }
    Assert-Stage9NoResultKeys (Invoke-Stage9StudentRead $Context student "/student/blitz/$blitz").data 'active detail after the replacement'
    if (@((Invoke-Stage9StudentRead $Context student '/student/blitz/finished').data | Where-Object { [string] $_.id -ceq $blitz }).Count -ne 0) { throw 'production defect: Stage 9 finished Blitz list shows an active Blitz.' }
    Add-Stage9Evidence $Context 'exception_replacement' ([pscustomobject] @{ replacement = $second; official = [string] $official.id })
}

# S09-D5: while the Blitz is active, no Student read carries a result, score or feedback, even with a checked Attempt.
function Assert-Stage9ActiveBlitzHidesResults {
    param($Context, [string] $BlitzId, [string] $Label)
    $active = @((Invoke-Stage9StudentRead $Context student '/student/blitz/active').data | Where-Object { [string] $_.id -ceq $BlitzId })
    if ($active.Count -ne 1) { throw "production defect: Stage 9 active Blitz list misses the Blitz with an available action ($Label)." }
    Assert-Stage9NoResultKeys $active[0] "active list $Label"
    Assert-Stage9NoResultKeys (Invoke-Stage9StudentRead $Context student "/student/blitz/$BlitzId").data "active detail $Label"
    if (@((Invoke-Stage9StudentRead $Context student '/student/blitz/finished').data | Where-Object { [string] $_.id -ceq $BlitzId }).Count -ne 0) { throw "production defect: Stage 9 finished Blitz list shows an active Blitz ($Label)." }
}

# Checkpoint replacement_seen: the Teacher closes the Blitz; the official row stays.
function Invoke-Stage9CloseExceptionBlitz {
    param($Context, $Facts)
    $m = $Context.Manifest
    $blitz = [string] $m.assessments.exception_blitz
    $student = [string] $m.users.student
    $official = @(Get-Stage9OfficialRows $Facts $blitz $student)
    Assert-Stage9ApiSuccess (Invoke-Stage9Call $Context teacher "/teacher/blitz/$blitz/close" POST -Body @{})
    $after = Get-Stage9DatabaseFacts
    $task = Get-Stage9Row $after blitz_tasks $blitz assessment_id
    if ($task.status -cne 'closed' -or $null -eq $task.closed_at) { throw 'production defect: Stage 9 Teacher close did not close the Blitz.' }
    Assert-Stage9Equal @(Get-Stage9OfficialRows $after $blitz $student) $official 'close keeps the official Blitz row'
}

# Each UI checkpoint is judged by the independent DB oracle before the Flutter test may continue.
function Test-Stage9UiCheckpoint {
    param($Context, $Checkpoint, [hashtable] $State)
    $m = $Context.Manifest
    $r = $Context.Runtime
    $facts = Get-Stage9DatabaseFacts
    Assert-Stage9TenantRows $facts
    $previous = $State.previous
    $attempt = [string] $r.review_attempt_id
    $hw = [string] $m.assessments.review_hw
    $student = [string] $m.users.student
    $teacher = [string] $m.users.teacher
    $q = $m.questions.review_hw
    Assert-Stage9OnlySessionsChanged $previous $facts "checkpoint $($Checkpoint.checkpoint)"
    switch ($Checkpoint.checkpoint) {
        'review_deadline_set' {
            if ([string] $Checkpoint.typed_date -cnotmatch '\A(\d{4})-(\d{2})-(\d{2})\z') { throw 'integration-harness defect: Stage 9 review deadline checkpoint lacks the typed date.' }
            # The pickers enter Institution wall-clock time (Asia/Tokyo, UTC+09:00 without DST); the time stays the initial 22:00,
            # which is the seeded 13:00Z. Device time (+05:00 on the runner host) would give another instant.
            $expected = [DateTimeOffset]::new([int] $Matches[1], [int] $Matches[2], [int] $Matches[3], 22, 0, 0, [TimeSpan]::FromHours(9))
            $row = Get-Stage9Row $facts homework_assignments $hw assessment_id
            Assert-Stage9SameInstant $row.review_due_at $expected.ToString('o') 'review deadline set through the pickers'
            Assert-Stage9OnlyTablesChanged $previous $facts @('homework_assignments', 'users', 'personal_access_tokens') 'setting the review deadline'
            Assert-Stage9Equal @($facts.tables.homework_assignments | Where-Object assessment_id -CNE $hw) @($previous.tables.homework_assignments | Where-Object assessment_id -CNE $hw) 'other Homework rows unchanged'
            $was = Get-Stage9Row $previous homework_assignments $hw assessment_id
            foreach ($column in @('status', 'deadline_at', 'activated_at', 'closed_at', 'archived_at')) { Assert-Stage9Equal $row.$column $was.$column "review deadline keeps $column" }
        }
        'review_partial' {
            Assert-Stage9Answer $facts $attempt $q.q3 teacher_checked '4.50000000' 'Clear reasoning.' $teacher 'partial review Q3' | Out-Null
            foreach ($label in @('q4', 'q5')) { Assert-Stage9Answer $facts $attempt $q.$label waiting_for_teacher_review $null $null $null "partial review $label" | Out-Null }
            Assert-Stage9AttemptScore (Get-Stage9Row $facts assessment_attempts $attempt) waiting_for_teacher_review $null $null 'after the partial review'
            Assert-Stage9NoOfficialRow $facts $hw $student 'partial review keeps the official score not ready'
            Assert-Stage9OnlyTablesChanged $previous $facts @('attempt_answers', 'assessment_attempts', 'users', 'personal_access_tokens') 'the partial review'
            Assert-Stage9Equal @($facts.tables.assessment_attempts | Where-Object id -CNE $attempt) @($previous.tables.assessment_attempts | Where-Object id -CNE $attempt) 'the partial review leaves other Attempts'
            Assert-Stage9Equal @($facts.tables.attempt_answers | Where-Object attempt_id -CNE $attempt) @($previous.tables.attempt_answers | Where-Object attempt_id -CNE $attempt) 'the partial review leaves other answers'
            Assert-Stage9FreezeAndAnswersKept $previous $facts @($attempt) 'the partial review'
        }
        'review_saved' {
            Assert-Stage9Equal (Assert-Stage9Answer $facts $attempt $q.q3 teacher_checked '4.50000000' 'Clear reasoning.' $teacher 'saved Q3') (Assert-Stage9Answer $previous $attempt $q.q3 teacher_checked '4.50000000' 'Clear reasoning.' $teacher 'partial Q3') 'Q3 unchanged by the next save'
            Assert-Stage9Answer $facts $attempt $q.q4 teacher_checked '3.25000000' 'Good structure, add an example.' $teacher 'saved Q4' | Out-Null
            Assert-Stage9Answer $facts $attempt $q.q5 teacher_checked '5.00000000' $null $teacher 'saved Q5' | Out-Null
            $row = Get-Stage9Row $facts assessment_attempts $attempt
            Assert-Stage9AttemptScore $row checked '16.75000000' '83.75000000' 'after the full review'
            Assert-Stage9OfficialRow $facts $hw $student $attempt '83.75000000' highest_valid_completed 'after the full review' | Out-Null
            Assert-Stage9OnlyTablesChanged $previous $facts @('attempt_answers', 'assessment_attempts', 'official_task_scores', 'users', 'personal_access_tokens') 'the full review'
            Assert-Stage9Equal @($facts.tables.assessment_attempts | Where-Object id -CNE $attempt) @($previous.tables.assessment_attempts | Where-Object id -CNE $attempt) 'the full review leaves other Attempts'
            Assert-Stage9Equal @($facts.tables.official_task_scores | Where-Object { $_.assessment_id -cne $hw -or $_.student_id -cne $student }) @($previous.tables.official_task_scores) 'the full review leaves other official rows'
            Assert-Stage9FreezeAndAnswersKept $previous $facts @($attempt) 'the full review'
            # The correction must land in a later server second so that its new timestamps are observable.
            Wait-Stage9TimestampBoundary ([string] $row.scoring_completed_at)
        }
        'review_corrected' {
            Assert-Stage9Answer $facts $attempt $q.q4 teacher_checked '1.27000000' 'Good structure, add an example.' $teacher 'corrected Q4' | Out-Null
            foreach ($label in @('q3', 'q5')) {
                Assert-Stage9Equal @(Get-Stage9Rows $facts attempt_answers attempt_id $attempt | Where-Object question_id -CEQ $q.$label) @(Get-Stage9Rows $previous attempt_answers attempt_id $attempt | Where-Object question_id -CEQ $q.$label) "correction leaves $label"
            }
            $row = Get-Stage9Row $facts assessment_attempts $attempt
            $was = Get-Stage9Row $previous assessment_attempts $attempt
            Assert-Stage9AttemptScore $row checked '14.77000000' '73.85000000' 'after the correction'
            if ((ConvertTo-Stage9Instant $row.scoring_completed_at) -le (ConvertTo-Stage9Instant $was.scoring_completed_at)) { throw 'production defect: Stage 9 correction did not advance scoring_completed_at.' }
            $official = Assert-Stage9OfficialRow $facts $hw $student $attempt '73.85000000' highest_valid_completed 'after the correction'
            $officialBefore = @(Get-Stage9OfficialRows $previous $hw $student)[0]
            if ($official.id -cne $officialBefore.id -or (ConvertTo-Stage9Instant $official.selected_at) -le (ConvertTo-Stage9Instant $officialBefore.selected_at)) { throw 'production defect: Stage 9 correction must update the same official row and advance selected_at.' }
            Assert-Stage9FreezeAndAnswersKept $previous $facts @($attempt) 'the correction'
        }
        'exception_granted' { Invoke-Stage9ReplacementAfterGrant $Context $facts }
        'replacement_seen' { Invoke-Stage9CloseExceptionBlitz $Context $facts }
        default { throw 'integration-harness defect: Unknown Stage 9 UI checkpoint.' }
    }
    $State.previous = Get-Stage9DatabaseFacts
}

# ---------------------------------------------------------------- section 9.5 after the UI

function Invoke-Stage9TeacherFileDownload {
    param($Context)
    $file = [string] $Context.Runtime.review_file_id
    $fixture = $Context.Files.Files['answer_pdf']
    foreach ($actor in @('teacher', 'student')) {
        Assert-Stage9Download (Invoke-Stage9Call $Context $actor "/files/$file/download" -Binary) $fixture
    }
    $facts = Get-Stage9DatabaseFacts
    Assert-Stage9NoPublicPath $Context.ApiBaseUrl ([string] (Get-Stage9Row $facts files $file).storage_key) $fixture
    Add-Stage9Evidence $Context 'teacher_file_download' ([pscustomobject] @{ file = $file; public_paths = 3 })
}

function Invoke-Stage9StudentResultsApi {
    param($Context)
    $m = $Context.Manifest
    $hw = [string] $m.assessments.review_hw
    $attempt = [string] $Context.Runtime.review_attempt_id
    $q = $m.questions.review_hw
    $detail = (Invoke-Stage9StudentRead $Context student "/student/homework/$hw").data
    if ($detail.score_visible -ne $true -or @($detail.attempt_results).Count -ne 1 -or [string] $detail.attempt_results[0].attempt_id -cne $attempt -or
        [int] $detail.attempt_results[0].attempt_number -ne 1 -or [string] $detail.attempt_results[0].status -cne 'checked') { throw 'production defect: Stage 9 Student Homework results mismatch.' }
    Assert-Stage9StudentOfficial $detail 73.85 1 'Student review Homework'
    Assert-Stage9StudentResult $detail.attempt_results[0].result $true 73.85 'Student review Homework result'
    $list = (Invoke-Stage9StudentRead $Context student "/student/homework?topic_id=$($m.topics.review)").data
    Assert-Stage9StudentOfficial @($list | Where-Object { [string] $_.id -ceq $hw })[0] 73.85 1 'Student Homework list'
    $read = (Invoke-Stage9StudentRead $Context student "/student/attempts/$attempt").data
    Assert-Stage9StudentResult $read.result $true 73.85 'Student Attempt read'
    $feedback = @{}
    foreach ($answer in @($read.answers)) { $feedback[[string] $answer.question_id] = $answer.feedback }
    Assert-Stage9Equal @($feedback[[string] $q.q1], $feedback[[string] $q.q2], $feedback[[string] $q.q3], $feedback[[string] $q.q4], $feedback[[string] $q.q5]) @($null, $null, 'Clear reasoning.', 'Good structure, add an example.', $null) 'Student sees exactly the saved feedback'
    $finished = (Invoke-Stage9StudentRead $Context student '/student/blitz/finished').data
    $item = @($finished | Where-Object { [string] $_.id -ceq [string] $m.assessments.exception_blitz })
    if ($item.Count -ne 1 -or $item[0].attempt_exception -ne $true -or $item[0].status -cne 'closed' -or [int] $item[0].result.attempt_number -ne 2) { throw 'production defect: Stage 9 finished Blitz item mismatch.' }
    Assert-Stage9StudentResult $item[0].result $true 95 'finished Blitz'
    $items = @($item[0].result.feedback)
    if ($items.Count -ne 1 -or [string] $items[0].question_id -cne [string] $m.questions.exception_blitz.q2 -or [int] $items[0].position -ne 2 -or [string] $items[0].text -cne 'Replacement feedback.') { throw 'production defect: Stage 9 finished Blitz feedback mismatch.' }
    $classmate = (Invoke-Stage9StudentRead $Context classmate "/student/homework/$hw").data
    Assert-Stage9StudentOfficial $classmate 30 2 'classmate after the UI'
    $classmateResults = @($classmate.attempt_results)
    if ($classmateResults.Count -ne 2) { throw 'production defect: Stage 9 classmate attempt_results changed after the UI.' }
    Assert-Stage9StudentResult $classmateResults[0].result $true 25 'classmate #1 after the UI'
    Assert-Stage9StudentResult $classmateResults[1].result $true 30 'classmate #2 after the UI'
    Assert-Stage9ManualHidden $Context
    foreach ($read in @($Context.StudentReads)) { Assert-Stage9NoProtectedKeys $read.Json "Student read $($read.Path)" }
    Add-Stage9Evidence $Context 'student_results_api' ([pscustomobject] @{ student_reads = $Context.StudentReads.Count })
}

# ---------------------------------------------------------------- section 9.6 restart persistence

function Get-Stage9RestartReads {
    param($Context)
    $m = $Context.Manifest
    $r = $Context.Runtime
    $reads = @(
        @('teacher', "/teacher/submissions/$($r.review_attempt_id)"),
        @('teacher', "/teacher/assessments/$($m.assessments.review_hw)/students/$($m.users.student)/official-score"),
        @('teacher', "/teacher/assessments/$($m.assessments.exception_blitz)/students/$($m.users.student)/official-score"),
        @('teacher', "/teacher/assessments/$($m.assessments.review_hw)/students/$($m.users.classmate)/official-score"),
        @('teacher', "/teacher/assessments/$($m.assessments.repair_hw)/students/$($m.users.repair_student)/official-score"),
        @('student', "/student/homework/$($m.assessments.review_hw)"),
        @('student', "/student/attempts/$($r.review_attempt_id)"),
        @('student', '/student/blitz/finished'),
        @('classmate', "/student/homework/$($m.assessments.review_hw)"),
        @('manual_student', "/student/homework/$($m.assessments.manual_hw)"),
        @('manual_student', "/student/homework?topic_id=$($m.topics.manual)"),
        @('manual_student', "/student/attempts/$($r.manual_attempt_id)")
    )
    $captured = [ordered] @{}
    foreach ($read in $reads) {
        $response = Invoke-Stage9Call $Context $read[0] $read[1]
        Assert-Stage9ApiSuccess $response 200 $(if ($read[1] -match '\A/student/(?:blitz/finished|homework\?)') { 'paged' } else { 'resource' })
        $captured["$($read[0]) $($read[1])"] = $response.Text
    }
    $captured
}

# ---------------------------------------------------------------- Android manual smoke (contract section 12)

function Invoke-Stage9AndroidSetup {
    param($Context)
    $m = $Context.Manifest
    $hw = [string] $m.assessments.android_hw
    $blitz = [string] $m.assessments.android_blitz
    $qh = $m.questions.android_hw
    $qb = $m.questions.android_blitz
    $homework = Start-Stage9Homework $Context android_student $hw (New-Stage9Key 501)
    Save-Stage9Answer $Context android_student $homework $qh.q1 @{ type = 'single_choice'; selected_option_ids = @(Get-Stage9Choice $Context android_hw q1 @(1)) } | Out-Null
    Save-Stage9Answer $Context android_student $homework $qh.q2 @{ type = 'open_written'; text = 'Android open answer.' } | Out-Null
    Submit-Stage9Attempt $Context android_student $homework (New-Stage9Key 502) 'Homework submitted successfully.' | Out-Null
    Wait-Stage9Checked $homework waiting_for_teacher_review
    $answers = Get-Stage9SubmissionAnswers $Context teacher $homework
    Save-Stage9Review $Context teacher $homework @(@{ answer_id = $answers[[string] $qh.q2]; awarded_points = 2.5; feedback = 'Android feedback.' }) | Out-Null
    $classmate = Start-Stage9Homework $Context android_classmate $hw (New-Stage9Key 503)
    Save-Stage9Answer $Context android_classmate $classmate $qh.q2 @{ type = 'open_written'; text = 'Android classmate answer.' } | Out-Null
    Submit-Stage9Attempt $Context android_classmate $classmate (New-Stage9Key 504) 'Homework submitted successfully.' | Out-Null
    Wait-Stage9Checked $classmate waiting_for_teacher_review
    $attempt = Start-Stage9Blitz $Context android_student $blitz (New-Stage9Key 505)
    Save-Stage9Answer $Context android_student $attempt $qb.q1 @{ type = 'single_choice'; selected_option_ids = @(Get-Stage9Choice $Context android_blitz q1 @(2)) } | Out-Null
    Save-Stage9Answer $Context android_student $attempt $qb.q2 @{ type = 'open_written'; text = 'Android Blitz answer.' } | Out-Null
    Submit-Stage9Attempt $Context android_student $attempt (New-Stage9Key 506) 'Blitz attempt submitted successfully.' | Out-Null
    Wait-Stage9Checked $attempt waiting_for_teacher_review
    $blitzAnswers = Get-Stage9SubmissionAnswers $Context teacher $attempt
    Save-Stage9Review $Context teacher $attempt @(@{ answer_id = $blitzAnswers[[string] $qb.q2]; awarded_points = 1; feedback = 'Android Blitz feedback.' }) | Out-Null
    Assert-Stage9ApiSuccess (Invoke-Stage9Call $Context teacher "/teacher/blitz/$blitz/close" POST -Body @{})
    $state = [pscustomobject] @{ homework = $homework; classmate = $classmate; blitz = $attempt }
    Assert-Stage9AndroidState (Get-Stage9DatabaseFacts) $state
    $state
}

function Assert-Stage9AndroidState {
    param($Facts, $State)
    $m = $Facts.manifest
    $hw = [string] $m.assessments.android_hw
    $blitz = [string] $m.assessments.android_blitz
    Assert-Stage9Set @(Get-Stage9Rows $Facts assessment_attempts assessment_id $hw | ForEach-Object id) @($State.homework, $State.classmate) 'Android Homework Attempts'
    Assert-Stage9Set @(Get-Stage9Rows $Facts assessment_attempts assessment_id $blitz | ForEach-Object id) @($State.blitz) 'Android Blitz Attempts'
    Assert-Stage9AttemptScore (Get-Stage9Row $Facts assessment_attempts $State.homework) checked '4.50000000' '90.00000000' 'Android Homework'
    Assert-Stage9AttemptScore (Get-Stage9Row $Facts assessment_attempts $State.classmate) waiting_for_teacher_review $null $null 'Android classmate'
    Assert-Stage9AttemptScore (Get-Stage9Row $Facts assessment_attempts $State.blitz) checked '3.00000000' '75.00000000' 'Android Blitz'
    Assert-Stage9OfficialRow $Facts $hw $m.users.android_student $State.homework '90.00000000' highest_valid_completed 'Android Homework official' | Out-Null
    Assert-Stage9OfficialRow $Facts $blitz $m.users.android_student $State.blitz '75.00000000' valid_normal_blitz 'Android Blitz official' | Out-Null
    Assert-Stage9NoOfficialRow $Facts $hw $m.users.android_classmate 'Android classmate waits for review'
    Assert-Stage9SameInstant (Get-Stage9Row $Facts homework_assignments $hw assessment_id).review_due_at '2026-01-15T13:00:00Z' 'Android review deadline unchanged'
    if ((Get-Stage9Row $Facts blitz_tasks $blitz assessment_id).status -cne 'closed') { throw 'production defect: Stage 9 Android Blitz is not closed.' }
}
