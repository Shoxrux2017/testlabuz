Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage7_oracle.ps1')
Add-Type -AssemblyName System.Net.Http

function Assert-Stage7ApiError {
    param($Response, [int] $ExpectedStatus, [string] $ExpectedCode, [string[]] $ErrorFields = @())
    if ([int] $Response.StatusCode -ne $ExpectedStatus -or $null -eq $Response.Json) { throw "production defect: Stage 7 API expected HTTP $ExpectedStatus ($ExpectedCode)." }
    $body = $Response.Json
    $properties = @($body.PSObject.Properties.Name)
    if (@(@('message','code','errors') | Where-Object { $_ -cnotin $properties }).Count -ne 0 -or
        @($properties | Where-Object { $_ -cnotin @('message','code','errors','request_id') }).Count -ne 0 -or
        $body.code -cne $ExpectedCode -or $body.message -isnot [string] -or [string]::IsNullOrWhiteSpace($body.message) -or
        $body.errors -isnot [pscustomobject]) { throw 'production defect: Stage 7 API error envelope mismatch.' }
    $fields = @($body.errors.PSObject.Properties | ForEach-Object Name)
    Assert-Stage7Set $fields $ErrorFields 'exact validation error fields'
    foreach ($field in $fields) {
        if ($body.errors.$field -isnot [array] -or @($body.errors.$field).Count -eq 0 -or @($body.errors.$field | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -ne 0) { throw 'production defect: Invalid validation error values.' }
    }
}

function Assert-Stage7ApiSuccess {
    param($Response, [int] $ExpectedStatus = 200, [ValidateSet('resource','collection','login','empty')][string] $Shape = 'resource')
    if ([int] $Response.StatusCode -ne $ExpectedStatus) { throw "production defect: Stage 7 API expected successful HTTP $ExpectedStatus." }
    if ($Shape -ceq 'empty') { if ($null -ne $Response.Json) { throw 'production defect: Expected empty response.' }; return }
    if ($null -eq $Response.Json -or $null -eq $Response.Json.PSObject.Properties['data']) { throw 'production defect: Missing success data envelope.' }
    $data = $Response.Json.data
    if ($Shape -ceq 'collection') {
        if ($data -isnot [array] -or $null -eq $Response.Json.PSObject.Properties['meta']) { throw 'production defect: Invalid Homework collection envelope.' }
    }
    elseif ($data -isnot [pscustomobject]) { throw 'production defect: Invalid success resource.' }
    elseif ($Shape -ceq 'login') {
        if ($null -eq $data.PSObject.Properties['token'] -or [string]::IsNullOrWhiteSpace($data.token) -or $data.token_type -cne 'Bearer') { throw 'environment/runtime defect: Stage 7 login failed.' }
    }
}

function Assert-Stage7NoProtectedKeys {
    param([AllowNull()] $Value)
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return }
    if ($Value -is [array]) { foreach ($item in $Value) { Assert-Stage7NoProtectedKeys $item }; return }
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.Name -cin @('is_correct','correct_value','accepted_answers','correct_position','match_key','checking_mode','configuration','client_key','storage_key','storage_disk','checksum_sha256')) {
            throw 'production defect: P1 Student success response disclosed a protected key.'
        }
        Assert-Stage7NoProtectedKeys $property.Value
    }
}

function Protect-Stage7Diagnostic {
    param([string] $Text, [AllowEmptyCollection()][string[]] $Secrets = @())
    $safe = [regex]::Replace($Text, '(?i)Bearer\s+[^\s,;"'']+', 'Bearer [REDACTED]')
    foreach ($secret in $Secrets) { if (-not [string]::IsNullOrEmpty($secret)) { $safe = $safe.Replace($secret, '[REDACTED]') } }
    $safe
}

function Assert-Stage7Download {
    param($Response, $Fixture)
    if ([int] $Response.StatusCode -ne 200) { throw 'production defect: Owner protected download failed.' }
    $headers = $Response.Headers
    if ([string] $headers['Content-Type'] -cne [string] $Fixture.mime_type -or
        [string] $headers['Content-Disposition'] -notmatch '(?i)\Aattachment\s*;' -or
        [string] $headers['Content-Disposition'] -notmatch '(?i)filename\*?=' -or
        [string] $headers['X-Content-Type-Options'] -cne 'nosniff') { throw 'production defect: Protected download security headers mismatch.' }
    $directives = @(([string] $headers['Cache-Control']).ToLowerInvariant().Split(',') | ForEach-Object { $_.Trim() })
    if ('private' -cnotin $directives -or 'no-store' -cnotin $directives -or 'public' -cin $directives) { throw 'production defect: Protected download is cacheable/public.' }
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $checksum = ([BitConverter]::ToString($hash.ComputeHash([byte[]] $Response.Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
    if ($checksum -cne $Fixture.sha256 -or [long] $Response.Bytes.Length -ne [long] $Fixture.size_bytes) { throw 'production defect: Protected download bytes differ from fixture.' }
}

function Assert-Stage7IdempotentResponse {
    param($First, $Replay, [int] $Status)
    Assert-Stage7ApiSuccess $First $Status
    Assert-Stage7ApiSuccess $Replay $Status
    Assert-Stage7Equal $Replay.Json.data $First.Json.data 'idempotent API logical resource/timestamps'
}

function Invoke-Stage7ApiRequest {
    param([string] $ApiBaseUrl, [string] $Path, [ValidateSet('GET','POST','PUT')][string] $Method = 'GET',
        [string] $Token, [AllowNull()] $Body, [string] $Key, [string] $FilePath, [string] $AnswerType = 'file_based', [switch] $Binary)
    $null = Resolve-Stage7ApiTarget $ApiBaseUrl
    if ($Path -notmatch '\A/(?:auth|student|teacher|files)/' -or $Path -match '[\r\n#\\]') { throw 'integration-harness defect: Unexpected Stage 7 API request path.' }
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(20)
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($Method), "$ApiBaseUrl$Path")
    $response = $null
    try {
        $null = $request.Headers.TryAddWithoutValidation('Accept', 'application/json')
        if ($Token) { $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token) }
        if ($Key) { $null = $request.Headers.TryAddWithoutValidation('Idempotency-Key', $Key) }
        if ($FilePath) {
            $multipart = [Net.Http.MultipartFormDataContent]::new()
            $multipart.Add([Net.Http.StringContent]::new($AnswerType), 'type')
            $fileContent = [Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes($FilePath))
            $fileContent.Headers.ContentType = [Net.Http.Headers.MediaTypeHeaderValue]::new('application/octet-stream')
            $multipart.Add($fileContent, 'file', [IO.Path]::GetFileName($FilePath))
            $request.Content = $multipart
        }
        elseif ($PSBoundParameters.ContainsKey('Body')) {
            $request.Content = [Net.Http.StringContent]::new(($Body | ConvertTo-Json -Depth 30 -Compress), [Text.Encoding]::UTF8, 'application/json')
        }
        try { $response = $client.SendAsync($request).GetAwaiter().GetResult() }
        catch { throw 'environment/runtime defect: Stage 7 API transport failed; request/exception payload withheld.' }
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $headers = @{}
        foreach ($header in $response.Headers) { $headers[$header.Key] = $header.Value -join ', ' }
        foreach ($header in $response.Content.Headers) { $headers[$header.Key] = $header.Value -join ', ' }
        $json = $null
        if ($bytes.Length -gt 0 -and (-not $Binary -or [int] $response.StatusCode -ne 200)) {
            try { $json = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json }
            catch { throw 'production defect: Stage 7 API returned invalid JSON; payload withheld.' }
        }
        [pscustomobject] @{ StatusCode = [int] $response.StatusCode; Json = $json; Headers = $headers; Bytes = $(if ($Binary) { $bytes } else { $null }) }
    }
    finally {
        if ($null -ne $response) { $response.Dispose() }
        $request.Dispose(); $client.Dispose(); $handler.Dispose()
        $Token = $null; $Body = $null; $bytes = $null
    }
}

function New-Stage7ApiSession {
    param([string] $ApiBaseUrl, [string] $Login, [string] $Password)
    try {
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path '/auth/login' -Method POST -Body @{ login = $Login; password = $Password }
        Assert-Stage7ApiSuccess $response 200 login
        [string] $response.Json.data.token
    }
    finally { $Password = $null; $response = $null }
}

function Remove-Stage7ApiSession {
    param([string] $ApiBaseUrl, [string] $Token)
    if (-not $Token) { return }
    try {
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path '/auth/logout' -Method POST -Token $Token -Body @{}
        Assert-Stage7ApiSuccess $response 204 empty
    }
    finally { $Token = $null }
}

function Invoke-Stage7LifecycleRequests {
    param([string] $ApiBaseUrl, [string] $Password, $Baseline, [string] $BackendContainerName = 'testlabuz-stage7-e2e-app')
    Assert-Stage7DatabaseFacts -Facts $Baseline -Mode Baseline
    $studentToken = $null; $teacherToken = $null
    $operationFailed = $false
    try {
        $studentToken = New-Stage7ApiSession $ApiBaseUrl 'e2e_s07_student' $Password
        $teacherToken = New-Stage7ApiSession $ApiBaseUrl 'e2e_s07_teacher' $Password
        $m = $Baseline.manifest
        $before = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7DatabaseFacts -Facts $before -Mode Baseline
        $read = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/student/attempts/$($m.attempts.deadline_read)" -Token $studentToken
        Assert-Stage7ApiSuccess $read
        Assert-Stage7NoProtectedKeys $read.Json
        $facts = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7DatabaseFacts -Facts $facts -Mode DeadlineRead -Baseline $Baseline
        $deadlineRow = Get-Stage7Row $facts assessment_attempts $m.attempts.deadline_read
        if ($read.Json.data.status -cne 'submitted' -or $null -ne $read.Json.data.submitted_at -or $read.Json.data.finalization_reason -cne 'homework_deadline_auto_submit' -or
            [DateTimeOffset] $read.Json.data.finalized_at -ne [DateTimeOffset] $deadlineRow.finalized_at) { throw 'production defect: Exact deadline GET did not expose reconciled state.' }
        $reject = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/student/attempts/$($m.attempts.deadline_read)/answers/$($m.questions.deadline_read.short_written)" -Method PUT -Token $studentToken -Body @{ type = 'short_written'; text = 'Must not replace lifecycle answer' }
        Assert-Stage7ApiError $reject 409 deadline_passed
        Assert-Stage7DatabaseFacts -Facts (Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName) -Mode DeadlineRead -Baseline $Baseline
        Write-Host 'Stage7 Deadline Read and unchanged lifecycle fixtures: PASS'
        foreach ($phase in @(@{ name = 'due_teacher_close'; before = 'DeadlineRead'; after = 'DueClose' }, @{ name = 'teacher_close'; before = 'DueClose'; after = 'TeacherClose' })) {
            $facts = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
            Assert-Stage7DatabaseFacts -Facts $facts -Mode $phase.before -Baseline $Baseline
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/teacher/homework/$($m.homework.($phase.name))/close" -Method POST -Token $teacherToken -Body @{}
            Assert-Stage7ApiSuccess $response
            $facts = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
            Assert-Stage7DatabaseFacts -Facts $facts -Mode $phase.after -Baseline $Baseline
            $studentRead = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/student/attempts/$($m.attempts.($phase.name))" -Token $studentToken
            Assert-Stage7ApiSuccess $studentRead
            Assert-Stage7NoProtectedKeys $studentRead.Json
            $terminalAttempt = Get-Stage7Row $facts assessment_attempts $m.attempts.($phase.name)
            if ($studentRead.Json.data.status -cne 'submitted' -or $null -ne $studentRead.Json.data.submitted_at -or $studentRead.Json.data.finalization_reason -cne $terminalAttempt.finalization_reason -or
                [DateTimeOffset] $studentRead.Json.data.finalized_at -ne [DateTimeOffset] $terminalAttempt.finalized_at) { throw 'production defect: Student read did not expose Teacher-close finalization.' }
            Write-Host "Stage7 $($phase.name) exact close path: PASS"
        }
        $candidates = @(Get-Stage7SchedulerCandidates -BackendContainerName $BackendContainerName)
        Assert-Stage7SchedulerCandidates $candidates $m
        $commandOutput = @(& docker exec $BackendContainerName php artisan homework:reconcile-deadlines 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'production defect: First homework:reconcile-deadlines command failed; inspect safe backend diagnostics.' }
        $first = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7DatabaseFacts -Facts $first -Mode Lifecycle -Baseline $Baseline
        Wait-Stage7TimestampBoundary (Get-Stage7Row $first assessment_attempts $m.attempts.scheduler).updated_at $BackendContainerName
        $candidates = @(Get-Stage7SchedulerCandidates -BackendContainerName $BackendContainerName)
        Assert-Stage7SchedulerCandidates $candidates $m -SecondInvocation
        $commandOutput = @(& docker exec $BackendContainerName php artisan homework:reconcile-deadlines 2>&1)
        if ($LASTEXITCODE -ne 0) { throw 'production defect: Second homework:reconcile-deadlines command failed.' }
        $second = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7DatabaseFacts -Facts $second -Mode Lifecycle -Baseline $Baseline
        Assert-Stage7Equal $second.tables $first.tables 'scheduler second invocation has zero write effect'
        Assert-Stage7SchedulerCandidates @(Get-Stage7SchedulerCandidates -BackendContainerName $BackendContainerName) $m -SecondInvocation
        Write-Host 'Stage7 global scheduler exact candidate guard, reconciliation and idempotency: PASS'
        $second
    }
    catch { $operationFailed = $true; throw }
    finally {
        $failures = 0
        foreach ($token in @($studentToken,$teacherToken)) { try { Remove-Stage7ApiSession $ApiBaseUrl $token } catch { $failures++ } }
        $studentToken = $null; $teacherToken = $null; $Password = $null
        if ($failures -ne 0) {
            if ($operationFailed) { Write-Warning 'environment/runtime defect: Lifecycle API session revocation also failed; original scenario failure preserved.' }
            else { throw 'environment/runtime defect: Lifecycle API session revocation failed.' }
        }
    }
}

function New-Stage7ApiKey {
    param([int] $Number)
    '07777777-7777-4777-8777-{0:D12}' -f $Number
}

function Assert-Stage7RejectedRequestUnchanged {
    param($Before, $After)
    Assert-Stage7Equal $After.tables $Before.tables 'rejected API request changes no fixture DB rows'
    Assert-Stage7Equal $After.blobs $Before.blobs 'rejected API request leaves no orphan/private blob changes'
    Assert-Stage7Equal $After.public_blobs $Before.public_blobs 'rejected API request leaves no public blob copies'
}

function Assert-Stage7SubmitAnswersPreserved {
    param($Before, $After, [string] $AttemptId)
    $answers = @($Before.tables.attempt_answers | Where-Object attempt_id -CEQ $AttemptId)
    $answerIds = @($answers | ForEach-Object id)
    Assert-Stage7Equal @($After.tables.attempt_answers | Where-Object attempt_id -CEQ $AttemptId) $answers 'Submit preserves saved answer parents and timestamps'
    foreach ($table in @('answer_choice_selections','answer_text_values','answer_boolean_values','answer_matching_pairs','answer_ordering_items','answer_fill_blank_values','answer_files')) {
        Assert-Stage7Equal @($After.tables.$table | Where-Object answer_id -CIN $answerIds) @($Before.tables.$table | Where-Object answer_id -CIN $answerIds) "Submit preserves exact $table children"
    }
    Assert-Stage7Equal $After.tables.files $Before.tables.files 'Submit preserves File metadata'
    Assert-Stage7Equal $After.blobs $Before.blobs 'Submit preserves private files'
    Assert-Stage7Equal $After.public_blobs $Before.public_blobs 'Submit preserves public blob absence'
}

function Invoke-Stage7ApiSecurityMatrix {
    param([string] $ApiBaseUrl, [string] $Password, $Baseline, $FileManifest, $UiEvidence,
        [string] $BackendContainerName = 'testlabuz-stage7-e2e-app')
    $sessions = @{}
    $operationFailed = $false
    $rejectedKeys = [Collections.Generic.List[string]]::new()
    $keyNumber = 100
    try {
        $facts = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7LifecycleState $facts $Baseline @('deadline_read','due_teacher_close','teacher_close','scheduler')
        $m = $facts.manifest
        $mainAttempt = [string] $UiEvidence.attempt_ids[0]
        $fileId = [string] $UiEvidence.replacement_file_id
        $mainQuestion = [string] $m.questions.main.true_false
        $calls = @(
            @{ Method = 'GET'; Path = '/student/homework' },
            @{ Method = 'GET'; Path = "/student/homework/$($m.homework.main)" },
            @{ Method = 'POST'; Path = "/student/homework/$($m.homework.main)/attempts"; Key = (New-Stage7ApiKey 1); Body = @{} },
            @{ Method = 'GET'; Path = "/student/attempts/$mainAttempt" },
            @{ Method = 'PUT'; Path = "/student/attempts/$mainAttempt/answers/$mainQuestion"; Body = @{ type = 'true_false'; value = $true } },
            @{ Method = 'POST'; Path = "/student/attempts/$mainAttempt/submit"; Key = (New-Stage7ApiKey 2); Body = @{} }
        )
        foreach ($actor in @('teacher','student','peer_student','unassigned_student','parent','foreign_student')) {
            $sessions[$actor] = New-Stage7ApiSession $ApiBaseUrl "e2e_s07_$actor" $Password
        }
        $before = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        foreach ($call in $calls) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl @call
            Assert-Stage7ApiError $response 401 authentication_required
            foreach ($role in @('teacher','parent')) {
                $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Token $sessions[$role] @call
                Assert-Stage7ApiError $response 403 forbidden
            }
        }
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/files/$fileId/download" -Binary
        Assert-Stage7ApiError $response 401 authentication_required
        foreach ($actor in @('unassigned_student','foreign_student')) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path '/student/homework?per_page=100' -Token $sessions[$actor]
            Assert-Stage7ApiSuccess $response 200 collection
            Assert-Stage7NoProtectedKeys $response.Json
            if (@($response.Json.data | Where-Object id -CEQ $m.homework.main).Count -ne 0) { throw 'production defect: P1 inaccessible Homework appeared in list.' }
            foreach ($call in @($calls | Where-Object { $_.Path -cne '/student/homework' })) {
                $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Token $sessions[$actor] @call
                Assert-Stage7ApiError $response 404 resource_not_found
                $safeError = $response.Json | ConvertTo-Json -Depth 20 -Compress
                foreach ($protected in @($m.homework.main,$mainAttempt,'E2E S07 Official Homework','e2e_s07_student')) {
                    if ($safeError.Contains($protected)) { throw 'production defect: P1 privacy-safe error disclosed target identity.' }
                }
            }
        }
        foreach ($actor in @('peer_student','unassigned_student','foreign_student','teacher')) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/files/$fileId/download" -Token $sessions[$actor] -Binary
            Assert-Stage7ApiError $response 404 resource_not_found
        }
        Assert-Stage7RejectedRequestUnchanged $before (Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName)
        $student = $sessions.student
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path '/student/homework?per_page=100' -Token $student
        Assert-Stage7ApiSuccess $response 200 collection
        Assert-Stage7NoProtectedKeys $response.Json
        if (@($response.Json.data | Where-Object { $_.id -cin @($m.homework.peer_only,$m.homework.foreign) }).Count -ne 0) { throw 'production defect: Unassigned/foreign Homework appeared for target Student.' }
        foreach ($name in @('peer_only','foreign')) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/student/homework/$($m.homework.$name)" -Token $student
            Assert-Stage7ApiError $response 404 resource_not_found
        }
        foreach ($path in @("/student/homework/$($m.homework.main)","/student/homework/$($m.homework.historical)","/student/attempts/$mainAttempt")) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $path -Token $student
            Assert-Stage7ApiSuccess $response
            Assert-Stage7NoProtectedKeys $response.Json
        }
        $download = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/files/$fileId/download" -Token $student -Binary
        Assert-Stage7Download $download $FileManifest.files.replacement_pptx
        Write-Host 'Stage7 auth, role, assignment, Tenant, recursive privacy and protected download matrix: PASS'

        $startPath = "/student/homework/$($m.homework.idempotency)/attempts"
        $before = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        foreach ($key in @('', 'malformed')) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $startPath -Method POST -Token $student -Key $key -Body @{}
            Assert-Stage7ApiError $response 422 validation_failed @('idempotency_key')
        }
        foreach ($case in @(@{ query = ''; body = @{ protected = $true }; field = 'body' }, @{ query = '?unexpected=1'; body = @{}; field = 'unexpected' })) {
            $key = New-Stage7ApiKey (++$keyNumber); $rejectedKeys.Add($key)
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$startPath$($case.query)" -Method POST -Token $student -Key $key -Body $case.body
            Assert-Stage7ApiError $response 422 validation_failed @($case.field)
        }
        Assert-Stage7RejectedRequestUnchanged $before (Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName)
        $key = New-Stage7ApiKey 10
        $resumeKey = New-Stage7ApiKey 11
        $first = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $startPath -Method POST -Token $student -Key $key -Body @{}
        Assert-Stage7ApiSuccess $first 201
        $attemptId = [string] $first.Json.data.id
        $replay = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $startPath -Method POST -Token $student -Key $key -Body @{}
        Assert-Stage7IdempotentResponse $first $replay 201
        $resume = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $startPath -Method POST -Token $student -Key $resumeKey -Body @{}
        Assert-Stage7ApiSuccess $resume 200
        Assert-Stage7Equal $resume.Json.data $first.Json.data 'different-key Start resumes same Attempt'
        Assert-Stage7NoProtectedKeys $first.Json
        $started = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        $attempt = Get-Stage7Row $started assessment_attempts $attemptId
        if ($attempt.status -cne 'in_progress' -or $attempt.assessment_id -cne $m.homework.idempotency -or @($started.tables.assessment_attempts | Where-Object assessment_id -CEQ $m.homework.idempotency).Count -ne 1) { throw 'production defect: Start idempotency created multiple/wrong Attempts.' }
        foreach ($success in @(@{ operation = 'student.homework.attempt.start'; key = $key; status = 201 }, @{ operation = 'student.homework.attempt.start'; key = $resumeKey; status = 200 })) {
            $record = @($started.tables.idempotency_records | Where-Object idempotency_key -CEQ $success.key)
            if ($record.Count -ne 1) { throw 'production defect: Start/resume success idempotency row missing.' }
            Assert-Stage7IdempotencyRecord $record[0] $m.institutions.target $m.users.student $success.operation $success.key $attemptId $success.status
        }

        $q = $m.questions.idempotency; $n = $m.nested.idempotency; $foreign = $m.nested.foreign
        $answerPath = "/student/attempts/$attemptId/answers"
        $invalidAnswers = @(
            @{ question = $m.questions.foreign.true_false; body = @{ type = 'true_false'; value = $true }; status = 404; code = 'resource_not_found'; fields = @() },
            @{ question = $q.single_choice; body = @{ type = 'single_choice'; selected_option_ids = @($n.multiple_choice[0]) }; status = 422; code = 'validation_failed'; fields = @('selected_option_ids') },
            @{ question = $q.single_choice; body = @{ type = 'single_choice'; selected_option_ids = @($foreign.single_choice[0]) }; status = 422; code = 'validation_failed'; fields = @('selected_option_ids') },
            @{ question = $q.matching; body = @{ type = 'matching'; pairs = @(@{ left_item_id = $foreign.matching.left[0]; right_item_id = $n.matching.right[0] }) }; status = 422; code = 'validation_failed'; fields = @('pairs') },
            @{ question = $q.ordering; body = @{ type = 'ordering'; items = @(@{ item_id = $foreign.ordering[0]; position = 1 }) }; status = 422; code = 'validation_failed'; fields = @('items') },
            @{ question = $q.fill_in_blank; body = @{ type = 'fill_in_blank'; values = @(@{ blank_id = $foreign.fill_in_blank[0]; text = 'rejected' }) }; status = 422; code = 'validation_failed'; fields = @('values') },
            @{ question = $q.true_false; body = @{ type = 'true_false'; value = $true; awarded_points = 999 }; status = 422; code = 'validation_failed'; fields = @('body') },
            @{ question = $q.file_based; body = @{ type = 'file_based' }; status = 422; code = 'validation_failed'; fields = @('type') }
        )
        $before = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        foreach ($case in $invalidAnswers) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$answerPath/$($case.question)" -Method PUT -Token $student -Body $case.body
            Assert-Stage7ApiError $response $case.status $case.code $case.fields
            $errorJson = $response.Json | ConvertTo-Json -Depth 30 -Compress
            foreach ($value in @($m.questions.foreign.PSObject.Properties.Value) + @('E2E S07 Foreign Institution','e2e_s07_foreign_student','E2E S07 private correctness')) {
                if ($errorJson.Contains([string] $value)) { throw 'production defect: P1 nested-answer rejection disclosed a foreign entity.' }
            }
        }
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$answerPath/$($q.true_false)" -Method PUT -Token $student -FilePath $FileManifest.files.valid_pdf.path -AnswerType 'true_false'
        Assert-Stage7ApiError $response 422 validation_failed @('type')
        foreach ($case in @(@{ fixture = 'fake_pdf'; code = 'unsupported_file_type' }, @{ fixture = 'over_limit_pdf'; code = 'file_too_large' })) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$answerPath/$($q.file_based)" -Method PUT -Token $student -FilePath $FileManifest.files.($case.fixture).path
            Assert-Stage7ApiError $response 422 $case.code @('file')
        }
        Assert-Stage7RejectedRequestUnchanged $before (Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName)

        Wait-Stage7TimestampBoundary $attempt.updated_at $BackendContainerName
        $payload = @{ type = 'short_written'; text = "E2E S07 direct API no-op — O‘zbekiston" }
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$answerPath/$($q.short_written)" -Method PUT -Token $student -Body $payload
        Assert-Stage7ApiSuccess $response
        Assert-Stage7NoProtectedKeys $response.Json
        $saved = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        $savedAnswer = @($saved.tables.attempt_answers | Where-Object attempt_id -CEQ $attemptId)
        if ($savedAnswer.Count -ne 1) { throw 'production defect: Rejected nested IDs wrote answers.' }
        Assert-Stage7TypedAnswer $saved $savedAnswer[0] short_written @($payload.text)
        Assert-Stage7Equal (Get-Stage7Row $saved assessment_attempts $attemptId).updated_at $attempt.updated_at 'answer save must not rewrite AssessmentAttempt.updated_at'
        Wait-Stage7TimestampBoundary $savedAnswer[0].updated_at $BackendContainerName
        $noop = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$answerPath/$($q.short_written)" -Method PUT -Token $student -Body $payload
        Assert-Stage7IdempotentResponse $response $noop 200
        $afterNoop = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7RejectedRequestUnchanged $saved $afterNoop
        $upload = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$answerPath/$($q.file_based)" -Method PUT -Token $student -FilePath $FileManifest.files.valid_pdf.path
        Assert-Stage7ApiSuccess $upload
        Assert-Stage7NoProtectedKeys $upload.Json
        $uploaded = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7TenantRows $uploaded
        $apiFileId = [string] $upload.Json.data.answer.file.id
        Assert-Stage7File $uploaded (Get-Stage7Row $uploaded files $apiFileId) (Get-Stage7FileExpectation $FileManifest valid_pdf) $attemptId $q.file_based
        Write-Host 'Stage7 Start idempotency, nested answer scope, strict transport, file authority and durable no-op: PASS'

        $submitPath = "/student/attempts/$attemptId/submit"
        $before = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        foreach ($invalidKey in @('', 'malformed')) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $submitPath -Method POST -Token $student -Key $invalidKey -Body @{}
            Assert-Stage7ApiError $response 422 validation_failed @('idempotency_key')
        }
        foreach ($case in @(@{ query = ''; body = @{ protected = $true }; field = 'body' }, @{ query = '?unexpected=1'; body = @{}; field = 'unexpected' })) {
            $rejectKey = New-Stage7ApiKey (++$keyNumber); $rejectedKeys.Add($rejectKey)
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$submitPath$($case.query)" -Method POST -Token $student -Key $rejectKey -Body $case.body
            Assert-Stage7ApiError $response 422 validation_failed @($case.field)
        }
        Assert-Stage7RejectedRequestUnchanged $before (Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName)
        $submitted = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $submitPath -Method POST -Token $student -Key $key -Body @{}
        Assert-Stage7ApiSuccess $submitted
        Assert-Stage7NoProtectedKeys $submitted.Json
        $firstSubmitFacts = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7SubmitAnswersPreserved $before $firstSubmitFacts $attemptId
        Wait-Stage7TimestampBoundary (Get-Stage7Row $firstSubmitFacts assessment_attempts $attemptId).updated_at $BackendContainerName
        $submitReplay = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $submitPath -Method POST -Token $student -Key $key -Body @{}
        Assert-Stage7IdempotentResponse $submitted $submitReplay 200
        Assert-Stage7RejectedRequestUnchanged $firstSubmitFacts (Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName)
        $rejectKey = New-Stage7ApiKey (++$keyNumber); $rejectedKeys.Add($rejectKey)
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path $submitPath -Method POST -Token $student -Key $rejectKey -Body @{}
        Assert-Stage7ApiError $response 409 attempt_not_editable
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "$answerPath/$($q.short_written)" -Method PUT -Token $student -Body @{ type = 'short_written'; text = 'Terminal mutation must fail' }
        Assert-Stage7ApiError $response 409 attempt_not_editable
        $rejectKey = New-Stage7ApiKey (++$keyNumber); $rejectedKeys.Add($rejectKey)
        $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/student/homework/$($m.homework.main)/attempts" -Method POST -Token $student -Key $rejectKey -Body @{}
        Assert-Stage7ApiError $response 409 attempts_exhausted
        $final = Get-Stage7DatabaseFacts -BackendContainerName $BackendContainerName
        Assert-Stage7RejectedRequestUnchanged $firstSubmitFacts $final
        $finalAnswers = @($final.tables.attempt_answers | Where-Object attempt_id -CEQ $attemptId)
        $typedAnswers = [ordered] @{}
        foreach ($table in @('answer_choice_selections','answer_text_values','answer_boolean_values','answer_matching_pairs','answer_ordering_items','answer_fill_blank_values','answer_files')) {
            $typedAnswers[$table] = @($final.tables.$table | Where-Object answer_id -CIN @($finalAnswers | ForEach-Object id))
        }
        $evidence = [pscustomobject] @{
            attempt_id = $attemptId; submitted_at = (Get-Stage7Row $final assessment_attempts $attemptId).submitted_at
            success_keys = @(
                [pscustomobject] @{ operation = 'student.homework.attempt.start'; key = $key; status = 201 },
                [pscustomobject] @{ operation = 'student.homework.attempt.start'; key = $resumeKey; status = 200 },
                [pscustomobject] @{ operation = 'student.homework.attempt.submit'; key = $key; status = 200 }
            )
            rejected_keys = @($rejectedKeys.ToArray()); answers = $finalAnswers; typed_answers = [pscustomobject] $typedAnswers
        }
        Assert-Stage7ApiPersistence $final $evidence
        Write-Host 'Stage7 Submit operation-scope independence, replay, terminal rejection and exhaustion: PASS'
        $evidence
    }
    catch { $operationFailed = $true; throw }
    finally {
        $logoutFailures = 0
        foreach ($token in @($sessions.Values)) { try { Remove-Stage7ApiSession $ApiBaseUrl $token } catch { $logoutFailures++ } }
        $sessions.Clear(); $student = $null; $Password = $null; $download = $null
        if ($logoutFailures -ne 0) {
            if ($operationFailed) { Write-Warning 'environment/runtime defect: API session revocation also failed; original scenario failure preserved.' }
            else { throw 'environment/runtime defect: Stage 7 API session revocation failed.' }
        }
    }
}

function Invoke-Stage7PostRestartRead {
    param([string] $ApiBaseUrl, [string] $Password, $Facts, $FileManifest)
    $token = $null
    try {
        $token = New-Stage7ApiSession $ApiBaseUrl 'e2e_s07_student' $Password
        $m = $Facts.manifest
        $homework = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/student/homework/$($m.homework.main)" -Token $token
        Assert-Stage7ApiSuccess $homework
        Assert-Stage7NoProtectedKeys $homework.Json
        $attempts = @($Facts.tables.assessment_attempts | Where-Object assessment_id -CEQ $m.homework.main | Sort-Object attempt_number)
        if ($attempts.Count -ne 3) { throw 'production defect: Restart lost Main Attempts.' }
        foreach ($attempt in $attempts) {
            $response = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/student/attempts/$($attempt.id)" -Token $token
            Assert-Stage7ApiSuccess $response
            Assert-Stage7NoProtectedKeys $response.Json
            if ($response.Json.data.status -cne 'submitted' -or $response.Json.data.finalization_reason -cne 'student_submit' -or
                [DateTimeOffset] $response.Json.data.submitted_at -ne [DateTimeOffset] $attempt.submitted_at -or
                [DateTimeOffset] $response.Json.data.finalized_at -ne [DateTimeOffset] $attempt.finalized_at) { throw 'production defect: Restart Attempt read is not persisted terminal state.' }
        }
        $answer = @($Facts.tables.attempt_answers | Where-Object { $_.attempt_id -ceq $attempts[0].id -and $_.question_id -ceq $m.questions.main.file_based })[0]
        $fileId = (Get-Stage7Row $Facts answer_files $answer.id answer_id).file_id
        $download = Invoke-Stage7ApiRequest -ApiBaseUrl $ApiBaseUrl -Path "/files/$fileId/download" -Token $token -Binary
        Assert-Stage7Download $download $FileManifest.files.replacement_pptx
        Write-Host 'Stage7 post-restart historical terminal reads and exact protected replacement download: PASS'
    }
    finally { Remove-Stage7ApiSession $ApiBaseUrl $token; $token = $null; $Password = $null; $download = $null }
}
