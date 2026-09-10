import 'student_homework_attempt.dart';
import 'student_question.dart';

sealed class StudentAnswerMutation {
  const StudentAnswerMutation();

  StudentQuestionType get type;
  Map<String, Object?> toJson();
}

class StudentSingleChoiceMutation extends StudentAnswerMutation {
  const StudentSingleChoiceMutation({required this.selectedOptionId});

  final String selectedOptionId;
  @override
  StudentQuestionType get type => StudentQuestionType.singleChoice;
  @override
  Map<String, Object?> toJson() => {
    'type': type.apiValue,
    'selected_option_ids': [selectedOptionId],
  };
}

class StudentMultipleChoiceMutation extends StudentAnswerMutation {
  StudentMultipleChoiceMutation({required List<String> selectedOptionIds})
    : selectedOptionIds = List.unmodifiable(selectedOptionIds);

  final List<String> selectedOptionIds;
  @override
  StudentQuestionType get type => StudentQuestionType.multipleChoice;
  @override
  Map<String, Object?> toJson() => {
    'type': type.apiValue,
    'selected_option_ids': selectedOptionIds,
  };
}

class StudentTrueFalseMutation extends StudentAnswerMutation {
  const StudentTrueFalseMutation({required this.value});

  final bool value;
  @override
  StudentQuestionType get type => StudentQuestionType.trueFalse;
  @override
  Map<String, Object?> toJson() => {'type': type.apiValue, 'value': value};
}

class StudentShortWrittenMutation extends StudentAnswerMutation {
  const StudentShortWrittenMutation({required this.text});

  final String text;
  @override
  StudentQuestionType get type => StudentQuestionType.shortWritten;
  @override
  Map<String, Object?> toJson() => {'type': type.apiValue, 'text': text};
}

class StudentOpenWrittenMutation extends StudentAnswerMutation {
  const StudentOpenWrittenMutation({required this.text});

  final String text;
  @override
  StudentQuestionType get type => StudentQuestionType.openWritten;
  @override
  Map<String, Object?> toJson() => {'type': type.apiValue, 'text': text};
}

class StudentMatchingMutation extends StudentAnswerMutation {
  StudentMatchingMutation({required List<StudentMatchingAnswerPair> pairs})
    : pairs = List.unmodifiable(pairs);

  final List<StudentMatchingAnswerPair> pairs;
  @override
  StudentQuestionType get type => StudentQuestionType.matching;
  @override
  Map<String, Object?> toJson() => {
    'type': type.apiValue,
    'pairs': [
      for (final pair in pairs)
        {'left_item_id': pair.leftItemId, 'right_item_id': pair.rightItemId},
    ],
  };
}

class StudentOrderingMutation extends StudentAnswerMutation {
  StudentOrderingMutation({required List<StudentOrderingAnswerItem> items})
    : items = List.unmodifiable(
        [...items]..sort((a, b) {
          final position = a.position.compareTo(b.position);
          return position != 0 ? position : a.itemId.compareTo(b.itemId);
        }),
      );

  final List<StudentOrderingAnswerItem> items;
  @override
  StudentQuestionType get type => StudentQuestionType.ordering;
  @override
  Map<String, Object?> toJson() => {
    'type': type.apiValue,
    'items': [
      for (final item in items)
        {'item_id': item.itemId, 'position': item.position},
    ],
  };
}

class StudentFillBlankMutation extends StudentAnswerMutation {
  StudentFillBlankMutation({required List<StudentFillBlankAnswerEntry> values})
    : values = List.unmodifiable(values);

  final List<StudentFillBlankAnswerEntry> values;
  @override
  StudentQuestionType get type => StudentQuestionType.fillInBlank;
  @override
  Map<String, Object?> toJson() => {
    'type': type.apiValue,
    'values': [
      for (final value in values)
        {'blank_id': value.blankId, 'text': value.text},
    ],
  };
}

class StudentAttemptAnswerMutationResult {
  const StudentAttemptAnswerMutationResult({
    required this.questionId,
    required this.type,
    required this.answer,
    required this.updatedAt,
  });

  final String questionId;
  final StudentQuestionType type;
  final StudentAttemptAnswerValue? answer;
  final DateTime? updatedAt;
}
