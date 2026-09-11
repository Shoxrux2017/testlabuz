Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Stage7FixtureRoot {
    param([Parameter(Mandatory = $true)][string] $Path)
    $root = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if (-not [IO.Path]::GetDirectoryName($root).Equals($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($root) -cnotmatch '\Atestlabuz-stage7-fixtures-[a-f0-9]{32}\z') {
        throw 'Stage 7 fixtures require their exact system-temp directory.'
    }
    if ((Test-Path -LiteralPath $root) -and
        ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Stage 7 fixture roots cannot be links.'
    }
    return $root
}

function New-Stage7PdfFixture {
    param([string] $Path, [switch] $OverLimit)
    $stream = "BT /F1 12 Tf 40 100 Td (E2E S07 Student answer) Tj ET`n"
    if ($OverLimit) { $stream += '%' + ('x' * 2097152) + "`n" }
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

function New-Stage7PptxFixture {
    param([string] $Path)
    $entries = [ordered] @{
        '[Content_Types].xml' = '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/></Types>'
        '_rels/.rels' = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>'
        'ppt/presentation.xml' = '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="9144000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>'
        'ppt/_rels/presentation.xml.rels' = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>'
        'ppt/slides/slide1.xml' = '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld name="E2E S07 replacement"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>'
    }
    $file = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $zip = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($name in $entries.Keys) {
                $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::NoCompression)
                $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
                $writer = [IO.StreamWriter]::new($entry.Open(), [Text.UTF8Encoding]::new($false))
                try { $writer.Write([string] $entries[$name]) } finally { $writer.Dispose() }
            }
        }
        finally { $zip.Dispose() }
    }
    finally { $file.Dispose() }
}

function New-Stage7FixtureManifest {
    param([Parameter(Mandatory = $true)][string] $DestinationRoot)
    $root = Assert-Stage7FixtureRoot $DestinationRoot
    if (Test-Path -LiteralPath $root) { throw 'Stage 7 fixture root must be new.' }
    [void] [IO.Directory]::CreateDirectory($root)
    try {
        New-Stage7PdfFixture -Path (Join-Path $root 'e2e_s07_answer.pdf')
        New-Stage7PdfFixture -Path (Join-Path $root 'e2e_s07_over_limit.pdf') -OverLimit
        New-Stage7PptxFixture -Path (Join-Path $root 'e2e_s07_replacement.pptx')
        [IO.File]::WriteAllText((Join-Path $root 'e2e_s07_fake.pdf'), 'E2E S07 unsupported plain text', [Text.UTF8Encoding]::new($false))
        $specs = @(
            @('valid_pdf', 'e2e_s07_answer.pdf', 'pdf', 'application/pdf'),
            @('replacement_pptx', 'e2e_s07_replacement.pptx', 'pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'),
            @('fake_pdf', 'e2e_s07_fake.pdf', 'pdf', 'application/pdf'),
            @('over_limit_pdf', 'e2e_s07_over_limit.pdf', 'pdf', 'application/pdf')
        )
        $files = [ordered] @{}
        foreach ($spec in $specs) {
            $path = Join-Path $root $spec[1]
            $files[$spec[0]] = [ordered] @{
                path = $path; original_name = $spec[1]; extension = $spec[2]; mime_type = $spec[3]
                size_bytes = (Get-Item -LiteralPath $path).Length
                sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
        $manifestPath = Join-Path $root 'fixture-manifest.json'
        [IO.File]::WriteAllText($manifestPath, ([ordered] @{ version = 1; files = $files } | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
        return [pscustomobject] @{ Root = $root; ManifestPath = $manifestPath; Files = $files }
    }
    catch {
        Remove-Stage7FixtureManifest -Root $root
        throw
    }
}

function Assert-Stage7FixtureManifest {
    param([Parameter(Mandatory = $true)][object] $Manifest)
    $root = Assert-Stage7FixtureRoot $Manifest.Root
    $expectedNames = @{
        valid_pdf = 'e2e_s07_answer.pdf'; replacement_pptx = 'e2e_s07_replacement.pptx'
        fake_pdf = 'e2e_s07_fake.pdf'; over_limit_pdf = 'e2e_s07_over_limit.pdf'
    }
    if (@($Manifest.Files.Keys).Count -ne 4) { throw 'Stage 7 requires exactly four generated fixtures.' }
    foreach ($key in $expectedNames.Keys) {
        $record = $Manifest.Files[$key]
        $expectedPath = Join-Path $root $expectedNames[$key]
        if ($record.path -cne $expectedPath -or $record.original_name -cne $expectedNames[$key] -or
            ('.' + $record.extension) -cne [IO.Path]::GetExtension($expectedPath) -or
            (Get-Item -LiteralPath $expectedPath).Length -ne $record.size_bytes -or
            (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $record.sha256) {
            throw 'Stage 7 fixture metadata/path/integrity mismatch.'
        }
        if ($key -ceq 'over_limit_pdf') {
            if ($record.size_bytes -le 2097152) { throw 'Stage 7 over-limit fixture is too small.' }
        }
        elseif ($record.size_bytes -le 0 -or $record.size_bytes -gt 2097152) { throw 'Stage 7 small fixture size is invalid.' }
        if ($record.extension -ceq 'pdf') {
            $header = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($expectedPath), 0, 5)
            if (($key -ceq 'fake_pdf') -eq ($header -ceq '%PDF-')) { throw 'Stage 7 PDF content identity is incorrect.' }
        }
    }
    $zip = [IO.Compression.ZipFile]::OpenRead($Manifest.Files['replacement_pptx'].path)
    try {
        foreach ($name in @('[Content_Types].xml', '_rels/.rels', 'ppt/presentation.xml', 'ppt/_rels/presentation.xml.rels', 'ppt/slides/slide1.xml')) {
            $entry = $zip.GetEntry($name)
            if ($null -eq $entry) { throw 'Stage 7 PPTX structure is incomplete.' }
            $reader = [IO.StreamReader]::new($entry.Open())
            try {
                $xml = [xml] $reader.ReadToEnd()
                if ($name -ceq 'ppt/presentation.xml' -and $xml.DocumentElement.LocalName -cne 'presentation') { throw 'Invalid PPTX presentation.' }
                if ($name -ceq '[Content_Types].xml' -and
                    @($xml.DocumentElement.ChildNodes | Where-Object { $_.LocalName -ceq 'Override' -and $_.GetAttribute('PartName') -ceq '/ppt/presentation.xml' -and $_.GetAttribute('ContentType') -ceq 'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml' }).Count -ne 1) {
                    throw 'Invalid PPTX main content type.'
                }
            }
            finally { $reader.Dispose() }
        }
    }
    finally { $zip.Dispose() }
}

function Remove-Stage7FixtureManifest {
    param([Parameter(Mandatory = $true)][string] $Root)
    $rootPath = Assert-Stage7FixtureRoot $Root
    if (-not (Test-Path -LiteralPath $rootPath)) { return }
    foreach ($name in @('e2e_s07_answer.pdf', 'e2e_s07_replacement.pptx', 'e2e_s07_fake.pdf', 'e2e_s07_over_limit.pdf', 'fixture-manifest.json')) {
        $path = Join-Path $rootPath $name
        if (Test-Path -LiteralPath $path) {
            $entry = Get-Item -LiteralPath $path
            if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Unsafe Stage 7 fixture cleanup entry.' }
            Remove-Item -LiteralPath $path
        }
    }
    # Nonrecursive removal preserves any unexpected file instead of deleting it.
    [IO.Directory]::Delete($rootPath, $false)
    if (Test-Path -LiteralPath $rootPath) { throw 'Stage 7 generated fixture cleanup failed.' }
}
