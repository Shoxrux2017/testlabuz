<?php

namespace App\Enums;

/** Why a Student's official task score is or is not ready (docs/09 §24.1 Status). */
enum OfficialScoreStatus: string
{
    case NotApplicable = 'not_applicable';
    case Ready = 'ready';
    case WaitingForReplacement = 'waiting_for_replacement';
    case AutomaticCheckingPending = 'automatic_checking_pending';
    case WaitingForTeacherReview = 'waiting_for_teacher_review';
    case NoCompletedAttempt = 'no_completed_attempt';
}
