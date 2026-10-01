import 'teacher_submission.dart';

final _canonicalIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

enum TeacherOfficialScoreStatus {
  notApplicable('not_applicable'),
  ready('ready'),
  waitingForReplacement('waiting_for_replacement'),
  automaticCheckingPending('automatic_checking_pending'),
  waitingForTeacherReview('waiting_for_teacher_review'),
  noCompletedAttempt('no_completed_attempt');

  const TeacherOfficialScoreStatus(this.value);

  final String value;

  static TeacherOfficialScoreStatus? fromValue(String value) {
    for (final status in values) {
      if (status.value == value) {
        return status;
      }
    }
    return null;
  }
}

enum TeacherOfficialScoreSelectionPolicy {
  highestValidCompleted('highest_valid_completed'),
  validNormalBlitz('valid_normal_blitz'),
  approvedBlitzExceptionReplacement('approved_blitz_exception_replacement');

  const TeacherOfficialScoreSelectionPolicy(this.value);

  final String value;

  static TeacherOfficialScoreSelectionPolicy? fromValue(String value) {
    for (final policy in values) {
      if (policy.value == value) {
        return policy;
      }
    }
    return null;
  }
}

/// Whose official score to read: one Student of one Homework or Blitz.
class TeacherOfficialScoreTarget {
  /// Throws [ArgumentError] unless both ids are canonical UUIDs.
  factory TeacherOfficialScoreTarget({
    required String assessmentId,
    required String studentId,
    required TeacherSubmissionTaskType type,
  }) {
    if (!_canonicalIdPattern.hasMatch(assessmentId) ||
        !_canonicalIdPattern.hasMatch(studentId)) {
      throw ArgumentError('An official score target needs canonical ids.');
    }
    return TeacherOfficialScoreTarget._(
      assessmentId.toLowerCase(),
      studentId.toLowerCase(),
      type,
    );
  }

  factory TeacherOfficialScoreTarget.ofSubmission(
    TeacherSubmission submission,
  ) => TeacherOfficialScoreTarget(
    assessmentId: submission.assessmentId,
    studentId: submission.studentId,
    type: submission.taskType,
  );

  const TeacherOfficialScoreTarget._(
    this.assessmentId,
    this.studentId,
    this.type,
  );

  final String assessmentId;
  final String studentId;
  final TeacherSubmissionTaskType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherOfficialScoreTarget &&
          other.assessmentId == assessmentId &&
          other.studentId == studentId &&
          other.type == type;

  @override
  int get hashCode => Object.hash(assessmentId, studentId, type);
}

/// A Student's official task score as the server evaluates it now; every
/// result field is null unless [status] is ready.
class TeacherOfficialScore {
  const TeacherOfficialScore({
    required this.assessmentId,
    required this.assessmentType,
    required this.studentId,
    required this.status,
    required this.officialAttemptId,
    required this.attemptNumber,
    required this.normalizedScore,
    required this.selectionPolicy,
    required this.selectedAt,
  });

  final String assessmentId;
  final TeacherSubmissionTaskType assessmentType;
  final String studentId;
  final TeacherOfficialScoreStatus status;
  final String? officialAttemptId;
  final int? attemptNumber;
  final double? normalizedScore;
  final TeacherOfficialScoreSelectionPolicy? selectionPolicy;
  final DateTime? selectedAt;

  bool matches(TeacherOfficialScoreTarget target) =>
      assessmentId.toLowerCase() == target.assessmentId &&
      studentId.toLowerCase() == target.studentId &&
      assessmentType == target.type;
}
