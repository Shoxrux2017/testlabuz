<?php

namespace App\Support\Files;

use InvalidArgumentException;

final readonly class ProtectedFileDownload
{
    /** @param resource $stream */
    public function __construct(
        public mixed $stream,
        public string $mimeType,
        public string $displayFilename,
        public string $canonicalExtension,
    ) {
        if (! is_resource($stream)) {
            throw new InvalidArgumentException('A protected download requires an open stream.');
        }
    }
}
