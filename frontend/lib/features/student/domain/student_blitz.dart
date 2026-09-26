import 'student_topic.dart';

bool isCanonicalStudentBlitzId(String value) =>
    canonicalStudentTopicIdPattern.hasMatch(value);

/// Successful Student Blitz resources are always Active; any other lifecycle
/// arrives as a conflict, never as parseable detail.
enum StudentBlitzStatus {
  active('active');

  const StudentBlitzStatus(this.apiValue);
  final String apiValue;

  static StudentBlitzStatus parse(String value) => switch (value) {
    'active' => active,
    _ => throw const FormatException('Unsupported Student Blitz status.'),
  };
}

enum StudentBlitzTimerMode {
  synchronized('synchronized'),
  individual('individual');

  const StudentBlitzTimerMode(this.apiValue);
  final String apiValue;

  static StudentBlitzTimerMode parse(String value) => switch (value) {
    'synchronized' => synchronized,
    'individual' => individual,
    _ => throw const FormatException('Unsupported Blitz timer mode.'),
  };
}

class StudentBlitzTopicSummary {
  const StudentBlitzTopicSummary({required this.id, required this.title});

  final String id;
  final String title;
}

class StudentBlitzAttemptSummary {
  const StudentBlitzAttemptSummary({
    required this.normalAttempts,
    required this.normalUsed,
    required this.inProgressAttemptId,
    required this.additionalExceptionGranted,
    required this.replacementAttemptAvailable,
  });

  final int normalAttempts;
  final int normalUsed;
  final String? inProgressAttemptId;
  final bool additionalExceptionGranted;
  final bool replacementAttemptAvailable;

  /// The latest Attempt is terminal and no replacement can be started.
  bool get isFinished =>
      normalUsed == 1 &&
      inProgressAttemptId == null &&
      !replacementAttemptAvailable;
}

/// One server timing snapshot; `remainingSeconds` is the countdown anchor.
class StudentBlitzTiming {
  const StudentBlitzTiming({
    required this.mode,
    required this.serverNow,
    required this.synchronizedEndsAt,
    required this.deadlineAt,
    required this.remainingSeconds,
  });

  final StudentBlitzTimerMode mode;
  final DateTime serverNow;
  final DateTime? synchronizedEndsAt;
  final DateTime? deadlineAt;
  final int? remainingSeconds;
}

class StudentActiveBlitzSummary {
  const StudentActiveBlitzSummary({
    required this.id,
    required this.topic,
    required this.title,
    required this.status,
    required this.durationSeconds,
    required this.timing,
    required this.attempts,
  });

  final String id;
  final StudentBlitzTopicSummary topic;
  final String title;
  final StudentBlitzStatus status;
  final int durationSeconds;
  final StudentBlitzTiming timing;
  final StudentBlitzAttemptSummary attempts;
}

/// Pre-Start Blitz detail. It deliberately has no Question or answer field.
class StudentBlitzDetail {
  const StudentBlitzDetail({
    required this.id,
    required this.topic,
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.status,
    required this.durationSeconds,
    required this.totalPossiblePoints,
    required this.timing,
    required this.attempts,
  });

  final String id;
  final StudentBlitzTopicSummary topic;
  final String title;
  final String? description;
  final String studentInstructions;
  final StudentBlitzStatus status;
  final int durationSeconds;
  final double totalPossiblePoints;
  final StudentBlitzTiming timing;
  final StudentBlitzAttemptSummary attempts;
}

/// Identity of one server timing snapshot that anchors a live countdown.
///
/// A newer snapshot re-anchors; a rebuild with the same identity does not.
class StudentBlitzCountdownAnchor {
  const StudentBlitzCountdownAnchor({
    required this.subjectId,
    required this.deadlineAt,
    required this.serverNow,
    required this.remainingSeconds,
  });

  /// The Blitz (pre-Start) or Attempt (execution) the countdown belongs to.
  final String subjectId;
  final DateTime deadlineAt;
  final DateTime serverNow;
  final int remainingSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentBlitzCountdownAnchor &&
          other.subjectId == subjectId &&
          other.deadlineAt.isAtSameMomentAs(deadlineAt) &&
          other.serverNow.isAtSameMomentAs(serverNow) &&
          other.remainingSeconds == remainingSeconds;

  @override
  int get hashCode => Object.hash(
    subjectId,
    deadlineAt.millisecondsSinceEpoch,
    serverNow.millisecondsSinceEpoch,
    remainingSeconds,
  );
}

/// The one execution path the server projection currently offers.
enum StudentBlitzExecutionAction { startNormal, resume, startReplacement }

StudentBlitzExecutionAction? studentBlitzExecutionAction(
  StudentBlitzAttemptSummary attempts,
) {
  if (attempts.inProgressAttemptId != null) {
    return StudentBlitzExecutionAction.resume;
  }
  if (attempts.replacementAttemptAvailable) {
    return StudentBlitzExecutionAction.startReplacement;
  }
  if (attempts.normalUsed == 0) {
    return StudentBlitzExecutionAction.startNormal;
  }
  return null;
}
