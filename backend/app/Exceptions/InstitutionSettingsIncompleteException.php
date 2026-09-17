<?php

namespace App\Exceptions;

use RuntimeException;

final class InstitutionSettingsIncompleteException extends RuntimeException
{
    /** @var list<string> */
    public readonly array $missingFields;

    /** @param list<string> $missingFields */
    public function __construct(array $missingFields)
    {
        parent::__construct('Required institution settings are incomplete.');
        $missingFields = array_values(array_unique($missingFields));
        sort($missingFields, SORT_STRING);
        $this->missingFields = $missingFields;
    }
}
