<?php

namespace App\Exceptions\Files;

use RuntimeException;

class FileTooLargeException extends RuntimeException
{
    public function __construct(public readonly int $maxSizeBytes)
    {
        parent::__construct();
    }
}
