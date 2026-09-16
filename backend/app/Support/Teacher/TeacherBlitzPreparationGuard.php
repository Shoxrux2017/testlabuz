<?php

namespace App\Support\Teacher;

use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskClosedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\BlitzTask;
use App\Models\Topic;

final class TeacherBlitzPreparationGuard
{
    public function ensureEditable(BlitzTask $blitz, Topic $topic): void
    {
        if ($blitz->status === BlitzStatus::Closed) {
            throw new TaskClosedException;
        }

        if ($blitz->status === BlitzStatus::Archived) {
            throw new TaskArchivedException;
        }

        if ($blitz->status === BlitzStatus::Active) {
            throw new BusinessConflictException;
        }

        if (! in_array($topic->status, [TopicStatus::Draft, TopicStatus::Active], true)) {
            throw new TopicNotEditableException;
        }
    }
}
