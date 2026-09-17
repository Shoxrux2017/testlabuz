<?php

namespace App\Exceptions;

use RuntimeException;

class IdempotencyKeyReusedException extends RuntimeException {}
