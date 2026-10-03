final canonicalTeacherStudentIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isCanonicalTeacherStudentId(String value) {
  return canonicalTeacherStudentIdPattern.hasMatch(value);
}

/// The seven Topic result statuses (docs/09 §25.3).
enum TeacherTopicResultStatus {
  waitingForHomework('waiting_for_homework'),
  waitingForBlitz('waiting_for_blitz'),
  waitingForTeacherReview('waiting_for_teacher_review'),
  waitingForSettings('waiting_for_settings'),
  calculated('calculated'),
  notCompleted('not_completed'),
  closed('closed');

  const TeacherTopicResultStatus(this.value);

  final String value;

  static TeacherTopicResultStatus parse(String value) {
    return _parseValue(values, value, (status) => status.value, 'status');
  }
}

enum TeacherTopicResultOutcome {
  calculated('calculated'),
  notCompleted('not_completed');

  const TeacherTopicResultOutcome(this.value);

  final String value;

  static TeacherTopicResultOutcome parse(String value) {
    return _parseValue(values, value, (outcome) => outcome.value, 'outcome');
  }
}

enum TeacherTopicResultMissingComponent {
  homework('homework'),
  blitz('blitz'),
  both('both');

  const TeacherTopicResultMissingComponent(this.value);

  final String value;

  static TeacherTopicResultMissingComponent parse(String value) {
    return _parseValue(
      values,
      value,
      (component) => component.value,
      'missing component',
    );
  }
}

/// The state of one side (Homework or Blitz) of a Topic result.
enum TeacherTopicResultSideState {
  ready('ready'),
  waitingForTeacherReview('waiting_for_teacher_review'),
  checking('checking'),
  notActivated('not_activated'),
  open('open'),
  missing('missing'),
  notDesignated('not_designated');

  const TeacherTopicResultSideState(this.value);

  final String value;

  static TeacherTopicResultSideState parse(String value) {
    return _parseValue(values, value, (state) => state.value, 'side state');
  }
}

enum TeacherTopicResultConsistency {
  consistent('consistent'),
  inconsistent('inconsistent');

  const TeacherTopicResultConsistency(this.value);

  final String value;

  static TeacherTopicResultConsistency parse(String value) {
    return _parseValue(
      values,
      value,
      (consistency) => consistency.value,
      'consistency',
    );
  }
}

enum TeacherTopicResultMethod {
  average('average'),
  blitz('blitz');

  const TeacherTopicResultMethod(this.value);

  final String value;

  static TeacherTopicResultMethod parse(String value) {
    return _parseValue(values, value, (method) => method.value, 'method');
  }
}

/// The five understanding category codes; only `not_completed` is not
/// numeric.
enum TeacherTopicResultCategoryCode {
  understoodWell('understood_well'),
  partiallyUnderstood('partially_understood'),
  needsRevision('needs_revision'),
  needsTeacherSupport('needs_teacher_support'),
  notCompleted('not_completed');

  const TeacherTopicResultCategoryCode(this.value);

  final String value;

  bool get isNumeric => this != notCompleted;

  static TeacherTopicResultCategoryCode parse(String value) {
    return _parseValue(values, value, (code) => code.value, 'category');
  }
}

enum TeacherStudentResultReleaseMode {
  automatic('automatic'),
  manualTeacher('manual_teacher');

  const TeacherStudentResultReleaseMode(this.value);

  final String value;

  static TeacherStudentResultReleaseMode parse(String value) {
    return _parseValue(
      values,
      value,
      (mode) => mode.value,
      'Student release mode',
    );
  }
}

enum TeacherParentResultReleaseMode {
  withStudent('with_student'),
  manualTeacher('manual_teacher'),
  hidden('hidden');

  const TeacherParentResultReleaseMode(this.value);

  final String value;

  static TeacherParentResultReleaseMode parse(String value) {
    return _parseValue(
      values,
      value,
      (mode) => mode.value,
      'Parent release mode',
    );
  }
}

enum TeacherTopicResultClosureReason {
  teacher('teacher'),
  topicArchived('topic_archived');

  const TeacherTopicResultClosureReason(this.value);

  final String value;

  static TeacherTopicResultClosureReason parse(String value) {
    return _parseValue(
      values,
      value,
      (reason) => reason.value,
      'closure reason',
    );
  }
}

T _parseValue<T>(
  List<T> values,
  String value,
  String Function(T item) valueOf,
  String name,
) {
  for (final item in values) {
    if (valueOf(item) == value) {
      return item;
    }
  }
  throw FormatException('Unsupported Topic result $name.');
}

/// One side of a Topic result; the Attempt and score exist only when ready.
class TeacherTopicResultSide {
  const TeacherTopicResultSide({
    required this.assessmentId,
    required this.state,
    required this.officialAttemptId,
    required this.attemptNumber,
    required this.score,
  });

  /// Null only for a Blitz that is not designated.
  final String? assessmentId;
  final TeacherTopicResultSideState state;
  final String? officialAttemptId;
  final int? attemptNumber;
  final double? score;
}

class TeacherTopicResultCategory {
  const TeacherTopicResultCategory({required this.code, required this.label});

  final TeacherTopicResultCategoryCode code;

  /// The server's label; the client never renames a category.
  final String label;
}

/// Whether the Student and the Parents see the values now, and which release
/// the Teacher can still perform.
class TeacherTopicResultVisibility {
  const TeacherTopicResultVisibility({
    required this.studentReleaseMode,
    required this.studentVisible,
    required this.studentReleasedAt,
    required this.canReleaseToStudent,
    required this.parentReleaseMode,
    required this.parentVisible,
    required this.parentReleasedAt,
    required this.canReleaseToParent,
  });

  /// Null while the Institution has not configured the mode.
  final TeacherStudentResultReleaseMode? studentReleaseMode;
  final bool studentVisible;
  final DateTime? studentReleasedAt;
  final bool canReleaseToStudent;
  final TeacherParentResultReleaseMode? parentReleaseMode;
  final bool parentVisible;
  final DateTime? parentReleasedAt;
  final bool canReleaseToParent;
}

/// One cohort Student's Topic result as the Teacher sees it (docs/09 §25.4).
class TeacherTopicResult {
  const TeacherTopicResult({
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.closedOutcome,
    required this.closedAt,
    required this.missingComponent,
    required this.homework,
    required this.blitz,
    required this.scoreDifference,
    required this.acceptableDifference,
    required this.consistency,
    required this.method,
    required this.finalScore,
    required this.categoryScore,
    required this.category,
    required this.teacherComment,
    required this.visibility,
    required this.canClose,
  });

  final String studentId;
  final String studentName;
  final TeacherTopicResultStatus status;
  final TeacherTopicResultOutcome? closedOutcome;
  final DateTime? closedAt;
  final TeacherTopicResultMissingComponent? missingComponent;
  final TeacherTopicResultSide homework;
  final TeacherTopicResultSide blitz;
  final double? scoreDifference;
  final double? acceptableDifference;
  final TeacherTopicResultConsistency? consistency;
  final TeacherTopicResultMethod? method;
  final double? finalScore;
  final int? categoryScore;
  final TeacherTopicResultCategory? category;
  final String? teacherComment;
  final TeacherTopicResultVisibility visibility;

  /// The server's closure permission; the client never recomputes it.
  final bool canClose;

  /// Calculated, open or closed.
  bool get isCalculated =>
      status == TeacherTopicResultStatus.calculated ||
      closedOutcome == TeacherTopicResultOutcome.calculated;

  /// Not completed, open or closed.
  bool get isNotCompleted =>
      status == TeacherTopicResultStatus.notCompleted ||
      closedOutcome == TeacherTopicResultOutcome.notCompleted;
}

class TeacherTopicResultActor {
  const TeacherTopicResultActor({required this.id, required this.fullName});

  final String id;
  final String fullName;
}

/// One Topic result with who changed it (docs/09 §25.6).
class TeacherTopicResultDetail {
  const TeacherTopicResultDetail({
    required this.result,
    required this.commentUpdatedAt,
    required this.commentUpdatedBy,
    required this.studentReleasedBy,
    required this.parentReleasedBy,
    required this.closedBy,
    required this.closureReason,
  });

  final TeacherTopicResult result;
  final DateTime? commentUpdatedAt;
  final TeacherTopicResultActor? commentUpdatedBy;
  final TeacherTopicResultActor? studentReleasedBy;
  final TeacherTopicResultActor? parentReleasedBy;
  final TeacherTopicResultActor? closedBy;
  final TeacherTopicResultClosureReason? closureReason;
}
