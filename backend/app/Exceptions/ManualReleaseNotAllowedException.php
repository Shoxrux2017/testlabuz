<?php

namespace App\Exceptions;

use RuntimeException;

/** A Teacher release of a Topic result while the current release mode is not manual Teacher release (docs/09 §27.3). */
class ManualReleaseNotAllowedException extends RuntimeException {}
