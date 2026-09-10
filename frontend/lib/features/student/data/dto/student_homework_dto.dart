import '../../domain/student_homework.dart';
import 'student_dto_parse.dart';
import 'student_question_dto.dart';

class StudentHomeworkSummaryDto {
  const StudentHomeworkSummaryDto({
    required this.id,
    required this.topic,
    required this.title,
    required this.status,
    required this.deadlineAt,
    required this.attempts,
    required this.myStatus,
    required this.scoreVisible,
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
      scoreVisible: _readScoreVisible(map),
    );
  }

  final String id;
  final StudentHomeworkTopicSummary topic;
  final String title;
  final StudentHomeworkStatus status;
  final DateTime? deadlineAt;
  final StudentHomeworkAttemptSummary attempts;
  final StudentHomeworkMyStatus myStatus;
  final bool scoreVisible;

  StudentHomeworkSummary toDomain() => StudentHomeworkSummary(
    id: id,
    topic: topic,
    title: title,
    status: status,
    deadlineAt: deadlineAt,
    attempts: attempts,
    myStatus: myStatus,
    scoreVisible: scoreVisible,
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
    required this.scoreVisible,
    required List<StudentQuestionDto> questions,
  }) : questions = List<StudentQuestionDto>.unmodifiable(questions);

  factory StudentHomeworkDetailDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Homework detail',
      keys: const {
        ..._summaryKeys,
        'description',
        'student_instructions',
        'total_possible_points',
        'questions',
      },
    );
    final myStatus = _readMyStatus(map);
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
      attempts: _readAttempts(
        map['attempts'],
        myStatus: myStatus,
        detail: true,
      ),
      myStatus: myStatus,
      scoreVisible: _readScoreVisible(map),
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
  final bool scoreVisible;
  final List<StudentQuestionDto> questions;

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
    questions: questions.map((question) => question.toDomain()).toList(),
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

bool _readScoreVisible(Map<String, Object?> map) {
  if (map['score_visible'] != false) {
    throw const FormatException(
      'Student Homework score_visible must be false.',
    );
  }
  return false;
}

const _summaryKeys = {
  'id',
  'topic',
  'title',
  'status',
  'deadline_at',
  'attempts',
  'my_status',
  'score_visible',
};
