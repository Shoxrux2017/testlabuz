Set-StrictMode -Version Latest

function Assert-Stage5OracleDestination {
    param([Parameter(Mandatory = $true)][string] $Path)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolved = [IO.Path]::GetFullPath($Path)
    if (
        -not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -cnotmatch '^testlabuz-stage5-oracle-[a-f0-9]{32}\.json$'
    ) { throw 'The Stage 5 oracle destination is outside its exact system-temp scope.' }
    $resolved
}

function Invoke-Stage5ReadOnlyPhp {
    param(
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $Program,
        [Parameter(Mandatory = $true)][string] $Marker
    )
    if ($BackendContainerName -cne 'testlabuz-stage5-e2e-app') {
        throw 'The Stage 5 oracle may use only the exact dedicated backend container.'
    }
    $output = $Program | & docker exec -i $BackendContainerName php 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'The guarded Stage 5 read-only PostgreSQL/private-storage oracle failed.' }
    $match = [regex]::Match(($output -join "`n"), ([regex]::Escape($Marker) + ':(?<payload>[A-Za-z0-9+/=]+)'))
    if (-not $match.Success) { throw 'The Stage 5 read-only oracle payload was absent.' }
    try {
        [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($match.Groups['payload'].Value))
    }
    catch { throw 'The Stage 5 read-only oracle payload was invalid.' }
}

function New-Stage5OracleFile {
    param(
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $DestinationPath
    )
    $destination = Assert-Stage5OracleDestination -Path $DestinationPath
    if (Test-Path -LiteralPath $destination) { throw 'The Stage 5 oracle destination must be new.' }

    $program = @'
<?php
require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;
if (app()->environment() !== 'testing' || DB::scalar('select current_database()') !== 'testlabuz_testing' || DB::connection()->getDriverName() !== 'pgsql' || DB::connection()->getPdo()->getAttribute(PDO::ATTR_DRIVER_NAME) !== 'pgsql') {
    throw new RuntimeException('Stage 5 oracle refused the runtime.');
}
$ids = [
    'target_institution' => '05000000-0000-4000-8000-000000000101',
    'low_limit_institution' => '05000000-0000-4000-8000-000000000102',
    'foreign_institution' => '05000000-0000-4000-8000-000000000103',
    'target_admin' => '05000000-0000-4000-9000-000000000101',
    'target_teacher' => '05000000-0000-4000-9000-000000000201',
    'target_student' => '05000000-0000-4000-9000-000000000202',
    'ended_student' => '05000000-0000-4000-9000-000000000203',
    'unrelated_teacher' => '05000000-0000-4000-9000-000000000204',
    'unrelated_student' => '05000000-0000-4000-9000-000000000205',
    'low_limit_admin' => '05000000-0000-4000-9000-000000000301',
    'low_limit_teacher' => '05000000-0000-4000-9000-000000000302',
    'foreign_admin' => '05000000-0000-4000-9000-000000000401',
    'foreign_teacher' => '05000000-0000-4000-9000-000000000402',
    'foreign_student' => '05000000-0000-4000-9000-000000000403',
    'group_a' => '05000000-0000-4000-a000-000000000101',
    'group_b' => '05000000-0000-4000-a000-000000000102',
    'group_c' => '05000000-0000-4000-a000-000000000103',
    'low_limit_group' => '05000000-0000-4000-a000-000000000201',
    'foreign_group' => '05000000-0000-4000-a000-000000000301',
    'seeded_target_topic' => '05000000-0000-4000-c000-000000000101',
    'seeded_draft_topic' => '05000000-0000-4000-c000-000000000102',
    'unrelated_topic' => '05000000-0000-4000-c000-000000000103',
    'archived_group_topic' => '05000000-0000-4000-c000-000000000104',
    'low_limit_topic' => '05000000-0000-4000-c000-000000000201',
    'foreign_topic' => '05000000-0000-4000-c000-000000000301',
    'seeded_target_material' => '05000000-0000-4000-d000-000000000101',
    'unrelated_material' => '05000000-0000-4000-d000-000000000102',
    'archived_group_material' => '05000000-0000-4000-d000-000000000103',
    'foreign_material' => '05000000-0000-4000-d000-000000000104',
    'seeded_target_file' => '05000000-0000-4000-e000-000000000101',
    'unrelated_file' => '05000000-0000-4000-e000-000000000102',
    'archived_group_file' => '05000000-0000-4000-e000-000000000103',
    'foreign_file' => '05000000-0000-4000-e000-000000000104',
];
$logins = [
    'target_admin' => 'e2e_s05_target_admin', 'target_teacher' => 'e2e_s05_target_teacher',
    'target_student' => 'e2e_s05_target_student', 'ended_student' => 'e2e_s05_ended_student',
    'unrelated_teacher' => 'e2e_s05_unrelated_teacher', 'unrelated_student' => 'e2e_s05_unrelated_student',
    'low_limit_admin' => 'e2e_s05_low_limit_admin', 'low_limit_teacher' => 'e2e_s05_low_limit_teacher',
    'foreign_admin' => 'e2e_s05_foreign_admin', 'foreign_teacher' => 'e2e_s05_foreign_teacher',
    'foreign_student' => 'e2e_s05_foreign_student',
];
foreach ($logins as $key => $login) {
    $user = DB::table('users')->where('id', $ids[$key])->first(['login_name', 'is_active', 'must_change_password']);
    throw_unless($user !== null && $user->login_name === $login && $user->is_active && ! $user->must_change_password, 'Stage 5 actor fixture mismatch.');
}
$targetFile = DB::table('files')->where('id', $ids['seeded_target_file'])->first(['checksum_sha256']);
throw_unless($targetFile !== null && preg_match('/^[a-f0-9]{64}$/D', $targetFile->checksum_sha256) === 1, 'Stage 5 seeded checksum is invalid.');
$oracle = ['version' => 1, 'logins' => $logins, 'ids' => $ids, 'seeded_sha256' => ['target_file' => $targetFile->checksum_sha256]];
echo 'Stage5Oracle:'.base64_encode(json_encode($oracle, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
'@
    $json = Invoke-Stage5ReadOnlyPhp -BackendContainerName $BackendContainerName -Program $program -Marker 'Stage5Oracle'
    try { $oracle = $json | ConvertFrom-Json } catch { throw 'The Stage 5 sanitized oracle JSON was invalid.' }
    if (
        [int] $oracle.version -ne 1 -or
        $null -eq $oracle.logins -or
        $null -eq $oracle.ids -or
        [string] $oracle.seeded_sha256.target_file -cnotmatch '^[a-f0-9]{64}$' -or
        $null -ne $oracle.PSObject.Properties['dynamic']
    ) { throw 'The Stage 5 sanitized oracle baseline was incomplete.' }
    [IO.File]::WriteAllText($destination, $json, [Text.UTF8Encoding]::new($false))
}

function Invoke-Stage5FrozenStateOracle {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Capture', 'Compare', 'Remove')][string] $Action,
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $ContainerSnapshotPath
    )
    if ($BackendContainerName -cne 'testlabuz-stage5-e2e-app') { throw 'The Stage 5 frozen oracle may use only the dedicated backend.' }
    if ($ContainerSnapshotPath -cnotmatch '^/tmp/testlabuz-stage5-frozen-[a-f0-9]{32}\.snapshot$') {
        throw 'The Stage 5 frozen-state path is invalid.'
    }
    $program = @'
<?php
$action = getenv('STAGE5_FROZEN_ACTION');
$snapshotPath = getenv('STAGE5_FROZEN_PATH');
if (! in_array($action, ['Capture', 'Compare', 'Remove'], true) || ! is_string($snapshotPath) || preg_match('#^/tmp/testlabuz-stage5-frozen-[a-f0-9]{32}\.snapshot$#D', $snapshotPath) !== 1) {
    throw new RuntimeException('Invalid Stage 5 frozen-state inputs.');
}
if ($action === 'Remove') {
    if (is_file($snapshotPath) && ! unlink($snapshotPath)) { throw new RuntimeException('Stage 5 frozen-state cleanup failed.'); }
    echo 'Stage5FrozenRemove'; exit(0);
}
require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;
if (app()->environment() !== 'testing' || DB::scalar('select current_database()') !== 'testlabuz_testing' || DB::connection()->getDriverName() !== 'pgsql') {
    throw new RuntimeException('Stage 5 frozen oracle refused the runtime.');
}
$targetInstitution = '05000000-0000-4000-8000-000000000101';
$lifecycleTopicExclusions = ['05000000-0000-4000-c000-000000000102', '05000000-0000-4000-c000-000000000104'];
$dynamic = DB::table('topics')->where('institution_id', $targetInstitution)->where('title', 'E2E S05 UI Topic')->pluck('id')->all();
throw_unless(count($dynamic) <= 1, 'Stage 5 dynamic Topic identity is ambiguous.');
$topicRowExclusions = [...$lifecycleTopicExclusions, ...$dynamic];
$contentBlobExclusions = $dynamic;
$canonical = static function (string $sql, array $bindings = []): string {
    $row = DB::selectOne($sql, $bindings);
    if ($row === null || ! is_string($row->payload)) { throw new RuntimeException('Stage 5 frozen query returned no payload.'); }
    return $row->payload;
};
$topicRowPlaceholders = implode(',', array_fill(0, count($topicRowExclusions), '?'));
$contentBlobPlaceholders = implode(',', array_fill(0, count($contentBlobExclusions), '?'));
$materialContentFilter = $contentBlobExclusions === [] ? '' : " where topic_id not in ($contentBlobPlaceholders)";
$fileContentFilter = $contentBlobExclusions === [] ? '' : " where id not in (select file_id from learning_materials where topic_id in ($contentBlobPlaceholders))";
$snapshot = [
    'institutions' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb)::text payload from (select * from institutions) s"),
    'settings' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.institution_id), '[]'::jsonb)::text payload from (select * from institution_settings) s"),
    'users' => $canonical("select coalesce(jsonb_agg(case when login_name like 'e2e_s05_%' then to_jsonb(s) - 'last_login_at' - 'updated_at' else to_jsonb(s) end order by s.id), '[]'::jsonb)::text payload from (select * from users) s"),
    'groups' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb)::text payload from (select * from groups) s"),
    'teacher_memberships' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb)::text payload from (select * from group_teacher_memberships) s"),
    'student_memberships' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb)::text payload from (select * from group_student_memberships) s"),
    'topics' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb)::text payload from (select * from topics where id not in ($topicRowPlaceholders)) s", $topicRowExclusions),
    'materials' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb)::text payload from (select * from learning_materials$materialContentFilter) s", $contentBlobExclusions),
    'files' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb)::text payload from (select * from files$fileContentFilter) s", $contentBlobExclusions),
    'tokens' => $canonical("select coalesce(jsonb_agg(to_jsonb(s) order by s.id), '[]'::jsonb)::text payload from (select * from personal_access_tokens where tokenable_id not in (select id from users where login_name like 'e2e_s05_%')) s"),
];
$privateRoot = config('filesystems.disks.local.root');
throw_unless(is_string($privateRoot) && $privateRoot === '/var/www/html/storage/app/private', 'Stage 5 frozen oracle private root mismatch.');
$blobHashes = [];
if (is_dir($privateRoot)) {
    $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($privateRoot, FilesystemIterator::SKIP_DOTS));
    foreach ($iterator as $entry) {
        throw_unless(! $entry->isLink() && $entry->isFile(), 'Stage 5 frozen oracle encountered an unsafe private entry.');
        $relative = str_replace('\\', '/', substr($entry->getPathname(), strlen($privateRoot) + 1));
        $excluded = false;
        foreach ($contentBlobExclusions as $topicId) {
            if (str_starts_with($relative, "learning-materials/$targetInstitution/$topicId/")) { $excluded = true; break; }
        }
        if (! $excluded) { $blobHashes[$relative] = hash_file('sha256', $entry->getPathname()); }
    }
}
ksort($blobHashes, SORT_STRING);
$snapshot['private_blobs'] = $blobHashes;
$bytes = json_encode($snapshot, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
if ($action === 'Capture') {
    if (file_put_contents($snapshotPath, $bytes, LOCK_EX) !== strlen($bytes) || ! chmod($snapshotPath, 0600)) { throw new RuntimeException('Stage 5 frozen baseline write failed.'); }
    echo 'Stage5FrozenCapture'; exit(0);
}
$baseline = file_get_contents($snapshotPath);
if (! is_string($baseline) || ! hash_equals($baseline, $bytes)) { throw new RuntimeException('Frozen unrelated Stage 5 DB/blob state changed.'); }
echo 'Stage5FrozenCompare';
'@
    $output = $program | & docker exec -i `
        -e "STAGE5_FROZEN_ACTION=$Action" `
        -e "STAGE5_FROZEN_PATH=$ContainerSnapshotPath" `
        $BackendContainerName php 2>&1
    $expected = switch ($Action) { 'Capture' { 'Stage5FrozenCapture' } 'Compare' { 'Stage5FrozenCompare' } 'Remove' { 'Stage5FrozenRemove' } }
    if ($LASTEXITCODE -ne 0 -or ($output -join "`n").Trim() -cne $expected) {
        throw "The Stage 5 frozen-state $Action action failed."
    }
}

function Get-Stage5DynamicPostconditions {
    param([Parameter(Mandatory = $true)][string] $BackendContainerName)
    $program = @'
<?php
require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
if (app()->environment() !== 'testing' || DB::scalar('select current_database()') !== 'testlabuz_testing' || config('filesystems.private_files_disk') !== 'local') {
    throw new RuntimeException('Stage 5 postcondition oracle refused the runtime.');
}
$institution = '05000000-0000-4000-8000-000000000101';
$teacher = '05000000-0000-4000-9000-000000000201';
$group = '05000000-0000-4000-a000-000000000101';
$topics = DB::table('topics')->where('title', 'E2E S05 UI Topic')->get();
throw_unless($topics->count() === 1, 'The dynamic Stage 5 Topic identity is missing or ambiguous.');
$topic = $topics->first();
throw_unless($topic->institution_id === $institution && $topic->teacher_id === $teacher && $topic->group_id === $group, 'Dynamic Topic ownership changed.');
throw_unless($topic->subject === 'E2E S05 Subject' && $topic->description === 'E2E S05 integration topic' && $topic->student_instructions === 'E2E S05 Student instructions' && $topic->lesson_at === null, 'Dynamic Topic metadata changed.');
throw_unless($topic->status === 'archived' && $topic->activated_at !== null && $topic->closed_at !== null && $topic->archived_at !== null, 'Dynamic Topic lifecycle is incomplete.');
throw_unless(strtotime($topic->created_at) <= strtotime($topic->activated_at) && strtotime($topic->activated_at) <= strtotime($topic->closed_at) && strtotime($topic->closed_at) <= strtotime($topic->archived_at), 'Dynamic Topic lifecycle order is invalid.');
$materials = DB::table('learning_materials')->where('topic_id', $topic->id)->orderBy('position')->get();
throw_unless($materials->count() === 4, 'Dynamic Topic material history is incomplete.');
$joined = DB::table('learning_materials')->join('files', 'files.id', '=', 'learning_materials.file_id')->where('learning_materials.topic_id', $topic->id)
    ->get(['learning_materials.id as material_id', 'learning_materials.title', 'learning_materials.position', 'learning_materials.removed_at as material_removed_at', 'files.id as file_id', 'files.original_name', 'files.storage_disk', 'files.storage_key', 'files.mime_type', 'files.extension', 'files.size_bytes', 'files.checksum_sha256', 'files.removed_at as file_removed_at']);
$replacement = $joined->firstWhere('original_name', 'e2e_s05_replacement.pdf');
$removed = $joined->firstWhere('original_name', 'e2e_s05_material.ppt');
throw_unless($replacement !== null && $replacement->title === 'E2E S05 PDF Renamed' && $replacement->material_removed_at === null && $replacement->file_removed_at === null, 'Replacement identity/title is invalid.');
throw_unless($removed !== null && $removed->material_removed_at !== null && $removed->file_removed_at !== null && $removed->material_removed_at === $removed->file_removed_at, 'Removed material/file history is invalid.');
$current = $joined->filter(fn (object $row): bool => $row->material_removed_at === null && $row->file_removed_at === null)->values();
throw_unless($current->count() === 3, 'The current dynamic material set is invalid.');
$positions = $joined->pluck('position', 'original_name')->all();
foreach ([
    'e2e_s05_replacement.pdf' => 0,
    'e2e_s05_material.docx' => 1,
    'e2e_s05_material.ppt' => 2,
    'e2e_s05_material.pptx' => 3,
] as $name => $position) {
    throw_unless(($positions[$name] ?? null) === $position, 'Dynamic material ordering changed.');
}
$expectedCurrentNames = ['e2e_s05_material.docx', 'e2e_s05_material.pptx', 'e2e_s05_replacement.pdf'];
$actualCurrentNames = $current->pluck('original_name')->sort()->values()->all(); sort($expectedCurrentNames);
throw_unless($actualCurrentNames === $expectedCurrentNames, 'The current dynamic material names are invalid.');
$expectedFileTypes = [
    'e2e_s05_replacement.pdf' => ['application/pdf', 'pdf'],
    'e2e_s05_material.docx' => ['application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'docx'],
    'e2e_s05_material.pptx' => ['application/vnd.openxmlformats-officedocument.presentationml.presentation', 'pptx'],
];
foreach ($current as $row) {
    $expectedType = $expectedFileTypes[$row->original_name] ?? null;
    throw_unless($expectedType !== null && $row->mime_type === $expectedType[0] && $row->extension === $expectedType[1] && $row->size_bytes > 0 && preg_match('/^[a-f0-9]{64}$/D', $row->checksum_sha256) === 1, 'Current File metadata is invalid.');
}
$disk = Storage::disk('local');
$namespace = "learning-materials/$institution/$topic->id";
$privateKeys = $disk->allFiles($namespace); sort($privateKeys);
throw_unless(count($privateKeys) === 3, 'Superseded, removed, or rejected private blobs remain.');
foreach ($current as $row) {
    throw_unless($row->storage_disk === 'local' && preg_match('#^'.preg_quote($namespace, '#').'/[0-9a-f-]+\.(pdf|docx|pptx)$#D', $row->storage_key) === 1, 'Current private storage metadata is invalid.');
    throw_unless($disk->exists($row->storage_key) && hash_file('sha256', $disk->path($row->storage_key)) === $row->checksum_sha256, 'Current private blob checksum mismatch.');
}
throw_unless(! $disk->exists($removed->storage_key), 'Removed private blob remains.');
$publicRoot = config('filesystems.disks.public.root');
throw_unless(is_string($publicRoot) && $publicRoot === '/var/www/html/storage/app/public', 'Public root mismatch.');
$publicNamespace = $publicRoot.'/'.str_replace('/', DIRECTORY_SEPARATOR, $namespace);
throw_unless(! is_dir($publicNamespace) || count(glob($publicNamespace.'/*') ?: []) === 0, 'Owned Stage 5 blob leaked to public storage.');
$draft = DB::table('topics')->where('id', '05000000-0000-4000-c000-000000000102')->first();
$groupC = DB::table('topics')->where('id', '05000000-0000-4000-c000-000000000104')->first();
$archivedGroupC = DB::table('groups')->where('id', '05000000-0000-4000-a000-000000000103')->first();
$groupCMaterial = DB::table('learning_materials')->where('id', '05000000-0000-4000-d000-000000000103')->first();
$groupCFile = DB::table('files')->where('id', '05000000-0000-4000-e000-000000000103')->first();
throw_unless($draft !== null && $draft->status === 'archived' && $draft->activated_at === null && $draft->closed_at === null && $draft->archived_at !== null, 'Seeded draft final lifecycle is invalid.');
throw_unless(strtotime($draft->created_at) <= strtotime($draft->archived_at), 'Seeded draft lifecycle order is invalid.');
throw_unless($groupC !== null && $groupC->status === 'archived' && $groupC->activated_at !== null && $groupC->closed_at !== null && $groupC->archived_at !== null, 'Archived Group Topic final lifecycle is invalid.');
throw_unless($archivedGroupC !== null && $archivedGroupC->archived_at !== null && $groupCMaterial !== null && $groupCFile !== null && $groupCMaterial->topic_id === $groupC->id && $groupCMaterial->file_id === $groupCFile->id, 'Archived Group C historical content is incomplete.');
throw_unless(strtotime($groupC->created_at) <= strtotime($groupC->activated_at), 'Archived Group Topic activation order is invalid.');
throw_unless(strtotime($groupC->created_at) < strtotime($archivedGroupC->archived_at) && strtotime($groupCMaterial->created_at) < strtotime($archivedGroupC->archived_at) && strtotime($groupCFile->created_at) < strtotime($archivedGroupC->archived_at), 'Archived Group C historical content order is invalid.');
throw_unless(strtotime($archivedGroupC->archived_at) <= strtotime($groupC->closed_at) && strtotime($groupC->closed_at) <= strtotime($groupC->archived_at), 'Archived Group Topic final lifecycle order is invalid.');
$dynamic = [
    'topic_id' => $topic->id, 'status' => 'archived',
    'replacement_material_id' => $replacement->material_id, 'replacement_file_id' => $replacement->file_id,
    'replacement_sha256' => $replacement->checksum_sha256,
    'removed_material_id' => $removed->material_id, 'removed_file_id' => $removed->file_id,
    'remaining_material_ids' => $current->pluck('material_id')->sort()->values()->all(),
];
echo 'Stage5Dynamic:'.base64_encode(json_encode($dynamic, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
'@
    $json = Invoke-Stage5ReadOnlyPhp -BackendContainerName $BackendContainerName -Program $program -Marker 'Stage5Dynamic'
    try { $dynamic = $json | ConvertFrom-Json } catch { throw 'The Stage 5 dynamic postcondition payload was invalid.' }
    if (
        [string] $dynamic.status -cne 'archived' -or
        [string] $dynamic.topic_id -cnotmatch '^[a-f0-9-]{36}$' -or
        [string] $dynamic.replacement_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
        @($dynamic.remaining_material_ids).Count -ne 3
    ) { throw 'The Stage 5 dynamic postcondition payload was incomplete.' }
    $dynamic
}

function Assert-Stage5DatabaseStoragePostconditions {
    param(
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][ValidateSet('Mutation', 'Persistence')][string] $Phase
    )
    Get-Stage5DynamicPostconditions -BackendContainerName $BackendContainerName | Out-Null
    Write-Output "Stage5${Phase}DatabaseStoragePostconditions: PASS"
}

function Add-Stage5DynamicOracleBlock {
    param(
        [Parameter(Mandatory = $true)][string] $BackendContainerName,
        [Parameter(Mandatory = $true)][string] $OraclePath
    )
    $path = Assert-Stage5OracleDestination -Path $OraclePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'The Stage 5 host oracle is unavailable.' }
    try { $oracle = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json } catch { throw 'The Stage 5 host oracle is invalid.' }
    if ($null -ne $oracle.PSObject.Properties['dynamic']) { throw 'The Stage 5 host oracle already contains dynamic state.' }
    $dynamic = Get-Stage5DynamicPostconditions -BackendContainerName $BackendContainerName
    $oracle | Add-Member -NotePropertyName dynamic -NotePropertyValue $dynamic
    $json = $oracle | ConvertTo-Json -Depth 8
    $replacement = Join-Path (Split-Path -Parent $path) ('testlabuz-stage5-oracle-replacement-' + [guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($replacement, $json, [Text.UTF8Encoding]::new($false))
    try { [IO.File]::Replace($replacement, $path, $null) } catch {
        if (Test-Path -LiteralPath $replacement) { Remove-Item -LiteralPath $replacement -Force }
        throw 'The Stage 5 host oracle atomic replacement failed.'
    }
}
