Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage7_test_files.ps1')

$roots = @(
    (Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage7-fixtures-' + [guid]::NewGuid().ToString('N'))),
    (Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage7-fixtures-' + [guid]::NewGuid().ToString('N')))
)
try {
    $first = New-Stage7FixtureManifest -DestinationRoot $roots[0]
    $second = New-Stage7FixtureManifest -DestinationRoot $roots[1]
    Assert-Stage7FixtureManifest $first
    Assert-Stage7FixtureManifest $second
    foreach ($key in $first.Files.Keys) {
        if ($first.Files[$key].sha256 -cne $second.Files[$key].sha256) { throw 'Stage 7 fixture generation is not deterministic.' }
    }
    $rejected = $false
    try { Assert-Stage7FixtureRoot -Path $PSScriptRoot | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'Stage 7 fixture guard accepted a repository directory.' }
    $first.Files['valid_pdf'].path = Join-Path $PSScriptRoot 'unexpected.pdf'
    $rejected = $false
    try { Assert-Stage7FixtureManifest $first } catch { $rejected = $true }
    if (-not $rejected) { throw 'Stage 7 fixture guard accepted an escaped path.' }
}
finally {
    foreach ($root in $roots) { Remove-Stage7FixtureManifest -Root $root }
}
foreach ($root in $roots) {
    if (Test-Path -LiteralPath $root) { throw 'Stage 7 test file cleanup left generated files.' }
}
Write-Output 'Stage7TestFiles: PASS (names/extensions, content, sizes, checksums, determinism, temp scope, cleanup)'
