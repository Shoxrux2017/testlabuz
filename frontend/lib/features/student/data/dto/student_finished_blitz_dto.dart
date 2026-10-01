import '../../domain/student_finished_blitz.dart';
import 'student_blitz_dto.dart';
import 'student_dto_parse.dart';

/// `GET /student/blitz/finished`, parsed strictly (`S09-BE-007C` §5.3).
class StudentFinishedBlitzPageDto {
  const StudentFinishedBlitzPageDto._(this._page);

  factory StudentFinishedBlitzPageDto.fromJson(
    Object? json, {
    required int page,
    required int perPage,
  }) {
    final envelope = readExactStudentMap(
      json,
      context: 'Student finished Blitz envelope',
      keys: const {'data', 'meta'},
    );
    final items = readStudentList(envelope, 'data').map(_readItem).toList();
    final meta = readExactStudentMap(
      envelope['meta'],
      context: 'Student finished Blitz meta',
      keys: const {'pagination'},
    );
    final pagination = readExactStudentMap(
      meta['pagination'],
      context: 'Student finished Blitz pagination',
      keys: const {'page', 'per_page', 'total', 'last_page'},
    );
    final returnedPage = readStudentInt(pagination, 'page');
    final returnedPerPage = readStudentInt(pagination, 'per_page');
    final total = readStudentInt(pagination, 'total');
    final lastPage = readStudentInt(pagination, 'last_page');
    if (returnedPage != page ||
        returnedPerPage != perPage ||
        returnedPerPage < 1 ||
        total < 0) {
      throw const FormatException(
        'Student finished Blitz pagination contradicts the request.',
      );
    }
    final expectedLastPage = total == 0
        ? 1
        : (total + returnedPerPage - 1) ~/ returnedPerPage;
    if (lastPage != expectedLastPage ||
        items.length > returnedPerPage ||
        items.length > total ||
        (returnedPage > lastPage && items.isNotEmpty)) {
      throw const FormatException(
        'Student finished Blitz pagination contradicts the request.',
      );
    }
    final ids = {for (final item in items) item.id.toLowerCase()};
    if (ids.length != items.length) {
      throw const FormatException('Student finished Blitz ids repeat.');
    }

    return StudentFinishedBlitzPageDto._(
      StudentFinishedBlitzPage(
        items: items,
        page: returnedPage,
        perPage: returnedPerPage,
        total: total,
        lastPage: lastPage,
      ),
    );
  }

  final StudentFinishedBlitzPage _page;

  StudentFinishedBlitzPage toDomain() => _page;
}

StudentFinishedBlitz _readItem(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student finished Blitz',
    keys: const {
      'id',
      'topic',
      'title',
      'status',
      'closed_at',
      'attempt_exception',
      'result',
    },
  );
  final statusValue = map['status'];
  final status = statusValue is String
      ? StudentFinishedBlitzStatus.fromValue(statusValue)
      : null;
  if (status == null) {
    throw const FormatException('Student finished Blitz status is unknown.');
  }
  // Only a closed Blitz can be archived after activation
  // (`blitz_tasks_lifecycle_check`), so every finished Blitz has a close time.
  final closedAt = readStudentWholeSecondUtcTimestamp(map, 'closed_at');
  final attemptException = readStudentBool(map, 'attempt_exception');
  final result = map['result'] == null
      ? null
      : _readResult(map['result'], attemptException: attemptException);

  return StudentFinishedBlitz(
    id: readStudentCanonicalUuid(map, 'id'),
    topic: readStudentBlitzTopic(map['topic']),
    title: readStudentNonBlankString(map, 'title'),
    status: status,
    closedAt: closedAt,
    attemptException: attemptException,
    result: result,
  );
}

StudentFinishedBlitzResult _readResult(
  Object? json, {
  required bool attemptException,
}) {
  final map = readExactStudentMap(
    json,
    context: 'Student finished Blitz result',
    keys: const {'attempt_number', 'visible', 'normalized_score', 'feedback'},
  );
  final attemptNumber = readStudentInt(map, 'attempt_number');
  final visible = readStudentBool(map, 'visible');
  final feedback = readStudentList(map, 'feedback').map(_readFeedback).toList();
  if (attemptNumber != (attemptException ? 2 : 1)) {
    throw const FormatException(
      'The counting Blitz Attempt contradicts the exception.',
    );
  }
  final score = visible
      ? readStudentNonNegativeNumber(map, 'normalized_score')
      : null;
  if (visible
      ? score! > 100
      : map['normalized_score'] != null || feedback.isNotEmpty) {
    throw const FormatException(
      'A finished Blitz result contradicts its visibility.',
    );
  }
  final questions = {
    for (final entry in feedback) entry.questionId.toLowerCase(),
  };
  for (var index = 1; index < feedback.length; index++) {
    // Question positions are unique within an Assessment.
    if (feedback[index].position <= feedback[index - 1].position) {
      throw const FormatException('Blitz feedback is out of Question order.');
    }
  }
  if (questions.length != feedback.length) {
    throw const FormatException('Blitz feedback repeats a Question.');
  }

  return StudentFinishedBlitzResult(
    attemptNumber: attemptNumber,
    visible: visible,
    normalizedScore: score,
    feedback: feedback,
  );
}

StudentFinishedBlitzFeedback _readFeedback(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student finished Blitz feedback',
    keys: const {'question_id', 'position', 'text'},
  );
  final position = readStudentInt(map, 'position');
  final text = map['text'];
  if (position < 1 || text is! String || text.isEmpty) {
    throw const FormatException('Blitz feedback is malformed.');
  }
  return StudentFinishedBlitzFeedback(
    questionId: readStudentCanonicalUuid(map, 'question_id'),
    position: position,
    text: text,
  );
}
