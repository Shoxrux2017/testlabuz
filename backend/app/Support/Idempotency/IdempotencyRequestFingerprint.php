<?php

namespace App\Support\Idempotency;

use App\Enums\IdempotencyOperation;
use App\Models\User;
use stdClass;

final class IdempotencyRequestFingerprint
{
    public function make(User $actor, IdempotencyOperation $operation, array $routeIdentity, array $bodyIdentity = []): string
    {
        $identity = [
            'operation' => $operation->value,
            'institution_id' => strtolower($actor->institution_id),
            'user_id' => strtolower($actor->id),
            'route' => (object) $routeIdentity,
            'body' => (object) $bodyIdentity,
        ];

        return hash('sha256', json_encode(
            $this->canonicalize($identity),
            JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION,
        ));
    }

    private function canonicalize(mixed $value): mixed
    {
        if ($value instanceof stdClass) {
            $properties = get_object_vars($value);
            ksort($properties, SORT_STRING);

            return (object) array_map($this->canonicalize(...), $properties);
        }

        if (is_array($value)) {
            if (! array_is_list($value)) {
                ksort($value, SORT_STRING);

                return (object) array_map($this->canonicalize(...), $value);
            }

            return array_map($this->canonicalize(...), $value);
        }

        return $value;
    }
}
