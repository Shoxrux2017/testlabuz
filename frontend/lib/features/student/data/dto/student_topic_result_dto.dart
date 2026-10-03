import '../../domain/student_topic_result.dart';
import 'student_dto_parse.dart';

/// `GET /student/topics/{topic}/result` data (docs/09 §29.5). The status fields
/// are always present; every value is null unless `visible`, and a visible
/// result carries exactly the values of its outcome.
class StudentTopicResultDto {
  const StudentTopicResultDto(this._result);

  factory StudentTopicResultDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Topic result',
      keys: _keys,
    );
    final status = StudentTopicResultStatus.parse(
      readStudentNonBlankString(map, 'result_status'),
    );
    final closedOutcome = _readOptional(
      map,
      'closed_outcome',
      StudentTopicResultOutcome.parse,
    );
    if ((status == StudentTopicResultStatus.closed) !=
        (closedOutcome != null)) {
      throw const FormatException(
        'A Topic result has a closed outcome exactly when it is closed.',
      );
    }
    final notCompleted =
        status == StudentTopicResultStatus.notCompleted ||
        closedOutcome == StudentTopicResultOutcome.notCompleted;
    final missingComponent = _readOptional(
      map,
      'missing_component',
      StudentTopicResultMissingComponent.parse,
    );
    if (notCompleted != (missingComponent != null)) {
      throw const FormatException(
        'A Topic result names its missing component exactly when it is '
        'Not completed.',
      );
    }
    final visible = readStudentBool(map, 'visible');
    final result = StudentTopicResult(
      topicId: readStudentCanonicalUuid(map, 'topic_id'),
      status: status,
      closedOutcome: closedOutcome,
      missingComponent: missingComponent,
      visible: visible,
      homeworkScore: _readScore(map, 'homework_score'),
      blitzScore: _readScore(map, 'blitz_score'),
      finalScore: _readScore(map, 'final_score'),
      method: _readOptional(
        map,
        'calculation_method',
        StudentTopicResultMethod.parse,
      ),
      category: _readCategory(map['category']),
      teacherComment: _readComment(map),
    );
    if (!visible) {
      _requireHiddenValues(result);
    } else if (!result.isOutcome) {
      throw const FormatException(
        'Only a calculated, Not completed or closed Topic result is visible.',
      );
    } else if (notCompleted) {
      _requireNotCompletedValues(result);
    } else {
      _requireCalculatedValues(result);
    }

    return StudentTopicResultDto(result);
  }

  final StudentTopicResult _result;

  StudentTopicResult toDomain() => _result;

  static const _keys = {
    'topic_id',
    'result_status',
    'closed_outcome',
    'missing_component',
    'visible',
    'homework_score',
    'blitz_score',
    'final_score',
    'calculation_method',
    'category',
    'teacher_comment',
  };
}

void _requireHiddenValues(StudentTopicResult result) {
  if (result.homeworkScore != null ||
      result.blitzScore != null ||
      result.finalScore != null ||
      result.method != null ||
      result.category != null ||
      result.teacherComment != null) {
    throw const FormatException('A hidden Topic result has no values.');
  }
}

void _requireCalculatedValues(StudentTopicResult result) {
  final category = result.category;
  if (result.homeworkScore == null ||
      result.blitzScore == null ||
      result.finalScore == null ||
      result.method == null ||
      category == null ||
      category.code == StudentTopicResultCategoryCode.notCompleted) {
    throw const FormatException(
      'A visible calculated Topic result has both scores, the final score, '
      'the method and a numeric category.',
    );
  }
}

void _requireNotCompletedValues(StudentTopicResult result) {
  final missing = result.missingComponent!;
  final homeworkMissing =
      missing == StudentTopicResultMissingComponent.homework ||
      missing == StudentTopicResultMissingComponent.both;
  final blitzMissing =
      missing == StudentTopicResultMissingComponent.blitz ||
      missing == StudentTopicResultMissingComponent.both;
  if (result.finalScore != null ||
      result.method != null ||
      result.category?.code != StudentTopicResultCategoryCode.notCompleted ||
      (homeworkMissing && result.homeworkScore != null) ||
      (blitzMissing && result.blitzScore != null)) {
    throw const FormatException(
      'A visible Not completed Topic result has no final score or method, '
      'the Not completed category and no score for a missing side.',
    );
  }
}

T? _readOptional<T>(
  Map<String, Object?> map,
  String key,
  T Function(String value) parse,
) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Student Topic result $key must be a string.');
  }
  return parse(value);
}

double? _readScore(Map<String, Object?> map, String key) {
  if (map[key] == null) {
    return null;
  }
  final score = readStudentNonNegativeNumber(map, key);
  if (score > 100) {
    throw FormatException('Student Topic result $key must be at most 100.');
  }
  return score;
}

StudentTopicResultCategory? _readCategory(Object? json) {
  if (json == null) {
    return null;
  }
  final map = readExactStudentMap(
    json,
    context: 'Student Topic result category',
    keys: const {'code', 'label'},
  );
  return StudentTopicResultCategory(
    code: StudentTopicResultCategoryCode.parse(
      readStudentNonBlankString(map, 'code'),
    ),
    label: readStudentNonBlankString(map, 'label'),
  );
}

String? _readComment(Map<String, Object?> map) {
  if (map['teacher_comment'] == null) {
    return null;
  }
  return readStudentNonBlankString(map, 'teacher_comment');
}
