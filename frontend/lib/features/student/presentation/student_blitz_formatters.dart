import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/student_blitz_attempt_start_state.dart';
import '../application/student_blitz_submit_readiness.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';

/// `mm:ss` below one hour, `h:mm:ss` from one hour; never negative.
String formatStudentBlitzCountdown(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final rest = total % 60;
  final mmss = '${_two(minutes)}:${_two(rest)}';
  return hours == 0 ? mmss : '$hours:$mmss';
}

/// Worded time for screen readers, for example `4 minutes 32 seconds`.
String formatStudentBlitzDurationWords(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  return <String>[
    if (total >= 3600) _unit(total ~/ 3600, 'hour'),
    if (total % 3600 >= 60) _unit((total % 3600) ~/ 60, 'minute'),
    if (total % 60 > 0 || total == 0) _unit(total % 60, 'second'),
  ].join(' ');
}

String formatStudentBlitzDuration(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final parts = <String>[
    if (total >= 3600) '${total ~/ 3600} h',
    if (total % 3600 >= 60) '${(total % 3600) ~/ 60} min',
    if (total % 60 > 0 || total == 0) '${total % 60} sec',
  ];
  return parts.join(' ');
}

String studentBlitzTimerModeLabel(StudentBlitzTimerMode mode) => switch (mode) {
  StudentBlitzTimerMode.synchronized => 'Shared class timer',
  StudentBlitzTimerMode.individual => 'Individual timer',
};

/// Active-card Attempt path. A replacement is never a "second normal attempt".
String studentBlitzAttemptPathLabel(StudentBlitzAttemptSummary attempts) {
  if (attempts.normalUsed == 0) {
    return 'Not started';
  }
  if (attempts.replacementAttemptAvailable) {
    return 'Additional attempt available';
  }
  if (attempts.inProgressAttemptId != null) {
    return attempts.additionalExceptionGranted
        ? 'Additional attempt in progress'
        : 'In progress';
  }
  return 'Finished';
}

/// Server-snapshot timing for an active card; the card never ticks.
String? studentBlitzListTimingText(StudentActiveBlitzSummary blitz) {
  final attempts = blitz.attempts;
  final remaining = blitz.timing.remainingSeconds;
  final duration = formatStudentBlitzDuration(blitz.durationSeconds);
  if (attempts.replacementAttemptAvailable) {
    return 'Full $duration additional attempt starts when you start.';
  }
  if (attempts.inProgressAttemptId != null && remaining != null) {
    return 'Attempt time remaining at last refresh: '
        '${formatStudentBlitzDuration(remaining)}';
  }
  if (attempts.normalUsed == 0) {
    return blitz.timing.mode == StudentBlitzTimerMode.synchronized &&
            remaining != null
        ? 'Class time remaining at last refresh: '
              '${formatStudentBlitzDuration(remaining)}'
        : 'Full $duration starts when you start.';
  }
  return null;
}

String formatStudentBlitzPoints(double points) =>
    points == points.roundToDouble()
    ? points.toStringAsFixed(0)
    : points.toString();

String studentBlitzNormalAttemptLabel(StudentBlitzAttemptSummary attempts) {
  if (attempts.normalUsed == 0) {
    return 'Not started';
  }
  return attempts.inProgressAttemptId != null &&
          !attempts.additionalExceptionGranted
      ? 'In progress'
      : 'Used';
}

String studentBlitzAdditionalAttemptLabel(StudentBlitzAttemptSummary attempts) {
  if (!attempts.additionalExceptionGranted) {
    return 'None';
  }
  if (attempts.replacementAttemptAvailable) {
    return 'Approved and available';
  }
  return attempts.inProgressAttemptId != null
      ? 'Approved and in progress'
      : 'Approved and used';
}

String studentBlitzAttemptLabel(int attemptNumber) => attemptNumber == 2
    ? 'Additional attempt (Attempt 2)'
    : 'Attempt $attemptNumber';

String studentActiveBlitzFailureMessage(ApiFailure failure) =>
    switch (failure.kind) {
      ApiFailureKind.connection => 'Could not reach the server.',
      ApiFailureKind.timeout => 'The active Blitz request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected active Blitz response.',
      _ => 'Try again.',
    };

String studentBlitzDetailFailureMessage(ApiFailure failure) =>
    switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The Blitz request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected Blitz response.',
      _ => 'The Blitz could not be loaded. Try again.',
    };

String studentBlitzStartFailureMessage(ApiFailure failure) =>
    switch (failure.serverCode) {
      ApiErrorCodes.blitzNotActive => 'This Blitz is no longer active.',
      ApiErrorCodes.blitzTimeExpired => 'The Blitz time has expired.',
      ApiErrorCodes.attemptNotEditable =>
        'This Blitz attempt can no longer be resumed.',
      ApiErrorCodes.attemptsExhausted => 'No Blitz attempts remain.',
      ApiErrorCodes.assessmentNotAssigned =>
        'This Blitz is no longer assigned to you.',
      ApiErrorCodes.resourceNotFound => 'This Blitz is no longer available.',
      ApiErrorCodes.idempotencyKeyReused =>
        'The Blitz attempt could not be started safely.\n'
            'Refresh and try again.',
      ApiErrorCodes.businessConflict =>
        'The Blitz changed. Refresh and try again.',
      _ => 'The Blitz attempt could not be started. Refresh and try again.',
    };

String studentBlitzStartFeedbackMessage(StudentBlitzStartFeedback feedback) =>
    switch (feedback) {
      StudentBlitzStartFeedback.started => 'Blitz started.',
      StudentBlitzStartFeedback.resumed => 'Blitz resumed.',
      StudentBlitzStartFeedback.additionalStarted =>
        'Additional Blitz attempt started.',
      StudentBlitzStartFeedback.additionalAlreadyInProgress =>
        'Additional Blitz attempt is already in progress.',
    };

/// The finalized Attempt state; a checked Attempt shows no checking result.
String studentBlitzFinalizedStateLabel(StudentBlitzAttemptStatus status) =>
    switch (status) {
      StudentBlitzAttemptStatus.inProgress => 'In progress',
      StudentBlitzAttemptStatus.submitted => 'Submitted',
      StudentBlitzAttemptStatus.timedOutFinalized =>
        'Finalized at the deadline',
      StudentBlitzAttemptStatus.waitingForReview => 'Finalized',
      StudentBlitzAttemptStatus.checked => 'Finalized',
    };

String studentBlitzFinalizationReasonLabel(
  StudentBlitzAttemptFinalizationReason reason,
) => switch (reason) {
  StudentBlitzAttemptFinalizationReason.studentSubmit => 'Submitted by you',
  StudentBlitzAttemptFinalizationReason.timeout => 'Time expired',
  StudentBlitzAttemptFinalizationReason.taskClosed =>
    'The Teacher closed the Blitz',
};

String studentBlitzSubmitBlockerMessage(StudentBlitzSubmitBlocker blocker) =>
    switch (blocker) {
      StudentBlitzSubmitBlocker.attemptNotEditable =>
        'This attempt is not available for submission.',
      StudentBlitzSubmitBlocker.attemptStateRefreshing =>
        'Wait until the current attempt is confirmed.',
      StudentBlitzSubmitBlocker.localTimeExpired =>
        'The time has run out on this device. '
            'Wait for the server to confirm the attempt.',
      StudentBlitzSubmitBlocker.nonFileUnsavedChanges =>
        'Save or discard unsaved answer changes before submitting.',
      StudentBlitzSubmitBlocker.nonFileSaveInProgress =>
        'Wait for the current answer save to finish.',
      StudentBlitzSubmitBlocker.nonFileSaveUncertain =>
        'Check the unconfirmed answer save before submitting.',
      StudentBlitzSubmitBlocker.fileSelectionPending =>
        'Upload or discard the selected file before submitting.',
      StudentBlitzSubmitBlocker.fileUploadInProgress =>
        'Wait for the current file operation to finish.',
      StudentBlitzSubmitBlocker.fileUploadUncertain =>
        'Check the unconfirmed file upload before submitting.',
      StudentBlitzSubmitBlocker.operationBusy =>
        'Wait for the current submission step to finish.',
      StudentBlitzSubmitBlocker.localStateUnavailable =>
        'Check the current attempt to confirm the saved answers '
            'before submitting.',
    };

String _unit(int value, String unit) => '$value $unit${value == 1 ? '' : 's'}';

String _two(int value) => value.toString().padLeft(2, '0');
