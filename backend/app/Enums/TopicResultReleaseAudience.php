<?php

namespace App\Enums;

/** Whom a Teacher releases a Topic result to (docs/09 §27.3-27.4). */
enum TopicResultReleaseAudience: string
{
    case Student = 'student';
    case Parent = 'parent';
}
