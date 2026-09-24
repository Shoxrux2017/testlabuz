import 'teacher_question.dart';

final canonicalTeacherBlitzIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isCanonicalTeacherBlitzId(String value) {
  return canonicalTeacherBlitzIdPattern.hasMatch(value);
}

enum TeacherBlitzStatus {
  draft('draft'),
  scheduled('scheduled'),
  active('active'),
  closed('closed'),
  archived('archived');

  const TeacherBlitzStatus(this.value);

  final String value;

  static TeacherBlitzStatus parse(String value) {
    return switch (value) {
      'draft' => TeacherBlitzStatus.draft,
      'scheduled' => TeacherBlitzStatus.scheduled,
      'active' => TeacherBlitzStatus.active,
      'closed' => TeacherBlitzStatus.closed,
      'archived' => TeacherBlitzStatus.archived,
      _ => throw const FormatException('Unsupported Teacher Blitz status.'),
    };
  }
}

// Kept separate from the Homework assignment mode even though the machine
// values match, so Blitz-specific behavior never couples to Homework types.
enum TeacherBlitzAssignmentMode {
  group('group'),
  selectedStudents('selected_students');

  const TeacherBlitzAssignmentMode(this.value);

  final String value;

  static TeacherBlitzAssignmentMode parse(String value) {
    return switch (value) {
      'group' => TeacherBlitzAssignmentMode.group,
      'selected_students' => TeacherBlitzAssignmentMode.selectedStudents,
      _ => throw const FormatException(
        'Unsupported Teacher Blitz assignment mode.',
      ),
    };
  }
}

enum TeacherBlitzTimerStartMode {
  synchronized('synchronized'),
  individual('individual');

  const TeacherBlitzTimerStartMode(this.value);

  final String value;

  static TeacherBlitzTimerStartMode parse(String value) {
    return switch (value) {
      'synchronized' => TeacherBlitzTimerStartMode.synchronized,
      'individual' => TeacherBlitzTimerStartMode.individual,
      _ => throw const FormatException(
        'Unsupported Teacher Blitz timer start mode.',
      ),
    };
  }
}

class TeacherBlitzSummary {
  const TeacherBlitzSummary({
    required this.id,
    required this.topicId,
    required this.groupId,
    required this.title,
    required this.assignmentMode,
    required this.totalPossiblePoints,
    required this.questionCount,
    required this.durationSeconds,
    required this.scheduledAt,
    required this.institutionTimezone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String topicId;
  final String groupId;
  final String title;
  final TeacherBlitzAssignmentMode assignmentMode;
  final double totalPossiblePoints;
  final int questionCount;
  final int durationSeconds;
  final DateTime? scheduledAt;
  final String institutionTimezone;
  final TeacherBlitzStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TeacherBlitzAttemptPolicy {
  const TeacherBlitzAttemptPolicy({
    required this.normalAttempts,
    required this.maxAdditionalExceptionAttempts,
  });

  static const requiredNormalAttempts = 1;
  static const requiredMaxAdditionalExceptionAttempts = 1;

  final int normalAttempts;
  final int maxAdditionalExceptionAttempts;
}

class TeacherBlitz {
  TeacherBlitz({
    required this.id,
    required this.topicId,
    required this.groupId,
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.assignmentMode,
    required List<String> studentIds,
    required this.totalPossiblePoints,
    required this.durationSeconds,
    required this.scheduledAt,
    required this.institutionTimezone,
    required this.status,
    required this.timerStartModeSnapshot,
    required this.attemptPolicy,
    required this.activatedAt,
    required this.synchronizedEndsAt,
    required this.closedAt,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    required List<TeacherQuestion> questions,
  }) : studentIds = List<String>.unmodifiable(studentIds),
       questions = List<TeacherQuestion>.unmodifiable(questions);

  final String id;
  final String topicId;
  final String groupId;
  final String title;
  final String? description;
  final String studentInstructions;
  final TeacherBlitzAssignmentMode assignmentMode;
  final List<String> studentIds;
  final double totalPossiblePoints;
  final int durationSeconds;
  final DateTime? scheduledAt;
  final String institutionTimezone;
  final TeacherBlitzStatus status;

  /// Null until activation; the backend snapshot is authoritative afterwards.
  final TeacherBlitzTimerStartMode? timerStartModeSnapshot;
  final TeacherBlitzAttemptPolicy attemptPolicy;
  final DateTime? activatedAt;
  final DateTime? synchronizedEndsAt;
  final DateTime? closedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TeacherQuestion> questions;
}
