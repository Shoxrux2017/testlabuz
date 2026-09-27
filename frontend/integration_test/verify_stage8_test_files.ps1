Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'stage8_test_files.ps1')

$script:checks = 0
function Confirm-Stage8FileReject {
    param([string] $Label, [scriptblock] $Check)
    $rejected = $false
    try { & $Check } catch { $rejected = $true }
    if (-not $rejected) { throw "Stage 8 fixture guard accepted $Label." }
    $script:checks++
}
function New-Stage8FixtureRootPath { Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage8-fixtures-' + [guid]::NewGuid().ToString('N')) }

$roots = @((New-Stage8FixtureRootPath), (New-Stage8FixtureRootPath))
try {
    $first = New-Stage8FixtureManifest -DestinationRoot $roots[0]
    $second = New-Stage8FixtureManifest -DestinationRoot $roots[1]
    Assert-Stage8FixtureManifest $first
    Assert-Stage8FixtureManifest $second
    foreach ($key in $first.Files.Keys) {
        if ($first.Files[$key].sha256 -cne $second.Files[$key].sha256) { throw 'Stage 8 fixture generation is not deterministic.' }
    }
    $script:checks += 3
    Confirm-Stage8FileReject 'a repository directory' { Assert-Stage8FixtureRoot -Path $PSScriptRoot | Out-Null }
    Confirm-Stage8FileReject 'a Stage 7 fixture root name' { Assert-Stage8FixtureRoot -Path (Join-Path ([IO.Path]::GetTempPath()) ('testlabuz-stage7-fixtures-' + [guid]::NewGuid().ToString('N'))) | Out-Null }
    Confirm-Stage8FileReject 'reusing an existing root' { New-Stage8FixtureManifest -DestinationRoot $roots[1] | Out-Null }
    $original = $first.Files['answer_pdf'].path
    $first.Files['answer_pdf'].path = Join-Path $PSScriptRoot 'unexpected.pdf'
    Confirm-Stage8FileReject 'an escaped path' { Assert-Stage8FixtureManifest $first }
    $first.Files['answer_pdf'].path = $original
    $hash = $first.Files['replacement_docx'].sha256
    $first.Files['replacement_docx'].sha256 = ('0' * 64)
    Confirm-Stage8FileReject 'a wrong checksum' { Assert-Stage8FixtureManifest $first }
    $first.Files['replacement_docx'].sha256 = $hash
    $first.Files['replacement_pptx'].mime_type = 'application/pdf'
    Confirm-Stage8FileReject 'a wrong MIME type' { Assert-Stage8FixtureManifest $first }
    $first.Files['replacement_pptx'].mime_type = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'

    # Tamper with bytes on disk so the content checks, not only the metadata checks, are exercised.
    $fake = $second.Files['fake_pdf']
    [IO.File]::WriteAllText($fake.path, '%PDF-1.7 disguised', [Text.UTF8Encoding]::new($false))
    $fake.size_bytes = (Get-Item -LiteralPath $fake.path).Length
    $fake.sha256 = (Get-FileHash -LiteralPath $fake.path -Algorithm SHA256).Hash.ToLowerInvariant()
    Confirm-Stage8FileReject 'a fake PDF with a real signature' { Assert-Stage8FixtureManifest $second }
    $docx = $second.Files['replacement_docx']
    Remove-Item -LiteralPath $docx.path
    New-Stage8OpenXmlFixture -Path $docx.path -Kind pptx
    $docx.size_bytes = (Get-Item -LiteralPath $docx.path).Length
    $docx.sha256 = (Get-FileHash -LiteralPath $docx.path -Algorithm SHA256).Hash.ToLowerInvariant()
    Confirm-Stage8FileReject 'a DOCX without word/document.xml' { Assert-Stage8FixtureManifest $second }
}
finally {
    foreach ($root in $roots) { Remove-Stage8FixtureManifest -Root $root }
}
foreach ($root in $roots) {
    if (Test-Path -LiteralPath $root) { throw 'Stage 8 test file cleanup left generated files.' }
}
Write-Output "Stage8TestFiles: PASS ($script:checks checks: names/extensions, PDF/DOCX/PPTX content, sizes, checksums, determinism, temp scope, cleanup)"
