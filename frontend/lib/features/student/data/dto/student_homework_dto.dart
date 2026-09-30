import '../../domain/student_homework.dart';
import '../../domain/student_homework_attempt.dart';
import 'student_dto_parse.dart';
import 'student_question_dto.dart';
import 'student_result_dto.dart';

class StudentHomeworkSummaryDto {
  const StudentHomeworkSummaryDto({
    required this.id,
    required this.topic,
    required this.title,
    required this.status,
    required this.deadlineAt,
    required this.attempts,
    required this.myStatus,
    required this.officialScore,
  });

  factory StudentHomeworkSummaryDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Homework summary',
      keys: _summaryKeys,
    );
    final myStatus = _readMyStatus(map);
    return StudentHomeworkSummaryDto(
      id: readStudentCanonicalUuid(map, 'id'),
      topic: _readTopic(map['topic']),
      title: readStudentNonBlankString(map, 'title'),
      status: _readStatus(map),
      deadlineAt: readStudentNullableWholeSecondUtcTimestamp(
        map,
        'deadline_at',
      ),
      attempts: _readAttempts(
        map['attempts'],
        myStatus: myStatus,
        detail: false,
      ),
      myStatus: myStatus,
      officialScore: readStudentOfficialScore(map),
    );
  }

  final String id;
  final StudentHomeworkTopicSummary topic;
  final String title;
  final StudentHomeworkStatus status;
  final DateTime? deadlineAt;
  final StudentHomeworkAttemptSummary attempts;
  final StudentHomeworkMyStatus myStatus;
  final StudentOfficialScore? officialScore;

  bool get scoreVisible => officialScore != null;

  StudentHomeworkSummary toDomain() => StudentHomeworkSummary(
    id: id,
    topic: topic,
    title: title,
    status: status,
    deadlineAt: deadlineAt,
    attempts: attempts,
    myStatus: myStatus,
    scoreVisible: scoreVisible,
    officialScore: officialScore,
  );
}

class StudentHomeworkDetailDto {
  StudentHomeworkDetailDto({
    required this.id,
    required this.topic,
    required this.title,
    required this.description,
    required this.studentInstructions,
    required this.status,
    required this.deadlineAt,
    required this.totalPossiblePoints,
    required this.attempts,
    required this.myStatus,
    required this.officialScore,
    required List<StudentHomeworkAttemptResultItem> attemptResults,
    required List<StudentQuestionDto> questions,
  }) : attemptResults = List<StudentHomeworkAttemptResultItem>.unmodifiable(
         attemptResults,
       ),
       questions = List<StudentQuestionDto>.unmodifiable(questions);

  factory StudentHomeworkDetailDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Homework detail',
      keys: const {
        ..._summaryKeys,
        'description',
        'student_instructions',
        'total_possible_points',
        'attempt_results',
        'questions',
      },
    );
    final myStatus = _readMyStatus(map);
    final attempts = _readAttempts(
      map['attempts'],
      myStatus: myStatus,
      detail: true,
    );
    final officialScore = readStudentOfficialScore(map);
    final questions = readStudentList(
      map,
      'questions',
    ).map(StudentQuestionDto.fromJson).toList();
    final questionIds = <String>{};
    for (var index = 0; index < questions.length; index += 1) {
      final question = questions[index];
      if (!questionIds.add(question.id.toLowerCase()) ||
          question.position != index + 1) {
        throw const FormatException(
          'Student Questions need unique IDs and positions ordered exactly 1..N.',
        );
      }
    }
    return StudentHomeworkDetailDto(
      id: readStudentCanonicalUuid(map, 'id'),
      topic: _readTopic(map['topic']),
      title: readStudentNonBlankString(map, 'title'),
      description: readStudentNullableString(map, 'description'),
      studentInstructions: readStudentNonBlankString(
        map,
        'student_instructions',
      ),
      status: _readStatus(map),
      deadlineAt: readStudentNullableWholeSecondUtcTimestamp(
        map,
        'deadline_at',
      ),
      totalPossiblePoints: readStudentNonNegativeNumber(
        map,
        'total_possible_points',
      ),
      attempts: attempts,
      myStatus: myStatus,
      officialScore: officialScore,
      attemptResults: _readAttemptResults(
        map,
        attempts: attempts,
        myStatus: myStatus,
        officialScore: officialScore,
      ),
      questions: questions,
    );
  }

  final String id;
  final StudentHomeworkTopicSummary topic;
  final String title;
  final String? description;
  final String studentInstructions;
  final StudentHomeworkStatus status;
  final DateTime? deadlineAt;
  final double totalPossiblePoints;
  final StudentHomeworkAttemptSummary attempts;
  final StudentHomeworkMyStatus myStatus;
  final StudentOfficialScore? officialScore;
  final List<StudentHomeworkAttemptResultItem> attemptResults;
  final List<StudentQuestionDto> questions;

  bool get scoreVisible => officialScore != null;

  StudentHomeworkDetail toDomain() => StudentHomeworkDetail(
    id: id,
    topic: topic,
    title: title,
    description: description,
    studentInstructions: studentInstructions,
    status: status,
    deadlineAt: deadlineAt,
    totalPossiblePoints: totalPossiblePoints,
    attempts: attempts,
    myStatus: myStatus,
    scoreVisible: scoreVisible,
    officialScore: officialScore,
    attemptResults: attemptResults,
    questions: questions.map((question) => question.toDomain()).toList(),
  );
}

/// Every terminal Attempt in attempt-number order: numbers 1..N below any
/// in-progress Attempt, the latest one carrying `my_status`, and a visible
/// official score confirmed by its Attempt's visible result.
List<StudentHomeworkAttemptResultItem> _readAttemptResults(
  Map<String, Object?> map, {
  required StudentHomeworkAttemptSummary attempts,
  required StudentHomeworkMyStatus myStatus,
  required StudentOfficialScore? officialScore,
}) {
  final items = readStudentList(
    map,
    'attempt_results',
  ).map(_readAttemptResult).toList();
  final ids = <String>{};
  for (var index = 0; index < items.length; index += 1) {
    if (items[index].attemptNumber != index + 1 ||
        !ids.add(items[index].attemptId.toLowerCase())) {
      throw const FormatException(
        'Homework attempt results need unique IDs and numbers 1..N.',
      );
    }
  }
  final inProgress = attempts.inProgressAttempt;
  if (items.length != attempts.used - (inProgress == null ? 0 : 1) ||
      (inProgress != null && ids.contains(inProgress.id.toLowerCase())) ||
      (inProgress == null &&
          items.isNotEmpty &&
          items.last.status.apiValue != myStatus.apiValue)) {
    throw const FormatException(
      'Homework attempt results do not match the Attempt history.',
    );
  }
  if (officialScore != null) {
    final official = items.where(
      (item) => item.attemptNumber == officialScore.attemptNumber,
    );
    if (official.length != 1 ||
        official.single.result.normalizedScore !=
            officialScore.normalizedScore) {
      throw const FormatException(
        'The official Homework score needs its visible Attempt result.',
      );
    }
  }
  return items;
}

StudentHomeworkAttemptResultItem _readAttemptResult(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student Homework attempt result',
    keys: const {'attempt_id', 'attempt_number', 'status', 'result'},
  );
  final status = StudentHomeworkAttemptStatus.parse(
    readStudentNonBlankString(map, 'status'),
  );
  final result = readStudentAttemptResult(map['result']);
  if (status == StudentHomeworkAttemptStatus.inProgress ||
      (result.visible && status != StudentHomeworkAttemptStatus.checked)) {
    throw const FormatException(
      'Only a checked terminal Attempt can show its result.',
    );
  }
  return StudentHomeworkAttemptResultItem(
    attemptId: readStudentCanonicalUuid(map, 'attempt_id'),
    attemptNumber: readStudentInt(map, 'attempt_number'),
    status: status,
    result: result,
  );
}

StudentHomeworkTopicSummary _readTopic(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student Homework Topic summary',
    keys: const {'id', 'title'},
  );
  return StudentHomeworkTopicSummary(
    id: readStudentCanonicalUuid(map, 'id'),
    title: readStudentNonBlankString(map, 'title'),
  );
}

StudentHomeworkAttemptSummary _readAttempts(
  Object? json, {
  required StudentHomeworkMyStatus myStatus,
  required bool detail,
}) {
  final map = readExactStudentMap(
    json,
    context: 'Student Homework Attempt summary',
    keys: {
      'allowed',
      'used',
      'remaining',
      'official_score_policy',
      if (detail) 'in_progress_attempt',
    },
  );
  final allowed = readStudentInt(map, 'allowed');
  final used = readStudentInt(map, 'used');
  final remaining = readStudentInt(map, 'remaining');
  final policy = readStudentNonBlankString(map, 'official_score_policy');
  if (allowed != 3 ||
      used < 0 ||
      used > 3 ||
      remaining < 0 ||
      remaining > 3 ||
      used + remaining > 3 ||
      policy != 'highest_valid_completed') {
    throw const FormatException('Student Homework Attempt summary is invalid.');
  }
  if ((used == 0) != (myStatus == StudentHomeworkMyStatus.notStarted)) {
    throw const FormatException(
      'Student Homework used count contradicts my status.',
    );
  }
  final inProgress = detail && map['in_progress_attempt'] != null
      ? _readInProgressAttempt(map['in_progress_attempt'])
      : null;
  if (detail &&
      ((myStatus == StudentHomeworkMyStatus.inProgress) !=
          (inProgress != null))) {
    throw const FormatException(
      'Student Homework in-progress identity contradicts my status.',
    );
  }
  if (inProgress != null && inProgress.attemptNumber > used) {
    throw const FormatException(
      'Student Homework Attempt number exceeds used count.',
    );
  }
  return StudentHomeworkAttemptSummary(
    allowed: allowed,
    used: used,
    remaining: remaining,
    officialScorePolicy: policy,
    inProgressAttempt: inProgress,
  );
}

StudentInProgressHomeworkAttempt _readInProgressAttempt(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student in-progress Homework Attempt',
    keys: const {'id', 'attempt_number', 'started_at'},
  );
  final attemptNumber = readStudentInt(map, 'attempt_number');
  final startedAt = readStudentNullableWholeSecondUtcTimestamp(
    map,
    'started_at',
  );
  if (attemptNumber < 1 || attemptNumber > 3 || startedAt == null) {
    throw const FormatException(
      'Student in-progress Homework Attempt is invalid.',
    );
  }
  return StudentInProgressHomeworkAttempt(
    id: readStudentCanonicalUuid(map, 'id'),
    attemptNumber: attemptNumber,
    startedAt: startedAt,
  );
}

StudentHomeworkStatus _readStatus(Map<String, Object?> map) =>
    StudentHomeworkStatus.parse(readStudentNonBlankString(map, 'status'));

StudentHomeworkMyStatus _readMyStatus(Map<String, Object?> map) =>
    StudentHomeworkMyStatus.parse(readStudentNonBlankString(map, 'my_status'));

const _summaryKeys = {
  'id',
  'topic',
  'title',
  'status',
  'deadline_at',
  'attempts',
  'my_status',
  'score_visible',
  'official_score',
};
