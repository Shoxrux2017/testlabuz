import '../../domain/teacher_official_score.dart';
import '../../domain/teacher_submission.dart';
import 'teacher_dto_parse.dart';

/// `GET /teacher/assessments/{a}/students/{s}/official-score` data, parsed
/// strictly (`S09-DOC-001` §14).
class TeacherOfficialScoreDto {
  const TeacherOfficialScoreDto._(this._score);

  factory TeacherOfficialScoreDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher official score',
      keys: const {
        'assessment_id',
        'assessment_type',
        'student_id',
        'status',
        'official_attempt_id',
        'attempt_number',
        'normalized_score',
        'selection_policy_code',
        'selected_at',
      },
    );
    final type = _readEnum(
      map,
      'assessment_type',
      TeacherSubmissionTaskType.fromValue,
    );
    final status = _readEnum(
      map,
      'status',
      TeacherOfficialScoreStatus.fromValue,
    );
    final attemptId = map['official_attempt_id'] == null
        ? null
        : readTeacherCanonicalUuid(map, 'official_attempt_id');
    final attemptNumber = map['attempt_number'] == null
        ? null
        : readTeacherInt(map, 'attempt_number');
    final normalizedScore = _readNullableScore(map, 'normalized_score');
    final policy = map['selection_policy_code'] == null
        ? null
        : _readEnum(
            map,
            'selection_policy_code',
            TeacherOfficialScoreSelectionPolicy.fromValue,
          );
    final selectedAt = readTeacherNullableUtcTimestamp(map, 'selected_at');

    final results = [
      attemptId,
      attemptNumber,
      normalizedScore,
      policy,
      selectedAt,
    ];
    final ready = status == TeacherOfficialScoreStatus.ready;
    if (ready
        ? results.contains(null)
        : results.any((field) => field != null)) {
      throw const FormatException(
        'Official score results must be set exactly when it is ready.',
      );
    }
    if (status == TeacherOfficialScoreStatus.waitingForReplacement &&
        type != TeacherSubmissionTaskType.blitz) {
      throw const FormatException('Only a Blitz waits for a replacement.');
    }
    if (ready) {
      final consistent = switch (policy!) {
        TeacherOfficialScoreSelectionPolicy.highestValidCompleted =>
          type == TeacherSubmissionTaskType.homework && attemptNumber! >= 1,
        TeacherOfficialScoreSelectionPolicy.validNormalBlitz =>
          type == TeacherSubmissionTaskType.blitz && attemptNumber == 1,
        TeacherOfficialScoreSelectionPolicy.approvedBlitzExceptionReplacement =>
          type == TeacherSubmissionTaskType.blitz && attemptNumber == 2,
      };
      if (!consistent) {
        throw const FormatException(
          'Official score policy does not match its task or Attempt.',
        );
      }
    }

    return TeacherOfficialScoreDto._(
      TeacherOfficialScore(
        assessmentId: readTeacherCanonicalUuid(map, 'assessment_id'),
        assessmentType: type,
        studentId: readTeacherCanonicalUuid(map, 'student_id'),
        status: status,
        officialAttemptId: attemptId,
        attemptNumber: attemptNumber,
        normalizedScore: normalizedScore,
        selectionPolicy: policy,
        selectedAt: selectedAt,
      ),
    );
  }

  final TeacherOfficialScore _score;

  TeacherOfficialScore toDomain() => _score;
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

double? _readNullableScore(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    throw FormatException('$key must be a number from 0 to 100.');
  }
  return value.toDouble();
}
