import '../../domain/teacher_question.dart';
import 'teacher_dto_parse.dart';

class TeacherQuestionDto {
  const TeacherQuestionDto({
    required this.id,
    required this.type,
    required this.prompt,
    required this.instructions,
    required this.points,
    required this.position,
    required this.checkingMode,
    required this.configuration,
  });

  factory TeacherQuestionDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Question resource',
      keys: _questionKeys,
    );
    final type = TeacherQuestionType.parse(
      readTeacherNonBlankString(map, 'type'),
    );
    final checkingMode = TeacherQuestionCheckingMode.parse(
      readTeacherNonBlankString(map, 'checking_mode'),
    );
    final prompt = readTeacherNonBlankString(map, 'prompt');
    final position = readTeacherInt(map, 'position');
    if (position < 1) {
      throw const FormatException(
        'Teacher Question position must be positive.',
      );
    }

    return TeacherQuestionDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      type: type,
      prompt: prompt,
      instructions: readTeacherNullableString(map, 'instructions'),
      points: _readNonNegativeNumber(map, 'points'),
      position: position,
      checkingMode: checkingMode,
      configuration: _readConfiguration(
        map['configuration'],
        type: type,
        checkingMode: checkingMode,
        prompt: prompt,
      ),
    );
  }

  final String id;
  final TeacherQuestionType type;
  final String prompt;
  final String? instructions;
  final double points;
  final int position;
  final TeacherQuestionCheckingMode checkingMode;
  final TeacherQuestionConfiguration configuration;

  TeacherQuestion toDomain() {
    return TeacherQuestion(
      id: id,
      type: type,
      prompt: prompt,
      instructions: instructions,
      points: points,
      position: position,
      checkingMode: checkingMode,
      configuration: configuration,
    );
  }
}

double readTeacherNonNegativeNumber(Map<String, Object?> map, String key) {
  return _readNonNegativeNumber(map, key);
}

double _readNonNegativeNumber(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('$key must be a finite non-negative JSON number.');
  }
  return value.toDouble();
}

TeacherQuestionConfiguration _readConfiguration(
  Object? json, {
  required TeacherQuestionType type,
  required TeacherQuestionCheckingMode checkingMode,
  required String prompt,
}) {
  final allowedCheckingMode = switch (type) {
    TeacherQuestionType.shortWritten => true,
    TeacherQuestionType.openWritten || TeacherQuestionType.fileBased =>
      checkingMode == TeacherQuestionCheckingMode.manual,
    _ => checkingMode == TeacherQuestionCheckingMode.automatic,
  };
  if (!allowedCheckingMode) {
    throw const FormatException(
      'Teacher Question type and checking mode are incompatible.',
    );
  }

  return switch ((type, checkingMode)) {
    (
      TeacherQuestionType.singleChoice || TeacherQuestionType.multipleChoice,
      TeacherQuestionCheckingMode.automatic,
    ) =>
      _readChoiceConfiguration(json, type),
    (TeacherQuestionType.trueFalse, TeacherQuestionCheckingMode.automatic) =>
      _readTrueFalseConfiguration(json),
    (TeacherQuestionType.shortWritten, TeacherQuestionCheckingMode.automatic) =>
      _readShortWrittenAutomaticConfiguration(json),
    (
      TeacherQuestionType.shortWritten || TeacherQuestionType.openWritten,
      TeacherQuestionCheckingMode.manual,
    ) =>
      _readEmptyConfiguration(json),
    (TeacherQuestionType.fileBased, TeacherQuestionCheckingMode.manual) =>
      _readFileBasedConfiguration(json),
    (TeacherQuestionType.matching, TeacherQuestionCheckingMode.automatic) =>
      _readMatchingConfiguration(json),
    (TeacherQuestionType.ordering, TeacherQuestionCheckingMode.automatic) =>
      _readOrderingConfiguration(json),
    (TeacherQuestionType.fillInBlank, TeacherQuestionCheckingMode.automatic) =>
      _readFillInBlankConfiguration(json, prompt),
    _ => throw const FormatException(
      'Teacher Question configuration is incompatible.',
    ),
  };
}

TeacherChoiceQuestionConfiguration _readChoiceConfiguration(
  Object? json,
  TeacherQuestionType type,
) {
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Choice Question configuration',
    keys: const {'options'},
  );
  final rawOptions = _readList(map, 'options');
  if (rawOptions.length < 2) {
    throw const FormatException(
      'Teacher Choice Question requires at least two options.',
    );
  }
  final options = <TeacherChoiceOption>[];
  for (var index = 0; index < rawOptions.length; index += 1) {
    final option = readExactTeacherMap(
      rawOptions[index],
      context: 'Teacher Choice Question option',
      keys: const {'text', 'is_correct', 'position'},
    );
    final position = readTeacherInt(option, 'position');
    if (position != index + 1 || option['is_correct'] is! bool) {
      throw const FormatException(
        'Teacher Choice Question options are not canonical.',
      );
    }
    options.add(
      TeacherChoiceOption(
        text: readTeacherNonBlankString(option, 'text'),
        isCorrect: option['is_correct']! as bool,
        position: position,
      ),
    );
  }
  final correctCount = options.where((option) => option.isCorrect).length;
  if ((type == TeacherQuestionType.singleChoice && correctCount != 1) ||
      (type == TeacherQuestionType.multipleChoice && correctCount < 1)) {
    throw const FormatException(
      'Teacher Choice Question has an invalid correct-option set.',
    );
  }
  return TeacherChoiceQuestionConfiguration(options: options);
}

TeacherTrueFalseQuestionConfiguration _readTrueFalseConfiguration(
  Object? json,
) {
  final map = readExactTeacherMap(
    json,
    context: 'Teacher True/False Question configuration',
    keys: const {'correct_value'},
  );
  final correctValue = map['correct_value'];
  if (correctValue is! bool) {
    throw const FormatException(
      'Teacher True/False correct value must be a boolean.',
    );
  }
  return TeacherTrueFalseQuestionConfiguration(correctValue: correctValue);
}

TeacherShortWrittenAutomaticConfiguration
_readShortWrittenAutomaticConfiguration(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Short Written Question configuration',
    keys: const {'accepted_answers'},
  );
  final answers = _readNonBlankStrings(map, 'accepted_answers');
  if (answers.isEmpty) {
    throw const FormatException(
      'Teacher Short Written Question requires accepted answers.',
    );
  }
  return TeacherShortWrittenAutomaticConfiguration(acceptedAnswers: answers);
}

TeacherEmptyQuestionConfiguration _readEmptyConfiguration(Object? json) {
  readExactTeacherMap(
    json,
    context: 'Teacher empty Question configuration',
    keys: const {},
  );
  return const TeacherEmptyQuestionConfiguration();
}

TeacherFileBasedQuestionConfiguration _readFileBasedConfiguration(
  Object? json,
) {
  final map = readExactTeacherMap(
    json,
    context: 'Teacher File Based Question configuration',
    keys: const {'allowed_extensions'},
  );
  final extensions = _readStringList(map, 'allowed_extensions');
  const expected = ['pdf', 'docx', 'ppt', 'pptx'];
  if (extensions.length != expected.length) {
    throw const FormatException(
      'Teacher File Based extensions are not canonical.',
    );
  }
  for (var index = 0; index < expected.length; index += 1) {
    if (extensions[index] != expected[index]) {
      throw const FormatException(
        'Teacher File Based extensions are not canonical.',
      );
    }
  }
  return TeacherFileBasedQuestionConfiguration(allowedExtensions: extensions);
}

TeacherMatchingQuestionConfiguration _readMatchingConfiguration(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Matching Question configuration',
    keys: const {'pairs'},
  );
  final rawPairs = _readList(map, 'pairs');
  if (rawPairs.isEmpty) {
    throw const FormatException(
      'Teacher Matching Question requires at least one pair.',
    );
  }
  final pairs = rawPairs
      .map((rawPair) {
        final pair = readExactTeacherMap(
          rawPair,
          context: 'Teacher Matching Question pair',
          keys: const {'client_key', 'left', 'right'},
        );
        return TeacherMatchingPair(
          clientKey: readTeacherCanonicalUuid(pair, 'client_key'),
          left: readTeacherNonBlankString(pair, 'left'),
          right: readTeacherNonBlankString(pair, 'right'),
        );
      })
      .toList(growable: false);
  if (pairs.map((pair) => pair.clientKey.toLowerCase()).toSet().length !=
      pairs.length) {
    throw const FormatException(
      'Teacher Matching Question contains duplicate client keys.',
    );
  }
  return TeacherMatchingQuestionConfiguration(pairs: pairs);
}

TeacherOrderingQuestionConfiguration _readOrderingConfiguration(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Ordering Question configuration',
    keys: const {'items'},
  );
  final rawItems = _readList(map, 'items');
  if (rawItems.length < 2) {
    throw const FormatException(
      'Teacher Ordering Question requires at least two items.',
    );
  }
  final items = <TeacherOrderingItem>[];
  for (var index = 0; index < rawItems.length; index += 1) {
    final item = readExactTeacherMap(
      rawItems[index],
      context: 'Teacher Ordering Question item',
      keys: const {'text', 'correct_position'},
    );
    final position = readTeacherInt(item, 'correct_position');
    if (position != index + 1) {
      throw const FormatException(
        'Teacher Ordering Question positions are not canonical.',
      );
    }
    items.add(
      TeacherOrderingItem(
        text: readTeacherNonBlankString(item, 'text'),
        correctPosition: position,
      ),
    );
  }
  return TeacherOrderingQuestionConfiguration(items: items);
}

TeacherFillInBlankQuestionConfiguration _readFillInBlankConfiguration(
  Object? json,
  String prompt,
) {
  final map = readExactTeacherMap(
    json,
    context: 'Teacher Fill in Blank Question configuration',
    keys: const {'blanks'},
  );
  final rawBlanks = _readList(map, 'blanks');
  if (rawBlanks.isEmpty) {
    throw const FormatException(
      'Teacher Fill in Blank Question requires at least one blank.',
    );
  }
  final blanks = <TeacherFillBlank>[];
  for (var index = 0; index < rawBlanks.length; index += 1) {
    final blank = readExactTeacherMap(
      rawBlanks[index],
      context: 'Teacher Fill in Blank Question blank',
      keys: const {'key', 'position', 'accepted_answers'},
    );
    final key = readTeacherNonBlankString(blank, 'key');
    final position = readTeacherInt(blank, 'position');
    final answers = _readNonBlankStrings(blank, 'accepted_answers');
    if (!_fillBlankKeyPattern.hasMatch(key) ||
        position != index + 1 ||
        answers.isEmpty) {
      throw const FormatException(
        'Teacher Fill in Blank Question blank is not canonical.',
      );
    }
    blanks.add(
      TeacherFillBlank(key: key, position: position, acceptedAnswers: answers),
    );
  }
  final configuredKeys = blanks.map((blank) => blank.key).toSet();
  if (configuredKeys.length != blanks.length) {
    throw const FormatException(
      'Teacher Fill in Blank Question contains duplicate keys.',
    );
  }
  final placeholderKeys = _fillBlankPlaceholderPattern
      .allMatches(prompt)
      .map((match) => match.group(1)!)
      .toList(growable: false);
  if (placeholderKeys.length != configuredKeys.length ||
      placeholderKeys.toSet().length != placeholderKeys.length ||
      placeholderKeys.toSet().difference(configuredKeys).isNotEmpty ||
      configuredKeys.difference(placeholderKeys.toSet()).isNotEmpty) {
    throw const FormatException(
      'Teacher Fill in Blank placeholders do not match configuration.',
    );
  }
  return TeacherFillInBlankQuestionConfiguration(blanks: blanks);
}

List<Object?> _readList(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! List) {
    throw FormatException('$key must be an array.');
  }
  return List<Object?>.unmodifiable(value);
}

List<String> _readStringList(Map<String, Object?> map, String key) {
  final values = _readList(map, key);
  if (values.any((value) => value is! String)) {
    throw FormatException('$key must contain only strings.');
  }
  return List<String>.unmodifiable(values.cast<String>());
}

List<String> _readNonBlankStrings(Map<String, Object?> map, String key) {
  final values = _readStringList(map, key);
  if (values.any((value) => value.trim().isEmpty)) {
    throw FormatException('$key must contain only non-blank strings.');
  }
  return values;
}

const _questionKeys = <String>{
  'id',
  'type',
  'prompt',
  'instructions',
  'points',
  'position',
  'checking_mode',
  'configuration',
};

final _fillBlankKeyPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,79}$');
final _fillBlankPlaceholderPattern = RegExp(
  r'\{\{([A-Za-z][A-Za-z0-9_-]{0,79})\}\}',
);
