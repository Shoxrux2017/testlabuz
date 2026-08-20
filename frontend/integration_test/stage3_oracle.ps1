Set-StrictMode -Version Latest

function New-Stage3OracleFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $BackendContainerName,

        [Parameter(Mandatory = $true)]
        [string] $DestinationPath
    )

    if ($BackendContainerName -cne 'testlabuz-stage3-e2e-app') {
        throw 'The Stage 3 oracle may query only the exact dedicated backend container.'
    }

    $resolvedDestination = [IO.Path]::GetFullPath($DestinationPath)
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolvedDestination.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The Stage 3 oracle artifact must remain under the system temporary directory.'
    }

    $oracleProgram = @'
<?php

require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

$environment = app()->environment();
$database = (string) DB::scalar('select current_database()');
$connection = DB::connection();
$driver = $connection->getDriverName();
$pdoDriver = (string) $connection->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME);

if ($environment !== 'testing' || $database !== 'testlabuz_testing' || $driver !== 'pgsql' || $pdoDriver !== 'pgsql') {
    throw new RuntimeException('Stage 3 oracle refused the active runtime.');
}

$targetInstitutionId = '03000000-0000-4000-8000-000000000101';
$foreignInstitutionId = '03000000-0000-4000-8000-000000000102';
$inactiveInstitutionId = '03000000-0000-4000-8000-000000000103';
$emptyInstitutionId = '03000000-0000-4000-8000-000000000104';
$foreignUserId = '03000000-0000-4000-9000-000000000204';
$fixtureInstitutionIds = [
    $targetInstitutionId, $foreignInstitutionId, $inactiveInstitutionId,
    $emptyInstitutionId,
];
$fixtureUserIds = [];
foreach ([101, 102, 103, 104, 105, 106, 107, 108, 201, 202, 203, 204, 205, 206] as $suffix) {
    $fixtureUserIds[] = sprintf('03000000-0000-4000-9000-%012d', $suffix);
}
for ($suffix = 301; $suffix <= 324; $suffix++) {
    $fixtureUserIds[] = sprintf('03000000-0000-4000-9000-%012d', $suffix);
}

$escapeLike = static fn (string $value): string => str_replace(
    ['!', '%', '_'],
    ['!!', '!%', '!_'],
    $value,
);

$serializeUsers = static fn ($rows): array => $rows->map(static fn (object $row): array => [
    'id' => (string) $row->id,
    'full_name' => (string) $row->full_name,
    'login_name' => (string) $row->login_name,
    'role' => (string) $row->role,
    'is_active' => (bool) $row->is_active,
])->all();

$userPage = static function (
    ?string $search = null,
    ?string $role = null,
    ?bool $isActive = null,
    int $page = 1,
    int $perPage = 20,
    string $sort = 'full_name',
    string $direction = 'asc',
) use ($targetInstitutionId, $escapeLike, $serializeUsers): array {
    $query = DB::table('users')
        ->where('institution_id', $targetInstitutionId)
        ->whereIn('role', ['teacher', 'student', 'parent']);
    if ($search !== null) {
        $pattern = '%'.$escapeLike($search).'%';
        $query->where(static function (Builder $query) use ($pattern): void {
            $query
                ->whereRaw("full_name ILIKE ? ESCAPE '!'", [$pattern])
                ->orWhereRaw("login_name ILIKE ? ESCAPE '!'", [$pattern])
                ->orWhereRaw("email ILIKE ? ESCAPE '!'", [$pattern])
                ->orWhereRaw("phone ILIKE ? ESCAPE '!'", [$pattern]);
        });
    }
    if ($role !== null) {
        $query->where('role', $role);
    }
    if ($isActive !== null) {
        $query->where('is_active', $isActive);
    }

    $sortExpressions = [
        'full_name' => 'lower(full_name)',
        'login_name' => 'lower(login_name)',
        'created_at' => 'created_at',
        'updated_at' => 'updated_at',
    ];
    if (! isset($sortExpressions[$sort]) || ! in_array($direction, ['asc', 'desc'], true)) {
        throw new RuntimeException('Invalid Stage 3 oracle User-list ordering.');
    }

    $total = (clone $query)->count();
    $rows = $query
        ->orderByRaw($sortExpressions[$sort].' '.$direction)
        ->orderBy('id', $direction)
        ->offset(($page - 1) * $perPage)
        ->limit($perPage)
        ->get(['id', 'full_name', 'login_name', 'role', 'is_active']);

    return [
        'items' => $serializeUsers($rows),
        'pagination' => [
            'page' => $page,
            'per_page' => $perPage,
            'total' => $total,
            'last_page' => max(1, (int) ceil($total / $perPage)),
        ],
    ];
};

$profile = static fn (string $institutionId): array => (array) DB::table('institutions')
    ->where('id', $institutionId)
    ->firstOrFail([
        'id', 'name', 'type', 'status', 'contact_email', 'contact_phone',
        'address', 'description', 'created_at', 'updated_at',
    ]);

$settings = static function (string $institutionId): array {
    $row = DB::table('institution_settings')->where('institution_id', $institutionId)->firstOrFail([
        'acceptable_score_difference', 'blitz_timer_start_mode',
        'student_result_release_mode', 'parent_result_release_mode', 'timezone',
        'learning_material_max_mb', 'student_submission_max_mb',
    ]);

    return (array) $row;
};

$categories = static fn (string $institutionId): array => DB::table('institution_understanding_categories')
    ->where('institution_id', $institutionId)
    ->orderBy('sort_order')
    ->get(['code', 'min_score', 'max_score', 'sort_order'])
    ->map(static fn (object $row): array => [
        'code' => (string) $row->code,
        'min_score' => $row->min_score === null ? null : (int) $row->min_score,
        'max_score' => $row->max_score === null ? null : (int) $row->max_score,
        'sort_order' => (int) $row->sort_order,
    ])->all();

$oracle = [
    'runtime' => [
        'environment' => $environment,
        'database' => $database,
        'driver' => $driver,
        'pdo_driver' => $pdoDriver,
    ],
    'ids' => [
        'target_institution' => $targetInstitutionId,
        'foreign_institution' => $foreignInstitutionId,
        'empty_institution' => $emptyInstitutionId,
        'foreign_user' => $foreignUserId,
        'unknown_user' => 'ffffffff-ffff-4fff-8fff-ffffffffffff',
    ],
    'dashboard' => [
        'target' => [
            'teachers' => DB::table('users')->where('institution_id', $targetInstitutionId)->where('role', 'teacher')->count(),
            'students' => DB::table('users')->where('institution_id', $targetInstitutionId)->where('role', 'student')->count(),
            'parents' => DB::table('users')->where('institution_id', $targetInstitutionId)->where('role', 'parent')->count(),
        ],
        'empty' => [
            'teachers' => DB::table('users')->where('institution_id', $emptyInstitutionId)->where('role', 'teacher')->count(),
            'students' => DB::table('users')->where('institution_id', $emptyInstitutionId)->where('role', 'student')->count(),
            'parents' => DB::table('users')->where('institution_id', $emptyInstitutionId)->where('role', 'parent')->count(),
        ],
    ],
    'profiles' => [
        'target' => $profile($targetInstitutionId),
        'foreign' => $profile($foreignInstitutionId),
        'empty' => $profile($emptyInstitutionId),
    ],
    'users' => [
        'default_page_1' => $userPage(),
        'default_page_2' => $userPage(page: 2),
        'per_page_50' => $userPage(perPage: 50),
        'per_page_100' => $userPage(perPage: 100),
        'teacher_filter' => $userPage(role: 'teacher'),
        'inactive_filter' => $userPage(isActive: false),
        'inactive_teacher_filter' => $userPage(role: 'teacher', isActive: false),
        'search_name_case' => $userPage(search: 'e2e s03 teacher'),
        'search_login' => $userPage(search: 'e2e_s03_teacher'),
        'search_email' => $userPage(search: 'e2e_s03_teacher@e2e-s03.invalid'),
        'search_phone' => $userPage(search: '+998930300201'),
        'literal_percent' => $userPage(search: '% User'),
        'literal_underscore' => $userPage(search: '_ User'),
        'literal_escape' => $userPage(search: '! User'),
        'sort_full_name_asc' => $userPage(sort: 'full_name'),
        'sort_full_name_desc' => $userPage(sort: 'full_name', direction: 'desc'),
        'sort_login_name_asc' => $userPage(sort: 'login_name'),
        'sort_login_name_desc' => $userPage(sort: 'login_name', direction: 'desc'),
        'sort_created_at_asc' => $userPage(sort: 'created_at'),
        'sort_created_at_desc' => $userPage(sort: 'created_at', direction: 'desc'),
        'sort_updated_at_asc' => $userPage(sort: 'updated_at'),
        'sort_updated_at_desc' => $userPage(sort: 'updated_at', direction: 'desc'),
    ],
    'settings' => [
        'target' => $settings($targetInstitutionId),
        'foreign' => $settings($foreignInstitutionId),
        'empty' => $settings($emptyInstitutionId),
    ],
    'categories' => [
        'target' => $categories($targetInstitutionId),
        'foreign' => $categories($foreignInstitutionId),
        'empty' => $categories($emptyInstitutionId),
    ],
    'preserved_token_row_metadata' => DB::table('personal_access_tokens')
        ->where('tokenable_id', '03000000-0000-4000-9000-000000000201')
        ->whereIn('name', ['stage3-preservation-a', 'stage3-preservation-b'])
        ->orderBy('name')
        ->get(['id', 'tokenable_type', 'tokenable_id', 'name', 'abilities', 'last_used_at', 'expires_at', 'created_at', 'updated_at'])
        ->map(static fn (object $row): array => (array) $row)
        ->all(),
    'frozen_unrelated_scope' => [
        'tables' => [
            'institutions', 'users', 'institution_settings',
            'institution_understanding_categories', 'personal_access_tokens',
        ],
        'excluded_institution_ids' => [$targetInstitutionId],
        'excluded_user_ids' => [
            '03000000-0000-4000-9000-000000000101',
            '03000000-0000-4000-9000-000000000103',
            '03000000-0000-4000-9000-000000000105',
            '03000000-0000-4000-9000-000000000107',
            '03000000-0000-4000-9000-000000000108',
            '03000000-0000-4000-9000-000000000201',
            '03000000-0000-4000-9000-000000000202',
            '03000000-0000-4000-9000-000000000203',
        ],
        'excluded_user_logins' => [
            'e2e_s03_created_teacher',
            'e2e_s03_created_student',
            'e2e_s03_created_parent',
        ],
        'preserved_seeded_token_rows_included' => true,
    ],
];

$json = json_encode($oracle, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
echo 'Stage3OracleBegin:'.base64_encode($json).':Stage3OracleEnd';
'@

    $oracleOutput = $oracleProgram | & docker exec -i $BackendContainerName php 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'The guarded Stage 3 read-only PostgreSQL oracle query failed.'
    }

    $oracleText = $oracleOutput -join "`n"
    $oracleMatch = [regex]::Match(
        $oracleText,
        'Stage3OracleBegin:(?<payload>[A-Za-z0-9+/=]+):Stage3OracleEnd'
    )
    if (-not $oracleMatch.Success) {
        throw 'The Stage 3 read-only oracle payload was absent.'
    }

    try {
        $oracleJson = [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($oracleMatch.Groups['payload'].Value)
        )
        $oracle = $oracleJson | ConvertFrom-Json
    }
    catch {
        throw 'The Stage 3 read-only oracle payload was invalid.'
    }

    if (
        $null -eq $oracle.runtime -or
        $null -eq $oracle.dashboard -or
        $null -eq $oracle.profiles -or
        $null -eq $oracle.users -or
        $null -eq $oracle.settings -or
        $null -eq $oracle.categories -or
        $null -eq $oracle.preserved_token_row_metadata -or
        $null -eq $oracle.frozen_unrelated_scope
    ) {
        throw 'The Stage 3 read-only oracle payload was incomplete.'
    }

    [IO.File]::WriteAllText(
        $resolvedDestination,
        $oracleJson,
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Stage3FrozenUnrelatedStateOracle {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Capture', 'Compare', 'Remove')]
        [string] $Action,

        [Parameter(Mandatory = $true)]
        [string] $BackendContainerName,

        [Parameter(Mandatory = $true)]
        [string] $ContainerSnapshotPath
    )

    if ($BackendContainerName -cne 'testlabuz-stage3-e2e-app') {
        throw 'The frozen unrelated-state oracle may use only the exact dedicated backend container.'
    }
    if ($ContainerSnapshotPath -cnotmatch '^/tmp/testlabuz-stage3-frozen-[a-f0-9]{32}\.snapshot$') {
        throw 'The frozen unrelated-state snapshot path is invalid.'
    }

    $frozenStateProgram = @'
<?php

$action = getenv('STAGE3_FROZEN_STATE_ACTION');
$snapshotPath = getenv('STAGE3_FROZEN_STATE_PATH');
$allowedActions = ['Capture', 'Compare', 'Remove'];

if (! in_array($action, $allowedActions, true)) {
    throw new RuntimeException('Invalid frozen-state oracle action.');
}
if (! is_string($snapshotPath) || preg_match('#^/tmp/testlabuz-stage3-frozen-[a-f0-9]{32}\.snapshot$#D', $snapshotPath) !== 1) {
    throw new RuntimeException('Invalid frozen-state oracle path.');
}

if ($action === 'Remove') {
    if (is_file($snapshotPath) && ! unlink($snapshotPath)) {
        throw new RuntimeException('Frozen-state oracle cleanup failed.');
    }
    echo 'Stage3FrozenUnrelatedStateCleanup: PASS';
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
    throw new RuntimeException('Frozen-state oracle refused the active runtime.');
}

$targetInstitutionId = '03000000-0000-4000-8000-000000000101';
$excludedUserIds = [
    '03000000-0000-4000-9000-000000000101',
    '03000000-0000-4000-9000-000000000103',
    '03000000-0000-4000-9000-000000000105',
    '03000000-0000-4000-9000-000000000107',
    '03000000-0000-4000-9000-000000000108',
    '03000000-0000-4000-9000-000000000201',
    '03000000-0000-4000-9000-000000000202',
    '03000000-0000-4000-9000-000000000203',
];
$excludedUserLogins = [
    'e2e_s03_created_teacher',
    'e2e_s03_created_student',
    'e2e_s03_created_parent',
];

$placeholders = static fn (array $values): string => implode(', ', array_fill(0, count($values), '?'));
$canonicalRows = static function (string $sql, array $bindings): string {
    $row = DB::selectOne($sql, $bindings);
    if ($row === null || ! is_string($row->payload)) {
        throw new RuntimeException('Frozen-state oracle query returned an invalid payload.');
    }

    return $row->payload;
};

$excludedUserCondition = sprintf(
    'id not in (%s) and login_name not in (%s)',
    $placeholders($excludedUserIds),
    $placeholders($excludedUserLogins),
);
$excludedUserBindings = [...$excludedUserIds, ...$excludedUserLogins];
$excludedTokenOwnerCondition = sprintf(
    'select id from users where id in (%s) or login_name in (%s)',
    $placeholders($excludedUserIds),
    $placeholders($excludedUserLogins),
);

$snapshot = [
    'institutions' => $canonicalRows(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload
        from (select * from institutions where id <> ?) snapshot",
        [$targetInstitutionId],
    ),
    'users' => $canonicalRows(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload
        from (select * from users where {$excludedUserCondition}) snapshot",
        $excludedUserBindings,
    ),
    'institution_settings' => $canonicalRows(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.institution_id), '[]'::jsonb)::text as payload
        from (select * from institution_settings where institution_id <> ?) snapshot",
        [$targetInstitutionId],
    ),
    'institution_understanding_categories' => $canonicalRows(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.institution_id, snapshot.sort_order, snapshot.id), '[]'::jsonb)::text as payload
        from (select * from institution_understanding_categories where institution_id <> ?) snapshot",
        [$targetInstitutionId],
    ),
    'personal_access_tokens' => $canonicalRows(
        "select coalesce(jsonb_agg(to_jsonb(snapshot) order by snapshot.id), '[]'::jsonb)::text as payload
        from (
            select * from personal_access_tokens
            where tokenable_id not in ({$excludedTokenOwnerCondition})
               or (
                    tokenable_id = '03000000-0000-4000-9000-000000000201'
                    and name in ('stage3-preservation-a', 'stage3-preservation-b')
               )
        ) snapshot",
        $excludedUserBindings,
    ),
];
$snapshotBytes = json_encode($snapshot, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

if ($action === 'Capture') {
    if (file_put_contents($snapshotPath, $snapshotBytes, LOCK_EX) !== strlen($snapshotBytes)) {
        throw new RuntimeException('Frozen-state oracle could not persist its baseline.');
    }
    if (! chmod($snapshotPath, 0600)) {
        throw new RuntimeException('Frozen-state oracle could not protect its baseline.');
    }
    echo 'Stage3FrozenUnrelatedStateBaseline: SAVED';
    exit(0);
}

$baselineBytes = file_get_contents($snapshotPath);
if (! is_string($baselineBytes)) {
    throw new RuntimeException('Frozen-state oracle baseline is unavailable.');
}
if ($baselineBytes !== $snapshotBytes) {
    throw new RuntimeException('Frozen unrelated persisted state changed.');
}

echo 'Stage3FrozenUnrelatedStateComparison: PASS';
'@

    $oracleOutput = $frozenStateProgram | & docker exec -i `
        -e "STAGE3_FROZEN_STATE_ACTION=$Action" `
        -e "STAGE3_FROZEN_STATE_PATH=$ContainerSnapshotPath" `
        $BackendContainerName `
        php 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "The frozen unrelated-state oracle $Action action failed."
    }

    $expectedMarker = switch ($Action) {
        'Capture' { 'Stage3FrozenUnrelatedStateBaseline: SAVED' }
        'Compare' { 'Stage3FrozenUnrelatedStateComparison: PASS' }
        'Remove' { 'Stage3FrozenUnrelatedStateCleanup: PASS' }
    }
    if (($oracleOutput -join "`n").Trim() -cne $expectedMarker) {
        throw "The frozen unrelated-state oracle $Action result was invalid."
    }
}
