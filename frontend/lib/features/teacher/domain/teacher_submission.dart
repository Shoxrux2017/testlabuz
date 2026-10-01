enum TeacherSubmissionTaskType {
  homework('homework'),
  blitz('blitz');

  const TeacherSubmissionTaskType(this.value);

  final String value;

  static TeacherSubmissionTaskType? fromValue(String value) {
    for (final type in values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}

/// The terminal Attempt statuses a review queue item can have.
enum TeacherSubmissionStatus {
  submitted('submitted'),
  timedOutFinalized('timed_out_finalized'),
  waitingForTeacherReview('waiting_for_teacher_review'),
  checked('checked');

  const TeacherSubmissionStatus(this.value);

  final String value;

  bool get isAutomaticCheckingPending =>
      this == submitted || this == timedOutFinalized;

  static TeacherSubmissionStatus? fromValue(String value) {
    for (final status in values) {
      if (status.value == value) {
        return status;
      }
    }
    return null;
  }
}

enum TeacherSubmissionFinalizationReason {
  studentSubmit('student_submit'),
  timeoutAutoSubmit('timeout_auto_submit'),
  taskClosedAutoFinalize('task_closed_auto_finalize'),
  homeworkDeadlineAutoSubmit('homework_deadline_auto_submit');

  const TeacherSubmissionFinalizationReason(this.value);

  final String value;

  static TeacherSubmissionFinalizationReason? fromValue(String value) {
    for (final reason in values) {
      if (reason.value == value) {
        return reason;
      }
    }
    return null;
  }
}

/// One terminal Attempt in the Teacher review queue (`S09-DOC-001` §10.2).
class TeacherSubmission {
  const TeacherSubmission({
    required this.id,
    required this.assessmentId,
    required this.taskType,
    required this.taskTitle,
    required this.official,
    required this.topicId,
    required this.topicTitle,
    required this.groupId,
    required this.groupName,
    required this.studentId,
    required this.studentName,
    required this.attemptNumber,
    required this.status,
    required this.officialScoreEligible,
    required this.finalizationReason,
    required this.finalizedAt,
    required this.waitingAnswers,
    required this.reviewedAnswers,
    required this.reviewDueAt,
    required this.reviewOverdue,
    required this.earnedPoints,
    required this.possiblePoints,
    required this.normalizedScore,
  });

  final String id;
  final String assessmentId;
  final TeacherSubmissionTaskType taskType;
  final String taskTitle;

  /// The Attempt belongs to the Topic's official task and still counts.
  final bool official;
  final String topicId;
  final String topicTitle;
  final String groupId;
  final String groupName;
  final String studentId;
  final String studentName;
  final int attemptNumber;
  final TeacherSubmissionStatus status;

  /// False for an invalidated Blitz attempt #1.
  final bool officialScoreEligible;
  final TeacherSubmissionFinalizationReason finalizationReason;
  final DateTime finalizedAt;
  final int waitingAnswers;
  final int reviewedAnswers;

  /// The Homework review deadline; always null for Blitz.
  final DateTime? reviewDueAt;
  final bool reviewOverdue;

  /// Null unless [status] is checked.
  final double? earnedPoints;
  final double possiblePoints;

  /// Null unless [status] is checked.
  final double? normalizedScore;
}
