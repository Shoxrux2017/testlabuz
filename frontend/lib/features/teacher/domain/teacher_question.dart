enum TeacherQuestionType {
  singleChoice('single_choice'),
  multipleChoice('multiple_choice'),
  trueFalse('true_false'),
  shortWritten('short_written'),
  openWritten('open_written'),
  fileBased('file_based'),
  matching('matching'),
  ordering('ordering'),
  fillInBlank('fill_in_blank');

  const TeacherQuestionType(this.value);

  final String value;

  static TeacherQuestionType parse(String value) {
    return switch (value) {
      'single_choice' => TeacherQuestionType.singleChoice,
      'multiple_choice' => TeacherQuestionType.multipleChoice,
      'true_false' => TeacherQuestionType.trueFalse,
      'short_written' => TeacherQuestionType.shortWritten,
      'open_written' => TeacherQuestionType.openWritten,
      'file_based' => TeacherQuestionType.fileBased,
      'matching' => TeacherQuestionType.matching,
      'ordering' => TeacherQuestionType.ordering,
      'fill_in_blank' => TeacherQuestionType.fillInBlank,
      _ => throw const FormatException('Unsupported Teacher Question type.'),
    };
  }
}

enum TeacherQuestionCheckingMode {
  automatic('automatic'),
  manual('manual');

  const TeacherQuestionCheckingMode(this.value);

  final String value;

  static TeacherQuestionCheckingMode parse(String value) {
    return switch (value) {
      'automatic' => TeacherQuestionCheckingMode.automatic,
      'manual' => TeacherQuestionCheckingMode.manual,
      _ => throw const FormatException(
        'Unsupported Teacher Question checking mode.',
      ),
    };
  }
}

class TeacherQuestion {
  const TeacherQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.instructions,
    required this.points,
    required this.position,
    required this.checkingMode,
    required this.configuration,
  });

  final String id;
  final TeacherQuestionType type;
  final String prompt;
  final String? instructions;
  final double points;
  final int position;
  final TeacherQuestionCheckingMode checkingMode;
  final TeacherQuestionConfiguration configuration;
}

sealed class TeacherQuestionConfiguration {
  const TeacherQuestionConfiguration();
}

final class TeacherChoiceQuestionConfiguration
    extends TeacherQuestionConfiguration {
  TeacherChoiceQuestionConfiguration({
    required List<TeacherChoiceOption> options,
  }) : options = List<TeacherChoiceOption>.unmodifiable(options);

  final List<TeacherChoiceOption> options;
}

class TeacherChoiceOption {
  const TeacherChoiceOption({
    required this.text,
    required this.isCorrect,
    required this.position,
  });

  final String text;
  final bool isCorrect;
  final int position;
}

final class TeacherTrueFalseQuestionConfiguration
    extends TeacherQuestionConfiguration {
  const TeacherTrueFalseQuestionConfiguration({required this.correctValue});

  final bool correctValue;
}

final class TeacherShortWrittenAutomaticConfiguration
    extends TeacherQuestionConfiguration {
  TeacherShortWrittenAutomaticConfiguration({
    required List<String> acceptedAnswers,
  }) : acceptedAnswers = List<String>.unmodifiable(acceptedAnswers);

  final List<String> acceptedAnswers;
}

final class TeacherEmptyQuestionConfiguration
    extends TeacherQuestionConfiguration {
  const TeacherEmptyQuestionConfiguration();
}

final class TeacherFileBasedQuestionConfiguration
    extends TeacherQuestionConfiguration {
  TeacherFileBasedQuestionConfiguration({
    required List<String> allowedExtensions,
  }) : allowedExtensions = List<String>.unmodifiable(allowedExtensions);

  final List<String> allowedExtensions;
}

final class TeacherMatchingQuestionConfiguration
    extends TeacherQuestionConfiguration {
  TeacherMatchingQuestionConfiguration({
    required List<TeacherMatchingPair> pairs,
  }) : pairs = List<TeacherMatchingPair>.unmodifiable(pairs);

  final List<TeacherMatchingPair> pairs;
}

class TeacherMatchingPair {
  const TeacherMatchingPair({
    required this.clientKey,
    required this.left,
    required this.right,
  });

  final String clientKey;
  final String left;
  final String right;
}

final class TeacherOrderingQuestionConfiguration
    extends TeacherQuestionConfiguration {
  TeacherOrderingQuestionConfiguration({
    required List<TeacherOrderingItem> items,
  }) : items = List<TeacherOrderingItem>.unmodifiable(items);

  final List<TeacherOrderingItem> items;
}

class TeacherOrderingItem {
  const TeacherOrderingItem({
    required this.text,
    required this.correctPosition,
  });

  final String text;
  final int correctPosition;
}

final class TeacherFillInBlankQuestionConfiguration
    extends TeacherQuestionConfiguration {
  TeacherFillInBlankQuestionConfiguration({
    required List<TeacherFillBlank> blanks,
  }) : blanks = List<TeacherFillBlank>.unmodifiable(blanks);

  final List<TeacherFillBlank> blanks;
}

class TeacherFillBlank {
  TeacherFillBlank({
    required this.key,
    required this.position,
    required List<String> acceptedAnswers,
  }) : acceptedAnswers = List<String>.unmodifiable(acceptedAnswers);

  final String key;
  final int position;
  final List<String> acceptedAnswers;
}
