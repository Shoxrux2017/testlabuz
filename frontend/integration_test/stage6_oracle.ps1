Set-StrictMode -Version Latest

$script:Stage6OraclePrefix = 'testlabuz-stage6-oracle-'
$script:Stage6FrozenPrefix = '/tmp/testlabuz-stage6-frozen-'
$script:Stage6AuthoringTopicId = '06000000-0000-4000-c000-000000000101'

function Assert-Stage6OraclePath {
    param([Parameter(Mandatory = $true)][string] $Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if (
        -not [IO.Path]::GetDirectoryName($fullPath).TrimEnd('\', '/').Equals($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not [IO.Path]::GetFileName($fullPath).StartsWith($script:Stage6OraclePrefix, [StringComparison]::Ordinal) -or
        [IO.Path]::GetFileName($fullPath) -notmatch '\Atestlabuz-stage6-oracle-[a-f0-9]{32}\.json\z'
    ) {
        throw 'Stage 6 oracle output must be an exact controlled system-temp JSON path.'
    }
    $fullPath
}

function Assert-Stage6FrozenPath {
    param([Parameter(Mandatory = $true)][string] $Path)
    if ($Path -notmatch '\A/tmp/testlabuz-stage6-frozen-[a-f0-9]{32}\.json\z') {
        throw 'Stage 6 frozen state must use its exact container-temp namespace.'
    }
}

function Invoke-Stage6ReadOnlyPhp {
    param(
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $Program,
        [Parameter(Mandatory = $true)][string] $Marker
    )
    if ($BackendContainerName -cne 'testlabuz-stage6-e2e-app') {
        throw 'Stage 6 oracle may query only the dedicated backend container.'
    }
    $output = & docker exec $BackendContainerName php artisan tinker "--execute=$Program" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Stage 6 read-only database probe failed for $Marker." }
    $match = [regex]::Match(($output -join "`n"), ([regex]::Escape($Marker) + '(?<payload>[A-Za-z0-9+/=]+)'))
    if (-not $match.Success) { throw "Stage 6 read-only database probe omitted $Marker." }
    try {
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($match.Groups['payload'].Value))
        $json | ConvertFrom-Json
    }
    catch { throw "Stage 6 read-only database probe returned invalid $Marker JSON." }
}

function New-Stage6SanitizedOracle {
    param(
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $Destination
    )
    $safeDestination = Assert-Stage6OraclePath -Path $Destination
    $program = @'
$manifest = [
    'version' => 1,
    'institution' => ['id' => '06000000-0000-4000-8000-000000000101', 'name' => 'E2E S06 Target Institution', 'timezone' => 'Asia/Tashkent'],
    'actors' => [
        'target_admin' => ['id' => '06000000-0000-4000-9000-000000000101', 'login' => 'e2e_s06_target_admin'],
        'target_teacher' => ['id' => '06000000-0000-4000-9000-000000000201', 'login' => 'e2e_s06_target_teacher'],
        'student_alpha' => ['id' => '06000000-0000-4000-9000-000000000301', 'login' => 'e2e_s06_student_alpha'],
        'student_beta' => ['id' => '06000000-0000-4000-9000-000000000302', 'login' => 'e2e_s06_student_beta'],
        'student_ended' => ['id' => '06000000-0000-4000-9000-000000000303', 'login' => 'e2e_s06_student_ended'],
        'student_inactive' => ['id' => '06000000-0000-4000-9000-000000000304', 'login' => 'e2e_s06_student_inactive'],
        'unrelated_teacher' => ['id' => '06000000-0000-4000-9000-000000000401', 'login' => 'e2e_s06_unrelated_teacher'],
        'foreign_student' => ['id' => '06000000-0000-4000-9000-000000000503', 'login' => 'e2e_s06_foreign_student'],
    ],
    'groups' => ['main' => ['id' => '06000000-0000-4000-a000-000000000101', 'name' => 'E2E S06 Main Group']],
    'topics' => [
        'authoring' => ['id' => '06000000-0000-4000-c000-000000000101', 'title' => 'E2E S06 Authoring Topic'],
        'locked' => ['id' => '06000000-0000-4000-c000-000000000102', 'title' => 'E2E S06 Locked Topic'],
        'expired' => ['id' => '06000000-0000-4000-c000-000000000103', 'title' => 'E2E S06 Expired Deadline Topic'],
        'foreign' => ['id' => '06000000-0000-4000-c000-000000000105', 'title' => 'E2E S06 Foreign Topic'],
        'security' => ['id' => '06000000-0000-4000-c000-000000000106', 'title' => 'E2E S06 Security Topic'],
    ],
    'homework' => [
        'locked' => ['id' => '06000000-0000-4000-d000-000000000101', 'title' => 'E2E S06 Locked Official Homework'],
        'replacement' => ['id' => '06000000-0000-4000-d000-000000000102', 'title' => 'E2E S06 Locked Replacement Candidate'],
        'expired' => ['id' => '06000000-0000-4000-d000-000000000103', 'title' => 'E2E S06 Expired Draft Homework'],
        'security_selected' => ['id' => '06000000-0000-4000-d000-000000000104', 'title' => 'E2E S06 Security Selected Candidate'],
        'foreign' => ['id' => '06000000-0000-4000-d000-000000000105', 'title' => 'E2E S06 Foreign Homework'],
    ],
    'expected' => ['main_title' => 'E2E S06 Official Homework', 'practice_title' => 'E2E S06 Selected Practice Homework'],
];
foreach ($manifest['actors'] as $actor) {
    if (DB::table('users')->where('id', $actor['id'])->where('login_name', $actor['login'])->count() !== 1) { throw new RuntimeException('Stage 6 actor manifest is absent.'); }
}
foreach ($manifest['topics'] as $topic) {
    if (DB::table('topics')->where('id', $topic['id'])->where('title', $topic['title'])->count() !== 1) { throw new RuntimeException('Stage 6 Topic manifest is absent.'); }
}
foreach ($manifest['homework'] as $homework) {
    if (DB::table('assessments')->where('id', $homework['id'])->where('title', $homework['title'])->count() !== 1) { throw new RuntimeException('Stage 6 Homework manifest is absent.'); }
}
if (DB::table('assessments')->where('topic_id', $manifest['topics']['authoring']['id'])->exists()) { throw new RuntimeException('Stage 6 Authoring Topic did not start empty.'); }
echo 'Stage6Manifest:'.base64_encode(json_encode($manifest, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
'@
    $manifest = Invoke-Stage6ReadOnlyPhp -BackendContainerName $BackendContainerName -Program $program -Marker 'Stage6Manifest:'
    if ([int] $manifest.version -ne 1) { throw 'Stage 6 sanitized oracle version is invalid.' }
    $manifestJson = $manifest | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText($safeDestination, $manifestJson, [Text.UTF8Encoding]::new($false))
    $safeDestination
}

function Remove-Stage6SanitizedOracle {
    param([Parameter(Mandatory = $true)][string] $Path)
    $safePath = Assert-Stage6OraclePath -Path $Path
    if (Test-Path -LiteralPath $safePath) { Remove-Item -LiteralPath $safePath -Force }
}

function Invoke-Stage6FrozenStateOracle {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Capture', 'Compare', 'Remove')][string] $Action,
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $ContainerPath
    )
    Assert-Stage6FrozenPath -Path $ContainerPath
    if ($BackendContainerName -cne 'testlabuz-stage6-e2e-app') { throw 'Stage 6 frozen state may use only the dedicated backend container.' }
    if ($Action -eq 'Remove') {
        & docker exec $BackendContainerName php -r "if (is_file('$ContainerPath')) { unlink('$ContainerPath'); }" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Stage 6 frozen-state cleanup failed.' }
        return
    }
    $program = @'
$authoringTopic = '06000000-0000-4000-c000-000000000101';
$authoringAssessments = DB::table('assessments')->where('topic_id', $authoringTopic)->pluck('id')->all();
$authoringQuestions = DB::table('questions')->whereIn('assessment_id', $authoringAssessments)->pluck('id')->all();
$authoringBlanks = DB::table('question_fill_blanks')->whereIn('question_id', $authoringQuestions)->pluck('id')->all();
$rows = static function (string $table, ?callable $scope = null, array $forget = []): array {
    $query = DB::table($table);
    if ($scope !== null) { $scope($query); }
    $values = $query->get()->map(static function ($row) use ($forget): array {
        $value = (array) $row;
        foreach ($forget as $column) { unset($value[$column]); }
        ksort($value);
        return $value;
    })->all();
    usort($values, static fn (array $left, array $right): int => strcmp(json_encode($left, JSON_THROW_ON_ERROR), json_encode($right, JSON_THROW_ON_ERROR)));
    return $values;
};
$userRows = $rows('users', null, ['password']);
foreach ($userRows as &$userRow) {
    if (str_starts_with((string) ($userRow['login_name'] ?? ''), 'e2e_s06_')) {
        unset($userRow['last_login_at'], $userRow['updated_at']);
        ksort($userRow);
    }
}
unset($userRow);
usort($userRows, static fn (array $left, array $right): int => strcmp(json_encode($left, JSON_THROW_ON_ERROR), json_encode($right, JSON_THROW_ON_ERROR)));
$snapshot = [
    'institutions' => $rows('institutions'),
    'institution_settings' => $rows('institution_settings'),
    'institution_understanding_categories' => $rows('institution_understanding_categories'),
    'users' => $userRows,
    'groups' => $rows('groups'),
    'group_teacher_memberships' => $rows('group_teacher_memberships'),
    'group_student_memberships' => $rows('group_student_memberships'),
    'parent_student_relationships' => $rows('parent_student_relationships'),
    'topics' => $rows('topics', static fn ($q) => $q->where('id', '<>', $authoringTopic)),
    'learning_materials' => $rows('learning_materials'),
    'files' => $rows('files'),
    'assessments' => $rows('assessments', static fn ($q) => $q->where('topic_id', '<>', $authoringTopic)),
    'homework_assignments' => $rows('homework_assignments', static fn ($q) => $q->whereNotIn('assessment_id', $authoringAssessments)),
    'assessment_students' => $rows('assessment_students', static fn ($q) => $q->whereNotIn('assessment_id', $authoringAssessments)),
    'assessment_attempts' => $rows('assessment_attempts', static fn ($q) => $q->whereNotIn('assessment_id', $authoringAssessments)),
    'topic_result_pairs' => $rows('topic_result_pairs', static fn ($q) => $q->where('topic_id', '<>', $authoringTopic)),
    'questions' => $rows('questions', static fn ($q) => $q->whereNotIn('assessment_id', $authoringAssessments)),
    'question_choice_options' => $rows('question_choice_options', static fn ($q) => $q->whereNotIn('question_id', $authoringQuestions)),
    'question_true_false_answers' => $rows('question_true_false_answers', static fn ($q) => $q->whereNotIn('question_id', $authoringQuestions)),
    'question_short_accepted_answers' => $rows('question_short_accepted_answers', static fn ($q) => $q->whereNotIn('question_id', $authoringQuestions)),
    'question_matching_items' => $rows('question_matching_items', static fn ($q) => $q->whereNotIn('question_id', $authoringQuestions)),
    'question_ordering_items' => $rows('question_ordering_items', static fn ($q) => $q->whereNotIn('question_id', $authoringQuestions)),
    'question_fill_blanks' => $rows('question_fill_blanks', static fn ($q) => $q->whereNotIn('question_id', $authoringQuestions)),
    'question_fill_blank_accepted_answers' => $rows('question_fill_blank_accepted_answers', static fn ($q) => $q->whereNotIn('blank_id', $authoringBlanks)),
];
echo 'Stage6Frozen:'.base64_encode(json_encode($snapshot, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
'@
    $facts = Invoke-Stage6ReadOnlyPhp -BackendContainerName $BackendContainerName -Program $program -Marker 'Stage6Frozen:'
    $canonical = $facts | ConvertTo-Json -Depth 100 -Compress
    if ($Action -eq 'Capture') {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($canonical))
        & docker exec $BackendContainerName php -r "file_put_contents('$ContainerPath', base64_decode('$encoded'));" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Stage 6 unrelated-state capture failed.' }
        return
    }
    $stored = & docker exec $BackendContainerName php -r "if (!is_file('$ContainerPath')) { exit(2); } echo file_get_contents('$ContainerPath');" 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Stage 6 unrelated-state baseline is absent.' }
    if (($stored -join "`n") -cne $canonical) { throw 'Stage 6 unrelated educational state changed.' }
}

function Get-Stage6DatabaseFacts {
    param([Parameter(Mandatory = $true)][string] $BackendContainerName)
    $program = @'
$mainTitle = 'E2E S06 Official Homework';
$practiceTitle = 'E2E S06 Selected Practice Homework';
$authoringTopic = '06000000-0000-4000-c000-000000000101';
$lockedHomework = '06000000-0000-4000-d000-000000000101';
$packAssessment = static function ($assessment): array {
    if ($assessment === null) { return []; }
    $id = $assessment->id;
    $questions = DB::table('questions')->where('assessment_id', $id)->orderBy('position')->get();
    $typed = [];
    foreach ($questions as $question) {
        $typed[] = [
            'id' => $question->id, 'type' => $question->type, 'prompt' => $question->prompt,
            'points' => (string) $question->points, 'position' => (int) $question->position,
            'checking_mode' => $question->checking_mode,
            'choices' => DB::table('question_choice_options')->where('question_id', $question->id)->orderBy('position')->get(['option_text', 'is_correct', 'position'])->all(),
            'true_false' => DB::table('question_true_false_answers')->where('question_id', $question->id)->get(['correct_value'])->all(),
            'short_answers' => DB::table('question_short_accepted_answers')->where('question_id', $question->id)->orderBy('position')->get(['accepted_text', 'position'])->all(),
            'matching' => DB::table('question_matching_items')->where('question_id', $question->id)->orderBy('side')->orderBy('position')->get(['side', 'match_key', 'item_text', 'position'])->all(),
            'ordering' => DB::table('question_ordering_items')->where('question_id', $question->id)->orderBy('correct_position')->get(['item_text', 'correct_position'])->all(),
            'blanks' => DB::table('question_fill_blanks')->where('question_id', $question->id)->orderBy('position')->get()->map(static function ($blank): array {
                return ['key' => $blank->blank_key, 'position' => (int) $blank->position, 'answers' => DB::table('question_fill_blank_accepted_answers')->where('blank_id', $blank->id)->orderBy('position')->pluck('accepted_text')->all()];
            })->all(),
        ];
    }
    $homework = DB::table('homework_assignments')->where('assessment_id', $id)->first();
    return [
        'id' => $id, 'institution_id' => $assessment->institution_id, 'topic_id' => $assessment->topic_id,
        'teacher_id' => $assessment->teacher_id, 'type' => $assessment->type, 'title' => $assessment->title,
        'description' => $assessment->description, 'student_instructions' => $assessment->student_instructions,
        'assignment_mode' => $assessment->assignment_mode, 'total' => (string) $assessment->total_possible_points,
        'status' => $homework?->status, 'deadline_at' => $homework?->deadline_at,
        'recipients' => DB::table('assessment_students')->where('assessment_id', $id)->orderBy('student_id')->get(['student_id', 'assignment_source'])->all(),
        'attempts' => DB::table('assessment_attempts')->where('assessment_id', $id)->orderBy('id')->get()->all(),
        'questions' => $typed,
    ];
};
$mainRows = DB::table('assessments')->where('institution_id', '06000000-0000-4000-8000-000000000101')->where('teacher_id', '06000000-0000-4000-9000-000000000201')->where('topic_id', $authoringTopic)->where('title', $mainTitle)->get();
$practiceRows = DB::table('assessments')->where('institution_id', '06000000-0000-4000-8000-000000000101')->where('teacher_id', '06000000-0000-4000-9000-000000000201')->where('topic_id', $authoringTopic)->where('title', $practiceTitle)->get();
$pair = DB::table('topic_result_pairs')->where('topic_id', $authoringTopic)->first();
$lockedPair = DB::table('topic_result_pairs')->where('topic_id', '06000000-0000-4000-c000-000000000102')->first();
$facts = [
    'main_count' => $mainRows->count(), 'main' => $packAssessment($mainRows->first()),
    'practice_count' => $practiceRows->count(), 'practice' => $packAssessment($practiceRows->first()),
    'authoring_topic_status' => DB::table('topics')->where('id', $authoringTopic)->value('status'),
    'authoring_open_homework_count' => DB::table('assessments')->join('homework_assignments', 'homework_assignments.assessment_id', '=', 'assessments.id')->where('assessments.topic_id', $authoringTopic)->whereIn('homework_assignments.status', ['draft', 'active'])->count(),
    'authoring_pair' => $pair, 'locked_pair' => $lockedPair, 'locked' => $packAssessment(DB::table('assessments')->where('id', $lockedHomework)->first()),
    'fake_blitz_count' => DB::table('assessments')->where('topic_id', $authoringTopic)->where('type', 'blitz')->count(),
    'rejected_homework_count' => DB::table('assessments')->where('topic_id', $authoringTopic)->where('title', 'E2E S06 Foreign Student Rejected')->count(),
    'temporary_question_count' => DB::table('questions')->where('prompt', 'E2E S06 Temporary Question')->count(),
];
echo 'Stage6DatabaseFacts:'.base64_encode(json_encode($facts, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
'@
    Invoke-Stage6ReadOnlyPhp -BackendContainerName $BackendContainerName -Program $program -Marker 'Stage6DatabaseFacts:'
}

function Assert-Stage6ExactSet {
    param([object[]] $Actual, [string[]] $Expected, [string] $Label)
    $actualValues = @($Actual | ForEach-Object { [string] $_ } | Sort-Object)
    $expectedValues = @($Expected | Sort-Object)
    if (($actualValues -join '|') -cne ($expectedValues -join '|')) { throw "Stage 6 oracle rejected $Label." }
}

function Assert-Stage6OrderedTextRows {
    param(
        [Parameter(Mandatory = $true)][object[]] $Rows,
        [Parameter(Mandatory = $true)][string] $TextProperty,
        [Parameter(Mandatory = $true)][string] $PositionProperty,
        [Parameter(Mandatory = $true)][string[]] $Expected,
        [Parameter(Mandatory = $true)][string] $Label
    )
    if ($Rows.Count -ne $Expected.Count) { throw "Stage 6 oracle rejected $Label count." }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        $row = @($Rows | Where-Object { [int] $_.$PositionProperty -eq ($index + 1) })
        if ($row.Count -ne 1 -or [string] $row[0].$TextProperty -cne $Expected[$index]) {
            throw "Stage 6 oracle rejected $Label order."
        }
    }
}

function Assert-Stage6DatabasePostconditions {
    param([Parameter(Mandatory = $true)][psobject] $Facts)

    if ([int] $Facts.main_count -ne 1 -or [int] $Facts.practice_count -ne 1) { throw 'Stage 6 oracle requires exactly one main and one practice Homework.' }
    $main = $Facts.main
    if (
        [string] $main.institution_id -cne '06000000-0000-4000-8000-000000000101' -or
        [string] $main.teacher_id -cne '06000000-0000-4000-9000-000000000201' -or
        [string] $main.topic_id -cne $script:Stage6AuthoringTopicId -or [string] $main.type -cne 'homework' -or
        [string] $main.title -cne 'E2E S06 Official Homework' -or [string] $main.description -cne 'Networking fundamentals' -or
        [string] $main.student_instructions -cne 'Complete every question.' -or [string] $main.assignment_mode -cne 'group' -or
        [decimal] $main.total -ne [decimal] 20.5 -or [string] $main.status -cne 'archived' -or
        ([DateTimeOffset] $main.deadline_at).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -cne '2035-06-15T13:00:00Z' -or
        @($main.attempts).Count -ne 0
    ) { throw 'Stage 6 oracle rejected main Homework identity or lifecycle.' }
    Assert-Stage6ExactSet -Actual @($main.recipients | ForEach-Object { "$($_.student_id):$($_.assignment_source)" }) -Expected @(
        '06000000-0000-4000-9000-000000000301:group', '06000000-0000-4000-9000-000000000302:group'
    ) -Label 'main recipient snapshot'
    $questions = @($main.questions)
    if ($questions.Count -ne 10) { throw 'Stage 6 oracle rejected retained Question count.' }
    Assert-Stage6ExactSet -Actual @($questions.position) -Expected @('1','2','3','4','5','6','7','8','9','10') -Label 'contiguous Question positions'
    Assert-Stage6ExactSet -Actual @($questions.type | Select-Object -Unique) -Expected @('single_choice','multiple_choice','true_false','short_written','open_written','file_based','matching','ordering','fill_in_blank') -Label 'nine Question types'
    if ([string] $questions[0].type -cne 'fill_in_blank') { throw 'Stage 6 oracle requires Fill in Blank first.' }
    if (($questions.type -join '|') -cne 'fill_in_blank|single_choice|multiple_choice|true_false|short_written|short_written|open_written|file_based|matching|ordering') { throw 'Stage 6 oracle rejected retained Question order.' }
    $single = @($questions | Where-Object type -eq 'single_choice')
    if ($single.Count -ne 1 -or [string] $single[0].prompt -cne 'What is the primary purpose of DNS?' -or [decimal] $single[0].points -ne 1.5 -or @($single[0].choices).Count -ne 3 -or @($single[0].choices | Where-Object is_correct).Count -ne 1) { throw 'Stage 6 oracle rejected Single Choice normalized data.' }
    Assert-Stage6ExactSet -Actual @($single[0].choices.option_text) -Expected @('Resolves domain names','Compresses files','Encrypts all traffic') -Label 'Single Choice options'
    Assert-Stage6ExactSet -Actual @($single[0].choices | Where-Object is_correct | ForEach-Object option_text) -Expected @('Resolves domain names') -Label 'Single Choice correct option'
    Assert-Stage6OrderedTextRows -Rows @($single[0].choices) -TextProperty 'option_text' -PositionProperty 'position' -Expected @('Resolves domain names','Compresses files','Encrypts all traffic') -Label 'Single Choice options'
    $multiple = @($questions | Where-Object type -eq 'multiple_choice')
    if ($multiple.Count -ne 1 -or @($multiple[0].choices).Count -ne 4) { throw 'Stage 6 oracle rejected Multiple Choice normalized data.' }
    Assert-Stage6ExactSet -Actual @($multiple[0].choices.option_text) -Expected @('HTTP','DNS','PNG','JPEG') -Label 'Multiple Choice options'
    Assert-Stage6ExactSet -Actual @($multiple[0].choices | Where-Object is_correct | ForEach-Object option_text) -Expected @('HTTP','DNS') -Label 'Multiple Choice correct options'
    Assert-Stage6OrderedTextRows -Rows @($multiple[0].choices) -TextProperty 'option_text' -PositionProperty 'position' -Expected @('HTTP','DNS','PNG','JPEG') -Label 'Multiple Choice options'
    $trueFalse = @($questions | Where-Object type -eq 'true_false')
    if ($trueFalse.Count -ne 1 -or [string] $trueFalse[0].prompt -cne 'An IP address can identify a network endpoint.' -or [decimal] $trueFalse[0].points -ne 1 -or @($trueFalse[0].true_false).Count -ne 1 -or -not [bool] $trueFalse[0].true_false[0].correct_value) { throw 'Stage 6 oracle rejected True/False normalized data.' }
    $short = @($questions | Where-Object type -eq 'short_written')
    Assert-Stage6ExactSet -Actual @($short.checking_mode) -Expected @('automatic','manual') -Label 'Short Written modes'
    $automatic = @($short | Where-Object checking_mode -eq 'automatic')[0]
    $manual = @($short | Where-Object checking_mode -eq 'manual')[0]
    if ([string] $automatic.prompt -cne 'Write the abbreviation for Domain Name System.' -or [decimal] $automatic.points -ne 1 -or [string] $manual.prompt -cne 'Describe DNS in one sentence.' -or [decimal] $manual.points -ne 2) { throw 'Stage 6 oracle rejected Short Written identity.' }
    Assert-Stage6ExactSet -Actual @($automatic.short_answers.accepted_text) -Expected @('DNS') -Label 'Short Written automatic answers'
    if ([int] $automatic.short_answers[0].position -ne 1) { throw 'Stage 6 oracle rejected Short Written answer position.' }
    if (@($manual.short_answers).Count -ne 0) { throw 'Stage 6 oracle rejected manual Short Written answers.' }
    foreach ($type in @('open_written','file_based')) {
        $question = @($questions | Where-Object type -eq $type)[0]
        if (@($question.choices).Count + @($question.true_false).Count + @($question.short_answers).Count + @($question.matching).Count + @($question.ordering).Count + @($question.blanks).Count -ne 0 -or [string] $question.checking_mode -cne 'manual') { throw "Stage 6 oracle rejected $type normalized data." }
    }
    if ([string] (@($questions | Where-Object type -eq 'open_written')[0]).prompt -cne 'Explain the steps of a DNS lookup.' -or [decimal] (@($questions | Where-Object type -eq 'open_written')[0]).points -ne 3) { throw 'Stage 6 oracle rejected Open Written identity.' }
    if ([string] (@($questions | Where-Object type -eq 'file_based')[0]).prompt -cne 'Upload the completed network presentation.' -or [decimal] (@($questions | Where-Object type -eq 'file_based')[0]).points -ne 4) { throw 'Stage 6 oracle rejected File Based identity.' }
    $matching = @($questions | Where-Object type -eq 'matching')[0]
    if ([string] $matching.prompt -cne 'Match each term to its meaning.' -or [decimal] $matching.points -ne 2 -or @($matching.matching).Count -ne 4 -or @($matching.matching.match_key | Select-Object -Unique).Count -ne 2) { throw 'Stage 6 oracle rejected Matching rows.' }
    Assert-Stage6ExactSet -Actual @($matching.matching.item_text) -Expected @('DNS','Domain name resolution','IP','Network address') -Label 'Matching items'
    foreach ($key in @($matching.matching.match_key | Select-Object -Unique)) {
        Assert-Stage6ExactSet -Actual @($matching.matching | Where-Object match_key -eq $key | ForEach-Object side) -Expected @('left','right') -Label 'Matching pair sides'
    }
    foreach ($expectedPair in @(
        [pscustomobject] @{ position = 1; left = 'DNS'; right = 'Domain name resolution' },
        [pscustomobject] @{ position = 2; left = 'IP'; right = 'Network address' }
    )) {
        $left = @($matching.matching | Where-Object { $_.side -ceq 'left' -and [int] $_.position -eq $expectedPair.position })
        if ($left.Count -ne 1 -or [string] $left[0].item_text -cne $expectedPair.left) { throw 'Stage 6 oracle rejected Matching left order.' }
        $right = @($matching.matching | Where-Object { $_.side -ceq 'right' -and [string] $_.match_key -ceq [string] $left[0].match_key })
        if ($right.Count -ne 1 -or [string] $right[0].item_text -cne $expectedPair.right -or [int] $right[0].position -ne $expectedPair.position) { throw 'Stage 6 oracle rejected Matching semantic pair.' }
    }
    $ordering = @($questions | Where-Object type -eq 'ordering')[0]
    if ([string] $ordering.prompt -cne 'Put the simplified lookup steps in order.' -or [decimal] $ordering.points -ne 2) { throw 'Stage 6 oracle rejected Ordering identity.' }
    Assert-Stage6ExactSet -Actual @($ordering.ordering.correct_position) -Expected @('1','2','3') -Label 'Ordering positions'
    Assert-Stage6ExactSet -Actual @($ordering.ordering.item_text) -Expected @('Enter domain','Resolve address','Contact server') -Label 'Ordering items'
    Assert-Stage6OrderedTextRows -Rows @($ordering.ordering) -TextProperty 'item_text' -PositionProperty 'correct_position' -Expected @('Enter domain','Resolve address','Contact server') -Label 'Ordering items'
    $fill = @($questions | Where-Object type -eq 'fill_in_blank')[0]
    if ([string] $fill.prompt -cne 'DNS converts {{host}} into an {{address}}.' -or [decimal] $fill.points -ne 2) { throw 'Stage 6 oracle rejected Fill in Blank placeholders.' }
    Assert-Stage6ExactSet -Actual @($fill.blanks.key) -Expected @('host','address') -Label 'Fill in Blank keys'
    foreach ($blank in @($fill.blanks)) {
        $expected = if ([string] $blank.key -ceq 'host') { 'domain name' } else { 'IP address' }
        Assert-Stage6ExactSet -Actual @($blank.answers) -Expected @($expected) -Label "Fill in Blank $($blank.key) answers"
        $expectedPosition = if ([string] $blank.key -ceq 'host') { 1 } else { 2 }
        if ([int] $blank.position -ne $expectedPosition) { throw 'Stage 6 oracle rejected Fill in Blank position.' }
    }
    if ([int] $Facts.temporary_question_count -ne 0) { throw 'Stage 6 oracle found the sacrificial Question.' }

    $pair = $Facts.authoring_pair
    if ($null -eq $pair -or [string] $pair.homework_assessment_id -cne [string] $main.id -or $null -ne $pair.blitz_assessment_id -or $null -eq $pair.cohort_snapshotted_at -or $null -ne $pair.locked_at) { throw 'Stage 6 oracle rejected the official result pair.' }
    $practice = $Facts.practice
    if ([string] $practice.assignment_mode -cne 'selected_students' -or [string] $practice.status -cne 'archived' -or [decimal] $practice.total -ne 0 -or @($practice.questions).Count -ne 0 -or @($practice.attempts).Count -ne 0 -or [string] $pair.homework_assessment_id -ceq [string] $practice.id) { throw 'Stage 6 oracle rejected the practice Homework.' }
    Assert-Stage6ExactSet -Actual @($practice.recipients | ForEach-Object { "$($_.student_id):$($_.assignment_source)" }) -Expected @('06000000-0000-4000-9000-000000000301:direct') -Label 'practice recipients'
    if ([string] $Facts.authoring_topic_status -cne 'closed' -or [int] $Facts.authoring_open_homework_count -ne 0) { throw 'Stage 6 oracle rejected final Topic state.' }
    $lockedPair = $Facts.locked_pair
    if ($null -eq $lockedPair -or $null -ne $lockedPair.blitz_assessment_id -or $null -eq $lockedPair.cohort_snapshotted_at -or $null -eq $lockedPair.locked_at -or @($Facts.locked.attempts).Count -ne 1 -or [string] $Facts.locked.attempts[0].status -cne 'in_progress' -or $null -ne $Facts.locked.attempts[0].submitted_at -or $null -ne $Facts.locked.attempts[0].finalized_at -or $null -ne $Facts.locked.attempts[0].finalization_reason -or @($Facts.locked.questions).Count -ne 1 -or [decimal] $Facts.locked.total -ne 1) { throw 'Stage 6 oracle rejected locked fixture integrity.' }
    if ([int] $Facts.fake_blitz_count -ne 0 -or [int] $Facts.rejected_homework_count -ne 0) { throw 'Stage 6 oracle found fabricated or partially rejected state.' }
}
