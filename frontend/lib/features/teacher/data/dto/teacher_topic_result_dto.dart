import '../../domain/teacher_topic_result.dart';
import 'teacher_dto_parse.dart';

/// One Topic result item (docs/09 §25.4). The result is rejected unless its
/// status, side states, comparison values, category and visibility agree.
class TeacherTopicResultDto {
  const TeacherTopicResultDto._(this._result);

  factory TeacherTopicResultDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Topic result',
      keys: itemKeys,
    );
    return TeacherTopicResultDto._(_readResult(map));
  }

  final TeacherTopicResult _result;

  TeacherTopicResult toDomain() => _result;

  static const itemKeys = {
    'student',
    'result_status',
    'closed_outcome',
    'closed_at',
    'missing_component',
    'homework',
    'blitz',
    'score_difference',
    'acceptable_difference',
    'consistency',
    'calculation_method',
    'final_score',
    'category_score',
    'category',
    'teacher_comment',
    'visibility',
    'can_close',
  };
}

/// One Topic result with its actors and closure reason (docs/09 §25.6).
class TeacherTopicResultDetailDto {
  const TeacherTopicResultDetailDto._(this._detail);

  factory TeacherTopicResultDetailDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Topic result detail',
      keys: const {...TeacherTopicResultDto.itemKeys, ..._detailKeys},
    );
    final result = _readResult(map);
    final closed = result.status == TeacherTopicResultStatus.closed;
    final closureReason = _readOptional(
      map,
      'closure_reason',
      TeacherTopicResultClosureReason.parse,
    );
    final closedBy = _readActor(map['closed_by']);
    if (closed != (closureReason != null) || (!closed && closedBy != null)) {
      throw const FormatException(
        'A Topic result has a closure reason exactly when it is closed, and '
        'an open result has no closing actor.',
      );
    }

    return TeacherTopicResultDetailDto._(
      TeacherTopicResultDetail(
        result: result,
        commentUpdatedAt: readTeacherNullableUtcTimestamp(
          map,
          'teacher_comment_updated_at',
        ),
        commentUpdatedBy: _readActor(map['teacher_comment_updated_by']),
        studentReleasedBy: _readActor(map['student_released_by']),
        parentReleasedBy: _readActor(map['parent_released_by']),
        closedBy: closedBy,
        closureReason: closureReason,
      ),
    );
  }

  final TeacherTopicResultDetail _detail;

  TeacherTopicResultDetail toDomain() => _detail;

  static const _detailKeys = {
    'teacher_comment_updated_at',
    'teacher_comment_updated_by',
    'student_released_by',
    'parent_released_by',
    'closed_by',
    'closure_reason',
  };
}

TeacherTopicResult _readResult(Map<String, Object?> map) {
  final student = readExactTeacherMap(
    map['student'],
    context: 'Teacher Topic result Student',
    keys: const {'id', 'full_name'},
  );
  final status = TeacherTopicResultStatus.parse(
    readTeacherNonBlankString(map, 'result_status'),
  );
  final closed = status == TeacherTopicResultStatus.closed;
  final closedOutcome = _readOptional(
    map,
    'closed_outcome',
    TeacherTopicResultOutcome.parse,
  );
  final closedAt = readTeacherNullableUtcTimestamp(map, 'closed_at');
  if (closed != (closedOutcome != null) || closed != (closedAt != null)) {
    throw const FormatException(
      'A Topic result has a closed outcome and time exactly when it is '
      'closed.',
    );
  }

  final result = TeacherTopicResult(
    studentId: readTeacherCanonicalUuid(student, 'id'),
    studentName: readTeacherNonBlankString(student, 'full_name'),
    status: status,
    closedOutcome: closedOutcome,
    closedAt: closedAt,
    missingComponent: _readOptional(
      map,
      'missing_component',
      TeacherTopicResultMissingComponent.parse,
    ),
    homework: _readSide(map['homework'], isHomework: true),
    blitz: _readSide(map['blitz'], isHomework: false),
    scoreDifference: _readScore(map, 'score_difference'),
    acceptableDifference: _readScore(map, 'acceptable_difference'),
    consistency: _readOptional(
      map,
      'consistency',
      TeacherTopicResultConsistency.parse,
    ),
    method: _readOptional(
      map,
      'calculation_method',
      TeacherTopicResultMethod.parse,
    ),
    finalScore: _readScore(map, 'final_score'),
    categoryScore: _readCategoryScore(map),
    category: _readCategory(map['category']),
    teacherComment: map['teacher_comment'] == null
        ? null
        : readTeacherNonBlankString(map, 'teacher_comment'),
    visibility: _readVisibility(map['visibility']),
    canClose: _readBool(map, 'can_close'),
  );
  // A result is Not completed exactly because some side is missing.
  final missingComponent = result.missingComponent;
  if (result.isNotCompleted != (missingComponent != null) ||
      missingComponent != _missingSides(result.homework, result.blitz)) {
    throw const FormatException(
      'A Topic result names its missing sides exactly when it is Not '
      'completed.',
    );
  }
  if (result.isCalculated) {
    _requireCalculatedValues(result);
  } else {
    _requireNoCalculatedValues(result);
  }
  _requireVisibilityAndClosure(result);

  return result;
}

TeacherTopicResultMissingComponent? _missingSides(
  TeacherTopicResultSide homework,
  TeacherTopicResultSide blitz,
) {
  final homeworkMissing = homework.state == TeacherTopicResultSideState.missing;
  final blitzMissing = blitz.state == TeacherTopicResultSideState.missing;
  return switch ((homeworkMissing, blitzMissing)) {
    (true, true) => TeacherTopicResultMissingComponent.both,
    (true, false) => TeacherTopicResultMissingComponent.homework,
    (false, true) => TeacherTopicResultMissingComponent.blitz,
    (false, false) => null,
  };
}

TeacherTopicResultSide _readSide(Object? json, {required bool isHomework}) {
  final name = isHomework ? 'Homework' : 'Blitz';
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Topic result $name side',
    keys: const {
      'assessment_id',
      'state',
      'official_attempt_id',
      'attempt_number',
      'score',
    },
  );
  final state = TeacherTopicResultSideState.parse(
    readTeacherNonBlankString(map, 'state'),
  );
  final notDesignated = state == TeacherTopicResultSideState.notDesignated;
  if (isHomework && notDesignated) {
    throw const FormatException('The official Homework is always designated.');
  }
  final assessmentId = map['assessment_id'] == null
      ? null
      : readTeacherCanonicalUuid(map, 'assessment_id');
  if (notDesignated != (assessmentId == null)) {
    throw FormatException(
      'The $name side has an assessment exactly when it is designated.',
    );
  }

  final attemptId = map['official_attempt_id'] == null
      ? null
      : readTeacherCanonicalUuid(map, 'official_attempt_id');
  final attemptNumber = map['attempt_number'] == null
      ? null
      : readTeacherInt(map, 'attempt_number');
  final score = _readScore(map, 'score');
  final ready = state == TeacherTopicResultSideState.ready;
  final values = [attemptId, attemptNumber, score];
  if (ready ? values.contains(null) : values.any((value) => value != null)) {
    throw FormatException(
      'The $name side has its official Attempt and score exactly when ready.',
    );
  }
  // Three Homework Attempts; a Blitz has its normal Attempt and at most one
  // exception replacement.
  if (attemptNumber != null &&
      (attemptNumber < 1 || attemptNumber > (isHomework ? 3 : 2))) {
    throw FormatException('The $name official Attempt number is invalid.');
  }

  return TeacherTopicResultSide(
    assessmentId: assessmentId,
    state: state,
    officialAttemptId: attemptId,
    attemptNumber: attemptNumber,
    score: score,
  );
}

void _requireCalculatedValues(TeacherTopicResult result) {
  final consistency = result.consistency;
  final method = result.method;
  final category = result.category;
  if (result.homework.state != TeacherTopicResultSideState.ready ||
      result.blitz.state != TeacherTopicResultSideState.ready ||
      result.scoreDifference == null ||
      result.acceptableDifference == null ||
      consistency == null ||
      method == null ||
      result.finalScore == null ||
      result.categoryScore == null ||
      category == null ||
      !category.code.isNumeric) {
    throw const FormatException(
      'A calculated Topic result has both sides ready, the comparison, the '
      'final score and a numeric category.',
    );
  }
  final usesAverage = method == TeacherTopicResultMethod.average;
  if (usesAverage !=
      (consistency == TeacherTopicResultConsistency.consistent)) {
    throw const FormatException(
      'A consistent result uses the average and an inconsistent result the '
      'Blitz score.',
    );
  }
}

void _requireNoCalculatedValues(TeacherTopicResult result) {
  final category = result.category;
  if (result.scoreDifference != null ||
      result.acceptableDifference != null ||
      result.consistency != null ||
      result.method != null ||
      result.finalScore != null ||
      result.categoryScore != null ||
      (result.isNotCompleted
          ? category?.code != TeacherTopicResultCategoryCode.notCompleted
          : category != null)) {
    throw const FormatException(
      'Only a calculated Topic result has a comparison and a final score; a '
      'Not completed result has the Not completed category.',
    );
  }
}

void _requireVisibilityAndClosure(TeacherTopicResult result) {
  final outcome =
      result.status == TeacherTopicResultStatus.calculated ||
      result.status == TeacherTopicResultStatus.notCompleted ||
      result.status == TeacherTopicResultStatus.closed;
  final visibility = result.visibility;
  if (!outcome && (visibility.studentVisible || visibility.parentVisible)) {
    throw const FormatException(
      'Only a calculated, Not completed or closed Topic result is visible.',
    );
  }
  if (result.canClose &&
      result.status != TeacherTopicResultStatus.calculated &&
      result.status != TeacherTopicResultStatus.notCompleted) {
    throw const FormatException(
      'Only an open calculated or Not completed Topic result can be closed.',
    );
  }
}

TeacherTopicResultVisibility _readVisibility(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Topic result visibility',
    keys: const {
      'student_release_mode',
      'student_visible',
      'student_released_at',
      'can_release_to_student',
      'parent_release_mode',
      'parent_visible',
      'parent_released_at',
      'can_release_to_parent',
    },
  );
  return TeacherTopicResultVisibility(
    studentReleaseMode: _readOptional(
      map,
      'student_release_mode',
      TeacherStudentResultReleaseMode.parse,
    ),
    studentVisible: _readBool(map, 'student_visible'),
    studentReleasedAt: readTeacherNullableUtcTimestamp(
      map,
      'student_released_at',
    ),
    canReleaseToStudent: _readBool(map, 'can_release_to_student'),
    parentReleaseMode: _readOptional(
      map,
      'parent_release_mode',
      TeacherParentResultReleaseMode.parse,
    ),
    parentVisible: _readBool(map, 'parent_visible'),
    parentReleasedAt: readTeacherNullableUtcTimestamp(
      map,
      'parent_released_at',
    ),
    canReleaseToParent: _readBool(map, 'can_release_to_parent'),
  );
}

TeacherTopicResultCategory? _readCategory(Object? json) {
  if (json == null) {
    return null;
  }
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Topic result category',
    keys: const {'code', 'label'},
  );
  return TeacherTopicResultCategory(
    code: TeacherTopicResultCategoryCode.parse(
      readTeacherNonBlankString(map, 'code'),
    ),
    label: readTeacherNonBlankString(map, 'label'),
  );
}

TeacherTopicResultActor? _readActor(Object? json) {
  if (json == null) {
    return null;
  }
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Topic result actor',
    keys: const {'id', 'full_name'},
  );
  return TeacherTopicResultActor(
    id: readTeacherCanonicalUuid(map, 'id'),
    fullName: readTeacherNonBlankString(map, 'full_name'),
  );
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
    throw FormatException('Teacher Topic result $key must be a string.');
  }
  return parse(value);
}

/// A score, D or T: a finite JSON number from 0 to 100, or null.
double? _readScore(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    throw FormatException('Teacher Topic result $key must be from 0 to 100.');
  }
  return value.toDouble();
}

int? _readCategoryScore(Map<String, Object?> map) {
  if (map['category_score'] == null) {
    return null;
  }
  final value = readTeacherInt(map, 'category_score');
  if (value < 0 || value > 100) {
    throw const FormatException(
      'Teacher Topic result category_score must be from 0 to 100.',
    );
  }
  return value;
}

bool _readBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Teacher Topic result $key must be a JSON boolean.');
}
