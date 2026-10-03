<?php

namespace App\Exceptions;

use RuntimeException;

/** A Teacher close of a Topic result that is not terminal or whose Student work is not finished (docs/09 §25.8). */
class ResultNotReadyForClosureException extends RuntimeException {}
