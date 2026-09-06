import 'teacher_question.dart';

final canonicalTeacherHomeworkIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isCanonicalTeacherHomeworkId(String value) {
  return canonicalTeacherHomeworkIdPattern.hasMatch(value);
}

enum TeacherHomeworkStatus {
  draft('draft'),
  active('active'),
  closed('closed'),
  archived('archived');

  const TeacherHomeworkStatus(this.value);

  final String value;

  static TeacherHomeworkStatus parse(String value) {
    return switch (value) {
      'draft' => TeacherHomeworkStatus.draft,
      'active' => TeacherHomeworkStatus.active,
      'closed' => TeacherHomeworkStatus.closed,
      'archived' => TeacherHomeworkStatus.archived,
      _ => throw const FormatException('Unsupported Teacher Homework status.'),
    };
  }
}

enum TeacherHomeworkAssignmentMode {
  group('group'),
  selectedStudents('selected_students');

  const TeacherHomeworkAssignmentMode(this.value);

  final String value;

  static TeacherHomeworkAssignmentMode parse(String value) {
    return switch (value) {
      'group' => TeacherHomeworkAssignmentMode.group,
      'selected_students' => TeacherHomeworkAssignmentMode.selectedStudents,
      _ => throw const FormatException(
        'Unsupported Teacher Homework assignment mode.',
      ),
    };
  }
}

class TeacherHomeworkSummary {
  const TeacherHomeworkSummary({
    required this.id,
    required this.topicId,
    required this.title,
    required this.assignmentMode,
    required this.totalPossiblePoints,
    required this.questionCount,
    required this.deadlineAt,
    required this.institutionTimezone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String topicId;
  final String title;
  final TeacherHomeworkAssignmentMode assignmentMode;
  final double totalPossiblePoints;
  final int questionCount;
  final DateTime? deadlineAt;
  final String institutionTimezone;
  final TeacherHomeworkStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TeacherHomeworkAttemptPolicy {
  const TeacherHomeworkAttemptPolicy({
    required this.normalAttempts,
    required this.officialScorePolicy,
  });

  static const requiredNormalAttempts = 3;
  static const requiredOfficialScorePolicy = 'highest_valid_completed';

  final int normalAttempts;
  final String officialScorePolicy;
}

class TeacherHomework {
  TeacherHomework({
    required this.id,
    required this.topicId,
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.assignmentMode,
    required List<String> studentIds,
    required this.totalPossiblePoints,
    required this.deadlineAt,
    required this.institutionTimezone,
    required this.status,
    required this.attemptPolicy,
    required this.activatedAt,
    required this.closedAt,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    required List<TeacherQuestion> questions,
  }) : studentIds = List<String>.unmodifiable(studentIds),
       questions = List<TeacherQuestion>.unmodifiable(questions);

  final String id;
  final String topicId;
  final String title;
  final String? description;
  final String studentInstructions;
  final TeacherHomeworkAssignmentMode assignmentMode;
  final List<String> studentIds;
  final double totalPossiblePoints;
  final DateTime? deadlineAt;
  final String institutionTimezone;
  final TeacherHomeworkStatus status;
  final TeacherHomeworkAttemptPolicy attemptPolicy;
  final DateTime? activatedAt;
  final DateTime? closedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TeacherQuestion> questions;
}
