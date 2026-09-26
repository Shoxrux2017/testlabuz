import 'student_question.dart';

/// Saved Student answer states shared by Homework and Blitz Attempts.
class StudentAttemptAnswerState {
  const StudentAttemptAnswerState({
    required this.questionId,
    required this.type,
    required this.value,
    required this.updatedAt,
  });

  final String questionId;
  final StudentQuestionType type;
  final StudentAttemptAnswerValue value;
  final DateTime updatedAt;
}

sealed class StudentAttemptAnswerValue {
  const StudentAttemptAnswerValue();
}

class StudentChoiceAnswerValue extends StudentAttemptAnswerValue {
  StudentChoiceAnswerValue({required List<String> selectedOptionIds})
    : selectedOptionIds = List<String>.unmodifiable(selectedOptionIds);

  final List<String> selectedOptionIds;
}

class StudentBooleanAnswerValue extends StudentAttemptAnswerValue {
  const StudentBooleanAnswerValue({required this.value});
  final bool value;
}

class StudentTextAnswerValue extends StudentAttemptAnswerValue {
  const StudentTextAnswerValue({required this.text});
  final String text;
}

class StudentMatchingAnswerPair {
  const StudentMatchingAnswerPair({
    required this.leftItemId,
    required this.rightItemId,
  });

  final String leftItemId;
  final String rightItemId;
}

class StudentMatchingAnswerValue extends StudentAttemptAnswerValue {
  StudentMatchingAnswerValue({required List<StudentMatchingAnswerPair> pairs})
    : pairs = List<StudentMatchingAnswerPair>.unmodifiable(pairs);

  final List<StudentMatchingAnswerPair> pairs;
}

class StudentOrderingAnswerItem {
  const StudentOrderingAnswerItem({
    required this.itemId,
    required this.position,
  });
  final String itemId;
  final int position;
}

class StudentOrderingAnswerValue extends StudentAttemptAnswerValue {
  StudentOrderingAnswerValue({required List<StudentOrderingAnswerItem> items})
    : items = List<StudentOrderingAnswerItem>.unmodifiable(items);

  final List<StudentOrderingAnswerItem> items;
}

class StudentFillBlankAnswerEntry {
  const StudentFillBlankAnswerEntry({
    required this.blankId,
    required this.text,
  });
  final String blankId;
  final String text;
}

class StudentFillBlankAnswerValue extends StudentAttemptAnswerValue {
  StudentFillBlankAnswerValue({
    required List<StudentFillBlankAnswerEntry> values,
  }) : values = List<StudentFillBlankAnswerEntry>.unmodifiable(values);

  final List<StudentFillBlankAnswerEntry> values;
}

class StudentSubmissionFile {
  const StudentSubmissionFile({
    required this.id,
    required this.originalName,
    required this.extension,
    required this.sizeBytes,
  });

  final String id;
  final String originalName;
  final String extension;
  final int sizeBytes;
}

class StudentFileAnswerValue extends StudentAttemptAnswerValue {
  const StudentFileAnswerValue({required this.file});
  final StudentSubmissionFile file;
}
