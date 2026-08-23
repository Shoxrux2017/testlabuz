import 'teacher_group.dart';

enum TeacherTopicStatus {
  draft('draft'),
  active('active'),
  closed('closed'),
  archived('archived');

  const TeacherTopicStatus(this.value);

  final String value;

  static TeacherTopicStatus parse(String value) {
    return switch (value) {
      'draft' => TeacherTopicStatus.draft,
      'active' => TeacherTopicStatus.active,
      'closed' => TeacherTopicStatus.closed,
      'archived' => TeacherTopicStatus.archived,
      _ => throw const FormatException('Unsupported Teacher Topic status.'),
    };
  }
}

class TeacherTopic {
  const TeacherTopic({
    required this.id,
    required this.group,
    required this.title,
    required this.description,
    required this.subject,
    required this.studentInstructions,
    required this.lessonAt,
    required this.status,
    required this.activatedAt,
    required this.closedAt,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final TeacherGroupSummary group;
  final String title;
  final String? description;
  final String subject;
  final String studentInstructions;
  final DateTime? lessonAt;
  final TeacherTopicStatus status;
  final DateTime? activatedAt;
  final DateTime? closedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
