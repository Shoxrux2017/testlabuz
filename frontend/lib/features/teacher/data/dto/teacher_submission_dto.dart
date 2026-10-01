import '../../domain/teacher_submission.dart';
import '../../domain/teacher_submission_list.dart';
import '../../domain/teacher_submission_list_query.dart';
import 'teacher_dto_parse.dart';
import 'teacher_list_envelope_dto.dart';
import 'teacher_question_dto.dart';

/// A strictly parsed review queue item (`S09-DOC-001` §10.2).
class TeacherSubmissionDto {
  const TeacherSubmissionDto._(this._submission);

  factory TeacherSubmissionDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher submission',
      keys: const {
        'id',
        'assessment',
        'official',
        'topic',
        'group',
        'student',
        'attempt_number',
        'status',
        'official_score_eligible',
        'finalization_reason',
        'finalized_at',
        'review',
        'review_due_at',
        'review_overdue',
        'score',
      },
    );
    final assessment = readExactTeacherMap(
      map['assessment'],
      context: 'Teacher submission assessment',
      keys: const {'id', 'type', 'title'},
    );
    final topic = readExactTeacherMap(
      map['topic'],
      context: 'Teacher submission topic',
      keys: const {'id', 'title'},
    );
    final group = readExactTeacherMap(
      map['group'],
      context: 'Teacher submission group',
      keys: const {'id', 'name'},
    );
    final student = readExactTeacherMap(
      map['student'],
      context: 'Teacher submission student',
      keys: const {'id', 'full_name'},
    );
    final review = readExactTeacherMap(
      map['review'],
      context: 'Teacher submission review',
      keys: const {'waiting_answers', 'reviewed_answers'},
    );
    final score = readExactTeacherMap(
      map['score'],
      context: 'Teacher submission score',
      keys: const {'earned_points', 'possible_points', 'normalized_score'},
    );

    final taskType = _readEnum(
      assessment,
      'type',
      TeacherSubmissionTaskType.fromValue,
    );
    final status = _readEnum(map, 'status', TeacherSubmissionStatus.fromValue);
    final reason = _readEnum(
      map,
      'finalization_reason',
      TeacherSubmissionFinalizationReason.fromValue,
    );
    final official = _readBool(map, 'official');
    final eligible = _readBool(map, 'official_score_eligible');
    final attemptNumber = readTeacherInt(map, 'attempt_number');
    final waiting = readTeacherInt(review, 'waiting_answers');
    final reviewed = readTeacherInt(review, 'reviewed_answers');
    final reviewDueAt = readTeacherNullableUtcTimestamp(map, 'review_due_at');
    final overdue = _readBool(map, 'review_overdue');
    final possible = readTeacherNonNegativeNumber(score, 'possible_points');
    final earned = _readNullableNonNegativeNumber(score, 'earned_points');
    final normalized = _readNullableNonNegativeNumber(
      score,
      'normalized_score',
    );
    final checked = status == TeacherSubmissionStatus.checked;

    if (attemptNumber < 1 || waiting < 0 || reviewed < 0) {
      throw const FormatException('Teacher submission counts are invalid.');
    }
    if (checked != (earned != null) || checked != (normalized != null)) {
      throw const FormatException(
        'Teacher submission score must exist exactly when it is checked.',
      );
    }
    if ((normalized != null && normalized > 100) ||
        (earned != null && earned > possible)) {
      throw const FormatException('Teacher submission score is out of range.');
    }
    if (taskType == TeacherSubmissionTaskType.blitz && reviewDueAt != null) {
      throw const FormatException('A Blitz submission has no review deadline.');
    }
    if (overdue &&
        (status != TeacherSubmissionStatus.waitingForTeacherReview ||
            reviewDueAt == null)) {
      throw const FormatException(
        'Only a waiting submission with a review deadline can be overdue.',
      );
    }
    if (official && !eligible) {
      throw const FormatException(
        'An official submission must be eligible for the official score.',
      );
    }

    return TeacherSubmissionDto._(
      TeacherSubmission(
        id: readTeacherCanonicalUuid(map, 'id'),
        assessmentId: readTeacherCanonicalUuid(assessment, 'id'),
        taskType: taskType,
        taskTitle: readTeacherNonBlankString(assessment, 'title'),
        official: official,
        topicId: readTeacherCanonicalUuid(topic, 'id'),
        topicTitle: readTeacherNonBlankString(topic, 'title'),
        groupId: readTeacherCanonicalUuid(group, 'id'),
        groupName: readTeacherNonBlankString(group, 'name'),
        studentId: readTeacherCanonicalUuid(student, 'id'),
        studentName: readTeacherNonBlankString(student, 'full_name'),
        attemptNumber: attemptNumber,
        status: status,
        officialScoreEligible: eligible,
        finalizationReason: reason,
        finalizedAt: readTeacherRequiredUtcTimestamp(map, 'finalized_at'),
        waitingAnswers: waiting,
        reviewedAnswers: reviewed,
        reviewDueAt: reviewDueAt,
        reviewOverdue: overdue,
        earnedPoints: earned,
        possiblePoints: possible,
        normalizedScore: normalized,
      ),
    );
  }

  final TeacherSubmission _submission;

  String get id => _submission.id;

  TeacherSubmission toDomain() => _submission;
}

class TeacherSubmissionListDto {
  const TeacherSubmissionListDto({
    required this.items,
    required this.pagination,
  });

  factory TeacherSubmissionListDto.fromJson(
    Object? json, {
    required TeacherSubmissionListQuery requestedQuery,
  }) {
    final envelope = TeacherListEnvelopeDto<TeacherSubmissionDto>.fromJson(
      json,
      requestedPage: requestedQuery.page,
      requestedPerPage: requestedQuery.perPage,
      resourceName: 'Teacher submission',
      readRow: TeacherSubmissionDto.fromJson,
      readId: (submission) => submission.id,
    );
    return TeacherSubmissionListDto(
      items: envelope.rows,
      pagination: envelope.pagination,
    );
  }

  final List<TeacherSubmissionDto> items;
  final TeacherListPaginationDto pagination;

  TeacherSubmissionList toDomain() {
    return TeacherSubmissionList(
      items: items.map((submission) => submission.toDomain()).toList(),
      pagination: pagination.toDomain(),
    );
  }
}

T _readEnum<T>(
  Map<String, Object?> map,
  String key,
  T? Function(String value) fromValue,
) {
  final value = map[key];
  final parsed = value is String ? fromValue(value) : null;
  if (parsed == null) {
    throw FormatException('$key has an unknown value.');
  }
  return parsed;
}

bool _readBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a boolean.');
}

double? _readNullableNonNegativeNumber(Map<String, Object?> map, String key) {
  return map[key] == null ? null : readTeacherNonNegativeNumber(map, key);
}
