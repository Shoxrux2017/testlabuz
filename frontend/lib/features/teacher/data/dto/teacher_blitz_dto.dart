import '../../domain/teacher_blitz.dart';
import 'teacher_dto_parse.dart';
import 'teacher_question_dto.dart';

class TeacherBlitzSummaryDto {
  const TeacherBlitzSummaryDto({
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

  factory TeacherBlitzSummaryDto.fromJson(
    Object? json, {
    String? expectedTopicId,
  }) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Blitz summary resource',
      keys: _blitzSummaryKeys,
    );
    final topicId = readTeacherCanonicalUuid(map, 'topic_id');
    if (expectedTopicId != null &&
        topicId.toLowerCase() != expectedTopicId.toLowerCase()) {
      throw const FormatException(
        'Teacher Blitz summary Topic does not match the request.',
      );
    }
    final questionCount = readTeacherInt(map, 'question_count');
    if (questionCount < 0) {
      throw const FormatException(
        'Teacher Blitz question count cannot be negative.',
      );
    }

    return TeacherBlitzSummaryDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      topicId: topicId,
      groupId: readTeacherCanonicalUuid(map, 'group_id'),
      title: readTeacherNonBlankString(map, 'title'),
      assignmentMode: TeacherBlitzAssignmentMode.parse(
        readTeacherNonBlankString(map, 'assignment_mode'),
      ),
      totalPossiblePoints: readTeacherNonNegativeNumber(
        map,
        'total_possible_points',
      ),
      questionCount: questionCount,
      durationSeconds: _readDurationSeconds(map),
      scheduledAt: readTeacherNullableUtcTimestamp(map, 'scheduled_at'),
      institutionTimezone: readTeacherNonBlankString(
        map,
        'institution_timezone',
      ),
      status: TeacherBlitzStatus.parse(
        readTeacherNonBlankString(map, 'status'),
      ),
      createdAt: readTeacherRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: readTeacherRequiredUtcTimestamp(map, 'updated_at'),
    );
  }

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

  TeacherBlitzSummary toDomain() {
    return TeacherBlitzSummary(
      id: id,
      topicId: topicId,
      groupId: groupId,
      title: title,
      assignmentMode: assignmentMode,
      totalPossiblePoints: totalPossiblePoints,
      questionCount: questionCount,
      durationSeconds: durationSeconds,
      scheduledAt: scheduledAt,
      institutionTimezone: institutionTimezone,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class TeacherBlitzAttemptPolicyDto {
  const TeacherBlitzAttemptPolicyDto({
    required this.normalAttempts,
    required this.maxAdditionalExceptionAttempts,
  });

  factory TeacherBlitzAttemptPolicyDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Blitz attempt policy',
      keys: const {'normal_attempts', 'max_additional_exception_attempts'},
    );
    final normalAttempts = readTeacherInt(map, 'normal_attempts');
    final maxAdditionalExceptionAttempts = readTeacherInt(
      map,
      'max_additional_exception_attempts',
    );
    if (normalAttempts != TeacherBlitzAttemptPolicy.requiredNormalAttempts ||
        maxAdditionalExceptionAttempts !=
            TeacherBlitzAttemptPolicy.requiredMaxAdditionalExceptionAttempts) {
      throw const FormatException(
        'Teacher Blitz attempt policy is not canonical.',
      );
    }
    return TeacherBlitzAttemptPolicyDto(
      normalAttempts: normalAttempts,
      maxAdditionalExceptionAttempts: maxAdditionalExceptionAttempts,
    );
  }

  final int normalAttempts;
  final int maxAdditionalExceptionAttempts;

  TeacherBlitzAttemptPolicy toDomain() {
    return TeacherBlitzAttemptPolicy(
      normalAttempts: normalAttempts,
      maxAdditionalExceptionAttempts: maxAdditionalExceptionAttempts,
    );
  }
}

class TeacherBlitzDto {
  TeacherBlitzDto({
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
    required List<TeacherQuestionDto> questions,
  }) : studentIds = List<String>.unmodifiable(studentIds),
       questions = List<TeacherQuestionDto>.unmodifiable(questions);

  factory TeacherBlitzDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Blitz resource',
      keys: _blitzKeys,
    );
    final assignmentMode = TeacherBlitzAssignmentMode.parse(
      readTeacherNonBlankString(map, 'assignment_mode'),
    );
    final studentIds = _readStudentIds(map['student_ids']);
    _validateRecipients(assignmentMode, studentIds);
    final durationSeconds = _readDurationSeconds(map);
    final scheduledAt = readTeacherNullableUtcTimestamp(map, 'scheduled_at');
    final status = TeacherBlitzStatus.parse(
      readTeacherNonBlankString(map, 'status'),
    );
    final timerStartModeSnapshot = _readTimerStartModeSnapshot(map);
    final activatedAt = readTeacherNullableUtcTimestamp(map, 'activated_at');
    final synchronizedEndsAt = readTeacherNullableUtcTimestamp(
      map,
      'synchronized_ends_at',
    );
    final closedAt = readTeacherNullableUtcTimestamp(map, 'closed_at');
    final archivedAt = readTeacherNullableUtcTimestamp(map, 'archived_at');
    _validateLifecycle(
      status: status,
      scheduledAt: scheduledAt,
      durationSeconds: durationSeconds,
      timerStartModeSnapshot: timerStartModeSnapshot,
      activatedAt: activatedAt,
      synchronizedEndsAt: synchronizedEndsAt,
      closedAt: closedAt,
      archivedAt: archivedAt,
    );

    return TeacherBlitzDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      topicId: readTeacherCanonicalUuid(map, 'topic_id'),
      groupId: readTeacherCanonicalUuid(map, 'group_id'),
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
      durationSeconds: durationSeconds,
      scheduledAt: scheduledAt,
      institutionTimezone: readTeacherNonBlankString(
        map,
        'institution_timezone',
      ),
      status: status,
      timerStartModeSnapshot: timerStartModeSnapshot,
      attemptPolicy: TeacherBlitzAttemptPolicyDto.fromJson(
        map['attempt_policy'],
      ),
      activatedAt: activatedAt,
      synchronizedEndsAt: synchronizedEndsAt,
      closedAt: closedAt,
      archivedAt: archivedAt,
      createdAt: readTeacherRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: readTeacherRequiredUtcTimestamp(map, 'updated_at'),
      questions: readTeacherQuestionList(
        map['questions'],
        resourceName: 'Teacher Blitz',
      ),
    );
  }

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
  final TeacherBlitzTimerStartMode? timerStartModeSnapshot;
  final TeacherBlitzAttemptPolicyDto attemptPolicy;
  final DateTime? activatedAt;
  final DateTime? synchronizedEndsAt;
  final DateTime? closedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TeacherQuestionDto> questions;

  TeacherBlitz toDomain() {
    return TeacherBlitz(
      id: id,
      topicId: topicId,
      groupId: groupId,
      title: title,
      description: description,
      studentInstructions: studentInstructions,
      assignmentMode: assignmentMode,
      studentIds: studentIds,
      totalPossiblePoints: totalPossiblePoints,
      durationSeconds: durationSeconds,
      scheduledAt: scheduledAt,
      institutionTimezone: institutionTimezone,
      status: status,
      timerStartModeSnapshot: timerStartModeSnapshot,
      attemptPolicy: attemptPolicy.toDomain(),
      activatedAt: activatedAt,
      synchronizedEndsAt: synchronizedEndsAt,
      closedAt: closedAt,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      questions: questions.map((question) => question.toDomain()).toList(),
    );
  }
}

class TeacherBlitzDetailDto {
  const TeacherBlitzDetailDto({required this.blitz});

  factory TeacherBlitzDetailDto.fromJson(Object? json) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Teacher Blitz detail envelope',
      keys: const {'data'},
    );
    return TeacherBlitzDetailDto(
      blitz: TeacherBlitzDto.fromJson(envelope['data']),
    );
  }

  final TeacherBlitzDto blitz;
}

int _readDurationSeconds(Map<String, Object?> map) {
  final durationSeconds = readTeacherInt(map, 'duration_seconds');
  if (durationSeconds < 1) {
    throw const FormatException('Teacher Blitz duration must be positive.');
  }
  return durationSeconds;
}

TeacherBlitzTimerStartMode? _readTimerStartModeSnapshot(
  Map<String, Object?> map,
) {
  final value = readTeacherNullableString(map, 'timer_start_mode_snapshot');
  return value == null ? null : TeacherBlitzTimerStartMode.parse(value);
}

List<String> _readStudentIds(Object? json) {
  if (json is! List || json.any((value) => value is! String)) {
    throw const FormatException(
      'Teacher Blitz student_ids must be an array of UUIDs.',
    );
  }
  final ids = <String>[];
  for (final value in json.cast<String>()) {
    if (!canonicalUuidPattern.hasMatch(value)) {
      throw const FormatException(
        'Teacher Blitz student_ids must contain canonical UUIDs.',
      );
    }
    ids.add(value);
  }
  if (ids.map((id) => id.toLowerCase()).toSet().length != ids.length) {
    throw const FormatException(
      'Teacher Blitz student_ids contains duplicates.',
    );
  }
  return List<String>.unmodifiable(ids);
}

void _validateRecipients(
  TeacherBlitzAssignmentMode assignmentMode,
  List<String> studentIds,
) {
  final valid = switch (assignmentMode) {
    TeacherBlitzAssignmentMode.group => studentIds.isEmpty,
    TeacherBlitzAssignmentMode.selectedStudents => studentIds.isNotEmpty,
  };
  if (!valid) {
    throw const FormatException(
      'Teacher Blitz assignment mode contradicts student_ids.',
    );
  }
}

void _validateLifecycle({
  required TeacherBlitzStatus status,
  required DateTime? scheduledAt,
  required int durationSeconds,
  required TeacherBlitzTimerStartMode? timerStartModeSnapshot,
  required DateTime? activatedAt,
  required DateTime? synchronizedEndsAt,
  required DateTime? closedAt,
  required DateTime? archivedAt,
}) {
  final neverActivated =
      timerStartModeSnapshot == null &&
      activatedAt == null &&
      synchronizedEndsAt == null &&
      closedAt == null;
  bool activatedTimer() => _hasActivatedTimer(
    durationSeconds: durationSeconds,
    timerStartModeSnapshot: timerStartModeSnapshot,
    activatedAt: activatedAt,
    synchronizedEndsAt: synchronizedEndsAt,
  );
  bool closedAfterActivation() =>
      closedAt != null && !closedAt.isBefore(activatedAt!);

  final valid = switch (status) {
    TeacherBlitzStatus.draft => neverActivated && archivedAt == null,
    TeacherBlitzStatus.scheduled =>
      scheduledAt != null && neverActivated && archivedAt == null,
    TeacherBlitzStatus.active =>
      activatedTimer() && closedAt == null && archivedAt == null,
    TeacherBlitzStatus.closed =>
      activatedTimer() && closedAfterActivation() && archivedAt == null,
    TeacherBlitzStatus.archived =>
      archivedAt != null &&
          (neverActivated ||
              (activatedTimer() &&
                  closedAfterActivation() &&
                  !archivedAt.isBefore(closedAt!))),
  };
  if (!valid) {
    throw const FormatException(
      'Teacher Blitz lifecycle and timer fields contradict its status.',
    );
  }
}

bool _hasActivatedTimer({
  required int durationSeconds,
  required TeacherBlitzTimerStartMode? timerStartModeSnapshot,
  required DateTime? activatedAt,
  required DateTime? synchronizedEndsAt,
}) {
  if (activatedAt == null) {
    return false;
  }
  return switch (timerStartModeSnapshot) {
    null => false,
    TeacherBlitzTimerStartMode.individual => synchronizedEndsAt == null,
    TeacherBlitzTimerStartMode.synchronized =>
      synchronizedEndsAt != null &&
          _isExactDuration(
            synchronizedEndsAt.difference(activatedAt),
            durationSeconds,
          ),
  };
}

// Compared through the difference so a huge duration cannot overflow Duration.
bool _isExactDuration(Duration elapsed, int durationSeconds) {
  return elapsed.inMicroseconds % Duration.microsecondsPerSecond == 0 &&
      elapsed.inSeconds == durationSeconds;
}

const _blitzSummaryKeys = <String>{
  'id',
  'topic_id',
  'group_id',
  'title',
  'assignment_mode',
  'total_possible_points',
  'question_count',
  'duration_seconds',
  'scheduled_at',
  'institution_timezone',
  'status',
  'created_at',
  'updated_at',
};

const _blitzKeys = <String>{
  'id',
  'topic_id',
  'group_id',
  'title',
  'description',
  'student_instructions',
  'assignment_mode',
  'student_ids',
  'total_possible_points',
  'duration_seconds',
  'scheduled_at',
  'institution_timezone',
  'status',
  'timer_start_mode_snapshot',
  'attempt_policy',
  'activated_at',
  'synchronized_ends_at',
  'closed_at',
  'archived_at',
  'created_at',
  'updated_at',
  'questions',
};
