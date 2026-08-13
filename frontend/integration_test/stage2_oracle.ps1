Set-StrictMode -Version Latest

function New-Stage2OracleFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $BackendContainerName,

        [Parameter(Mandatory = $true)]
        [string] $DestinationPath
    )

    if ($BackendContainerName -cne 'testlabuz-stage2-e2e-app') {
        throw 'The Stage 2 oracle may query only the exact dedicated backend container.'
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

if ($environment !== 'testing' || $database !== 'testlabuz_testing') {
    throw new RuntimeException('Stage 2 oracle refused the active runtime.');
}

$escapeLike = static fn (string $value): string => str_replace(
    ['!', '%', '_'],
    ['!!', '!%', '!_'],
    $value,
);

$pageResult = static function (
    Builder $query,
    string $sort,
    string $direction,
    int $page,
    int $perPage,
    bool $caseInsensitive,
    bool $directionalTieBreak,
    string $identityNameColumn = 'name',
): array {
    if (! in_array($direction, ['asc', 'desc'], true)) {
        throw new InvalidArgumentException('Invalid oracle direction.');
    }

    $total = (clone $query)->count();
    if ($caseInsensitive) {
        $query->orderByRaw("lower({$sort}) {$direction}");
    } else {
        $query->orderBy($sort, $direction);
    }
    $query->orderBy('id', $directionalTieBreak ? $direction : 'asc');

    $rows = $query
        ->offset(($page - 1) * $perPage)
        ->limit($perPage)
        ->get(['id', DB::raw("{$identityNameColumn} as name")]);

    return [
        'identities' => $rows->map(static fn (object $row): array => [
            'id' => (string) $row->id,
            'name' => (string) $row->name,
        ])->all(),
        'pagination' => [
            'page' => $page,
            'per_page' => $perPage,
            'total' => $total,
            'last_page' => max(1, (int) ceil($total / $perPage)),
        ],
    ];
};

$institutionPage = static function (
    ?string $search = null,
    ?string $status = null,
    ?string $type = null,
    string $sort = 'name',
    string $direction = 'asc',
    int $page = 1,
    int $perPage = 20,
) use ($escapeLike, $pageResult): array {
    $query = DB::table('institutions');

    if ($search !== null) {
        $query->whereRaw("name ILIKE ? ESCAPE '!'", ['%'.$escapeLike($search).'%']);
    }
    if ($status !== null) {
        $query->where('status', $status);
    }
    if ($type !== null) {
        $query->where('type', $type);
    }
    if (! in_array($sort, ['name', 'status', 'created_at', 'updated_at'], true)) {
        throw new InvalidArgumentException('Invalid Institution oracle sort.');
    }

    return $pageResult(
        $query,
        $sort,
        $direction,
        $page,
        $perPage,
        $sort === 'name',
        false,
        'name',
    );
};

$targetInstitutionId = '02000000-0000-4000-8000-000000000101';
$adminPage = static function (
    ?string $search = null,
    ?bool $isActive = null,
    string $sort = 'full_name',
    string $direction = 'asc',
    int $page = 1,
    int $perPage = 20,
) use ($escapeLike, $pageResult, $targetInstitutionId): array {
    $query = DB::table('users')
        ->where('institution_id', $targetInstitutionId)
        ->where('role', 'institution_admin');

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
    if ($isActive !== null) {
        $query->where('is_active', $isActive);
    }
    if (! in_array($sort, ['full_name', 'login_name', 'created_at', 'updated_at'], true)) {
        throw new InvalidArgumentException('Invalid Admin oracle sort.');
    }

    return $pageResult(
        $query,
        $sort,
        $direction,
        $page,
        $perPage,
        in_array($sort, ['full_name', 'login_name'], true),
        true,
        'full_name',
    );
};

$recentInstitutions = DB::table('institutions')
    ->orderByDesc('created_at')
    ->orderByDesc('id')
    ->limit(5)
    ->get(['id', 'name'])
    ->map(static fn (object $row): array => [
        'id' => (string) $row->id,
        'name' => (string) $row->name,
    ])
    ->all();

$oracle = [
    'dashboard' => [
        'institutions' => [
            'total' => DB::table('institutions')->count(),
            'active' => DB::table('institutions')->where('status', 'active')->count(),
            'inactive' => DB::table('institutions')->where('status', 'inactive')->count(),
        ],
        'users' => [
            'total' => DB::table('users')->count(),
            'active' => DB::table('users')->where('is_active', true)->count(),
        ],
        'recent_institutions' => $recentInstitutions,
    ],
    'institutions' => [
        'default_page_1' => $institutionPage(),
        'default_page_2' => $institutionPage(page: 2),
        'search_mixed_case' => $institutionPage(search: 'mixed case'),
        'search_literal_percent' => $institutionPage(search: '%'),
        'search_literal_underscore' => $institutionPage(search: '_'),
        'combined_literal_inactive_training' => $institutionPage(
            search: 'Literal',
            status: 'inactive',
            type: 'training_center',
        ),
        'sort_name_desc' => $institutionPage(sort: 'name', direction: 'desc'),
        'sort_status_asc' => $institutionPage(sort: 'status'),
        'sort_created_at_asc' => $institutionPage(sort: 'created_at'),
        'sort_updated_at_asc' => $institutionPage(sort: 'updated_at'),
        'per_page_50' => $institutionPage(perPage: 50),
        'per_page_100' => $institutionPage(perPage: 100),
    ],
    'admins' => [
        'default_page_1' => $adminPage(),
        'search_target_admin' => $adminPage(search: 'Target Admin'),
        'search_target_admin_inactive' => $adminPage(
            search: 'Target Admin',
            isActive: false,
        ),
        'search_literal_percent' => $adminPage(search: '%'),
        'status_inactive' => $adminPage(isActive: false),
        'sort_login_name_desc_page_1' => $adminPage(
            sort: 'login_name',
            direction: 'desc',
        ),
        'sort_login_name_desc_page_2' => $adminPage(
            sort: 'login_name',
            direction: 'desc',
            page: 2,
        ),
        'sort_login_name_desc_per_page_50' => $adminPage(
            sort: 'login_name',
            direction: 'desc',
            perPage: 50,
        ),
        'sort_login_name_desc_per_page_100' => $adminPage(
            sort: 'login_name',
            direction: 'desc',
            perPage: 100,
        ),
    ],
];

$json = json_encode($oracle, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
echo 'Stage2OracleBegin:'.base64_encode($json).':Stage2OracleEnd';
'@

    $oracleOutput = $oracleProgram | & docker exec -i $BackendContainerName php 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'The guarded Stage 2 read-only oracle query failed.'
    }

    $oracleText = $oracleOutput -join "`n"
    $oracleMatch = [regex]::Match(
        $oracleText,
        'Stage2OracleBegin:(?<payload>[A-Za-z0-9+/=]+):Stage2OracleEnd'
    )
    if (-not $oracleMatch.Success) {
        throw 'The Stage 2 read-only oracle payload was absent.'
    }

    try {
        $oracleJson = [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($oracleMatch.Groups['payload'].Value)
        )
        $oracle = $oracleJson | ConvertFrom-Json
    }
    catch {
        throw 'The Stage 2 read-only oracle payload was invalid.'
    }

    if (
        $null -eq $oracle.dashboard -or
        $null -eq $oracle.institutions -or
        $null -eq $oracle.admins
    ) {
        throw 'The Stage 2 read-only oracle payload was incomplete.'
    }

    [IO.File]::WriteAllText(
        $DestinationPath,
        $oracleJson,
        [Text.UTF8Encoding]::new($false)
    )
}
