<?php

namespace App\Exceptions;

use RuntimeException;

/** A Parent release of a Topic result whose values the Student cannot see yet (docs/09 §27.4). */
class StudentResultNotReleasedException extends RuntimeException {}
