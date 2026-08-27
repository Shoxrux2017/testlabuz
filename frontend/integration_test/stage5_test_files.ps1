Set-StrictMode -Version Latest

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Stage5FixtureRoot {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][ValidateSet('Automated', 'Manual')][string] $Mode
    )
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $resolved = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $prefix = if ($Mode -ceq 'Automated') { 'testlabuz-stage5-fixtures-' } else { 'testlabuz-stage5-manual-' }
    if (
        -not $resolved.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -cnotmatch ('^' + [regex]::Escape($prefix) + '[a-f0-9]{32}$')
    ) {
        throw 'The Stage 5 fixture root is outside its exact system-temp scope.'
    }
    $resolved
}

function Write-Stage5Bytes {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][byte[]] $Bytes
    )
    [IO.File]::WriteAllBytes($Path, $Bytes)
    if ((Get-Item -LiteralPath $Path).Length -ne $Bytes.Length) {
        throw 'A Stage 5 fixture was not written completely.'
    }
}

function New-Stage5PdfFixture {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Label,
        [Nullable[int64]] $ExactSize
    )
    $bytes = [Text.Encoding]::ASCII.GetBytes("%PDF-1.7`n% TestLabUz Stage 5 $Label`n1 0 obj<</Type/Catalog>>endobj`n%%EOF`n")
    if ($null -eq $ExactSize) {
        Write-Stage5Bytes -Path $Path -Bytes $bytes
        return
    }
    $exactSizeBytes = [int64] $ExactSize
    if ($exactSizeBytes -lt $bytes.Length) { throw 'The requested Stage 5 PDF size is too small.' }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.SetLength($exactSizeBytes)
        $stream.Flush($true)
    }
    finally { $stream.Dispose() }
    if ((Get-Item -LiteralPath $Path).Length -ne $exactSizeBytes) { throw 'The Stage 5 sized PDF length is invalid.' }
}

function New-Stage5OoxmlFixture {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][ValidateSet('docx', 'pptx')][string] $Type
    )
    $part = if ($Type -ceq 'docx') { 'word/document.xml' } else { 'ppt/presentation.xml' }
    $contentType = if ($Type -ceq 'docx') {
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'
    }
    else { 'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml' }
    $fileStream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $archive = [IO.Compression.ZipArchive]::new($fileStream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            $entries = [ordered] @{
                '[Content_Types].xml' = "<Types><Override PartName=`"/$part`" ContentType=`"$contentType`"/></Types>"
                $part = '<root/>'
            }
            foreach ($name in $entries.Keys) {
                $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::NoCompression)
                $writer = [IO.StreamWriter]::new($entry.Open(), [Text.UTF8Encoding]::new($false))
                try { $writer.Write([string] $entries[$name]) } finally { $writer.Dispose() }
            }
        }
        finally { $archive.Dispose() }
    }
    finally { $fileStream.Dispose() }
}

function Set-Stage5UInt16 {
    param([byte[]] $Bytes, [int] $Offset, [uint16] $Value)
    [Array]::Copy([BitConverter]::GetBytes($Value), 0, $Bytes, $Offset, 2)
}

function Set-Stage5UInt32 {
    param([byte[]] $Bytes, [int] $Offset, [uint32] $Value)
    [Array]::Copy([BitConverter]::GetBytes($Value), 0, $Bytes, $Offset, 4)
}

function New-Stage5PptFixture {
    param([Parameter(Mandatory = $true)][string] $Path)
    $bytes = [byte[]]::new(1536)
    [Array]::Copy([byte[]] @(0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1), 0, $bytes, 0, 8)
    Set-Stage5UInt16 -Bytes $bytes -Offset 30 -Value 9
    Set-Stage5UInt32 -Bytes $bytes -Offset 44 -Value 1
    Set-Stage5UInt32 -Bytes $bytes -Offset 48 -Value 0
    Set-Stage5UInt32 -Bytes $bytes -Offset 68 -Value ([uint32]::MaxValue - 1)
    Set-Stage5UInt32 -Bytes $bytes -Offset 72 -Value 0
    Set-Stage5UInt32 -Bytes $bytes -Offset 76 -Value 1
    for ($offset = 80; $offset -lt 512; $offset += 4) { Set-Stage5UInt32 -Bytes $bytes -Offset $offset -Value ([uint32]::MaxValue) }
    $encodedName = [Text.Encoding]::Unicode.GetBytes("PowerPoint Document`0")
    [Array]::Copy($encodedName, 0, $bytes, 512, $encodedName.Length)
    Set-Stage5UInt16 -Bytes $bytes -Offset 576 -Value ([uint16] $encodedName.Length)
    $bytes[578] = 2
    for ($offset = 1024; $offset -lt 1536; $offset += 4) { Set-Stage5UInt32 -Bytes $bytes -Offset $offset -Value ([uint32]::MaxValue) }
    Set-Stage5UInt32 -Bytes $bytes -Offset 1024 -Value ([uint32]::MaxValue - 1)
    Set-Stage5UInt32 -Bytes $bytes -Offset 1028 -Value ([uint32]::MaxValue - 2)
    Write-Stage5Bytes -Path $Path -Bytes $bytes
}

function Get-Stage5FixtureRecord {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $OriginalName,
        [Parameter(Mandatory = $true)][string] $Extension,
        [Parameter(Mandatory = $true)][string] $MimeType
    )
    $file = Get-Item -LiteralPath $Path
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($file.FullName -cne [IO.Path]::GetFullPath($Path) -or $hash -cnotmatch '^[a-f0-9]{64}$') {
        throw 'A Stage 5 fixture record failed validation.'
    }
    [ordered] @{
        path = $file.FullName
        original_name = $OriginalName
        extension = $Extension
        mime_type = $MimeType
        size_bytes = [int64] $file.Length
        sha256 = $hash
    }
}

function New-Stage5FixtureManifest {
    param(
        [Parameter(Mandatory = $true)][string] $DestinationRoot,
        [Parameter(Mandatory = $true)][ValidateSet('Automated', 'Manual')][string] $Mode
    )
    $root = Assert-Stage5FixtureRoot -Path $DestinationRoot -Mode $Mode
    if (Test-Path -LiteralPath $root) { throw 'The Stage 5 fixture root must be new.' }
    New-Item -ItemType Directory -Path $root | Out-Null

    $files = [ordered] @{}
    if ($Mode -ceq 'Automated') {
        $specifications = @(
            @{ Key = 'pdf'; Name = 'e2e_s05_material.pdf'; Extension = 'pdf'; Mime = 'application/pdf'; Kind = 'pdf'; Label = 'automated-pdf' },
            @{ Key = 'docx'; Name = 'e2e_s05_material.docx'; Extension = 'docx'; Mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'; Kind = 'docx' },
            @{ Key = 'ppt'; Name = 'e2e_s05_material.ppt'; Extension = 'ppt'; Mime = 'application/vnd.ms-powerpoint'; Kind = 'ppt' },
            @{ Key = 'pptx'; Name = 'e2e_s05_material.pptx'; Extension = 'pptx'; Mime = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'; Kind = 'pptx' },
            @{ Key = 'replacement_pdf'; Name = 'e2e_s05_replacement.pdf'; Extension = 'pdf'; Mime = 'application/pdf'; Kind = 'pdf'; Label = 'replacement-pdf' },
            @{ Key = 'unsupported'; Name = 'e2e_s05_unsupported.txt'; Extension = 'txt'; Mime = 'text/plain'; Kind = 'text' },
            @{ Key = 'low_limit_over'; Name = 'e2e_s05_low_limit_over.pdf'; Extension = 'pdf'; Mime = 'application/pdf'; Kind = 'sized'; Size = [int64] 1048577; Label = 'low-limit-over' },
            @{ Key = 'platform_over'; Name = 'e2e_s05_platform_over.pdf'; Extension = 'pdf'; Mime = 'application/pdf'; Kind = 'sized'; Size = [int64] 26214401; Label = 'platform-over' }
        )
    }
    else {
        $specifications = @(
            @{ Key = 'manual_pdf'; Name = 'e2e_s05_manual_smoke.pdf'; Extension = 'pdf'; Mime = 'application/pdf'; Kind = 'pdf'; Label = 'manual-smoke' }
        )
    }
    foreach ($specification in $specifications) {
        $path = Join-Path $root $specification.Name
        switch ($specification.Kind) {
            'pdf' { New-Stage5PdfFixture -Path $path -Label $specification.Label }
            'sized' { New-Stage5PdfFixture -Path $path -Label $specification.Label -ExactSize $specification.Size }
            'docx' { New-Stage5OoxmlFixture -Path $path -Type docx }
            'pptx' { New-Stage5OoxmlFixture -Path $path -Type pptx }
            'ppt' { New-Stage5PptFixture -Path $path }
            'text' { Write-Stage5Bytes -Path $path -Bytes ([Text.Encoding]::UTF8.GetBytes('unsupported Stage 5 fixture')) }
        }
        $files[$specification.Key] = Get-Stage5FixtureRecord `
            -Path $path `
            -OriginalName $specification.Name `
            -Extension $specification.Extension `
            -MimeType $specification.Mime
    }
    $manifestPath = Join-Path $root 'fixture-manifest.json'
    $json = [ordered] @{ version = 1; files = $files } | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($manifestPath, $json, [Text.UTF8Encoding]::new($false))

    [pscustomobject] @{ Root = $root; ManifestPath = $manifestPath; Files = $files }
}
