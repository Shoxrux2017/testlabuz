import 'student_question.dart';

final _canonicalStudentHomeworkIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isCanonicalStudentHomeworkId(String value) =>
    _canonicalStudentHomeworkIdPattern.hasMatch(value);

bool isCanonicalStudentAttemptId(String value) =>
    _canonicalStudentHomeworkIdPattern.hasMatch(value);

enum StudentHomeworkStatus {
  active('active'),
  closed('closed'),
  archived('archived');

  const StudentHomeworkStatus(this.apiValue);
  final String apiValue;

  static StudentHomeworkStatus parse(String value) => switch (value) {
    'active' => active,
    'closed' => closed,
    'archived' => archived,
    _ => throw const FormatException('Unsupported Student Homework status.'),
  };
}

enum StudentHomeworkMyStatus {
  notStarted('not_started'),
  inProgress('in_progress'),
  submitted('submitted'),
  waitingForReview('waiting_for_teacher_review'),
  checked('checked');

  const StudentHomeworkMyStatus(this.apiValue);
  final String apiValue;

  static StudentHomeworkMyStatus parse(String value) => switch (value) {
    'not_started' => notStarted,
    'in_progress' => inProgress,
    'submitted' => submitted,
    'waiting_for_teacher_review' => waitingForReview,
    'checked' => checked,
    _ => throw const FormatException(
      'Unsupported Student Homework read status.',
    ),
  };
}

class StudentHomeworkTopicSummary {
  const StudentHomeworkTopicSummary({required this.id, required this.title});

  final String id;
  final String title;
}

class StudentHomeworkAttemptSummary {
  const StudentHomeworkAttemptSummary({
    required this.allowed,
    required this.used,
    required this.remaining,
    required this.officialScorePolicy,
    this.inProgressAttempt,
  });

  final int allowed;
  final int used;
  final int remaining;
  final String officialScorePolicy;
  final StudentInProgressHomeworkAttempt? inProgressAttempt;
}

class StudentInProgressHomeworkAttempt {
  const StudentInProgressHomeworkAttempt({
    required this.id,
    required this.attemptNumber,
    required this.startedAt,
  });

  final String id;
  final int attemptNumber;
  final DateTime startedAt;
}

class StudentHomeworkSummary {
  const StudentHomeworkSummary({
    required this.id,
    required this.topic,
    required this.title,
    required this.status,
    required this.deadlineAt,
    required this.attempts,
    required this.myStatus,
    required this.scoreVisible,
  });

  final String id;
  final StudentHomeworkTopicSummary topic;
  final String title;
  final StudentHomeworkStatus status;
  final DateTime? deadlineAt;
  final StudentHomeworkAttemptSummary attempts;
  final StudentHomeworkMyStatus myStatus;
  final bool scoreVisible;
}

class StudentHomeworkDetail {
  StudentHomeworkDetail({
    required this.id,
    required this.topic,
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.status,
    required this.deadlineAt,
    required this.totalPossiblePoints,
    required this.attempts,
    required this.myStatus,
    required this.scoreVisible,
    required List<StudentQuestion> questions,
  }) : questions = List<StudentQuestion>.unmodifiable(questions);

  final String id;
  final StudentHomeworkTopicSummary topic;
  final String title;
  final String? description;
  final String studentInstructions;
  final StudentHomeworkStatus status;
  final DateTime? deadlineAt;
  final double totalPossiblePoints;
  final StudentHomeworkAttemptSummary attempts;
  final StudentHomeworkMyStatus myStatus;
  final bool scoreVisible;
  final List<StudentQuestion> questions;
}
