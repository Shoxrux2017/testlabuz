<?php

namespace App\Support\Results;

/** What a Teacher result action did to one result; a bulk call counts the skipped ones (docs/09 §27.5). */
enum TopicResultActionOutcome
{
    case Done;
    case AlreadyDone;
    case NotReady;
}
