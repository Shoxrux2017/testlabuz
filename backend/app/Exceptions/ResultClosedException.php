<?php

namespace App\Exceptions;

use RuntimeException;

/** A change to a closed Topic result, or to scoring the closure froze (docs/09 §25.11). */
class ResultClosedException extends RuntimeException {}
