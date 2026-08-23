import '../../domain/teacher_topic.dart';
import 'teacher_dto_parse.dart';
import 'teacher_group_dto.dart';

class TeacherTopicDto {
  const TeacherTopicDto({
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

  factory TeacherTopicDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Topic resource',
      keys: _topicKeys,
    );
    final status = TeacherTopicStatus.parse(
      readTeacherNonBlankString(map, 'status'),
    );
    final activatedAt = readTeacherNullableUtcTimestamp(map, 'activated_at');
    final closedAt = readTeacherNullableUtcTimestamp(map, 'closed_at');
    final archivedAt = readTeacherNullableUtcTimestamp(map, 'archived_at');
    _validateLifecycle(
      status: status,
      activatedAt: activatedAt,
      closedAt: closedAt,
      archivedAt: archivedAt,
    );

    return TeacherTopicDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      group: TeacherGroupDto.fromTopicGroupJson(map['group']),
      title: readTeacherNonBlankString(map, 'title'),
      description: readTeacherNullableString(map, 'description'),
      subject: readTeacherNonBlankString(map, 'subject'),
      studentInstructions: readTeacherNonBlankString(
        map,
        'student_instructions',
      ),
      lessonAt: readTeacherNullableUtcTimestamp(map, 'lesson_at'),
      status: status,
      activatedAt: activatedAt,
      closedAt: closedAt,
      archivedAt: archivedAt,
      createdAt: readTeacherRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: readTeacherRequiredUtcTimestamp(map, 'updated_at'),
    );
  }

  final String id;
  final TeacherGroupDto group;
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

  TeacherTopic toDomain() {
    return TeacherTopic(
      id: id,
      group: group.toDomain(),
      title: title,
      description: description,
      subject: subject,
      studentInstructions: studentInstructions,
      lessonAt: lessonAt,
      status: status,
      activatedAt: activatedAt,
      closedAt: closedAt,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

void _validateLifecycle({
  required TeacherTopicStatus status,
  required DateTime? activatedAt,
  required DateTime? closedAt,
  required DateTime? archivedAt,
}) {
  final valid = switch (status) {
    TeacherTopicStatus.draft =>
      activatedAt == null && closedAt == null && archivedAt == null,
    TeacherTopicStatus.active =>
      activatedAt != null && closedAt == null && archivedAt == null,
    TeacherTopicStatus.closed =>
      activatedAt != null && closedAt != null && archivedAt == null,
    TeacherTopicStatus.archived =>
      archivedAt != null &&
          ((activatedAt == null && closedAt == null) ||
              (activatedAt != null && closedAt != null)),
  };
  if (!valid) {
    throw const FormatException(
      'Teacher Topic lifecycle timestamps contradict its status.',
    );
  }
}

const _topicKeys = <String>{
  'id',
  'group',
  'title',
  'description',
  'subject',
  'student_instructions',
  'lesson_at',
  'status',
  'activated_at',
  'closed_at',
  'archived_at',
  'created_at',
  'updated_at',
};
