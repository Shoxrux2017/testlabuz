Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage8_oracle.ps1')
. (Join-Path $PSScriptRoot 'stage8_concurrency_probe.ps1')
Add-Type -AssemblyName System.Net.Http

$script:Stage8ProtectedKeys = @('is_correct', 'correct_value', 'accepted_answers', 'accepted_text', 'correct_position', 'match_key', 'checking_mode', 'configuration', 'client_key', 'storage_key', 'storage_disk', 'checksum_sha256', 'earned_points', 'normalized_score', 'awarded_points')
$script:Stage8DetailKeys = @('id', 'topic', 'title', 'description', 'student_instructions', 'status', 'duration_seconds', 'total_possible_points', 'timing', 'attempts')
$script:Stage8DetailTimingKeys = @('mode', 'server_now', 'synchronized_ends_at', 'deadline_at', 'remaining_seconds')
$script:Stage8DetailAttemptKeys = @('normal_attempts', 'normal_used', 'in_progress_attempt_id', 'additional_exception_granted', 'replacement_attempt_available')

# ---------------------------------------------------------------- pure response assertions

function Assert-Stage8ApiError {
    param($Response, [int] $ExpectedStatus, [string] $ExpectedCode, [string[]] $AllowedFields = @(), [string[]] $RequiredFields = @())
    # An empty list assigned from an if-expression arrives as $null; treat it as empty.
    $AllowedFields = @($AllowedFields | Where-Object { -not [string]::IsNullOrEmpty($_) })
    $RequiredFields = @($RequiredFields | Where-Object { -not [string]::IsNullOrEmpty($_) })
    if ([int] $Response.StatusCode -ne $ExpectedStatus -or $null -eq $Response.Json) { throw "production defect: Stage 8 API expected HTTP $ExpectedStatus ($ExpectedCode), got $($Response.StatusCode)." }
    $body = $Response.Json
    $properties = @($body.PSObject.Properties.Name)
    $allowed = @('message', 'code', 'errors')
    if ($ExpectedCode -ceq 'institution_settings_incomplete') { $allowed += 'meta' }
    if (@(@('message', 'code', 'errors') | Where-Object { $_ -cnotin $properties }).Count -ne 0 -or
        @($properties | Where-Object { $_ -cnotin $allowed }).Count -ne 0 -or
        $body.code -cne $ExpectedCode -or $body.message -isnot [string] -or [string]::IsNullOrWhiteSpace($body.message) -or
        $body.errors -isnot [pscustomobject]) { throw "production defect: Stage 8 API error envelope mismatch for $ExpectedCode." }
    $fields = @($body.errors.PSObject.Properties | ForEach-Object Name)
    if ($ExpectedStatus -eq 422 -and $ExpectedCode -ceq 'validation_failed') {
        if ($fields.Count -eq 0) { throw 'production defect: Stage 8 validation_failed without field errors.' }
        if (@($fields | Where-Object { $_ -cnotin $AllowedFields }).Count -ne 0) { throw "production defect: Stage 8 validation errors name fields outside the invalid vector: $($fields -join ',')." }
        if (@($RequiredFields | Where-Object { $_ -cnotin $fields }).Count -ne 0) { throw "production defect: Stage 8 validation errors miss the invalid field: $($fields -join ',')." }
        foreach ($field in $fields) {
            if ($body.errors.$field -isnot [array] -or @($body.errors.$field).Count -eq 0 -or @($body.errors.$field | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -ne 0) {
                throw 'production defect: Stage 8 validation error values must be non-empty string arrays.'
            }
        }
    }
    elseif ($fields.Count -ne 0) { throw "production defect: Stage 8 $ExpectedCode must carry errors = {}." }
    if ($ExpectedCode -ceq 'institution_settings_incomplete') {
        if ($null -eq $body.PSObject.Properties['meta'] -or (@($body.meta.missing_fields) -join ',') -cne 'blitz_timer_start_mode') { throw 'production defect: Stage 8 settings conflict must name blitz_timer_start_mode.' }
    }
}

function Assert-Stage8ApiSuccess {
    param($Response, [int] $ExpectedStatus = 200, [ValidateSet('resource', 'collection', 'login', 'empty')][string] $Shape = 'resource')
    if ([int] $Response.StatusCode -ne $ExpectedStatus) { throw "production defect: Stage 8 API expected successful HTTP $ExpectedStatus, got $($Response.StatusCode) $(if ($null -ne $Response.Json -and $null -ne $Response.Json.PSObject.Properties['code']) { $Response.Json.code })." }
    if ($Shape -ceq 'empty') { if ($null -ne $Response.Json) { throw 'production defect: Expected an empty Stage 8 response.' }; return }
    if ($null -eq $Response.Json -or $null -eq $Response.Json.PSObject.Properties['data']) { throw 'production defect: Missing Stage 8 success data envelope.' }
    $data = $Response.Json.data
    if ($Shape -ceq 'collection') { if ($data -isnot [array]) { throw 'production defect: Invalid Stage 8 collection envelope.' } }
    elseif ($data -isnot [pscustomobject]) { throw 'production defect: Invalid Stage 8 success resource.' }
    elseif ($Shape -ceq 'login') {
        if ($null -eq $data.PSObject.Properties['token'] -or [string]::IsNullOrWhiteSpace($data.token) -or $data.token_type -cne 'Bearer') { throw 'environment/runtime defect: Stage 8 login failed.' }
    }
}

function Assert-Stage8NoProtectedKeys {
    param([AllowNull()] $Value)
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return }
    if ($Value -is [array]) { foreach ($item in $Value) { Assert-Stage8NoProtectedKeys $item }; return }
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.Name -cin $script:Stage8ProtectedKeys) { throw "production defect: P1 Stage 8 Student response disclosed $($property.Name)." }
        Assert-Stage8NoProtectedKeys $property.Value
    }
}

# P1 oracle: before Start the Student sees timing and allowance, never Questions or answers.
function Assert-Stage8PreStartPrivacy {
    param($Response)
    Assert-Stage8ApiSuccess $Response
    $data = $Response.Json.data
    Assert-Stage8Equal @($data.PSObject.Properties.Name | Sort-Object) @($script:Stage8DetailKeys | Sort-Object) 'pre-Start detail keys (no questions/answers)'
    Assert-Stage8Equal @($data.timing.PSObject.Properties.Name | Sort-Object) @($script:Stage8DetailTimingKeys | Sort-Object) 'pre-Start timing keys'
    Assert-Stage8Equal @($data.attempts.PSObject.Properties.Name | Sort-Object) @($script:Stage8DetailAttemptKeys | Sort-Object) 'pre-Start allowance keys'
    Assert-Stage8NoProtectedKeys $Response.Json
    $text = $Response.Json | ConvertTo-Json -Depth 30 -Compress
    if ($text -match '"questions"|"answers"|"prompt"|"answer_ui"') { throw 'production defect: P1 Stage 8 pre-Start detail leaked Question content.' }
}

# Attacker check: sorting public item IDs must not recover Matching pairs or the Ordering key.
function Assert-Stage8ItemIdPrivacy {
    param($Questions, $Nested)
    $matching = @($Questions | Where-Object type -CEQ 'matching')
    $ordering = @($Questions | Where-Object type -CEQ 'ordering')
    if ($matching.Count -ne 1 -or $ordering.Count -ne 1) { throw 'integration-harness defect: Item privacy check needs one Matching and one Ordering Question.' }
    $pairs = @(0..2 | ForEach-Object { "$($Nested.matching.left[$_]):$($Nested.matching.right[$_])" })
    $left = @($matching[0].answer_ui.left_items | ForEach-Object id | Sort-Object)
    $right = @($matching[0].answer_ui.right_items | ForEach-Object id | Sort-Object)
    Assert-Stage8Set @($left + $right) @($Nested.matching.left + $Nested.matching.right) 'public Matching item identities'
    $rank = @(0..($left.Count - 1) | ForEach-Object { "$($left[$_]):$($right[$_])" })
    if (@($rank | Where-Object { $_ -cin $pairs }).Count -ne 0) { throw 'production defect: P1 Matching pairs recoverable by sorting item IDs.' }
    $sortedOrder = @($ordering[0].answer_ui.items | ForEach-Object id | Sort-Object)
    if ((($sortedOrder) -join ',') -ceq (@($Nested.ordering) -join ',')) { throw 'production defect: P1 Ordering key recoverable by sorting item IDs.' }
}

function Assert-Stage8MonitoringPrivacy {
    param($Response)
    Assert-Stage8ApiSuccess $Response
    $text = $Response.Json | ConvertTo-Json -Depth 30 -Compress
    if ($text -match '"questions"|"answers"|"answer_ui"|"file"|"files"|"storage_key"|"prompt"') { throw 'production defect: Stage 8 monitoring leaked answers/files.' }
    foreach ($row in @($Response.Json.data.students)) { if ($null -ne $row.score) { throw 'production defect: Stage 8 monitoring exposed a score.' } }
}

function Assert-Stage8Download {
    param($Response, $Fixture)
    if ([int] $Response.StatusCode -ne 200) { throw 'production defect: Stage 8 owner protected download failed.' }
    $headers = $Response.Headers
    if ([string] $headers['Content-Type'] -cne [string] $Fixture.mime_type -or
        [string] $headers['Content-Disposition'] -notmatch '(?i)\Aattachment\s*;' -or
        [string] $headers['X-Content-Type-Options'] -cne 'nosniff') { throw 'production defect: Stage 8 protected download security headers mismatch.' }
    $directives = @(([string] $headers['Cache-Control']).ToLowerInvariant().Split(',') | ForEach-Object { $_.Trim() })
    if ('private' -cnotin $directives -or 'no-store' -cnotin $directives -or 'public' -cin $directives) { throw 'production defect: Stage 8 protected download is cacheable/public.' }
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $checksum = ([BitConverter]::ToString($hash.ComputeHash([byte[]] $Response.Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $hash.Dispose() }
    if ($checksum -cne $Fixture.sha256 -or [long] $Response.Bytes.Length -ne [long] $Fixture.size_bytes) { throw 'production defect: Stage 8 protected download bytes differ from the fixture.' }
}

function Assert-Stage8NoBytes {
    param($Response)
    if ($null -ne $Response.Bytes -and $Response.Bytes.Length -gt 0 -and [int] $Response.StatusCode -eq 200) { throw 'production defect: P1 Stage 8 protected file bytes were returned to an unauthorized actor.' }
}

# Section 64: the private blob is never reachable through a public web path of the same server.
function Assert-Stage8NoPublicPath {
    param([string] $ApiBaseUrl, [string] $StorageKey, $Fixture)
    $null = Resolve-Stage8ApiTarget $ApiBaseUrl
    if ([string]::IsNullOrEmpty($StorageKey)) { throw 'integration-harness defect: Stage 8 public-path probe needs the storage key.' }
    $origin = ([Uri] $ApiBaseUrl).GetLeftPart([UriPartial]::Authority)
    $encoded = @($StorageKey.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    foreach ($path in @("/storage/$encoded", "/$encoded", "/storage/app/private/$encoded")) {
        $handler = [Net.Http.HttpClientHandler]::new()
        $handler.AllowAutoRedirect = $false
        $client = [Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromSeconds(30)
        $response = $null
        try {
            try { $response = $client.GetAsync("$origin$path").GetAwaiter().GetResult() }
            catch { throw 'environment/runtime defect: Stage 8 public-path probe transport failed.' }
            $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            $hash = [Security.Cryptography.SHA256]::Create()
            try { $checksum = ([BitConverter]::ToString($hash.ComputeHash([byte[]] $bytes))).Replace('-', '').ToLowerInvariant() }
            finally { $hash.Dispose() }
            if (([int] $response.StatusCode -ge 200 -and [int] $response.StatusCode -lt 300) -or $checksum -ceq [string] $Fixture.sha256) {
                throw 'production defect: P1 Stage 8 private file is reachable through a public path.'
            }
        }
        finally {
            if ($null -ne $response) { $response.Dispose() }
            $client.Dispose(); $handler.Dispose()
        }
    }
}

function Assert-Stage8ReplayOutcome {
    param($First, $Replay, [int] $Status, [string[]] $StableFields)
    # The caller already judged the first response; a new-key Start may legitimately answer 200 after a 201.
    Assert-Stage8ApiSuccess $Replay $Status
    foreach ($field in $StableFields) { Assert-Stage8Equal $Replay.Json.data.$field $First.Json.data.$field "replay keeps $field" }
}

function Protect-Stage8Diagnostic {
    param([string] $Text, [AllowEmptyCollection()][string[]] $Secrets = @())
    $safe = [regex]::Replace($Text, '(?i)Bearer\s+[^\s,;"'']+', 'Bearer [REDACTED]')
    $safe = [regex]::Replace($safe, '\b[0-9]+\|[A-Za-z0-9]{20,}', '[REDACTED-TOKEN]')
    foreach ($secret in $Secrets) { if (-not [string]::IsNullOrEmpty($secret)) { $safe = $safe.Replace($secret, '[REDACTED]') } }
    $safe
}

# ---------------------------------------------------------------- transport and sessions

function New-Stage8Key { param([int] $Number) '08000000-0000-4000-8000-{0:D12}' -f (9000000 + $Number) }

function Invoke-Stage8ApiRequest {
    param([string] $ApiBaseUrl, [string] $Path, [ValidateSet('GET', 'POST', 'PUT')][string] $Method = 'GET',
        [string] $Token, [AllowNull()] $Body, [string] $RawBody, [string] $ContentType = 'application/json', [string] $Key, [string] $FilePath, [string] $AnswerType = 'file_based', [switch] $Binary, [switch] $NoContent)
    $null = Resolve-Stage8ApiTarget $ApiBaseUrl
    if ($Path -notmatch '\A/(?:auth|student|teacher|files)/' -or $Path -match '[\r\n#\\]') { throw 'integration-harness defect: Unexpected Stage 8 API request path.' }
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($Method), "$ApiBaseUrl$Path")
    $response = $null
    try {
        $null = $request.Headers.TryAddWithoutValidation('Accept', 'application/json')
        if ($Token) { $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token) }
        if ($PSBoundParameters.ContainsKey('Key')) { $null = $request.Headers.TryAddWithoutValidation('Idempotency-Key', $Key) }
        if ($FilePath) {
            $multipart = [Net.Http.MultipartFormDataContent]::new()
            $multipart.Add([Net.Http.StringContent]::new($AnswerType), 'type')
            $fileContent = [Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes($FilePath))
            $fileContent.Headers.ContentType = [Net.Http.Headers.MediaTypeHeaderValue]::new('application/octet-stream')
            $multipart.Add($fileContent, 'file', [IO.Path]::GetFileName($FilePath))
            $request.Content = $multipart
        }
        elseif ($PSBoundParameters.ContainsKey('RawBody')) {
            $request.Content = [Net.Http.StringContent]::new($RawBody, [Text.Encoding]::UTF8)
            $request.Content.Headers.ContentType = [Net.Http.Headers.MediaTypeHeaderValue]::new($ContentType)
        }
        elseif ($PSBoundParameters.ContainsKey('Body') -and -not $NoContent) {
            $request.Content = [Net.Http.StringContent]::new(($Body | ConvertTo-Json -Depth 30 -Compress), [Text.Encoding]::UTF8, 'application/json')
        }
        try { $response = $client.SendAsync($request).GetAwaiter().GetResult() }
        catch { throw 'environment/runtime defect: Stage 8 API transport failed; request/exception payload withheld.' }
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $headers = @{}
        foreach ($header in $response.Headers) { $headers[$header.Key] = $header.Value -join ', ' }
        foreach ($header in $response.Content.Headers) { $headers[$header.Key] = $header.Value -join ', ' }
        $json = $null
        if ($bytes.Length -gt 0 -and (-not $Binary -or [int] $response.StatusCode -ne 200)) {
            try { $json = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json }
            catch { throw 'production defect: Stage 8 API returned invalid JSON; payload withheld.' }
        }
        [pscustomobject] @{ StatusCode = [int] $response.StatusCode; Json = $json; Headers = $headers; Bytes = $(if ($Binary) { $bytes } else { $null }) }
    }
    finally {
        if ($null -ne $response) { $response.Dispose() }
        $request.Dispose(); $client.Dispose(); $handler.Dispose()
        $Token = $null; $Body = $null; $bytes = $null
    }
}

function New-Stage8ApiSession {
    param([string] $ApiBaseUrl, [string] $Login, [string] $Password)
    try {
        $response = Invoke-Stage8ApiRequest -ApiBaseUrl $ApiBaseUrl -Path '/auth/login' -Method POST -Body @{ login = $Login; password = $Password }
        Assert-Stage8ApiSuccess $response 200 login
        [string] $response.Json.data.token
    }
    finally { $Password = $null; $response = $null }
}

function Remove-Stage8ApiSession {
    param([string] $ApiBaseUrl, [string] $Token)
    if (-not $Token) { return }
    try {
        $response = Invoke-Stage8ApiRequest -ApiBaseUrl $ApiBaseUrl -Path '/auth/logout' -Method POST -Token $Token -Body @{}
        Assert-Stage8ApiSuccess $response 204 empty
    }
    finally { $Token = $null }
}

# One API context per runner invocation: sessions are opened lazily and always revoked.
function New-Stage8ApiContext {
    param([string] $ApiBaseUrl, [string] $Password, $Manifest, $FileManifest, $Runtime)
    [pscustomobject] @{ ApiBaseUrl = $ApiBaseUrl; Password = $Password; Manifest = $Manifest; Files = $FileManifest; Runtime = $Runtime
        Sessions = @{}; Evidence = [ordered] @{}; RejectedKeys = [Collections.Generic.List[string]]::new() }
}

function Get-Stage8Token {
    param($Context, [string] $Actor, [switch] $Fresh)
    if ($Fresh) {
        $token = New-Stage8ApiSession $Context.ApiBaseUrl "e2e_s08_$Actor" $Context.Password
        $Context.Sessions["$Actor#$([guid]::NewGuid().ToString('N'))"] = $token
        return $token
    }
    if (-not $Context.Sessions.ContainsKey($Actor)) { $Context.Sessions[$Actor] = New-Stage8ApiSession $Context.ApiBaseUrl "e2e_s08_$Actor" $Context.Password }
    $Context.Sessions[$Actor]
}

function Close-Stage8ApiContext {
    param($Context, [bool] $OperationFailed)
    $failures = 0
    foreach ($token in @($Context.Sessions.Values)) { try { Remove-Stage8ApiSession $Context.ApiBaseUrl $token } catch { $failures++ } }
    $Context.Sessions.Clear()
    $Context.Password = $null
    if ($failures -ne 0) {
        if ($OperationFailed) { Write-Warning 'environment/runtime defect: Stage 8 API session revocation also failed; original failure preserved.' }
        else { throw 'environment/runtime defect: Stage 8 API session revocation failed.' }
    }
}

function Invoke-Stage8Call {
    param($Context, [string] $Actor, [string] $Path, [string] $Method = 'GET', [AllowNull()] $Body, [string] $Key, [string] $FilePath, [switch] $Binary, [string] $RawBody, [string] $ContentType = 'application/json')
    $arguments = @{ ApiBaseUrl = $Context.ApiBaseUrl; Path = $Path; Method = $Method }
    if ($Actor) { $arguments.Token = Get-Stage8Token $Context $Actor }
    if ($PSBoundParameters.ContainsKey('Body')) { $arguments.Body = $Body }
    if ($PSBoundParameters.ContainsKey('Key')) { $arguments.Key = $Key }
    if ($FilePath) { $arguments.FilePath = $FilePath }
    if ($Binary) { $arguments.Binary = $true }
    if ($PSBoundParameters.ContainsKey('RawBody')) { $arguments.RawBody = $RawBody; $arguments.ContentType = $ContentType }
    Invoke-Stage8ApiRequest @arguments
}

function Add-Stage8Evidence { param($Context, [string] $Name, $Details) $Context.Evidence[$Name] = [pscustomobject] @{ result = 'PASS'; details = $Details }; Write-Host "Stage8Scenario: PASS $Name" }

function Get-Stage8Facts { Get-Stage8DatabaseFacts }

# ---------------------------------------------------------------- security matrices (Sections 35-39)

function Assert-Stage8NegativeProbes {
    param($Context, [object[]] $Probes, [string] $Label)
    # Logins write tokens and last_login_at, so every session opens before the snapshot.
    foreach ($probe in $Probes) { if ($probe.Actor) { Get-Stage8Token $Context $probe.Actor | Out-Null } }
    $before = Get-Stage8Facts
    foreach ($probe in $Probes) {
        $arguments = @{ Context = $Context; Actor = $probe.Actor; Path = $probe.Path; Method = $probe.Method }
        foreach ($name in @('Body', 'Key', 'FilePath', 'RawBody', 'ContentType')) { if ($probe.ContainsKey($name)) { $arguments[$name] = $probe[$name] } }
        if ($probe.ContainsKey('Binary')) { $arguments.Binary = $true }
        if ($probe.ContainsKey('Key') -and $probe.Key -cmatch '\A08000000-') { $Context.RejectedKeys.Add($probe.Key) }
        $response = Invoke-Stage8Call @arguments
        $allowed = @(if ($probe.ContainsKey('Fields')) { $probe.Fields })
        $required = @(if ($probe.ContainsKey('Required')) { $probe.Required })
        try { Assert-Stage8ApiError $response $probe.Status $probe.Code -AllowedFields $allowed -RequiredFields $required }
        catch { throw "$($_.Exception.Message) [$Label $($probe.Method) $($probe.Path)]" }
        Assert-Stage8NoBytes $response
        $safe = $response.Json | ConvertTo-Json -Depth 20 -Compress
        foreach ($protected in @('e2e_s08_', 'E2E S08 Foreign', 'private correctness')) { if ($safe.Contains($protected)) { throw 'production defect: P1 Stage 8 privacy-safe error disclosed a protected identity.' } }
    }
    $after = Get-Stage8Facts
    Assert-Stage8Equal $after.tables $before.tables "$Label changes no manifest rows"
    Assert-Stage8Equal $after.blobs $before.blobs "$Label changes no private blobs"
    foreach ($probe in $Probes) { if ($probe.ContainsKey('Key') -and $probe.Key -cmatch '\A08000000-') { Assert-Stage8NoIdempotencyRecord $after $probe.Key } }
    $after
}

function Initialize-Stage8ForeignResources {
    param($Context)
    $m = $Context.Manifest
    $activate = Invoke-Stage8Call $Context foreign_teacher "/teacher/blitz/$($m.assessments.foreign)/activate" POST -Key (New-Stage8Key 101) -Body @{}
    Assert-Stage8ApiSuccess $activate
    $start = Invoke-Stage8Call $Context foreign_student "/student/blitz/$($m.assessments.foreign)/attempts" POST -Key (New-Stage8Key 102) -Body @{ intent = 'start_normal' }
    Assert-Stage8ApiSuccess $start 201
    $attemptId = [string] $start.Json.data.id
    $upload = Invoke-Stage8Call $Context foreign_student "/student/attempts/$attemptId/answers/$($m.questions.foreign.file_based)" PUT -FilePath $Context.Files.Files['answer_pdf'].path
    Assert-Stage8ApiSuccess $upload
    [pscustomobject] @{ AttemptId = $attemptId; FileId = [string] $upload.Json.data.answer.file.id }
}

# Sections 35-37: unauthenticated, wrong role, cross-Tenant and non-recipient probes are exact and write nothing.
function Invoke-Stage8SecurityMatrix {
    param($Context, $UiEvidence)
    $m = $Context.Manifest
    $main = $m.assessments.main
    $mainAttempt = [string] $UiEvidence.attempt_ids[0]
    $mainFile = [string] $UiEvidence.file_id
    $shortQuestion = [string] $m.questions.main.short_written
    $foreign = Initialize-Stage8ForeignResources $Context
    $student = [string] $m.users.student
    $calls = @(
        @{ Method = 'GET'; Path = "/teacher/blitz/$main" },
        @{ Method = 'POST'; Path = "/teacher/blitz/$main/activate"; Key = (New-Stage8Key 110); Body = @{} },
        @{ Method = 'GET'; Path = "/teacher/blitz/$main/monitoring" },
        @{ Method = 'POST'; Path = "/teacher/blitz/$main/students/$student/attempt-exception"; Key = (New-Stage8Key 111); Body = @{ reason_type = 'technical'; reason = 'E2E S08 probe' } },
        @{ Method = 'GET'; Path = "/student/blitz/$main" },
        @{ Method = 'POST'; Path = "/student/blitz/$main/attempts"; Key = (New-Stage8Key 112); Body = @{ intent = 'start_normal' } },
        @{ Method = 'PUT'; Path = "/student/attempts/$mainAttempt/answers/$shortQuestion"; Body = @{ type = 'short_written'; text = 'E2E S08 probe' } },
        @{ Method = 'POST'; Path = "/student/attempts/$mainAttempt/submit"; Key = (New-Stage8Key 113); Body = @{} }
    )
    $probes = [Collections.Generic.List[hashtable]]::new()
    foreach ($call in $calls) { $probe = $call.Clone(); $probe.Actor = $null; $probe.Status = 401; $probe.Code = 'authentication_required'; $probes.Add($probe) }
    $probes.Add(@{ Actor = $null; Method = 'GET'; Path = "/files/$mainFile/download"; Binary = $true; Status = 401; Code = 'authentication_required' })
    foreach ($call in $calls[0..3]) { $probe = $call.Clone(); $probe.Actor = 'student'; $probe.Status = 403; $probe.Code = 'forbidden'; $probes.Add($probe) }
    foreach ($call in $calls[4..7]) { $probe = $call.Clone(); $probe.Actor = 'teacher'; $probe.Status = 403; $probe.Code = 'forbidden'; $probes.Add($probe) }
    # Teacher ownership of the Blitz never grants Student-submission access: privacy-safe 404, not 403.
    $probes.Add(@{ Actor = 'teacher'; Method = 'GET'; Path = "/files/$mainFile/download"; Binary = $true; Status = 404; Code = 'resource_not_found' })
    $foreignBlitz = $m.assessments.foreign
    $foreignStudent = [string] $m.users.foreign_student
    foreach ($probe in @(
            @{ Actor = 'teacher'; Method = 'GET'; Path = "/teacher/blitz/$foreignBlitz" },
            @{ Actor = 'teacher'; Method = 'POST'; Path = "/teacher/blitz/$foreignBlitz/activate"; Key = (New-Stage8Key 120); Body = @{} },
            @{ Actor = 'teacher'; Method = 'GET'; Path = "/teacher/blitz/$foreignBlitz/monitoring" },
            @{ Actor = 'teacher'; Method = 'POST'; Path = "/teacher/blitz/$foreignBlitz/students/$foreignStudent/attempt-exception"; Key = (New-Stage8Key 121); Body = @{ reason_type = 'technical'; reason = 'E2E S08 probe' } },
            @{ Actor = 'teacher'; Method = 'POST'; Path = "/teacher/blitz/$main/students/$foreignStudent/attempt-exception"; Key = (New-Stage8Key 122); Body = @{ reason_type = 'technical'; reason = 'E2E S08 probe' } },
            @{ Actor = 'student'; Method = 'GET'; Path = "/student/blitz/$foreignBlitz" },
            @{ Actor = 'student'; Method = 'POST'; Path = "/student/blitz/$foreignBlitz/attempts"; Key = (New-Stage8Key 123); Body = @{ intent = 'start_normal' } },
            @{ Actor = 'student'; Method = 'PUT'; Path = "/student/attempts/$($foreign.AttemptId)/answers/$($m.questions.foreign.short_written)"; Body = @{ type = 'short_written'; text = 'E2E S08 probe' } },
            @{ Actor = 'student'; Method = 'POST'; Path = "/student/attempts/$($foreign.AttemptId)/submit"; Key = (New-Stage8Key 124); Body = @{} },
            @{ Actor = 'student'; Method = 'GET'; Path = "/files/$($foreign.FileId)/download"; Binary = $true },
            @{ Actor = 'teacher'; Method = 'GET'; Path = '/teacher/blitz/not-a-uuid' },
            @{ Actor = 'student'; Method = 'GET'; Path = '/student/blitz/not-a-uuid' },
            @{ Actor = 'student'; Method = 'POST'; Path = '/student/attempts/not-a-uuid/submit'; Key = (New-Stage8Key 125); Body = @{} },
            @{ Actor = 'late_member'; Method = 'GET'; Path = "/student/blitz/$main" },
            @{ Actor = 'late_member'; Method = 'POST'; Path = "/student/blitz/$main/attempts"; Key = (New-Stage8Key 126); Body = @{ intent = 'start_normal' } },
            @{ Actor = 'peer'; Method = 'PUT'; Path = "/student/attempts/$mainAttempt/answers/$shortQuestion"; Body = @{ type = 'short_written'; text = 'E2E S08 probe' } },
            @{ Actor = 'peer'; Method = 'POST'; Path = "/student/attempts/$mainAttempt/submit"; Key = (New-Stage8Key 127); Body = @{} },
            @{ Actor = 'peer'; Method = 'GET'; Path = "/files/$mainFile/download"; Binary = $true })) {
        $probe.Status = 404; $probe.Code = 'resource_not_found'; $probes.Add($probe)
    }
    $after = Assert-Stage8NegativeProbes $Context $probes.ToArray() 'auth/role/Tenant/assignment matrix'
    if (@(Get-Stage8Rows $after assessment_attempts assessment_id $main | Where-Object student_id -CEQ $m.users.late_member).Count -ne 0) { throw 'production defect: P1 non-cohort Student created a Stage 8 Attempt.' }
    foreach ($actor in @('student', 'peer')) {
        $read = Invoke-Stage8Call $Context $actor "/student/blitz/$main"
        Assert-Stage8ApiSuccess $read
        Assert-Stage8NoProtectedKeys $read.Json
    }
    $download = Invoke-Stage8Call $Context student "/files/$mainFile/download" -Binary
    Assert-Stage8Download $download $Context.Files.Files['answer_pdf']
    Assert-Stage8NoPublicPath $Context.ApiBaseUrl ([string] (Get-Stage8Row $after files $mainFile).storage_key) $Context.Files.Files['answer_pdf']
    Add-Stage8Evidence $Context 'auth_role_tenant_assignment' ([pscustomobject] @{ probes = $probes.Count; foreign_attempt = $foreign.AttemptId; foreign_file = $foreign.FileId; main_file = $mainFile; public_paths = 3 })
    $foreign
}

# Section 39 / 34.1.4: malformed shapes are exactly 422 validation_failed with no domain or idempotency write.
function Invoke-Stage8TransportMatrix {
    param($Context, $UiEvidence)
    $m = $Context.Manifest
    $idleBlitz = $m.assessments.activation_idem_other
    $matrix = $m.assessments.matrix
    $peer = [string] $m.users.d_matrix_peer
    $finalAttempt = [string] $UiEvidence.attempt_ids[1]
    $startPath = "/student/blitz/$matrix/attempts"
    $number = 200
    $next = { $script:stage8TransportKey++; New-Stage8Key $script:stage8TransportKey }
    $script:stage8TransportKey = $number
    $probes = @(
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$idleBlitz/activate"; Body = @{}; Fields = @('idempotency_key'); Required = @('idempotency_key') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$idleBlitz/activate"; Key = 'malformed-key'; Body = @{}; Fields = @('idempotency_key'); Required = @('idempotency_key') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$idleBlitz/activate?unexpected=1"; Key = (& $next); Body = @{}; Fields = @('unexpected'); Required = @('unexpected') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$idleBlitz/activate"; Key = (& $next); Body = @{ protected = $true }; Fields = @('body'); Required = @('body') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$idleBlitz/close"; Body = @{ protected = $true }; Fields = @('body'); Required = @('body') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$idleBlitz/archive?unexpected=1"; Body = @{}; Fields = @('unexpected'); Required = @('unexpected') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$idleBlitz/archive"; Body = @{ protected = $true }; Fields = @('body'); Required = @('body') },
        @{ Actor = 'individual_teacher'; Method = 'GET'; Path = "/teacher/blitz/$($m.assessments.monitoring)/monitoring?unexpected=1"; Fields = @('unexpected'); Required = @('unexpected') },
        @{ Actor = 'd_matrix_peer'; Method = 'GET'; Path = "/student/blitz/$matrix`?unexpected=1"; Fields = @('unexpected'); Required = @('unexpected') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Body = @{ intent = 'start_normal' }; Fields = @('idempotency_key'); Required = @('idempotency_key') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = 'malformed-key'; Body = @{ intent = 'start_normal' }; Fields = @('idempotency_key'); Required = @('idempotency_key') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = (& $next); RawBody = ''; Fields = @('body', 'intent'); Required = @('body', 'intent') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = (& $next); RawBody = '{}'; Fields = @('intent'); Required = @('intent') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = (& $next); Body = @{ intent = 'start_third' }; Fields = @('intent'); Required = @('intent') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = (& $next); Body = @{ intent = 'start_normal'; deadline_at = '2100-01-01T00:00:00Z' }; Fields = @('deadline_at'); Required = @('deadline_at') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = (& $next); Body = @{ intent = 'resume' }; Fields = @('attempt_id'); Required = @('attempt_id') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = (& $next); Body = @{ intent = 'start_normal'; attempt_id = $finalAttempt }; Fields = @('attempt_id'); Required = @('attempt_id') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = (& $next); Body = @{ intent = 'start_replacement'; attempt_id = $finalAttempt }; Fields = @('attempt_id'); Required = @('attempt_id') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = $startPath; Key = (& $next); Body = @{ intent = 'resume'; attempt_id = '08000000000040008000000003000001' }; Fields = @('attempt_id'); Required = @('attempt_id') },
        @{ Actor = 'd_matrix_peer'; Method = 'POST'; Path = "$startPath`?unexpected=1"; Key = (& $next); Body = @{ intent = 'start_normal' }; Fields = @('unexpected'); Required = @('unexpected') },
        @{ Actor = 'student'; Method = 'POST'; Path = "/student/attempts/$finalAttempt/submit"; Body = @{}; Fields = @('idempotency_key'); Required = @('idempotency_key') },
        @{ Actor = 'student'; Method = 'POST'; Path = "/student/attempts/$finalAttempt/submit"; Key = 'malformed-key'; Body = @{}; Fields = @('idempotency_key'); Required = @('idempotency_key') },
        @{ Actor = 'student'; Method = 'POST'; Path = "/student/attempts/$finalAttempt/submit"; Key = (& $next); Body = @{ protected = $true }; Fields = @('body'); Required = @('body') },
        @{ Actor = 'student'; Method = 'POST'; Path = "/student/attempts/$finalAttempt/submit?unexpected=1"; Key = (& $next); Body = @{}; Fields = @('unexpected'); Required = @('unexpected') },
        @{ Actor = 'student'; Method = 'PUT'; Path = "/student/attempts/$finalAttempt/answers/$($m.questions.main.short_written)"; Body = @{ type = 'short_written'; text = 'x'; awarded_points = 9 }; Fields = @('body'); Required = @('body') },
        @{ Actor = 'student'; Method = 'PUT'; Path = "/student/attempts/$finalAttempt/answers/$($m.questions.main.short_written)?unexpected=1"; Body = @{ type = 'short_written'; text = 'x' }; Fields = @('query'); Required = @('query') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$matrix/students/$peer/attempt-exception"; Body = @{ reason_type = 'technical'; reason = 'E2E S08' }; Fields = @('idempotency_key'); Required = @('idempotency_key') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$matrix/students/$peer/attempt-exception"; Key = 'malformed-key'; Body = @{ reason_type = 'technical'; reason = 'E2E S08' }; Fields = @('idempotency_key'); Required = @('idempotency_key') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$matrix/students/$peer/attempt-exception"; Key = (& $next); Body = @{ reason_type = 'excuse'; reason = 'E2E S08' }; Fields = @('reason_type'); Required = @('reason_type') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$matrix/students/$peer/attempt-exception"; Key = (& $next); Body = @{ reason_type = 'technical'; reason = '   ' }; Fields = @('reason'); Required = @('reason') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$matrix/students/$peer/attempt-exception"; Key = (& $next); Body = @{ reason_type = 'technical'; reason = 'E2E S08'; attempt_id = $finalAttempt }; Fields = @('attempt_id'); Required = @('attempt_id') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = "/teacher/topics/$($m.topics.practice)/result-pair"; Body = @{ homework_assessment_id = $m.assessments.practice_homework; blitz_assessment_id = $null }; Fields = @('blitz_assessment_id'); Required = @('blitz_assessment_id') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = "/teacher/topics/$($m.topics.practice)/result-pair"; Body = @{ homework_assessment_id = $m.assessments.practice_homework; blitz_assessment_id = 'not-a-uuid' }; Fields = @('blitz_assessment_id'); Required = @('blitz_assessment_id') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = "/teacher/topics/$($m.topics.practice)/result-pair"; Body = @{ homework_assessment_id = $m.assessments.practice_homework; blitz_assessment_id = $m.assessments.practice_blitz; unexpected_field = 1 }; Fields = @('unexpected_field'); Required = @('unexpected_field') },
        @{ Actor = 'individual_teacher'; Method = 'POST'; Path = "/teacher/blitz/$idleBlitz/schedule"; Body = @{ scheduled_at = '2100-01-01T09:00:00+05:00'; unexpected_field = 1 }; Fields = @('unexpected_field'); Required = @('unexpected_field') }
    )
    foreach ($probe in $probes) { $probe.Status = 422; $probe.Code = 'validation_failed' }
    Assert-Stage8NegativeProbes $Context $probes 'strict transport matrix' | Out-Null
    Add-Stage8Evidence $Context 'strict_transport' ([pscustomobject] @{ probes = $probes.Count })
}
