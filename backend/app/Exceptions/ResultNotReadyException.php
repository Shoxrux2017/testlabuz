<?php

namespace App\Exceptions;

use RuntimeException;

/** A Student release of a Topic result that is not an outcome yet or whose Student work is not finished (docs/09 §27.3). */
class ResultNotReadyException extends RuntimeException {}
