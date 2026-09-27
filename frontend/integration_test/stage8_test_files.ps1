Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:Stage8FixtureSpecs = [ordered] @{
    answer_pdf = @('e2e_s08_answer.pdf', 'pdf', 'application/pdf')
    replacement_docx = @('e2e_s08_replacement.docx', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    replacement_pptx = @('e2e_s08_replacement.pptx', 'pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation')
    fake_pdf = @('e2e_s08_fake.pdf', 'pdf', 'application/pdf')
}

function Assert-Stage8FixtureRoot {
    param([Parameter(Mandatory = $true)][string] $Path)
    $root = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if (-not [IO.Path]::GetDirectoryName($root).Equals($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($root) -cnotmatch '\Atestlabuz-stage8-fixtures-[a-f0-9]{32}\z') {
        throw 'Stage 8 fixtures require their exact system-temp directory.'
    }
    if ((Test-Path -LiteralPath $root) -and
        ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Stage 8 fixture roots cannot be links.'
    }
    return $root
}

function New-Stage8PdfFixture {
    param([string] $Path)
    $stream = "BT /F1 12 Tf 40 100 Td (E2E S08 Student Blitz answer) Tj ET`n"
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

function New-Stage8OpenXmlFixture {
    param([string] $Path, [ValidateSet('docx', 'pptx')][string] $Kind)
    $relationships = 'http://schemas.openxmlformats.org/package/2006/relationships'
    $entries = if ($Kind -ceq 'docx') {
        [ordered] @{
            '[Content_Types].xml' = '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
            '_rels/.rels' = '<Relationships xmlns="' + $relationships + '"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
            'word/document.xml' = '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>E2E S08 replacement answer</w:t></w:r></w:p></w:body></w:document>'
        }
    }
    else {
        [ordered] @{
            '[Content_Types].xml' = '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/></Types>'
            '_rels/.rels' = '<Relationships xmlns="' + $relationships + '"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>'
            'ppt/presentation.xml' = '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="9144000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>'
            'ppt/_rels/presentation.xml.rels' = '<Relationships xmlns="' + $relationships + '"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>'
            'ppt/slides/slide1.xml' = '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld name="E2E S08 replacement"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>'
        }
    }
    $file = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $zip = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($name in $entries.Keys) {
                # Fixed entry timestamps keep the archive bytes deterministic.
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

function New-Stage8FixtureManifest {
    param([Parameter(Mandatory = $true)][string] $DestinationRoot)
    $root = Assert-Stage8FixtureRoot $DestinationRoot
    if (Test-Path -LiteralPath $root) { throw 'Stage 8 fixture root must be new.' }
    [void] [IO.Directory]::CreateDirectory($root)
    try {
        New-Stage8PdfFixture -Path (Join-Path $root 'e2e_s08_answer.pdf')
        New-Stage8OpenXmlFixture -Path (Join-Path $root 'e2e_s08_replacement.docx') -Kind docx
        New-Stage8OpenXmlFixture -Path (Join-Path $root 'e2e_s08_replacement.pptx') -Kind pptx
        [IO.File]::WriteAllText((Join-Path $root 'e2e_s08_fake.pdf'), 'E2E S08 unsupported plain text', [Text.UTF8Encoding]::new($false))
        $files = [ordered] @{}
        foreach ($key in $script:Stage8FixtureSpecs.Keys) {
            $spec = $script:Stage8FixtureSpecs[$key]
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
        Remove-Stage8FixtureManifest -Root $root
        throw
    }
}

function Assert-Stage8OpenXmlStructure {
    param([string] $Path, [ValidateSet('docx', 'pptx')][string] $Kind)
    $main = if ($Kind -ceq 'docx') { 'word/document.xml' } else { 'ppt/presentation.xml' }
    $mainType = if ($Kind -ceq 'docx') { 'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml' } else { 'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml' }
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($name in @('[Content_Types].xml', '_rels/.rels', $main)) {
            $entry = $zip.GetEntry($name)
            if ($null -eq $entry) { throw "Stage 8 $Kind structure is incomplete." }
            $reader = [IO.StreamReader]::new($entry.Open())
            try {
                $xml = [xml] $reader.ReadToEnd()
                if ($name -ceq '[Content_Types].xml' -and
                    @($xml.DocumentElement.ChildNodes | Where-Object { $_.LocalName -ceq 'Override' -and $_.GetAttribute('PartName') -ceq "/$main" -and $_.GetAttribute('ContentType') -ceq $mainType }).Count -ne 1) {
                    throw "Invalid Stage 8 $Kind main content type."
                }
            }
            finally { $reader.Dispose() }
        }
    }
    finally { $zip.Dispose() }
}

function Assert-Stage8FixtureManifest {
    param([Parameter(Mandatory = $true)][object] $Manifest)
    $root = Assert-Stage8FixtureRoot $Manifest.Root
    if (@($Manifest.Files.Keys).Count -ne $script:Stage8FixtureSpecs.Count) { throw 'Stage 8 requires exactly the declared generated fixtures.' }
    foreach ($key in $script:Stage8FixtureSpecs.Keys) {
        $spec = $script:Stage8FixtureSpecs[$key]
        $record = $Manifest.Files[$key]
        $expectedPath = Join-Path $root $spec[0]
        if ($null -eq $record -or $record.path -cne $expectedPath -or $record.original_name -cne $spec[0] -or $record.extension -cne $spec[1] -or
            $record.mime_type -cne $spec[2] -or (Get-Item -LiteralPath $expectedPath).Length -ne $record.size_bytes -or
            (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $record.sha256) {
            throw 'Stage 8 fixture metadata/path/integrity mismatch.'
        }
        if ($record.size_bytes -le 0 -or $record.size_bytes -gt 1048576) { throw 'Stage 8 fixture size is invalid.' }
        $bytes = [IO.File]::ReadAllBytes($expectedPath)
        $pdfHeader = $bytes.Length -ge 5 -and [Text.Encoding]::ASCII.GetString($bytes, 0, 5) -ceq '%PDF-'
        $zipHeader = $bytes.Length -ge 4 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B -and $bytes[2] -eq 0x03 -and $bytes[3] -eq 0x04
        switch ($key) {
            'answer_pdf' { if (-not $pdfHeader) { throw 'Stage 8 valid PDF signature is missing.' } }
            'fake_pdf' { if ($pdfHeader -or $zipHeader) { throw 'Stage 8 fake PDF must not carry a supported signature.' } }
            'replacement_docx' { if (-not $zipHeader) { throw 'Stage 8 DOCX is not a ZIP package.' }; Assert-Stage8OpenXmlStructure -Path $expectedPath -Kind docx }
            'replacement_pptx' { if (-not $zipHeader) { throw 'Stage 8 PPTX is not a ZIP package.' }; Assert-Stage8OpenXmlStructure -Path $expectedPath -Kind pptx }
        }
    }
    $hashes = @($script:Stage8FixtureSpecs.Keys | ForEach-Object { $Manifest.Files[$_].sha256 })
    if (@($hashes | Sort-Object -Unique).Count -ne $hashes.Count) { throw 'Stage 8 fixtures must have distinct bytes so replacement is observable.' }
}

function Remove-Stage8FixtureManifest {
    param([Parameter(Mandatory = $true)][string] $Root)
    $rootPath = Assert-Stage8FixtureRoot $Root
    if (-not (Test-Path -LiteralPath $rootPath)) { return }
    foreach ($name in @(@($script:Stage8FixtureSpecs.Values | ForEach-Object { $_[0] }) + 'fixture-manifest.json')) {
        $path = Join-Path $rootPath $name
        if (Test-Path -LiteralPath $path) {
            $entry = Get-Item -LiteralPath $path
            if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Unsafe Stage 8 fixture cleanup entry.' }
            Remove-Item -LiteralPath $path
        }
    }
    # Nonrecursive removal preserves any unexpected file instead of deleting it.
    [IO.Directory]::Delete($rootPath, $false)
    if (Test-Path -LiteralPath $rootPath) { throw 'Stage 8 generated fixture cleanup failed.' }
}
