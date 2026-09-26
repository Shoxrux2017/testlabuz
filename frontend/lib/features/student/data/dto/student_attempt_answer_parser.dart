import '../../domain/student_attempt_answer.dart';
import '../../domain/student_question.dart';
import 'student_dto_parse.dart';
import 'student_question_dto.dart';

/// Safe Questions and saved answers of one Student Attempt resource.
///
/// Shared by Homework and Blitz so both keep one integrity boundary.
class StudentAttemptContentDto {
  StudentAttemptContentDto._({
    required List<StudentQuestionDto> questions,
    required List<StudentAttemptAnswerState> answers,
  }) : questions = List<StudentQuestionDto>.unmodifiable(questions),
       answers = List<StudentAttemptAnswerState>.unmodifiable(answers);

  factory StudentAttemptContentDto.fromAttemptMap(Map<String, Object?> map) {
    final questions = readStudentList(
      map,
      'questions',
    ).map(StudentQuestionDto.fromJson).toList();
    final questionsById = <String, StudentQuestionDto>{};
    for (var index = 0; index < questions.length; index += 1) {
      final question = questions[index];
      final id = question.id.toLowerCase();
      if (questionsById.containsKey(id) || question.position != index + 1) {
        throw const FormatException(
          'Attempt Questions need unique IDs and positions ordered exactly 1..N.',
        );
      }
      questionsById[id] = question;
    }
    final answeredQuestionIds = <String>{};
    final answers = readStudentList(map, 'answers').map((json) {
      final answer = _readAnswer(json, questionsById);
      if (!answeredQuestionIds.add(answer.questionId.toLowerCase())) {
        throw const FormatException(
          'Attempt Answer Question IDs must be unique.',
        );
      }
      return answer;
    }).toList();
    return StudentAttemptContentDto._(questions: questions, answers: answers);
  }

  final List<StudentQuestionDto> questions;
  final List<StudentAttemptAnswerState> answers;
}

StudentAttemptAnswerState _readAnswer(
  Object? json,
  Map<String, StudentQuestionDto> questionsById,
) {
  final map = readExactStudentMap(
    json,
    context: 'Student Attempt Answer',
    keys: const {'question_id', 'type', 'answer', 'updated_at'},
  );
  final questionId = readStudentCanonicalUuid(map, 'question_id');
  final type = StudentQuestionType.parse(
    readStudentNonBlankString(map, 'type'),
  );
  final question = questionsById[questionId.toLowerCase()];
  if (question == null || question.type != type) {
    throw const FormatException(
      'Saved Answer does not match an Attempt Question.',
    );
  }
  return StudentAttemptAnswerState(
    questionId: questionId,
    type: type,
    value: parseStudentAttemptAnswerValue(map['answer'], question.toDomain()),
    updatedAt: readStudentWholeSecondUtcTimestamp(map, 'updated_at'),
  );
}

StudentAttemptAnswerValue parseStudentAttemptAnswerValue(
  Object? json,
  StudentQuestion question,
) => switch (question.type) {
  StudentQuestionType.singleChoice ||
  StudentQuestionType.multipleChoice => _readChoice(json, question),
  StudentQuestionType.trueFalse => _readBoolean(json),
  StudentQuestionType.shortWritten ||
  StudentQuestionType.openWritten => _readText(json),
  StudentQuestionType.matching => _readMatching(
    json,
    question.answerUi as StudentMatchingAnswerUi,
  ),
  StudentQuestionType.ordering => _readOrdering(
    json,
    question.answerUi as StudentOrderingAnswerUi,
  ),
  StudentQuestionType.fillInBlank => _readFillBlank(
    json,
    question.answerUi as StudentFillBlankAnswerUi,
  ),
  StudentQuestionType.fileBased => _readFile(json),
};

StudentChoiceAnswerValue _readChoice(Object? json, StudentQuestion question) {
  final map = readExactStudentMap(
    json,
    context: 'Student saved choice',
    keys: const {'selected_option_ids'},
  );
  final ids = readStudentList(map, 'selected_option_ids').map((id) {
    return readStudentCanonicalUuid({'id': id}, 'id');
  }).toList();
  final answerUi = question.answerUi as StudentChoiceAnswerUi;
  final maximum = question.type == StudentQuestionType.singleChoice
      ? 1
      : answerUi.maxSelections!;
  if (ids.isEmpty || ids.length > maximum) {
    throw const FormatException(
      'Saved choice count is outside its Question range.',
    );
  }
  _validateChildIds(ids, answerUi.options.map((option) => option.id));
  return StudentChoiceAnswerValue(selectedOptionIds: ids);
}

StudentBooleanAnswerValue _readBoolean(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student saved boolean',
    keys: const {'value'},
  );
  final value = map['value'];
  if (value is! bool) {
    throw const FormatException('Saved true/false value must be a boolean.');
  }
  return StudentBooleanAnswerValue(value: value);
}

StudentTextAnswerValue _readText(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student saved text',
    keys: const {'text'},
  );
  return StudentTextAnswerValue(text: readStudentNonBlankString(map, 'text'));
}

StudentMatchingAnswerValue _readMatching(
  Object? json,
  StudentMatchingAnswerUi answerUi,
) {
  final map = readExactStudentMap(
    json,
    context: 'Student saved matching',
    keys: const {'pairs'},
  );
  final pairs = readStudentList(map, 'pairs').map((raw) {
    final pair = readExactStudentMap(
      raw,
      context: 'Student saved matching pair',
      keys: const {'left_item_id', 'right_item_id'},
    );
    return StudentMatchingAnswerPair(
      leftItemId: readStudentCanonicalUuid(pair, 'left_item_id'),
      rightItemId: readStudentCanonicalUuid(pair, 'right_item_id'),
    );
  }).toList();
  _validateChildIds(
    pairs.map((pair) => pair.leftItemId),
    answerUi.leftItems.map((item) => item.id),
  );
  _validateChildIds(
    pairs.map((pair) => pair.rightItemId),
    answerUi.rightItems.map((item) => item.id),
  );
  return StudentMatchingAnswerValue(pairs: pairs);
}

StudentOrderingAnswerValue _readOrdering(
  Object? json,
  StudentOrderingAnswerUi answerUi,
) {
  final map = readExactStudentMap(
    json,
    context: 'Student saved ordering',
    keys: const {'items'},
  );
  final positions = <int>{};
  final items = readStudentList(map, 'items').map((raw) {
    final item = readExactStudentMap(
      raw,
      context: 'Student saved ordering item',
      keys: const {'item_id', 'position'},
    );
    final position = readStudentInt(item, 'position');
    if (position < 1 ||
        position > answerUi.items.length ||
        !positions.add(position)) {
      throw const FormatException(
        'Saved ordering position is invalid or repeated.',
      );
    }
    return StudentOrderingAnswerItem(
      itemId: readStudentCanonicalUuid(item, 'item_id'),
      position: position,
    );
  }).toList();
  _validateChildIds(
    items.map((item) => item.itemId),
    answerUi.items.map((item) => item.id),
  );
  return StudentOrderingAnswerValue(items: items);
}

StudentFillBlankAnswerValue _readFillBlank(
  Object? json,
  StudentFillBlankAnswerUi answerUi,
) {
  final map = readExactStudentMap(
    json,
    context: 'Student saved fill blanks',
    keys: const {'values'},
  );
  final values = readStudentList(map, 'values').map((raw) {
    final value = readExactStudentMap(
      raw,
      context: 'Student saved blank',
      keys: const {'blank_id', 'text'},
    );
    return StudentFillBlankAnswerEntry(
      blankId: readStudentCanonicalUuid(value, 'blank_id'),
      text: readStudentNonBlankString(value, 'text'),
    );
  }).toList();
  _validateChildIds(
    values.map((value) => value.blankId),
    answerUi.blanks.map((blank) => blank.id),
  );
  return StudentFillBlankAnswerValue(values: values);
}

StudentFileAnswerValue _readFile(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student saved file answer',
    keys: const {'file'},
  );
  final file = readExactStudentMap(
    map['file'],
    context: 'Student submission file',
    keys: const {'id', 'original_name', 'extension', 'size_bytes'},
  );
  final extension = readStudentNonBlankString(file, 'extension');
  final sizeBytes = readStudentInt(file, 'size_bytes');
  if (!const {'pdf', 'docx', 'ppt', 'pptx'}.contains(extension) ||
      sizeBytes < 1 ||
      sizeBytes > 15_728_640) {
    throw const FormatException('Student submission file metadata is invalid.');
  }
  return StudentFileAnswerValue(
    file: StudentSubmissionFile(
      id: readStudentCanonicalUuid(file, 'id'),
      originalName: readStudentNonBlankString(file, 'original_name'),
      extension: extension,
      sizeBytes: sizeBytes,
    ),
  );
}

void _validateChildIds(Iterable<String> ids, Iterable<String> allowedIds) {
  final values = ids.map((id) => id.toLowerCase()).toList();
  final allowed = allowedIds.map((id) => id.toLowerCase()).toSet();
  if (values.isEmpty ||
      values.toSet().length != values.length ||
      !allowed.containsAll(values)) {
    throw const FormatException(
      'Saved Answer IDs are empty, repeated or unknown.',
    );
  }
}
