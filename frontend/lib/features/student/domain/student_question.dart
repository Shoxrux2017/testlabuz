enum StudentQuestionType {
  singleChoice('single_choice'),
  multipleChoice('multiple_choice'),
  trueFalse('true_false'),
  shortWritten('short_written'),
  openWritten('open_written'),
  fileBased('file_based'),
  matching('matching'),
  ordering('ordering'),
  fillInBlank('fill_in_blank');

  const StudentQuestionType(this.apiValue);
  final String apiValue;

  static StudentQuestionType parse(String value) => switch (value) {
    'single_choice' => singleChoice,
    'multiple_choice' => multipleChoice,
    'true_false' => trueFalse,
    'short_written' => shortWritten,
    'open_written' => openWritten,
    'file_based' => fileBased,
    'matching' => matching,
    'ordering' => ordering,
    'fill_in_blank' => fillInBlank,
    _ => throw const FormatException('Unsupported Student Question type.'),
  };
}

class StudentQuestion {
  const StudentQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.instructions,
    required this.points,
    required this.position,
    required this.answerUi,
  });

  final String id;
  final StudentQuestionType type;
  final String prompt;
  final String? instructions;
  final double points;
  final int position;
  final StudentAnswerUi answerUi;
}

sealed class StudentAnswerUi {
  const StudentAnswerUi();
}

class StudentChoiceOption {
  const StudentChoiceOption({required this.id, required this.text});

  final String id;
  final String text;
}

class StudentChoiceAnswerUi extends StudentAnswerUi {
  StudentChoiceAnswerUi({
    required List<StudentChoiceOption> options,
    this.maxSelections,
  }) : options = List<StudentChoiceOption>.unmodifiable(options);

  final List<StudentChoiceOption> options;
  final int? maxSelections;
}

class StudentEmptyAnswerUi extends StudentAnswerUi {
  const StudentEmptyAnswerUi();
}

class StudentFileAnswerUi extends StudentAnswerUi {
  StudentFileAnswerUi({
    required List<String> allowedExtensions,
    required this.maxSizeBytes,
  }) : allowedExtensions = List<String>.unmodifiable(allowedExtensions);

  final List<String> allowedExtensions;
  final int maxSizeBytes;
}

class StudentMatchingItem {
  const StudentMatchingItem({required this.id, required this.text});

  final String id;
  final String text;
}

class StudentMatchingAnswerUi extends StudentAnswerUi {
  StudentMatchingAnswerUi({
    required List<StudentMatchingItem> leftItems,
    required List<StudentMatchingItem> rightItems,
  }) : leftItems = List<StudentMatchingItem>.unmodifiable(leftItems),
       rightItems = List<StudentMatchingItem>.unmodifiable(rightItems);

  final List<StudentMatchingItem> leftItems;
  final List<StudentMatchingItem> rightItems;
}

class StudentOrderingItem {
  const StudentOrderingItem({required this.id, required this.text});

  final String id;
  final String text;
}

class StudentOrderingAnswerUi extends StudentAnswerUi {
  StudentOrderingAnswerUi({required List<StudentOrderingItem> items})
    : items = List<StudentOrderingItem>.unmodifiable(items);

  final List<StudentOrderingItem> items;
}

class StudentFillBlank {
  const StudentFillBlank({
    required this.id,
    required this.key,
    required this.position,
  });

  final String id;
  final String key;
  final int position;
}

class StudentFillBlankAnswerUi extends StudentAnswerUi {
  StudentFillBlankAnswerUi({required List<StudentFillBlank> blanks})
    : blanks = List<StudentFillBlank>.unmodifiable(blanks);

  final List<StudentFillBlank> blanks;
}
