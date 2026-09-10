import '../../domain/student_question.dart';
import 'student_dto_parse.dart';

class StudentQuestionDto {
  const StudentQuestionDto({
    required this.id,
    required this.type,
    required this.prompt,
    required this.instructions,
    required this.points,
    required this.position,
    required this.answerUi,
  });

  factory StudentQuestionDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Question',
      keys: const {
        'id',
        'type',
        'prompt',
        'instructions',
        'points',
        'position',
        'answer_ui',
      },
    );
    final type = StudentQuestionType.parse(
      readStudentNonBlankString(map, 'type'),
    );
    final position = readStudentInt(map, 'position');
    if (position < 1) {
      throw const FormatException(
        'Student Question position must be positive.',
      );
    }
    return StudentQuestionDto(
      id: readStudentCanonicalUuid(map, 'id'),
      type: type,
      prompt: readStudentNonBlankString(map, 'prompt'),
      instructions: readStudentNullableString(map, 'instructions'),
      points: readStudentNonNegativeNumber(map, 'points'),
      position: position,
      answerUi: _readAnswerUi(map['answer_ui'], type),
    );
  }

  final String id;
  final StudentQuestionType type;
  final String prompt;
  final String? instructions;
  final double points;
  final int position;
  final StudentAnswerUi answerUi;

  StudentQuestion toDomain() => StudentQuestion(
    id: id,
    type: type,
    prompt: prompt,
    instructions: instructions,
    points: points,
    position: position,
    answerUi: answerUi,
  );
}

StudentAnswerUi _readAnswerUi(Object? json, StudentQuestionType type) {
  return switch (type) {
    StudentQuestionType.singleChoice => _readChoices(json, multiple: false),
    StudentQuestionType.multipleChoice => _readChoices(json, multiple: true),
    StudentQuestionType.trueFalse ||
    StudentQuestionType.shortWritten ||
    StudentQuestionType.openWritten => _readEmpty(json),
    StudentQuestionType.fileBased => _readFile(json),
    StudentQuestionType.matching => _readMatching(json),
    StudentQuestionType.ordering => _readOrdering(json),
    StudentQuestionType.fillInBlank => _readFillBlanks(json),
  };
}

StudentChoiceAnswerUi _readChoices(Object? json, {required bool multiple}) {
  final map = readExactStudentMap(
    json,
    context: 'Student choice answer UI',
    keys: multiple ? const {'options', 'max_selections'} : const {'options'},
  );
  final options = readStudentList(map, 'options').map((raw) {
    final option = _readTextItem(raw);
    return StudentChoiceOption(
      id: readStudentCanonicalUuid(option, 'id'),
      text: readStudentNonBlankString(option, 'text'),
    );
  }).toList();
  if (options.length < 2 || !_uniqueIds(options.map((option) => option.id))) {
    throw const FormatException(
      'Student choices need at least two unique IDs.',
    );
  }
  final maxSelections = multiple ? readStudentInt(map, 'max_selections') : null;
  if (maxSelections != null &&
      (maxSelections < 1 || maxSelections > options.length)) {
    throw const FormatException('Student max selections is out of range.');
  }
  return StudentChoiceAnswerUi(options: options, maxSelections: maxSelections);
}

StudentEmptyAnswerUi _readEmpty(Object? json) {
  readExactStudentMap(json, context: 'Student empty answer UI', keys: const {});
  return const StudentEmptyAnswerUi();
}

StudentFileAnswerUi _readFile(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student file answer UI',
    keys: const {'allowed_extensions', 'max_size_bytes'},
  );
  final extensions = readStudentList(map, 'allowed_extensions');
  if (extensions.length != _allowedExtensions.length ||
      extensions.any((value) => value is! String) ||
      !extensions.toSet().containsAll(_allowedExtensions)) {
    throw const FormatException('Student file extensions are unsupported.');
  }
  final maxSizeBytes = readStudentInt(map, 'max_size_bytes');
  if (maxSizeBytes < 1 || maxSizeBytes > 15_728_640) {
    throw const FormatException('Student maximum file size is out of range.');
  }
  return StudentFileAnswerUi(
    allowedExtensions: extensions.cast<String>(),
    maxSizeBytes: maxSizeBytes,
  );
}

StudentMatchingAnswerUi _readMatching(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student matching answer UI',
    keys: const {'left_items', 'right_items'},
  );
  final leftItems = _readMatchingItems(map, 'left_items');
  final rightItems = _readMatchingItems(map, 'right_items');
  if (!_uniqueIds([
    ...leftItems.map((item) => item.id),
    ...rightItems.map((item) => item.id),
  ])) {
    throw const FormatException('Student matching item IDs must not overlap.');
  }
  return StudentMatchingAnswerUi(leftItems: leftItems, rightItems: rightItems);
}

List<StudentMatchingItem> _readMatchingItems(
  Map<String, Object?> map,
  String key,
) {
  final items = readStudentList(map, key).map((raw) {
    final item = _readTextItem(raw);
    return StudentMatchingItem(
      id: readStudentCanonicalUuid(item, 'id'),
      text: readStudentNonBlankString(item, 'text'),
    );
  }).toList();
  if (items.isEmpty || !_uniqueIds(items.map((item) => item.id))) {
    throw const FormatException(
      'Student matching items need non-empty unique IDs.',
    );
  }
  return items;
}

StudentOrderingAnswerUi _readOrdering(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student ordering answer UI',
    keys: const {'items'},
  );
  final items = readStudentList(map, 'items').map((raw) {
    final item = _readTextItem(raw);
    return StudentOrderingItem(
      id: readStudentCanonicalUuid(item, 'id'),
      text: readStudentNonBlankString(item, 'text'),
    );
  }).toList();
  if (items.isEmpty || !_uniqueIds(items.map((item) => item.id))) {
    throw const FormatException(
      'Student ordering items need non-empty unique IDs.',
    );
  }
  return StudentOrderingAnswerUi(items: items);
}

StudentFillBlankAnswerUi _readFillBlanks(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student fill blank answer UI',
    keys: const {'blanks'},
  );
  final blanks = readStudentList(map, 'blanks').map((raw) {
    final blank = readExactStudentMap(
      raw,
      context: 'Student blank',
      keys: const {'id', 'key', 'position'},
    );
    final position = readStudentInt(blank, 'position');
    if (position < 1) {
      throw const FormatException('Student blank position must be positive.');
    }
    return StudentFillBlank(
      id: readStudentCanonicalUuid(blank, 'id'),
      key: readStudentNonBlankString(blank, 'key'),
      position: position,
    );
  }).toList();
  if (!_uniqueIds(blanks.map((blank) => blank.id)) ||
      blanks.map((blank) => blank.key).toSet().length != blanks.length ||
      blanks.map((blank) => blank.position).toSet().length != blanks.length) {
    throw const FormatException(
      'Student blank IDs, keys and positions must be unique.',
    );
  }
  return StudentFillBlankAnswerUi(blanks: blanks);
}

Map<String, Object?> _readTextItem(Object? json) => readExactStudentMap(
  json,
  context: 'Student answer display item',
  keys: const {'id', 'text'},
);

bool _uniqueIds(Iterable<String> ids) {
  final values = ids.toList();
  return values.map((id) => id.toLowerCase()).toSet().length == values.length;
}

const _allowedExtensions = {'pdf', 'docx', 'ppt', 'pptx'};
