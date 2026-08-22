Set-StrictMode -Version Latest

function New-Stage4OracleFile {
    param(
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $DestinationPath
    )

    if ($BackendContainerName -cne 'testlabuz-stage4-e2e-app') {
        throw 'The Stage 4 oracle may use only the exact dedicated backend container.'
    }
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedDestination = [IO.Path]::GetFullPath($DestinationPath)
    if (
        -not $resolvedDestination.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolvedDestination) -cnotmatch '^testlabuz-stage4-oracle-[a-f0-9]{32}\.json$'
    ) {
        throw 'The Stage 4 oracle destination must be a dedicated system-temp file.'
    }

    $oracleProgram = @'
<?php

require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Support\Facades\DB;

$environment = app()->environment();
$database = (string) DB::scalar('select current_database()');
$driver = DB::connection()->getDriverName();
$pdoDriver = (string) DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME);
if ($environment !== 'testing' || $database !== 'testlabuz_testing' || $driver !== 'pgsql' || $pdoDriver !== 'pgsql') {
    throw new RuntimeException('Stage 4 oracle refused the active runtime.');
}

$ids = [
    'target_institution' => '04000000-0000-4000-8000-000000000101',
    'foreign_institution' => '04000000-0000-4000-8000-000000000102',
    'target_admin' => '04000000-0000-4000-9000-000000000101',
    'wrong_role' => '04000000-0000-4000-9000-000000000201',
    'target_teacher' => '04000000-0000-4000-9000-000000000201',
    'target_student' => '04000000-0000-4000-9000-000000000205',
    'target_parent' => '04000000-0000-4000-9000-000000000208',
    'foreign_teacher' => '04000000-0000-4000-9000-000000000301',
    'foreign_student' => '04000000-0000-4000-9000-000000000302',
    'foreign_parent' => '04000000-0000-4000-9000-000000000303',
    'target_active_group' => '04000000-0000-4000-a000-000000000101',
    'target_archived_group' => '04000000-0000-4000-a000-000000000102',
    'foreign_group' => '04000000-0000-4000-a000-000000000103',
    'foreign_relationship' => '04000000-0000-4000-c000-000000000102',
];

$user = static fn (string $id): array => (array) DB::table('users')
    ->where('id', $id)
    ->firstOrFail(['id', 'institution_id', 'login_name', 'role', 'is_active']);
$group = static fn (string $id): array => (array) DB::table('groups')
    ->where('id', $id)
    ->firstOrFail(['id', 'institution_id', 'name', 'status', 'created_by_user_id', 'archived_at']);
$rows = static fn (string $table, string $institutionId): array => DB::table($table)
    ->where('institution_id', $institutionId)
    ->orderBy('id')
    ->get()
    ->map(static fn (object $row): array => (array) $row)
    ->all();

$oracle = [
    'runtime' => [
        'environment' => $environment,
        'database' => $database,
        'driver' => $driver,
        'pdo_driver' => $pdoDriver,
    ],
    'ids' => $ids,
    'users' => [
        'target_admin' => $user($ids['target_admin']),
        'wrong_role' => $user($ids['wrong_role']),
        'target_teacher' => $user($ids['target_teacher']),
        'target_student' => $user($ids['target_student']),
        'target_parent' => $user($ids['target_parent']),
        'foreign_teacher' => $user($ids['foreign_teacher']),
        'foreign_student' => $user($ids['foreign_student']),
        'foreign_parent' => $user($ids['foreign_parent']),
    ],
    'groups' => [
        'target_active' => $group($ids['target_active_group']),
        'target_archived' => $group($ids['target_archived_group']),
        'foreign' => $group($ids['foreign_group']),
    ],
    'memberships' => [
        'target_teachers' => $rows('group_teacher_memberships', $ids['target_institution']),
        'target_students' => $rows('group_student_memberships', $ids['target_institution']),
        'foreign_teachers' => $rows('group_teacher_memberships', $ids['foreign_institution']),
        'foreign_students' => $rows('group_student_memberships', $ids['foreign_institution']),
    ],
    'relationships' => [
        'target' => $rows('parent_student_relationships', $ids['target_institution']),
        'foreign' => $rows('parent_student_relationships', $ids['foreign_institution']),
    ],
    'ui_expected' => [
        'created_group_name' => 'E2E S04 UI Group',
        'edited_group_name' => 'E2E S04 UI Group Edited',
        'edited_level' => 'Level 4 Advanced',
        'edited_subject_direction' => 'STEM Integration',
        'edited_description' => 'E2E S04 edited through Windows UI.',
    ],
    'frozen_scope' => [
        'tables' => [
            'institutions', 'institution_settings', 'users', 'groups', 'group_teacher_memberships',
            'group_student_memberships', 'parent_student_relationships',
        ],
        'excluded_login_user_ids' => [$ids['target_admin'], $ids['wrong_role']],
        'excluded_group_names' => ['E2E S04 UI Group', 'E2E S04 UI Group Edited'],
        'excluded_relationship_pair' => [$ids['target_parent'], $ids['target_student']],
    ],
];

$json = json_encode($oracle, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
echo 'Stage4OracleBegin:'.base64_encode($json).':Stage4OracleEnd';
'@

    $oracleOutput = $oracleProgram | & docker exec -i $BackendContainerName php 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'The guarded Stage 4 read-only PostgreSQL oracle query failed.'
    }
    $oracleMatch = [regex]::Match(
        ($oracleOutput -join "`n"),
        'Stage4OracleBegin:(?<payload>[A-Za-z0-9+/=]+):Stage4OracleEnd'
    )
    if (-not $oracleMatch.Success) {
        throw 'The Stage 4 read-only oracle payload was absent.'
    }
    try {
        $oracleJson = [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($oracleMatch.Groups['payload'].Value)
        )
        $oracle = $oracleJson | ConvertFrom-Json
    }
    catch {
        throw 'The Stage 4 read-only oracle payload was invalid.'
    }
    if (
        $null -eq $oracle.runtime -or
        $null -eq $oracle.ids -or
        $null -eq $oracle.users -or
        $null -eq $oracle.groups -or
        $null -eq $oracle.memberships -or
        $null -eq $oracle.relationships -or
        $null -eq $oracle.ui_expected -or
        $null -eq $oracle.frozen_scope
    ) {
        throw 'The Stage 4 read-only oracle payload was incomplete.'
    }

    [IO.File]::WriteAllText($resolvedDestination, $oracleJson, [Text.UTF8Encoding]::new($false))
}

function Invoke-Stage4FrozenStateOracle {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Capture', 'Compare', 'Remove')]
        [string] $Action,

        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $ContainerSnapshotPath
    )

    if ($BackendContainerName -cne 'testlabuz-stage4-e2e-app') {
        throw 'The Stage 4 frozen-state oracle may use only the dedicated backend.'
    }
    if ($ContainerSnapshotPath -cnotmatch '^/tmp/testlabuz-stage4-frozen-[a-f0-9]{32}\.snapshot$') {
        throw 'The Stage 4 frozen-state snapshot path is invalid.'
    }

    $program = @'
<?php

$action = getenv('STAGE4_FROZEN_STATE_ACTION');
$snapshotPath = getenv('STAGE4_FROZEN_STATE_PATH');
if (! in_array($action, ['Capture', 'Compare', 'Remove'], true)) {
    throw new RuntimeException('Invalid Stage 4 frozen-state action.');
}
if (! is_string($snapshotPath) || preg_match('#^/tmp/testlabuz-stage4-frozen-[a-f0-9]{32}\.snapshot$#D', $snapshotPath) !== 1) {
    throw new RuntimeException('Invalid Stage 4 frozen-state path.');
}
if ($action === 'Remove') {
    if (is_file($snapshotPath) && ! unlink($snapshotPath)) {
        throw new RuntimeException('Stage 4 frozen-state cleanup failed.');
    }
    echo 'Stage4FrozenStateCleanup: PASS';
    exit(0);
}

require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Support\Facades\DB;

if (
    app()->environment() !== 'testing'
    || DB::scalar('select current_database()') !== 'testlabuz_testing'
    || DB::connection()->getDriverName() !== 'pgsql'
    || DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME) !== 'pgsql'
) {
    throw new RuntimeException('Stage 4 frozen-state oracle refused the runtime.');
}

$canonical = static function (string $sql, array $bindings = []): string {
    $row = DB::selectOne($sql, $bindings);
    if ($row === null || ! is_string($row->payload)) {
        throw new RuntimeException('Stage 4 frozen-state query returned no payload.');
    }
    return $row->payload;
};
$uiNames = ['E2E S04 UI Group', 'E2E S04 UI Group Edited'];
$snapshot = [
    'institutions' => $canonical(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload from (select * from institutions) snapshot"
    ),
    'users' => $canonical(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload from (select * from users where id not in (?, ?)) snapshot",
        ['04000000-0000-4000-9000-000000000101', '04000000-0000-4000-9000-000000000201'],
    ),
    'institution_settings' => $canonical(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.institution_id), '[]'::jsonb)::text as payload from (select * from institution_settings) snapshot"
    ),
    'groups' => $canonical(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload from (select * from groups where name not in (?, ?)) snapshot",
        $uiNames,
    ),
    'teacher_memberships' => $canonical(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload
        from (select * from group_teacher_memberships where group_id not in (select id from groups where name in (?, ?))) snapshot",
        $uiNames,
    ),
    'student_memberships' => $canonical(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload
        from (select * from group_student_memberships where group_id not in (select id from groups where name in (?, ?))) snapshot",
        $uiNames,
    ),
    'relationships' => $canonical(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload
        from (select * from parent_student_relationships where not (parent_id = ? and student_id = ?)) snapshot",
        ['04000000-0000-4000-9000-000000000208', '04000000-0000-4000-9000-000000000205'],
    ),
];
$snapshotBytes = json_encode($snapshot, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

if ($action === 'Capture') {
    if (file_put_contents($snapshotPath, $snapshotBytes, LOCK_EX) !== strlen($snapshotBytes) || ! chmod($snapshotPath, 0600)) {
        throw new RuntimeException('Stage 4 frozen-state baseline could not be protected.');
    }
    echo 'Stage4FrozenStateBaseline: SAVED';
    exit(0);
}
$baselineBytes = file_get_contents($snapshotPath);
if (! is_string($baselineBytes) || $baselineBytes !== $snapshotBytes) {
    throw new RuntimeException('Foreign or unrelated Stage 4 persisted state changed.');
}
echo 'Stage4FrozenStateComparison: PASS';
'@

    $output = $program | & docker exec -i `
        -e "STAGE4_FROZEN_STATE_ACTION=$Action" `
        -e "STAGE4_FROZEN_STATE_PATH=$ContainerSnapshotPath" `
        $BackendContainerName php 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "The Stage 4 frozen-state oracle $Action action failed."
    }
    $expected = switch ($Action) {
        'Capture' { 'Stage4FrozenStateBaseline: SAVED' }
        'Compare' { 'Stage4FrozenStateComparison: PASS' }
        'Remove' { 'Stage4FrozenStateCleanup: PASS' }
    }
    if (($output -join "`n").Trim() -cne $expected) {
        throw "The Stage 4 frozen-state oracle $Action result was invalid."
    }
}

function Assert-Stage4DatabasePostconditions {
    param(
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][ValidateSet('Mutation', 'Persistence')][string] $Phase
    )

    if ($BackendContainerName -cne 'testlabuz-stage4-e2e-app') {
        throw 'Stage 4 postconditions may use only the exact dedicated backend.'
    }

    $program = @'
<?php

require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Support\Facades\DB;

if (
    app()->environment() !== 'testing'
    || DB::scalar('select current_database()') !== 'testlabuz_testing'
    || DB::connection()->getDriverName() !== 'pgsql'
    || DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME) !== 'pgsql'
) {
    throw new RuntimeException('Stage 4 postcondition oracle refused the runtime.');
}

$group = DB::table('groups')
    ->where('institution_id', '04000000-0000-4000-8000-000000000101')
    ->where('name', 'E2E S04 UI Group Edited')
    ->first();
throw_unless($group !== null, 'The UI-created Group is missing.');
throw_unless(DB::table('groups')->whereIn('name', ['E2E S04 UI Group', 'E2E S04 UI Group Edited'])->count() === 1, 'The UI Group identity is ambiguous.');
throw_unless($group->level === 'Level 4 Advanced', 'The UI Group level was not edited.');
throw_unless($group->subject_direction === 'STEM Integration', 'The UI Group subject was not edited.');
throw_unless($group->description === 'E2E S04 edited through Windows UI.', 'The UI Group description was not edited.');
throw_unless($group->status === 'archived' && $group->archived_at !== null, 'The UI Group was not archived.');
throw_unless($group->created_by_user_id === '04000000-0000-4000-9000-000000000101', 'The UI Group creator changed.');

$assertHistory = static function (string $table, string $memberColumn, string $memberId) use ($group): void {
    $rows = DB::table($table)
        ->where('group_id', $group->id)
        ->where($memberColumn, $memberId)
        ->orderBy('started_at')
        ->get();
    $current = $rows->whereNull('ended_at');
    $ended = $rows->whereNotNull('ended_at');
    throw_unless($rows->count() >= 2, "$table history is incomplete.");
    throw_unless($current->count() === 1, "$table must have exactly one current row.");
    throw_unless($ended->count() >= 1, "$table must retain an ended row.");
    throw_unless(! $ended->pluck('id')->contains($current->first()->id), "$table replacement id was reused.");
    throw_unless($rows->every(fn (object $row): bool => $row->institution_id === '04000000-0000-4000-8000-000000000101'), "$table tenant changed.");
};
$assertHistory('group_teacher_memberships', 'teacher_id', '04000000-0000-4000-9000-000000000201');
$assertHistory('group_student_memberships', 'student_id', '04000000-0000-4000-9000-000000000205');

$relationships = DB::table('parent_student_relationships')
    ->where('parent_id', '04000000-0000-4000-9000-000000000208')
    ->where('student_id', '04000000-0000-4000-9000-000000000205')
    ->orderBy('started_at')
    ->get();
$currentRelationship = $relationships->whereNull('ended_at');
$endedRelationship = $relationships->whereNotNull('ended_at');
throw_unless($relationships->count() === 2, 'Parent-Student history must contain exactly two rows.');
throw_unless($currentRelationship->count() === 1 && $endedRelationship->count() === 1, 'Parent-Student current/ended history is invalid.');
throw_unless($currentRelationship->first()->id !== $endedRelationship->first()->id, 'Parent-Student replacement id was reused.');
throw_unless($relationships->every(fn (object $row): bool => $row->institution_id === '04000000-0000-4000-8000-000000000101'), 'Parent-Student tenant changed.');

throw_unless(DB::table('groups')->where('id', '04000000-0000-4000-a000-000000000101')->where('status', 'active')->count() === 1, 'Seeded target active Group changed.');
throw_unless(DB::table('groups')->where('id', '04000000-0000-4000-a000-000000000102')->where('status', 'archived')->count() === 1, 'Seeded target archived Group changed.');
throw_unless(DB::table('groups')->where('id', '04000000-0000-4000-a000-000000000103')->where('institution_id', '04000000-0000-4000-8000-000000000102')->count() === 1, 'Foreign Group changed.');
throw_unless(DB::table('group_teacher_memberships')->where('id', '04000000-0000-4000-b000-000000000201')->whereNull('ended_at')->count() === 1, 'Foreign Teacher membership changed.');
throw_unless(DB::table('group_student_memberships')->where('id', '04000000-0000-4000-b000-000000000202')->whereNull('ended_at')->count() === 1, 'Foreign Student membership changed.');
throw_unless(DB::table('parent_student_relationships')->where('id', '04000000-0000-4000-c000-000000000102')->whereNull('ended_at')->count() === 1, 'Foreign Parent-Student relationship changed.');

echo 'Stage4DatabasePostconditions: PASS';
'@

    $output = $program | & docker exec -i $BackendContainerName php 2>&1
    if ($LASTEXITCODE -ne 0 -or ($output -join "`n").Trim() -cne 'Stage4DatabasePostconditions: PASS') {
        throw "The Stage 4 $Phase database postconditions failed."
    }
}
