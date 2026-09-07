Set-StrictMode -Version Latest

function Assert-Stage6ApiError {
    param(
        [Parameter(Mandatory = $true)][psobject] $Response,
        [Parameter(Mandatory = $true)][int] $ExpectedStatus,
        [Parameter(Mandatory = $true)][string] $ExpectedCode,
        [string] $ErrorField
    )
    if ([int] $Response.StatusCode -ne $ExpectedStatus) {
        throw "Stage 6 API expected HTTP $ExpectedStatus but received $($Response.StatusCode)."
    }
    $body = $Response.Json
    $properties = @($body.PSObject.Properties.Name)
    $allowed = @('message', 'code', 'errors', 'request_id')
    if (
        [string] $body.code -cne $ExpectedCode -or
        @(@('message', 'code', 'errors') | Where-Object { $_ -cnotin $properties }).Count -ne 0 -or
        @($properties | Where-Object { $_ -cnotin $allowed }).Count -ne 0
    ) { throw 'Stage 6 API returned the wrong error envelope.' }
    if ($ErrorField) {
        if ($null -eq $body.errors.PSObject.Properties[$ErrorField] -or @($body.errors.$ErrorField).Count -lt 1) {
            throw "Stage 6 API error envelope omitted errors.$ErrorField."
        }
    }
    elseif (@($body.errors.PSObject.Properties).Count -ne 0) {
        throw 'Stage 6 API error envelope unexpectedly contained validation details.'
    }
}

function Assert-Stage6NoProtectedDisclosure {
    param(
        [Parameter(Mandatory = $true)][psobject] $Response,
        [Parameter(Mandatory = $true)][string[]] $ForbiddenValues
    )
    foreach ($value in $ForbiddenValues) {
        if ($value -and $Response.Raw.IndexOf($value, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw 'Stage 6 privacy-safe error disclosed a protected resource value.'
        }
    }
}

function Assert-Stage6ApiSuccess {
    param([Parameter(Mandatory = $true)][psobject] $Response, [int] $ExpectedStatus = 200)
    if ([int] $Response.StatusCode -ne $ExpectedStatus -or $null -eq $Response.Json) {
        throw "Stage 6 API expected successful HTTP $ExpectedStatus."
    }
}

function Get-Stage6ErrorBody {
    param([Parameter(Mandatory = $true)][object] $Exception)
    $response = $Exception.Response
    if ($null -eq $response) { return $null }
    if ($null -ne $response.PSObject.Properties['Content']) {
        return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    }
    $stream = $response.GetResponseStream()
    if ($null -eq $stream) { return $null }
    $reader = [IO.StreamReader]::new($stream)
    try { $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Invoke-Stage6ApiRequest {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST', 'PUT', 'PATCH')][string] $Method,
        [Parameter(Mandatory = $true)][string] $Uri,
        [string] $Token,
        [AllowNull()][object] $Body
    )
    $headers = @{ Accept = 'application/json' }
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $parameters = @{ UseBasicParsing = $true; Method = $Method; Uri = $Uri; Headers = $headers; TimeoutSec = 10 }
    if ($PSBoundParameters.ContainsKey('Body')) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = $Body | ConvertTo-Json -Depth 30 -Compress
    }
    $status = $null
    $raw = $null
    try {
        $response = Invoke-WebRequest @parameters
        $status = [int] $response.StatusCode
        $raw = [string] $response.Content
    }
    catch {
        if ($null -eq $_.Exception.Response) { throw "Stage 6 API request was unreachable: $Method $Uri" }
        $status = [int] $_.Exception.Response.StatusCode
        $raw = [string] (Get-Stage6ErrorBody -Exception $_.Exception)
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $json = $null
    }
    else {
        try { $json = $raw | ConvertFrom-Json } catch { throw "Stage 6 API returned invalid JSON for $Method $Uri." }
    }
    [pscustomobject] @{ StatusCode = $status; Json = $json; Raw = $raw }
}

function Get-Stage6ResponseData {
    param([Parameter(Mandatory = $true)][psobject] $Response)
    if ($null -ne $Response.Json.PSObject.Properties['data']) { return $Response.Json.data }
    $Response.Json
}

function New-Stage6ApiSession {
    param([string] $ApiBaseUrl, [string] $Login, [string] $Password)
    $response = Invoke-Stage6ApiRequest -Method POST -Uri "$ApiBaseUrl/auth/login" -Body @{ login = $Login; password = $Password }
    Assert-Stage6ApiSuccess -Response $response
    $data = Get-Stage6ResponseData -Response $response
    if (-not $data.token -or [string] $data.token_type -cne 'Bearer') { throw "Stage 6 login failed for $Login." }
    [string] $data.token
}

function Remove-Stage6ApiSession {
    param([string] $ApiBaseUrl, [string] $Token)
    if (-not $Token) { return }
    $response = Invoke-Stage6ApiRequest -Method POST -Uri "$ApiBaseUrl/auth/logout" -Token $Token -Body @{}
    if ([int] $response.StatusCode -ne 204) { throw 'Stage 6 API session revocation failed.' }
}

function Assert-Stage6PairNoOp {
    param([psobject] $Before, [psobject] $After)
    foreach ($field in @('id', 'homework_assessment_id', 'designated_at', 'locked_at', 'updated_at')) {
        if ([string] $Before.$field -cne [string] $After.$field) { throw "Stage 6 same-target pair PUT changed $field." }
    }
    if ($null -ne $Before.blitz_assessment_id -or $null -ne $After.blitz_assessment_id) {
        throw 'Stage 6 same-target pair PUT fabricated a Blitz assessment.'
    }
}

function Invoke-Stage6ApiSecurityMatrix {
    param(
        [Parameter(Mandatory = $true)][string] $ApiBaseUrl,
        [Parameter(Mandatory = $true)][string] $OraclePath,
        [Parameter(Mandatory = $true)][string] $Password
    )
    if (-not (Test-Path -LiteralPath $OraclePath)) { throw 'Stage 6 API security requires the sanitized oracle.' }
    $oracle = Get-Content -LiteralPath $OraclePath -Raw | ConvertFrom-Json
    $authoringTopic = [string] $oracle.topics.authoring.id
    $lockedTopic = [string] $oracle.topics.locked.id
    $lockedHomework = [string] $oracle.homework.locked.id
    $replacement = [string] $oracle.homework.replacement.id
    $expiredHomework = [string] $oracle.homework.expired.id
    $foreignTopic = [string] $oracle.topics.foreign.id
    $foreignHomework = [string] $oracle.homework.foreign.id
    $securityTopic = [string] $oracle.topics.security.id
    $securitySelected = [string] $oracle.homework.security_selected.id
    $questionPayload = @{
        type = 'true_false'; prompt = 'E2E S06 Locked Mutation Rejected'; instructions = $null
        points = 1; position = 2; checking_mode = 'automatic'; configuration = @{ correct_value = $true }
    }

    $unauthenticated = Invoke-Stage6ApiRequest -Method GET -Uri "$ApiBaseUrl/teacher/topics/$authoringTopic/homework"
    Assert-Stage6ApiError -Response $unauthenticated -ExpectedStatus 401 -ExpectedCode 'authentication_required'

    $sessions = @{}
    try {
        foreach ($key in @('student_alpha', 'target_admin', 'unrelated_teacher', 'target_teacher')) {
            $sessions[$key] = New-Stage6ApiSession -ApiBaseUrl $ApiBaseUrl -Login ([string] $oracle.actors.$key.login) -Password $Password
        }

        foreach ($key in @('student_alpha', 'target_admin')) {
            $response = Invoke-Stage6ApiRequest -Method GET -Uri "$ApiBaseUrl/teacher/topics/$authoringTopic/homework" -Token $sessions[$key]
            Assert-Stage6ApiError -Response $response -ExpectedStatus 403 -ExpectedCode 'forbidden'
        }

        $unrelatedToken = [string] $sessions.unrelated_teacher
        $unrelatedCalls = @(
            @{ Method = 'GET'; Uri = "$ApiBaseUrl/teacher/topics/$authoringTopic/homework" },
            @{ Method = 'GET'; Uri = "$ApiBaseUrl/teacher/homework/$lockedHomework" },
            @{ Method = 'PATCH'; Uri = "$ApiBaseUrl/teacher/homework/$lockedHomework"; Body = @{ title = 'E2E S06 Unauthorized Mutation' } },
            @{ Method = 'POST'; Uri = "$ApiBaseUrl/teacher/assessments/$lockedHomework/questions"; Body = $questionPayload },
            @{ Method = 'GET'; Uri = "$ApiBaseUrl/teacher/topics/$lockedTopic/result-pair" },
            @{ Method = 'PUT'; Uri = "$ApiBaseUrl/teacher/topics/$lockedTopic/result-pair"; Body = @{ homework_assessment_id = $lockedHomework } }
        )
        foreach ($call in $unrelatedCalls) {
            $arguments = @{ Method = $call.Method; Uri = $call.Uri; Token = $unrelatedToken }
            if ($call.ContainsKey('Body')) { $arguments.Body = $call.Body }
            $response = Invoke-Stage6ApiRequest @arguments
            Assert-Stage6ApiError -Response $response -ExpectedStatus 404 -ExpectedCode 'resource_not_found'
            Assert-Stage6NoProtectedDisclosure -Response $response -ForbiddenValues @('E2E S06 Locked Official Homework', 'E2E S06 Authoring Topic', 'e2e_s06_target_teacher')
        }

        $teacherToken = [string] $sessions.target_teacher
        $foreignCalls = @(
            @{ Method = 'GET'; Uri = "$ApiBaseUrl/teacher/topics/$foreignTopic/homework" },
            @{ Method = 'GET'; Uri = "$ApiBaseUrl/teacher/homework/$foreignHomework" },
            @{ Method = 'PATCH'; Uri = "$ApiBaseUrl/teacher/homework/$foreignHomework"; Body = @{ title = 'E2E S06 Unauthorized Foreign Mutation' } },
            @{ Method = 'POST'; Uri = "$ApiBaseUrl/teacher/assessments/$foreignHomework/questions"; Body = $questionPayload },
            @{ Method = 'GET'; Uri = "$ApiBaseUrl/teacher/topics/$foreignTopic/result-pair" },
            @{ Method = 'PUT'; Uri = "$ApiBaseUrl/teacher/topics/$foreignTopic/result-pair"; Body = @{ homework_assessment_id = $foreignHomework } }
        )
        foreach ($call in $foreignCalls) {
            $arguments = @{ Method = $call.Method; Uri = $call.Uri; Token = $teacherToken }
            if ($call.ContainsKey('Body')) { $arguments.Body = $call.Body }
            $response = Invoke-Stage6ApiRequest @arguments
            Assert-Stage6ApiError -Response $response -ExpectedStatus 404 -ExpectedCode 'resource_not_found'
            Assert-Stage6NoProtectedDisclosure -Response $response -ForbiddenValues @('E2E S06 Foreign Homework', 'E2E S06 Foreign Topic', 'e2e_s06_foreign_student', 'E2E S06 Foreign Institution')
        }

        $foreignSelection = Invoke-Stage6ApiRequest -Method POST -Uri "$ApiBaseUrl/teacher/topics/$authoringTopic/homework" -Token $teacherToken -Body @{
            title = 'E2E S06 Foreign Student Rejected'; description = 'Must not persist'
            student_instructions = 'Must not persist.'; assignment_mode = 'selected_students'
            student_ids = @([string] $oracle.actors.foreign_student.id); deadline_at = $null; questions = @()
        }
        Assert-Stage6ApiError -Response $foreignSelection -ExpectedStatus 422 -ExpectedCode 'validation_failed' -ErrorField 'student_ids'
        Assert-Stage6NoProtectedDisclosure -Response $foreignSelection -ForbiddenValues @('e2e_s06_foreign_student', 'E2E S06 Foreign Institution')

        $selectedOfficial = Invoke-Stage6ApiRequest -Method PUT -Uri "$ApiBaseUrl/teacher/topics/$securityTopic/result-pair" -Token $teacherToken -Body @{ homework_assessment_id = $securitySelected }
        Assert-Stage6ApiError -Response $selectedOfficial -ExpectedStatus 409 -ExpectedCode 'official_task_requires_group_assignment'

        $replaceLocked = Invoke-Stage6ApiRequest -Method PUT -Uri "$ApiBaseUrl/teacher/topics/$lockedTopic/result-pair" -Token $teacherToken -Body @{ homework_assessment_id = $replacement }
        Assert-Stage6ApiError -Response $replaceLocked -ExpectedStatus 409 -ExpectedCode 'result_pair_locked'

        $pairBeforeResponse = Invoke-Stage6ApiRequest -Method GET -Uri "$ApiBaseUrl/teacher/topics/$lockedTopic/result-pair" -Token $teacherToken
        Assert-Stage6ApiSuccess -Response $pairBeforeResponse
        $sameTargetResponse = Invoke-Stage6ApiRequest -Method PUT -Uri "$ApiBaseUrl/teacher/topics/$lockedTopic/result-pair" -Token $teacherToken -Body @{ homework_assessment_id = $lockedHomework }
        Assert-Stage6ApiSuccess -Response $sameTargetResponse
        Assert-Stage6PairNoOp -Before (Get-Stage6ResponseData $pairBeforeResponse) -After (Get-Stage6ResponseData $sameTargetResponse)

        $closeLocked = Invoke-Stage6ApiRequest -Method POST -Uri "$ApiBaseUrl/teacher/homework/$lockedHomework/close" -Token $teacherToken -Body @{}
        Assert-Stage6ApiError -Response $closeLocked -ExpectedStatus 409 -ExpectedCode 'business_conflict'

        $mutateLocked = Invoke-Stage6ApiRequest -Method POST -Uri "$ApiBaseUrl/teacher/assessments/$lockedHomework/questions" -Token $teacherToken -Body $questionPayload
        Assert-Stage6ApiError -Response $mutateLocked -ExpectedStatus 409 -ExpectedCode 'result_pair_locked'

        $activateExpired = Invoke-Stage6ApiRequest -Method POST -Uri "$ApiBaseUrl/teacher/homework/$expiredHomework/activate" -Token $teacherToken -Body @{}
        Assert-Stage6ApiError -Response $activateExpired -ExpectedStatus 409 -ExpectedCode 'deadline_passed'
    }
    finally {
        $logoutErrors = [Collections.Generic.List[string]]::new()
        foreach ($token in @($sessions.Values)) {
            try { Remove-Stage6ApiSession -ApiBaseUrl $ApiBaseUrl -Token ([string] $token) }
            catch { $logoutErrors.Add($_.Exception.Message) }
        }
        if ($logoutErrors.Count -ne 0) { throw ('Stage 6 API session cleanup failed: ' + ($logoutErrors -join ' | ')) }
    }
    Write-Output 'Stage6ApiSecurityMatrix: PASS'
}
