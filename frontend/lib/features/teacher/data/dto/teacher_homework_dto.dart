import '../../domain/teacher_homework.dart';
import 'teacher_dto_parse.dart';
import 'teacher_question_dto.dart';

class TeacherHomeworkSummaryDto {
  const TeacherHomeworkSummaryDto({
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

  factory TeacherHomeworkSummaryDto.fromJson(
    Object? json, {
    String? expectedTopicId,
  }) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Homework summary resource',
      keys: _homeworkSummaryKeys,
    );
    final topicId = readTeacherCanonicalUuid(map, 'topic_id');
    if (expectedTopicId != null &&
        topicId.toLowerCase() != expectedTopicId.toLowerCase()) {
      throw const FormatException(
        'Teacher Homework summary Topic does not match the request.',
      );
    }
    final questionCount = readTeacherInt(map, 'question_count');
    if (questionCount < 0) {
      throw const FormatException(
        'Teacher Homework question count cannot be negative.',
      );
    }

    return TeacherHomeworkSummaryDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      topicId: topicId,
      title: readTeacherNonBlankString(map, 'title'),
      assignmentMode: TeacherHomeworkAssignmentMode.parse(
        readTeacherNonBlankString(map, 'assignment_mode'),
      ),
      totalPossiblePoints: readTeacherNonNegativeNumber(
        map,
        'total_possible_points',
      ),
      questionCount: questionCount,
      deadlineAt: readTeacherNullableUtcTimestamp(map, 'deadline_at'),
      institutionTimezone: readTeacherNonBlankString(
        map,
        'institution_timezone',
      ),
      status: TeacherHomeworkStatus.parse(
        readTeacherNonBlankString(map, 'status'),
      ),
      createdAt: readTeacherRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: readTeacherRequiredUtcTimestamp(map, 'updated_at'),
    );
  }

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

  TeacherHomeworkSummary toDomain() {
    return TeacherHomeworkSummary(
      id: id,
      topicId: topicId,
      title: title,
      assignmentMode: assignmentMode,
      totalPossiblePoints: totalPossiblePoints,
      questionCount: questionCount,
      deadlineAt: deadlineAt,
      institutionTimezone: institutionTimezone,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class TeacherHomeworkAttemptPolicyDto {
  const TeacherHomeworkAttemptPolicyDto({
    required this.normalAttempts,
    required this.officialScorePolicy,
  });

  factory TeacherHomeworkAttemptPolicyDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Homework attempt policy',
      keys: const {'normal_attempts', 'official_score_policy'},
    );
    final normalAttempts = readTeacherInt(map, 'normal_attempts');
    final officialScorePolicy = readTeacherNonBlankString(
      map,
      'official_score_policy',
    );
    if (normalAttempts != TeacherHomeworkAttemptPolicy.requiredNormalAttempts ||
        officialScorePolicy !=
            TeacherHomeworkAttemptPolicy.requiredOfficialScorePolicy) {
      throw const FormatException(
        'Teacher Homework attempt policy is not canonical.',
      );
    }
    return TeacherHomeworkAttemptPolicyDto(
      normalAttempts: normalAttempts,
      officialScorePolicy: officialScorePolicy,
    );
  }

  final int normalAttempts;
  final String officialScorePolicy;

  TeacherHomeworkAttemptPolicy toDomain() {
    return TeacherHomeworkAttemptPolicy(
      normalAttempts: normalAttempts,
      officialScorePolicy: officialScorePolicy,
    );
  }
}

class TeacherHomeworkDto {
  TeacherHomeworkDto({
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
    required List<TeacherQuestionDto> questions,
  }) : studentIds = List<String>.unmodifiable(studentIds),
       questions = List<TeacherQuestionDto>.unmodifiable(questions);

  factory TeacherHomeworkDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Homework resource',
      keys: _homeworkKeys,
    );
    final assignmentMode = TeacherHomeworkAssignmentMode.parse(
      readTeacherNonBlankString(map, 'assignment_mode'),
    );
    final studentIds = _readStudentIds(map['student_ids']);
    _validateRecipients(assignmentMode, studentIds);
    final status = TeacherHomeworkStatus.parse(
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
    final questions = _readQuestions(map['questions']);

    return TeacherHomeworkDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      topicId: readTeacherCanonicalUuid(map, 'topic_id'),
      title: readTeacherNonBlankString(map, 'title'),
      description: readTeacherNullableString(map, 'description'),
      studentInstructions: readTeacherNonBlankString(
        map,
        'student_instructions',
      ),
      assignmentMode: assignmentMode,
      studentIds: studentIds,
      totalPossiblePoints: readTeacherNonNegativeNumber(
        map,
        'total_possible_points',
      ),
      deadlineAt: readTeacherNullableUtcTimestamp(map, 'deadline_at'),
      institutionTimezone: readTeacherNonBlankString(
        map,
        'institution_timezone',
      ),
      status: status,
      attemptPolicy: TeacherHomeworkAttemptPolicyDto.fromJson(
        map['attempt_policy'],
      ),
      activatedAt: activatedAt,
      closedAt: closedAt,
      archivedAt: archivedAt,
      createdAt: readTeacherRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: readTeacherRequiredUtcTimestamp(map, 'updated_at'),
      questions: questions,
    );
  }

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
  final TeacherHomeworkAttemptPolicyDto attemptPolicy;
  final DateTime? activatedAt;
  final DateTime? closedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TeacherQuestionDto> questions;

  TeacherHomework toDomain() {
    return TeacherHomework(
      id: id,
      topicId: topicId,
      title: title,
      description: description,
      studentInstructions: studentInstructions,
      assignmentMode: assignmentMode,
      studentIds: studentIds,
      totalPossiblePoints: totalPossiblePoints,
      deadlineAt: deadlineAt,
      institutionTimezone: institutionTimezone,
      status: status,
      attemptPolicy: attemptPolicy.toDomain(),
      activatedAt: activatedAt,
      closedAt: closedAt,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      questions: questions.map((question) => question.toDomain()).toList(),
    );
  }
}

class TeacherHomeworkDetailDto {
  const TeacherHomeworkDetailDto({required this.homework});

  factory TeacherHomeworkDetailDto.fromJson(Object? json) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Homework detail envelope',
      keys: const {'data'},
    );
    return TeacherHomeworkDetailDto(
      homework: TeacherHomeworkDto.fromJson(envelope['data']),
    );
  }

  final TeacherHomeworkDto homework;
}

List<String> _readStudentIds(Object? json) {
  if (json is! List || json.any((value) => value is! String)) {
    throw const FormatException(
      'Teacher Homework student_ids must be an array of UUIDs.',
    );
  }
  final ids = <String>[];
  for (final value in json.cast<String>()) {
    if (!canonicalUuidPattern.hasMatch(value)) {
      throw const FormatException(
        'Teacher Homework student_ids must contain canonical UUIDs.',
      );
    }
    ids.add(value);
  }
  if (ids.map((id) => id.toLowerCase()).toSet().length != ids.length) {
    throw const FormatException(
      'Teacher Homework student_ids contains duplicates.',
    );
  }
  return List<String>.unmodifiable(ids);
}

void _validateRecipients(
  TeacherHomeworkAssignmentMode assignmentMode,
  List<String> studentIds,
) {
  final valid = switch (assignmentMode) {
    TeacherHomeworkAssignmentMode.group => studentIds.isEmpty,
    TeacherHomeworkAssignmentMode.selectedStudents => studentIds.isNotEmpty,
  };
  if (!valid) {
    throw const FormatException(
      'Teacher Homework assignment mode contradicts student_ids.',
    );
  }
}

List<TeacherQuestionDto> _readQuestions(Object? json) {
  if (json is! List) {
    throw const FormatException('Teacher Homework questions must be an array.');
  }
  final questions = json
      .map(TeacherQuestionDto.fromJson)
      .toList(growable: false);
  if (questions.map((question) => question.id.toLowerCase()).toSet().length !=
      questions.length) {
    throw const FormatException(
      'Teacher Homework contains duplicate Question IDs.',
    );
  }
  for (var index = 0; index < questions.length; index += 1) {
    if (questions[index].position != index + 1) {
      throw const FormatException(
        'Teacher Homework Question positions are not canonical.',
      );
    }
  }
  return List<TeacherQuestionDto>.unmodifiable(questions);
}

void _validateLifecycle({
  required TeacherHomeworkStatus status,
  required DateTime? activatedAt,
  required DateTime? closedAt,
  required DateTime? archivedAt,
}) {
  final valid = switch (status) {
    TeacherHomeworkStatus.draft =>
      activatedAt == null && closedAt == null && archivedAt == null,
    TeacherHomeworkStatus.active =>
      activatedAt != null && closedAt == null && archivedAt == null,
    TeacherHomeworkStatus.closed =>
      activatedAt != null && closedAt != null && archivedAt == null,
    TeacherHomeworkStatus.archived =>
      archivedAt != null &&
          ((activatedAt == null && closedAt == null) ||
              (activatedAt != null && closedAt != null)),
  };
  if (!valid) {
    throw const FormatException(
      'Teacher Homework lifecycle timestamps contradict its status.',
    );
  }
}

const _homeworkSummaryKeys = <String>{
  'id',
  'topic_id',
  'title',
  'assignment_mode',
  'total_possible_points',
  'question_count',
  'deadline_at',
  'institution_timezone',
  'status',
  'created_at',
  'updated_at',
};

const _homeworkKeys = <String>{
  'id',
  'topic_id',
  'title',
  'description',
  'student_instructions',
  'assignment_mode',
  'student_ids',
  'total_possible_points',
  'deadline_at',
  'institution_timezone',
  'status',
  'attempt_policy',
  'activated_at',
  'closed_at',
  'archived_at',
  'created_at',
  'updated_at',
  'questions',
};
