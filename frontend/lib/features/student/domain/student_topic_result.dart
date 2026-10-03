/// The Student's own Topic result (docs/09 §29.5): the status is always known,
/// the values only when the server marks the result visible.
enum StudentTopicResultStatus {
  waitingForHomework('waiting_for_homework'),
  waitingForBlitz('waiting_for_blitz'),
  waitingForTeacherReview('waiting_for_teacher_review'),
  waitingForSettings('waiting_for_settings'),
  calculated('calculated'),
  notCompleted('not_completed'),
  closed('closed');

  const StudentTopicResultStatus(this.value);

  final String value;

  static StudentTopicResultStatus parse(String value) {
    for (final status in values) {
      if (status.value == value) {
        return status;
      }
    }
    throw const FormatException('Unsupported Student Topic result status.');
  }
}

enum StudentTopicResultOutcome {
  calculated('calculated'),
  notCompleted('not_completed');

  const StudentTopicResultOutcome(this.value);

  final String value;

  static StudentTopicResultOutcome parse(String value) {
    return switch (value) {
      'calculated' => StudentTopicResultOutcome.calculated,
      'not_completed' => StudentTopicResultOutcome.notCompleted,
      _ => throw const FormatException(
        'Unsupported Student Topic result outcome.',
      ),
    };
  }
}

enum StudentTopicResultMissingComponent {
  homework('homework'),
  blitz('blitz'),
  both('both');

  const StudentTopicResultMissingComponent(this.value);

  final String value;

  static StudentTopicResultMissingComponent parse(String value) {
    return switch (value) {
      'homework' => StudentTopicResultMissingComponent.homework,
      'blitz' => StudentTopicResultMissingComponent.blitz,
      'both' => StudentTopicResultMissingComponent.both,
      _ => throw const FormatException(
        'Unsupported Student Topic result missing component.',
      ),
    };
  }
}

enum StudentTopicResultMethod {
  average('average'),
  blitz('blitz');

  const StudentTopicResultMethod(this.value);

  final String value;

  static StudentTopicResultMethod parse(String value) {
    return switch (value) {
      'average' => StudentTopicResultMethod.average,
      'blitz' => StudentTopicResultMethod.blitz,
      _ => throw const FormatException(
        'Unsupported Student Topic result calculation method.',
      ),
    };
  }
}

enum StudentTopicResultCategoryCode {
  understoodWell('understood_well'),
  partiallyUnderstood('partially_understood'),
  needsRevision('needs_revision'),
  needsTeacherSupport('needs_teacher_support'),
  notCompleted('not_completed');

  const StudentTopicResultCategoryCode(this.value);

  final String value;

  static StudentTopicResultCategoryCode parse(String value) {
    for (final code in values) {
      if (code.value == value) {
        return code;
      }
    }
    throw const FormatException('Unsupported Student Topic result category.');
  }
}

/// The understanding category with the label the server provides.
class StudentTopicResultCategory {
  const StudentTopicResultCategory({required this.code, required this.label});

  final StudentTopicResultCategoryCode code;
  final String label;
}

class StudentTopicResult {
  const StudentTopicResult({
    required this.topicId,
    required this.status,
    required this.closedOutcome,
    required this.missingComponent,
    required this.visible,
    required this.homeworkScore,
    required this.blitzScore,
    required this.finalScore,
    required this.method,
    required this.category,
    required this.teacherComment,
  });

  final String topicId;
  final StudentTopicResultStatus status;
  final StudentTopicResultOutcome? closedOutcome;
  final StudentTopicResultMissingComponent? missingComponent;
  final bool visible;
  final double? homeworkScore;
  final double? blitzScore;
  final double? finalScore;
  final StudentTopicResultMethod? method;
  final StudentTopicResultCategory? category;
  final String? teacherComment;

  /// A calculated or Not completed outcome, open or closed: values exist, and
  /// the work-finished window and the release decide whether they are shown.
  bool get isOutcome =>
      status == StudentTopicResultStatus.calculated ||
      status == StudentTopicResultStatus.notCompleted ||
      status == StudentTopicResultStatus.closed;
}
