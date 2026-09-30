import '../../domain/student_result.dart';
import 'student_dto_parse.dart';

/// `{visible, normalized_score}`: a visible result carries a score in 0..100,
/// a hidden one carries null.
StudentAttemptResult readStudentAttemptResult(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student Attempt result',
    keys: const {'visible', 'normalized_score'},
  );
  final visible = map['visible'];
  if (visible is! bool) {
    throw const FormatException(
      'Student Attempt result visible must be a bool.',
    );
  }
  if (!visible) {
    if (map['normalized_score'] != null) {
      throw const FormatException('A hidden Student result has no score.');
    }
    return const StudentAttemptResult.hidden();
  }
  return StudentAttemptResult.visible(_readScore(map));
}

/// `score_visible` and `official_score` of a Student Homework: the official
/// score is present exactly when `score_visible` is true.
StudentOfficialScore? readStudentOfficialScore(Map<String, Object?> homework) {
  final visible = homework['score_visible'];
  if (visible is! bool) {
    throw const FormatException(
      'Student Homework score_visible must be a bool.',
    );
  }
  final json = homework['official_score'];
  if (visible != (json != null)) {
    throw const FormatException(
      'Student Homework score_visible must match official_score.',
    );
  }
  if (json == null) {
    return null;
  }
  final map = readExactStudentMap(
    json,
    context: 'Student Homework official score',
    keys: const {'normalized_score', 'attempt_number'},
  );
  final attemptNumber = readStudentInt(map, 'attempt_number');
  if (attemptNumber < 1 || attemptNumber > 3) {
    throw const FormatException(
      'Official Homework attempt number must be in 1..3.',
    );
  }
  return StudentOfficialScore(
    normalizedScore: _readScore(map),
    attemptNumber: attemptNumber,
  );
}

double _readScore(Map<String, Object?> map) {
  final score = readStudentNonNegativeNumber(map, 'normalized_score');
  if (score > 100) {
    throw const FormatException('normalized_score must be at most 100.');
  }
  return score;
}
