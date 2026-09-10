import '../../domain/student_homework_attempt.dart';
import '../../domain/student_question.dart';
import 'student_dto_parse.dart';
import 'student_question_dto.dart';

class StudentHomeworkAttemptDto {
  StudentHomeworkAttemptDto({
    required this.id,
    required this.assessmentId,
    required this.attemptNumber,
    required this.status,
    required this.startedAt,
    required this.submittedAt,
    required this.finalizedAt,
    required this.finalizationReason,
    required this.deadlineAt,
    required List<StudentQuestionDto> questions,
    required List<StudentAttemptAnswerState> answers,
  }) : questions = List<StudentQuestionDto>.unmodifiable(questions),
       answers = List<StudentAttemptAnswerState>.unmodifiable(answers);

  factory StudentHomeworkAttemptDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Homework Attempt',
      keys: const {
        'id',
        'assessment_id',
        'attempt_number',
        'status',
        'started_at',
        'submitted_at',
        'finalized_at',
        'finalization_reason',
        'deadline_at',
        'questions',
        'answers',
      },
    );
    final attemptNumber = readStudentInt(map, 'attempt_number');
    if (attemptNumber < 1 || attemptNumber > 3) {
      throw const FormatException('Homework Attempt number must be in 1..3.');
    }
    final status = StudentHomeworkAttemptStatus.parse(
      readStudentNonBlankString(map, 'status'),
    );
    final startedAt = _requiredTimestamp(map, 'started_at');
    final submittedAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'submitted_at',
    );
    final finalizedAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'finalized_at',
    );
    final deadlineAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'deadline_at',
    );
    final reason = map['finalization_reason'] == null
        ? null
        : StudentHomeworkAttemptFinalizationReason.parse(
            readStudentNonBlankString(map, 'finalization_reason'),
          );
    _validateLifecycle(
      status: status,
      startedAt: startedAt,
      submittedAt: submittedAt,
      finalizedAt: finalizedAt,
      reason: reason,
      deadlineAt: deadlineAt,
    );
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
    return StudentHomeworkAttemptDto(
      id: readStudentCanonicalUuid(map, 'id'),
      assessmentId: readStudentCanonicalUuid(map, 'assessment_id'),
      attemptNumber: attemptNumber,
      status: status,
      startedAt: startedAt,
      submittedAt: submittedAt,
      finalizedAt: finalizedAt,
      finalizationReason: reason,
      deadlineAt: deadlineAt,
      questions: questions,
      answers: answers,
    );
  }

  final String id;
  final String assessmentId;
  final int attemptNumber;
  final StudentHomeworkAttemptStatus status;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime? finalizedAt;
  final StudentHomeworkAttemptFinalizationReason? finalizationReason;
  final DateTime? deadlineAt;
  final List<StudentQuestionDto> questions;
  final List<StudentAttemptAnswerState> answers;

  StudentHomeworkAttempt toDomain() => StudentHomeworkAttempt(
    id: id,
    assessmentId: assessmentId,
    attemptNumber: attemptNumber,
    status: status,
    startedAt: startedAt,
    submittedAt: submittedAt,
    finalizedAt: finalizedAt,
    finalizationReason: finalizationReason,
    deadlineAt: deadlineAt,
    questions: questions.map((question) => question.toDomain()).toList(),
    answers: answers,
  );
}

class StudentHomeworkAttemptStartOperationDto {
  const StudentHomeworkAttemptStartOperationDto({
    required this.attempt,
    required this.resultKind,
  });

  final StudentHomeworkAttemptDto attempt;
  final StudentHomeworkAttemptStartResultKind resultKind;

  StudentHomeworkAttemptStartResult toDomain() =>
      StudentHomeworkAttemptStartResult(
        attempt: attempt.toDomain(),
        resultKind: resultKind,
      );
}

DateTime _requiredTimestamp(Map<String, Object?> map, String key) {
  final timestamp = readStudentNullableWholeSecondUtcTimestamp(map, key);
  if (timestamp == null) {
    throw FormatException('$key must not be null.');
  }
  return timestamp;
}

void _validateLifecycle({
  required StudentHomeworkAttemptStatus status,
  required DateTime startedAt,
  required DateTime? submittedAt,
  required DateTime? finalizedAt,
  required StudentHomeworkAttemptFinalizationReason? reason,
  required DateTime? deadlineAt,
}) {
  if ((submittedAt != null && startedAt.isAfter(submittedAt)) ||
      (finalizedAt != null && startedAt.isAfter(finalizedAt))) {
    throw const FormatException('Attempt completion precedes its start.');
  }
  if (status == StudentHomeworkAttemptStatus.inProgress) {
    if (submittedAt != null || finalizedAt != null || reason != null) {
      throw const FormatException('In-progress Attempt cannot be finalized.');
    }
    return;
  }
  if (finalizedAt == null || reason == null) {
    throw const FormatException('Completed Attempt requires finalization.');
  }
  final valid = switch (reason) {
    StudentHomeworkAttemptFinalizationReason.studentSubmit =>
      submittedAt == finalizedAt &&
          (deadlineAt == null || finalizedAt.isBefore(deadlineAt)),
    StudentHomeworkAttemptFinalizationReason.homeworkDeadline =>
      submittedAt == null && deadlineAt != null && finalizedAt == deadlineAt,
    StudentHomeworkAttemptFinalizationReason.taskClosed =>
      submittedAt == null &&
          (deadlineAt == null || finalizedAt.isBefore(deadlineAt)),
  };
  if (!valid) {
    throw const FormatException(
      'Attempt finalization metadata is inconsistent.',
    );
  }
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
    updatedAt: _requiredTimestamp(map, 'updated_at'),
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
