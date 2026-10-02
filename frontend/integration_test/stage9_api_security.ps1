Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'stage9_oracle.ps1')
Add-Type -AssemblyName System.Net.Http

# Student responses never carry answer keys, checking metadata, the reviewer or official-row internals (contract section 11.4).
$script:Stage9ProtectedKeys = @('awarded_points', 'checking_status', 'checked_by', 'checked_by_user_id', 'checked_at', 'is_correct', 'correct_value',
    'accepted_answers', 'accepted_text', 'match_key', 'correct_position', 'earned_points', 'official_attempt_id', 'selection_policy_code', 'selected_at',
    'review_due_at', 'review_overdue', 'checking_mode', 'configuration', 'client_key', 'storage_key', 'storage_disk', 'checksum_sha256')

# ---------------------------------------------------------------- pure response assertions

function Assert-Stage9ApiError {
    param($Response, [int] $ExpectedStatus, [string] $ExpectedCode, [string[]] $AllowedFields = @(), [string[]] $RequiredFields = @())
    # An empty list assigned from an if-expression arrives as $null; treat it as empty.
    $AllowedFields = @($AllowedFields | Where-Object { -not [string]::IsNullOrEmpty($_) })
    $RequiredFields = @($RequiredFields | Where-Object { -not [string]::IsNullOrEmpty($_) })
    if ([int] $Response.StatusCode -ne $ExpectedStatus -or $null -eq $Response.Json) { throw "production defect: Stage 9 API expected HTTP $ExpectedStatus ($ExpectedCode), got $($Response.StatusCode)." }
    $body = $Response.Json
    $properties = @($body.PSObject.Properties.Name)
    if (@(@('message', 'code', 'errors') | Where-Object { $_ -cnotin $properties }).Count -ne 0 -or
        @($properties | Where-Object { $_ -cnotin @('message', 'code', 'errors') }).Count -ne 0 -or
        $body.code -cne $ExpectedCode -or $body.message -isnot [string] -or [string]::IsNullOrWhiteSpace($body.message) -or
        $body.errors -isnot [pscustomobject]) { throw "production defect: Stage 9 API error envelope mismatch for $ExpectedCode." }
    $fields = @($body.errors.PSObject.Properties | ForEach-Object Name)
    if ($ExpectedStatus -eq 422 -and $ExpectedCode -ceq 'validation_failed') {
        if ($fields.Count -eq 0) { throw 'production defect: Stage 9 validation_failed without field errors.' }
        if (@($fields | Where-Object { $_ -cnotin $AllowedFields }).Count -ne 0) { throw "production defect: Stage 9 validation errors name fields outside the invalid vector: $($fields -join ',')." }
        if (@($RequiredFields | Where-Object { $_ -cnotin $fields }).Count -ne 0) { throw "production defect: Stage 9 validation errors miss the invalid field: $($fields -join ',')." }
        foreach ($field in $fields) {
            if ($body.errors.$field -isnot [array] -or @($body.errors.$field).Count -eq 0 -or @($body.errors.$field | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -ne 0) {
                throw 'production defect: Stage 9 validation error values must be non-empty string arrays.'
            }
        }
    }
    elseif ($fields.Count -ne 0) { throw "production defect: Stage 9 $ExpectedCode must carry errors = {}." }
}

function Assert-Stage9ApiSuccess {
    param($Response, [int] $ExpectedStatus = 200, [ValidateSet('resource', 'collection', 'paged', 'login', 'empty')][string] $Shape = 'resource')
    if ([int] $Response.StatusCode -ne $ExpectedStatus) { throw "production defect: Stage 9 API expected successful HTTP $ExpectedStatus, got $($Response.StatusCode) $(if ($null -ne $Response.Json -and $null -ne $Response.Json.PSObject.Properties['code']) { $Response.Json.code })." }
    if ($Shape -ceq 'empty') { if ($null -ne $Response.Json) { throw 'production defect: Expected an empty Stage 9 response.' }; return }
    if ($null -eq $Response.Json -or $null -eq $Response.Json.PSObject.Properties['data']) { throw 'production defect: Missing Stage 9 success data envelope.' }
    $data = $Response.Json.data
    if ($Shape -ceq 'collection' -or $Shape -ceq 'paged') {
        if ($data -isnot [array]) { throw 'production defect: Invalid Stage 9 collection envelope.' }
        if ($Shape -ceq 'paged') {
            $meta = $Response.Json.PSObject.Properties['meta']
            $pagination = if ($null -ne $meta -and $null -ne $meta.Value) { $meta.Value.PSObject.Properties['pagination'] } else { $null }
            if ($null -eq $pagination -or (@($pagination.Value.PSObject.Properties.Name | Sort-Object) -join ',') -cne 'last_page,page,per_page,total') {
                throw 'production defect: Stage 9 paged collection lacks the exact meta.pagination {page, per_page, total, last_page}.'
            }
        }
    }
    elseif ($data -isnot [pscustomobject]) { throw 'production defect: Invalid Stage 9 success resource.' }
    elseif ($Shape -ceq 'login') {
        if ($null -eq $data.PSObject.Properties['token'] -or [string]::IsNullOrWhiteSpace($data.token) -or $data.token_type -cne 'Bearer') { throw 'environment/runtime defect: Stage 9 login failed.' }
    }
}

function Assert-Stage9NoProtectedKeys {
    param([AllowNull()] $Value, [string] $Label = 'Student response')
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return }
    if ($Value -is [array]) { foreach ($item in $Value) { Assert-Stage9NoProtectedKeys $item $Label }; return }
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.Name -cin $script:Stage9ProtectedKeys) { throw "production defect: P1 Stage 9 $Label disclosed $($property.Name)." }
        Assert-Stage9NoProtectedKeys $property.Value $Label
    }
}

function Assert-Stage9Download {
    param($Response, $Fixture)
    if ([int] $Response.StatusCode -ne 200) { throw 'production defect: Stage 9 protected download failed.' }
    $headers = $Response.Headers
    if ([string] $headers['Content-Type'] -cne [string] $Fixture.mime_type -or
        [string] $headers['Content-Disposition'] -notmatch '(?i)\Aattachment\s*;' -or
        -not ([string] $headers['Content-Disposition']).Contains([string] $Fixture.original_name) -or
        [string] $headers['X-Content-Type-Options'] -cne 'nosniff') { throw 'production defect: Stage 9 protected download security headers mismatch.' }
    $directives = @(([string] $headers['Cache-Control']).ToLowerInvariant().Split(',') | ForEach-Object { $_.Trim() })
    if ('private' -cnotin $directives -or 'no-store' -cnotin $directives -or 'public' -cin $directives) { throw 'production defect: Stage 9 protected download is cacheable/public.' }
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $checksum = ([BitConverter]::ToString($hash.ComputeHash([byte[]] $Response.Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $hash.Dispose() }
    if ($checksum -cne $Fixture.sha256 -or [long] $Response.Bytes.Length -ne [long] $Fixture.size_bytes) { throw 'production defect: Stage 9 protected download bytes differ from the fixture.' }
}

function Assert-Stage9NoBytes {
    param($Response)
    if ($null -ne $Response.Bytes -and $Response.Bytes.Length -gt 0 -and [int] $Response.StatusCode -eq 200) { throw 'production defect: P1 Stage 9 protected file bytes were returned to an unauthorized actor.' }
}

# The private blob is never reachable through a public web path of the same server.
function Assert-Stage9NoPublicPath {
    param([string] $ApiBaseUrl, [string] $StorageKey, $Fixture)
    $null = Resolve-Stage9ApiTarget $ApiBaseUrl
    if ([string]::IsNullOrEmpty($StorageKey)) { throw 'integration-harness defect: Stage 9 public-path probe needs the storage key.' }
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
            catch { throw 'environment/runtime defect: Stage 9 public-path probe transport failed.' }
            $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            $hash = [Security.Cryptography.SHA256]::Create()
            try { $checksum = ([BitConverter]::ToString($hash.ComputeHash([byte[]] $bytes))).Replace('-', '').ToLowerInvariant() }
            finally { $hash.Dispose() }
            if (([int] $response.StatusCode -ge 200 -and [int] $response.StatusCode -lt 300) -or $checksum -ceq [string] $Fixture.sha256) {
                throw 'production defect: P1 Stage 9 private file is reachable through a public path.'
            }
        }
        finally {
            if ($null -ne $response) { $response.Dispose() }
            $client.Dispose(); $handler.Dispose()
        }
    }
}

function Protect-Stage9Diagnostic {
    param([string] $Text, [AllowEmptyCollection()][string[]] $Secrets = @())
    $safe = [regex]::Replace($Text, '(?i)Bearer\s+[^\s,;"'']+', 'Bearer [REDACTED]')
    $safe = [regex]::Replace($safe, '\b[0-9]+\|[A-Za-z0-9]{20,}', '[REDACTED-TOKEN]')
    foreach ($secret in $Secrets) { if (-not [string]::IsNullOrEmpty($secret)) { $safe = $safe.Replace($secret, '[REDACTED]') } }
    $safe
}

# ---------------------------------------------------------------- transport and sessions

function New-Stage9Key { param([int] $Number) '09000000-0000-4000-8000-{0:D12}' -f (9000000 + $Number) }

function Invoke-Stage9ApiRequest {
    param([string] $ApiBaseUrl, [string] $Path, [ValidateSet('GET', 'POST', 'PUT')][string] $Method = 'GET',
        [string] $Token, [AllowNull()] $Body, [string] $RawBody, [string] $ContentType = 'application/json', [string] $Key, [string] $FilePath, [string] $AnswerType = 'file_based', [switch] $Binary, [switch] $NoContent)
    $null = Resolve-Stage9ApiTarget $ApiBaseUrl
    if ($Path -notmatch '\A/(?:auth|student|teacher|files)/' -or $Path -match '[\r\n#\\]') { throw 'integration-harness defect: Unexpected Stage 9 API request path.' }
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
        catch { throw 'environment/runtime defect: Stage 9 API transport failed; request/exception payload withheld.' }
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $headers = @{}
        foreach ($header in $response.Headers) { $headers[$header.Key] = $header.Value -join ', ' }
        foreach ($header in $response.Content.Headers) { $headers[$header.Key] = $header.Value -join ', ' }
        $json = $null
        $text = $null
        if ($bytes.Length -gt 0 -and (-not $Binary -or [int] $response.StatusCode -ne 200)) {
            $text = [Text.Encoding]::UTF8.GetString($bytes)
            try { $json = $text | ConvertFrom-Json }
            catch { throw 'production defect: Stage 9 API returned invalid JSON; payload withheld.' }
        }
        [pscustomobject] @{ StatusCode = [int] $response.StatusCode; Json = $json; Text = $text; Headers = $headers; Bytes = $(if ($Binary) { $bytes } else { $null }) }
    }
    finally {
        if ($null -ne $response) { $response.Dispose() }
        $request.Dispose(); $client.Dispose(); $handler.Dispose()
        $Token = $null; $Body = $null; $bytes = $null
    }
}

function New-Stage9ApiSession {
    param([string] $ApiBaseUrl, [string] $Login, [string] $Password)
    try {
        $response = Invoke-Stage9ApiRequest -ApiBaseUrl $ApiBaseUrl -Path '/auth/login' -Method POST -Body @{ login = $Login; password = $Password }
        Assert-Stage9ApiSuccess $response 200 login
        [string] $response.Json.data.token
    }
    finally { $Password = $null; $response = $null }
}

function Remove-Stage9ApiSession {
    param([string] $ApiBaseUrl, [string] $Token)
    if (-not $Token) { return }
    try {
        $response = Invoke-Stage9ApiRequest -ApiBaseUrl $ApiBaseUrl -Path '/auth/logout' -Method POST -Token $Token -Body @{}
        Assert-Stage9ApiSuccess $response 204 empty
    }
    finally { $Token = $null }
}

# One API context per runner invocation: sessions are opened lazily and always revoked.
function New-Stage9ApiContext {
    param([string] $ApiBaseUrl, [string] $Password, $Manifest, $FileManifest)
    [pscustomobject] @{ ApiBaseUrl = $ApiBaseUrl; Password = $Password; Manifest = $Manifest; Files = $FileManifest
        Sessions = @{}; Evidence = [ordered] @{}; RejectedKeys = [Collections.Generic.List[string]]::new(); StudentReads = [Collections.Generic.List[object]]::new(); Runtime = [ordered] @{} }
}

function Get-Stage9Token {
    param($Context, [string] $Actor)
    if (-not $Context.Sessions.ContainsKey($Actor)) { $Context.Sessions[$Actor] = New-Stage9ApiSession $Context.ApiBaseUrl "e2e_s09_$Actor" $Context.Password }
    $Context.Sessions[$Actor]
}

function Close-Stage9ApiContext {
    param($Context, [bool] $OperationFailed)
    $failures = 0
    foreach ($token in @($Context.Sessions.Values)) { try { Remove-Stage9ApiSession $Context.ApiBaseUrl $token } catch { $failures++ } }
    $Context.Sessions.Clear()
    $Context.Password = $null
    if ($failures -ne 0) {
        if ($OperationFailed) { Write-Warning 'environment/runtime defect: Stage 9 API session revocation also failed; original failure preserved.' }
        else { throw 'environment/runtime defect: Stage 9 API session revocation failed.' }
    }
}

function Invoke-Stage9Call {
    param($Context, [string] $Actor, [string] $Path, [string] $Method = 'GET', [AllowNull()] $Body, [string] $Key, [string] $FilePath, [switch] $Binary, [string] $RawBody, [string] $ContentType = 'application/json')
    $arguments = @{ ApiBaseUrl = $Context.ApiBaseUrl; Path = $Path; Method = $Method }
    if ($Actor) { $arguments.Token = Get-Stage9Token $Context $Actor }
    if ($PSBoundParameters.ContainsKey('Body')) { $arguments.Body = $Body }
    if ($PSBoundParameters.ContainsKey('Key')) { $arguments.Key = $Key }
    if ($FilePath) { $arguments.FilePath = $FilePath }
    if ($Binary) { $arguments.Binary = $true }
    if ($PSBoundParameters.ContainsKey('RawBody')) { $arguments.RawBody = $RawBody; $arguments.ContentType = $ContentType }
    $response = Invoke-Stage9ApiRequest @arguments
    # Every Student JSON response of the run is later checked against the protected-key denylist.
    if ($Path.StartsWith('/student/', [StringComparison]::Ordinal) -and $null -ne $response.Json) { $Context.StudentReads.Add([pscustomobject] @{ Path = $Path; Json = $response.Json }) }
    $response
}

# A successful Student read; it never carries a protected key.
function Invoke-Stage9StudentRead {
    param($Context, [string] $Actor, [string] $Path)
    $response = Invoke-Stage9Call $Context $Actor $Path
    $shape = if ($Path -match '\A/student/(?:homework|blitz/finished)(?:\?|\z)') { 'paged' } elseif ($Path -match '\A/student/blitz/active\z') { 'collection' } else { 'resource' }
    Assert-Stage9ApiSuccess $response 200 $shape
    Assert-Stage9NoProtectedKeys $response.Json "Student read $Path"
    $response.Json
}

function Add-Stage9Evidence { param($Context, [string] $Name, $Details) $Context.Evidence[$Name] = [pscustomobject] @{ result = 'PASS'; details = $Details }; Write-Host "Stage9Scenario: PASS $Name" }

# ---------------------------------------------------------------- negative probes

function Assert-Stage9NegativeProbes {
    param($Context, [object[]] $Probes, [string] $Label)
    # Logins write tokens and last_login_at, so every session opens before the snapshot.
    foreach ($probe in $Probes) { if ($probe.Actor) { Get-Stage9Token $Context $probe.Actor | Out-Null } }
    $before = Get-Stage9DatabaseFacts
    foreach ($probe in $Probes) {
        $arguments = @{ Context = $Context; Actor = $probe.Actor; Path = $probe.Path; Method = $probe.Method }
        foreach ($name in @('Body', 'Key', 'FilePath', 'RawBody', 'ContentType')) { if ($probe.ContainsKey($name)) { $arguments[$name] = $probe[$name] } }
        if ($probe.ContainsKey('Binary')) { $arguments.Binary = $true }
        if ($probe.ContainsKey('Key') -and $probe.Key -cmatch '\A09000000-') { $Context.RejectedKeys.Add($probe.Key) }
        $response = Invoke-Stage9Call @arguments
        $allowed = @(if ($probe.ContainsKey('Fields')) { $probe.Fields })
        $required = @(if ($probe.ContainsKey('Required')) { $probe.Required })
        try { Assert-Stage9ApiError $response $probe.Status $probe.Code -AllowedFields $allowed -RequiredFields $required }
        catch { throw "$($_.Exception.Message) [$Label $($probe.Method) $($probe.Path)]" }
        Assert-Stage9NoBytes $response
        if ($null -ne $response.Text -and ($response.Text.Contains('e2e_s09_') -or $response.Text.Contains('E2E S09'))) { throw 'production defect: P1 Stage 9 privacy-safe error disclosed a protected identity.' }
        # Contract section 11.3: an error names no id beyond the ones the caller put in the path.
        if ($null -ne $response.Text) {
            foreach ($id in @([regex]::Matches($response.Text, '(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') | ForEach-Object Value)) {
                if (-not $probe.Path.ToLowerInvariant().Contains($id.ToLowerInvariant())) { throw 'production defect: P1 Stage 9 error response disclosed an id the caller did not send.' }
            }
        }
    }
    $after = Get-Stage9DatabaseFacts
    Assert-Stage9Equal $after.tables $before.tables "$Label changes no manifest rows"
    Assert-Stage9Equal $after.blobs $before.blobs "$Label changes no private blobs"
    foreach ($probe in $Probes) { if ($probe.ContainsKey('Key') -and $probe.Key -cmatch '\A09000000-') { Assert-Stage9NoIdempotencyRecord $after $probe.Key } }
    $after
}

function Get-Stage9ReviewBody {
    param([string] $AnswerId, $Points = 1, [AllowNull()] $Feedback = $null)
    @{ answers = @(@{ answer_id = $AnswerId; awarded_points = $Points; feedback = $Feedback }) }
}

# Contract section 9.2: the review API error contract; every probe writes nothing.
function Invoke-Stage9ReviewTransportMatrix {
    param($Context)
    $m = $Context.Manifest
    $runtime = $Context.Runtime
    $submission = [string] $runtime.review_attempt_id
    $path = "/teacher/submissions/$submission/review"
    $q3 = [string] $runtime.review_answer_ids.q3
    $q1 = [string] $runtime.review_auto_answer_ids.q1
    $pending = [string] $m.answers.backfill_hw_1.q8
    $long = 'x' * 2001
    $probes = @(
        @{ Actor = 'teacher'; Method = 'PUT'; Path = "/teacher/submissions/$($m.attempts.backfill_hw_1)/review"; Body = (Get-Stage9ReviewBody $pending); Status = 409; Code = 'automatic_checking_pending' },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; Body = (Get-Stage9ReviewBody $q3 5.5); Fields = @('answers.0.awarded_points'); Required = @('answers.0.awarded_points') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; Body = (Get-Stage9ReviewBody $q3 -1); Fields = @('answers.0.awarded_points'); Required = @('answers.0.awarded_points') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; RawBody = ('{"answers":[{"answer_id":"' + $q3 + '","awarded_points":1.1234567,"feedback":null}]}'); Fields = @('answers.0.awarded_points'); Required = @('answers.0.awarded_points') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; Body = (Get-Stage9ReviewBody $q3 1 $long); Fields = @('answers.0.feedback'); Required = @('answers.0.feedback') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; Body = (Get-Stage9ReviewBody $q1); Fields = @('answers.0.answer_id'); Required = @('answers.0.answer_id') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; Body = @{ answers = @(@{ answer_id = $q3; awarded_points = 1; feedback = $null }, @{ answer_id = $q3.ToUpperInvariant(); awarded_points = 1; feedback = $null }) }; Fields = @('answers.1.answer_id'); Required = @('answers.1.answer_id') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; Body = @{ answers = @(@{ answer_id = $q3; awarded_points = 1 }) }; Fields = @('answers.0.feedback'); Required = @('answers.0.feedback') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; Body = @{ answers = @(@{ answer_id = $q3; awarded_points = 1; feedback = $null; extra = 1 }) }; Fields = @('answers.0.extra'); Required = @('answers.0.extra') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; Body = @{ answers = @(@{ answer_id = $q3; awarded_points = 1; feedback = $null }); extra = 1 }; Fields = @('extra'); Required = @('extra') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = "$path`?unexpected=1"; Body = (Get-Stage9ReviewBody $q3); Fields = @('unexpected'); Required = @('unexpected') },
        @{ Actor = 'teacher'; Method = 'PUT'; Path = $path; RawBody = 'not json'; ContentType = 'text/plain'; Fields = @('body'); Required = @('body') },
        @{ Actor = 'teacher'; Method = 'GET'; Path = '/teacher/submissions?unexpected=1'; Fields = @('unexpected'); Required = @('unexpected') },
        @{ Actor = 'teacher'; Method = 'GET'; Path = "/teacher/submissions/$submission`?unexpected=1"; Fields = @('unexpected'); Required = @('unexpected') }
    )
    foreach ($probe in $probes) { if (-not $probe.ContainsKey('Status')) { $probe.Status = 422; $probe.Code = 'validation_failed' } }
    Assert-Stage9NegativeProbes $Context $probes 'review error contract' | Out-Null
    Add-Stage9Evidence $Context 'review_transport' ([pscustomobject] @{ probes = $probes.Count })
}

# Contract section 9.5 tenant_privacy: role, Tenant, ownership and classmate boundaries over every Stage 9 endpoint.
function Invoke-Stage9TenantPrivacyMatrix {
    param($Context)
    $m = $Context.Manifest
    $runtime = $Context.Runtime
    $targets = @(
        [pscustomobject] @{ Submission = [string] $runtime.review_attempt_id; Answer = [string] $runtime.review_answer_ids.q3; Assessment = [string] $m.assessments.review_hw; Student = [string] $m.users.student; Homework = [string] $m.assessments.review_hw; Owner = 'teacher'; Foreign = 'manual_teacher' },
        [pscustomobject] @{ Submission = [string] $runtime.exception_attempt_1_id; Answer = [string] $runtime.exception_answer_1_q2; Assessment = [string] $m.assessments.exception_blitz; Student = [string] $m.users.student; Homework = $null; Owner = 'teacher'; Foreign = 'manual_teacher' },
        [pscustomobject] @{ Submission = [string] $runtime.manual_attempt_id; Answer = [string] $runtime.manual_answer_q2; Assessment = [string] $m.assessments.manual_hw; Student = [string] $m.users.manual_student; Homework = [string] $m.assessments.manual_hw; Owner = 'manual_teacher'; Foreign = 'teacher' }
    )
    $file = [string] $runtime.review_file_id
    $probes = [Collections.Generic.List[hashtable]]::new()
    foreach ($target in $targets) {
        $calls = @(
            @{ Method = 'GET'; Path = "/teacher/submissions/$($target.Submission)" },
            @{ Method = 'PUT'; Path = "/teacher/submissions/$($target.Submission)/review"; Body = (Get-Stage9ReviewBody $target.Answer) },
            @{ Method = 'GET'; Path = "/teacher/assessments/$($target.Assessment)/students/$($target.Student)/official-score" }
        )
        if ($null -ne $target.Homework) { $calls += @{ Method = 'PUT'; Path = "/teacher/homework/$($target.Homework)/review-due-at"; Body = @{ review_due_at = $null } } }
        foreach ($call in $calls) {
            foreach ($actor in @($null, 'student')) {
                $probe = $call.Clone(); $probe.Actor = $actor
                if ($null -eq $actor) { $probe.Status = 401; $probe.Code = 'authentication_required' } else { $probe.Status = 403; $probe.Code = 'forbidden' }
                $probes.Add($probe)
            }
            foreach ($actor in @($target.Foreign) + $(if ($target.Owner -ceq 'teacher') { @('peer_teacher') } else { @() })) {
                $probe = $call.Clone(); $probe.Actor = $actor; $probe.Status = 404; $probe.Code = 'resource_not_found'; $probes.Add($probe)
            }
        }
    }
    $probes.Add(@{ Actor = $null; Method = 'GET'; Path = '/teacher/submissions'; Status = 401; Code = 'authentication_required' })
    $probes.Add(@{ Actor = 'student'; Method = 'GET'; Path = '/teacher/submissions'; Status = 403; Code = 'forbidden' })
    $probes.Add(@{ Actor = $null; Method = 'GET'; Path = "/files/$file/download"; Binary = $true; Status = 401; Code = 'authentication_required' })
    foreach ($actor in @('classmate', 'peer_teacher', 'manual_teacher', 'manual_student')) {
        $probes.Add(@{ Actor = $actor; Method = 'GET'; Path = "/files/$file/download"; Binary = $true; Status = 404; Code = 'resource_not_found' })
    }
    $probes.Add(@{ Actor = 'classmate'; Method = 'GET'; Path = "/student/attempts/$($runtime.review_attempt_id)"; Status = 404; Code = 'resource_not_found' })
    $probes.Add(@{ Actor = 'manual_student'; Method = 'GET'; Path = "/student/homework/$($m.assessments.review_hw)"; Status = 404; Code = 'resource_not_found' })
    Assert-Stage9NegativeProbes $Context $probes.ToArray() 'Tenant/role/privacy matrix' | Out-Null

    # Queues list exactly the caller's accessible submissions, in every checking status.
    $queue = { param($Actor) $response = Invoke-Stage9Call $Context $Actor '/teacher/submissions?per_page=100'; Assert-Stage9ApiSuccess $response 200 paged; if ([int] $response.Json.meta.pagination.last_page -ne 1) { throw 'integration-harness defect: Stage 9 queue check needs one page.' }; @($response.Json.data | ForEach-Object { [string] $_.id }) }
    $manualAttempts = @([string] $runtime.manual_attempt_id)
    $facts = Get-Stage9DatabaseFacts
    $autoAttempts = @($facts.tables.assessment_attempts | Where-Object { $_.institution_id -ceq [string] $Context.Manifest.institutions.auto -and $_.status -cne 'in_progress' } | ForEach-Object { [string] $_.id })
    if (@(& $queue 'peer_teacher').Count -ne 0) { throw 'production defect: P1 a same-Institution non-owner Teacher sees review submissions.' }
    $foreignQueue = @(& $queue 'manual_teacher')
    if ((@($foreignQueue | Sort-Object) -join ',') -cne (@($manualAttempts | Sort-Object) -join ',')) { throw 'production defect: P1 the manual Institution queue is not exactly its own submission.' }
    $ownerQueue = @(& $queue 'teacher')
    if ((@($ownerQueue | Sort-Object) -join ',') -cne (@($autoAttempts | Sort-Object) -join ',')) { throw 'production defect: P1 the owner queue is not exactly the owned frozen Attempts of its Institution.' }
    Add-Stage9Evidence $Context 'tenant_privacy' ([pscustomobject] @{ probes = $probes.Count; owner_queue = $ownerQueue.Count; foreign_queue = $foreignQueue.Count })
}
