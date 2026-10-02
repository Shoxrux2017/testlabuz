Set-StrictMode -Version Latest

$script:Stage9FixtureSpecs = [ordered] @{
    answer_pdf = @('e2e_s09_answer.pdf', 'pdf', 'application/pdf')
}

function Assert-Stage9FixtureRoot {
    param([Parameter(Mandatory = $true)][string] $Path)
    $root = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if (-not [IO.Path]::GetDirectoryName($root).Equals($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($root) -cnotmatch '\Atestlabuz-stage9-fixtures-[a-f0-9]{32}\z') {
        throw 'integration-harness defect: Stage 9 fixtures require their exact system-temp directory.'
    }
    if ((Test-Path -LiteralPath $root) -and
        ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'integration-harness defect: Stage 9 fixture roots cannot be links.'
    }
    return $root
}

function New-Stage9PdfFixture {
    param([string] $Path)
    $stream = "BT /F1 12 Tf 40 100 Td (E2E S09 Student Homework answer) Tj ET`n"
    $objects = @(
        '<</Type /Catalog /Pages 2 0 R>>',
        '<</Type /Pages /Kids [3 0 R] /Count 1>>',
        '<</Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources <</Font <</F1 4 0 R>>>> /Contents 5 0 R>>',
        '<</Type /Font /Subtype /Type1 /BaseFont /Helvetica>>',
        ('<</Length ' + $stream.Length + ">>`nstream`n" + $stream + 'endstream')
    )
    $pdf = [Text.StringBuilder]::new("%PDF-1.7`n")
    $offsets = [Collections.Generic.List[int]]::new()
    for ($index = 0; $index -lt $objects.Count; $index++) {
        $offsets.Add($pdf.Length)
        [void] $pdf.Append(($index + 1).ToString() + " 0 obj`n" + $objects[$index] + "`nendobj`n")
    }
    $xref = $pdf.Length
    [void] $pdf.Append("xref`n0 6`n0000000000 65535 f `n")
    foreach ($offset in $offsets) { [void] $pdf.Append($offset.ToString('D10') + " 00000 n `n") }
    [void] $pdf.Append("trailer`n<</Size 6 /Root 1 0 R>>`nstartxref`n$xref`n%%EOF`n")
    [IO.File]::WriteAllBytes($Path, [Text.Encoding]::ASCII.GetBytes($pdf.ToString()))
}

function New-Stage9FixtureManifest {
    param([Parameter(Mandatory = $true)][string] $DestinationRoot)
    $root = Assert-Stage9FixtureRoot $DestinationRoot
    if (Test-Path -LiteralPath $root) { throw 'integration-harness defect: Stage 9 fixture root must be new.' }
    [void] [IO.Directory]::CreateDirectory($root)
    try {
        New-Stage9PdfFixture -Path (Join-Path $root 'e2e_s09_answer.pdf')
        $files = [ordered] @{}
        foreach ($key in $script:Stage9FixtureSpecs.Keys) {
            $spec = $script:Stage9FixtureSpecs[$key]
            $path = Join-Path $root $spec[0]
            $files[$key] = [ordered] @{
                path = $path; original_name = $spec[0]; extension = $spec[1]; mime_type = $spec[2]
                size_bytes = (Get-Item -LiteralPath $path).Length
                sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
        $manifestPath = Join-Path $root 'fixture-manifest.json'
        [IO.File]::WriteAllText($manifestPath, ([ordered] @{ version = 1; files = $files } | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
        return [pscustomobject] @{ Root = $root; ManifestPath = $manifestPath; Files = $files }
    }
    catch {
        Remove-Stage9FixtureManifest -Root $root
        throw
    }
}

function Assert-Stage9FixtureManifest {
    param([Parameter(Mandatory = $true)][object] $Manifest)
    $root = Assert-Stage9FixtureRoot $Manifest.Root
    if (@($Manifest.Files.Keys).Count -ne $script:Stage9FixtureSpecs.Count) { throw 'integration-harness defect: Stage 9 requires exactly the declared generated fixtures.' }
    foreach ($key in $script:Stage9FixtureSpecs.Keys) {
        $spec = $script:Stage9FixtureSpecs[$key]
        $record = $Manifest.Files[$key]
        $expectedPath = Join-Path $root $spec[0]
        if ($null -eq $record -or $record.path -cne $expectedPath -or $record.original_name -cne $spec[0] -or $record.extension -cne $spec[1] -or
            $record.mime_type -cne $spec[2] -or (Get-Item -LiteralPath $expectedPath).Length -ne $record.size_bytes -or
            (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $record.sha256) {
            throw 'integration-harness defect: Stage 9 fixture metadata/path/integrity mismatch.'
        }
        if ($record.size_bytes -le 0 -or $record.size_bytes -gt 1048576) { throw 'integration-harness defect: Stage 9 fixture size is invalid.' }
        $bytes = [IO.File]::ReadAllBytes($expectedPath)
        $pdfHeader = $bytes.Length -ge 5 -and [Text.Encoding]::ASCII.GetString($bytes, 0, 5) -ceq '%PDF-'
        if ($key -ceq 'answer_pdf' -and -not $pdfHeader) { throw 'integration-harness defect: Stage 9 valid PDF signature is missing.' }
    }
}

function Remove-Stage9FixtureManifest {
    param([Parameter(Mandatory = $true)][string] $Root)
    $rootPath = Assert-Stage9FixtureRoot $Root
    if (-not (Test-Path -LiteralPath $rootPath)) { return }
    foreach ($name in @(@($script:Stage9FixtureSpecs.Values | ForEach-Object { $_[0] }) + 'fixture-manifest.json')) {
        $path = Join-Path $rootPath $name
        if (Test-Path -LiteralPath $path) {
            $entry = Get-Item -LiteralPath $path
            if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'integration-harness defect: Unsafe Stage 9 fixture cleanup entry.' }
            Remove-Item -LiteralPath $path
        }
    }
    # Nonrecursive removal preserves any unexpected file instead of deleting it.
    [IO.Directory]::Delete($rootPath, $false)
    if (Test-Path -LiteralPath $rootPath) { throw 'integration-harness defect: Stage 9 generated fixture cleanup failed.' }
}
