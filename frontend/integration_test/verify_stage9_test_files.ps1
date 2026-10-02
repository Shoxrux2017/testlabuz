Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage9_test_files.ps1')

$script:checks = 0
function Confirm-Stage9FileReject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "Stage 9 fixture guard accepted $Label." }
    $script:checks++
}
function New-Stage9FixtureRootPath { Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage9-fixtures-' + [guid]::NewGuid().ToString('N')) }

$roots = @((New-Stage9FixtureRootPath), (New-Stage9FixtureRootPath))
try {
    $first = New-Stage9FixtureManifest -DestinationRoot $roots[0]
    $second = New-Stage9FixtureManifest -DestinationRoot $roots[1]
    Assert-Stage9FixtureManifest $first
    Assert-Stage9FixtureManifest $second
    foreach ($key in $first.Files.Keys) {
        if ($first.Files[$key].sha256 -cne $second.Files[$key].sha256) { throw 'Stage 9 fixture generation is not deterministic.' }
    }
    $script:checks += 3
    Confirm-Stage9FileReject 'a repository directory' { Assert-Stage9FixtureRoot -Path $PSScriptRoot | Out-Null }
    Confirm-Stage9FileReject 'a Stage 7 fixture root name' { Assert-Stage9FixtureRoot -Path (Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage7-fixtures-' + [guid]::NewGuid().ToString('N'))) | Out-Null }
    Confirm-Stage9FileReject 'reusing an existing root' { New-Stage9FixtureManifest -DestinationRoot $roots[1] | Out-Null }
    $answer = $first.Files['answer_pdf']
    $original = $answer.path
    $answer.path = Join-Path $PSScriptRoot 'unexpected.pdf'
    Confirm-Stage9FileReject 'an escaped path' { Assert-Stage9FixtureManifest $first }
    $answer.path = $original
    $hash = $answer.sha256
    $answer.sha256 = ('0' * 64)
    Confirm-Stage9FileReject 'a wrong checksum' { Assert-Stage9FixtureManifest $first }
    $answer.sha256 = $hash
    $answer.mime_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    Confirm-Stage9FileReject 'a wrong MIME type' { Assert-Stage9FixtureManifest $first }
    $answer.mime_type = 'application/pdf'
    $first.Files['extra_pdf'] = $answer
    Confirm-Stage9FileReject 'an undeclared extra fixture' { Assert-Stage9FixtureManifest $first }
    $first.Files.Remove('extra_pdf')
    Assert-Stage9FixtureManifest $first

    # Tamper with bytes on disk so the content check, not only the metadata checks, is exercised.
    $tampered = $second.Files['answer_pdf']
    [IO.File]::WriteAllText($tampered.path, 'E2E S09 plain text disguised as a PDF', [Text.UTF8Encoding]::new($false))
    $tampered.size_bytes = (Get-Item -LiteralPath $tampered.path).Length
    $tampered.sha256 = (Get-FileHash -LiteralPath $tampered.path -Algorithm SHA256).Hash.ToLowerInvariant()
    Confirm-Stage9FileReject 'a PDF without its signature' { Assert-Stage9FixtureManifest $second }
}
finally {
    foreach ($root in $roots) { Remove-Stage9FixtureManifest -Root $root }
}
foreach ($root in $roots) {
    if (Test-Path -LiteralPath $root) { throw 'Stage 9 test file cleanup left generated files.' }
}
Write-Output "Stage9TestFiles: PASS ($script:checks checks: names/extensions, PDF content, sizes, checksums, determinism, temp scope, cleanup)"
