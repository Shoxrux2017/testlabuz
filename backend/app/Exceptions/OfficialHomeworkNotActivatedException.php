<?php

namespace App\Exceptions;

use RuntimeException;

/** An official Blitz activation while the official Homework is still a draft (S10-D8, docs/09 §19.1). */
class OfficialHomeworkNotActivatedException extends RuntimeException {}
