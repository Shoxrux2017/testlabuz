<?php

namespace App\Support\Files;

use App\Enums\FileExtension;
use App\Exceptions\Files\UnsupportedFileTypeException;
use Illuminate\Http\UploadedFile;
use RuntimeException;
use ZipArchive;

final class LearningMaterialFileInspector
{
    private const MIME_TYPES = [
        'pdf' => 'application/pdf',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'ppt' => 'application/vnd.ms-powerpoint',
        'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    ];

    private const OLE_SIGNATURE = "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1";

    private const FREE_SECTOR = 0xFFFFFFFF;

    private const END_OF_CHAIN = 0xFFFFFFFE;

    public function inspect(UploadedFile $upload): LearningMaterialFileMetadata
    {
        $path = $upload->getPathname();
        $sizeBytes = filesize($path);
        $checksumSha256 = hash_file('sha256', $path);

        if (! is_int($sizeBytes) || ! is_string($checksumSha256)) {
            throw new RuntimeException('The uploaded file could not be inspected.');
        }

        $extension = $this->detectExtension($path);
        $originalName = $upload->getClientOriginalName();
        $filenameExtension = strtolower((string) pathinfo($originalName, PATHINFO_EXTENSION));

        if ($filenameExtension === '' || $filenameExtension !== $extension->value) {
            throw new UnsupportedFileTypeException;
        }

        return new LearningMaterialFileMetadata(
            originalName: $originalName,
            extension: $extension,
            mimeType: self::MIME_TYPES[$extension->value],
            sizeBytes: $sizeBytes,
            checksumSha256: strtolower($checksumSha256),
        );
    }

    private function detectExtension(string $path): FileExtension
    {
        $signature = file_get_contents($path, false, null, 0, 8);

        if (is_string($signature) && preg_match('/\A%PDF-[0-9]\.[0-9]/', $signature) === 1) {
            return FileExtension::Pdf;
        }

        $ooxmlExtension = $this->detectOoxmlExtension($path);

        if ($ooxmlExtension instanceof FileExtension) {
            return $ooxmlExtension;
        }

        if ($signature === self::OLE_SIGNATURE && $this->oleContainsPowerPointDocumentStream($path)) {
            return FileExtension::Ppt;
        }

        throw new UnsupportedFileTypeException;
    }

    private function detectOoxmlExtension(string $path): ?FileExtension
    {
        $zip = new ZipArchive;

        if ($zip->open($path) !== true) {
            return null;
        }

        try {
            $contentTypesIndex = $zip->locateName('[Content_Types].xml');

            if ($contentTypesIndex === false) {
                return null;
            }

            $contentTypesStat = $zip->statIndex($contentTypesIndex);

            if (! is_array($contentTypesStat) || ($contentTypesStat['size'] ?? 0) > 1_048_576) {
                return null;
            }

            $contentTypes = $zip->getFromIndex($contentTypesIndex);

            if (! is_string($contentTypes)) {
                return null;
            }

            if ($zip->locateName('word/document.xml', ZipArchive::FL_NOCASE) !== false
                && str_contains($contentTypes, self::MIME_TYPES['docx'].'.main+xml')) {
                return FileExtension::Docx;
            }

            if ($zip->locateName('ppt/presentation.xml', ZipArchive::FL_NOCASE) !== false
                && str_contains($contentTypes, self::MIME_TYPES['pptx'].'.main+xml')) {
                return FileExtension::Pptx;
            }

            return null;
        } finally {
            $zip->close();
        }
    }

    private function oleContainsPowerPointDocumentStream(string $path): bool
    {
        $contents = file_get_contents($path);

        if (! is_string($contents) || strlen($contents) < 512) {
            return false;
        }

        $sectorShift = $this->uint16($contents, 30);

        if (! in_array($sectorShift, [9, 12], true)) {
            return false;
        }

        $sectorSize = 1 << $sectorShift;

        $fatSectorIds = [];

        for ($offset = 76; $offset < 512; $offset += 4) {
            $sectorId = $this->uint32($contents, $offset);
            if ($sectorId !== self::FREE_SECTOR) {
                $fatSectorIds[] = $sectorId;
            }
        }

        $nextDifatSector = $this->uint32($contents, 68);
        $difatSectorCount = $this->uint32($contents, 72);
        $maximumSectorCount = intdiv(strlen($contents) - 512, $sectorSize);
        $visitedDifatSectors = [];

        for ($index = 0; $index < min($difatSectorCount, $maximumSectorCount)
            && $nextDifatSector < self::END_OF_CHAIN
            && ! isset($visitedDifatSectors[$nextDifatSector]); $index++) {
            $visitedDifatSectors[$nextDifatSector] = true;
            $difatOffset = $this->sectorOffset($nextDifatSector, $sectorSize);
            if ($difatOffset + $sectorSize > strlen($contents)) {
                return false;
            }

            for ($entryOffset = 0; $entryOffset < $sectorSize - 4; $entryOffset += 4) {
                $sectorId = $this->uint32($contents, $difatOffset + $entryOffset);
                if ($sectorId !== self::FREE_SECTOR) {
                    $fatSectorIds[] = $sectorId;
                }
            }

            $nextDifatSector = $this->uint32($contents, $difatOffset + $sectorSize - 4);
        }

        $fat = [];
        foreach ($fatSectorIds as $fatSectorId) {
            $fatOffset = $this->sectorOffset($fatSectorId, $sectorSize);
            if ($fatOffset + $sectorSize > strlen($contents)) {
                return false;
            }

            for ($entryOffset = 0; $entryOffset < $sectorSize; $entryOffset += 4) {
                $fat[] = $this->uint32($contents, $fatOffset + $entryOffset);
            }
        }

        $directorySector = $this->uint32($contents, 48);
        $visited = [];

        while ($directorySector < self::END_OF_CHAIN && ! isset($visited[$directorySector])) {
            $visited[$directorySector] = true;
            $directoryOffset = $this->sectorOffset($directorySector, $sectorSize);

            if ($directoryOffset + $sectorSize > strlen($contents)) {
                return false;
            }

            for ($entryOffset = 0; $entryOffset < $sectorSize; $entryOffset += 128) {
                $nameLength = $this->uint16($contents, $directoryOffset + $entryOffset + 64);
                $objectType = ord($contents[$directoryOffset + $entryOffset + 66]);

                if ($objectType !== 2 || $nameLength < 2 || $nameLength > 64) {
                    continue;
                }

                $encodedName = substr($contents, $directoryOffset + $entryOffset, $nameLength - 2);
                $name = mb_convert_encoding($encodedName, 'UTF-8', 'UTF-16LE');

                if ($name === 'PowerPoint Document') {
                    return true;
                }
            }

            $directorySector = $fat[$directorySector] ?? self::END_OF_CHAIN;
        }

        return false;
    }

    private function sectorOffset(int $sectorId, int $sectorSize): int
    {
        return ($sectorId + 1) * $sectorSize;
    }

    private function uint16(string $contents, int $offset): int
    {
        return unpack('vvalue', substr($contents, $offset, 2))['value'];
    }

    private function uint32(string $contents, int $offset): int
    {
        return unpack('Vvalue', substr($contents, $offset, 4))['value'];
    }
}
