import 'student_question.dart';

enum StudentHomeworkAttemptStatus {
  inProgress('in_progress'),
  submitted('submitted'),
  waitingForReview('waiting_for_teacher_review'),
  checked('checked');

  const StudentHomeworkAttemptStatus(this.apiValue);
  final String apiValue;

  static StudentHomeworkAttemptStatus parse(String value) => switch (value) {
    'in_progress' => inProgress,
    'submitted' => submitted,
    'waiting_for_teacher_review' => waitingForReview,
    'checked' => checked,
    _ => throw const FormatException('Unsupported Homework Attempt status.'),
  };
}

enum StudentHomeworkAttemptFinalizationReason {
  studentSubmit('student_submit'),
  homeworkDeadline('homework_deadline_auto_submit'),
  taskClosed('task_closed_auto_finalize');

  const StudentHomeworkAttemptFinalizationReason(this.apiValue);
  final String apiValue;

  static StudentHomeworkAttemptFinalizationReason parse(String value) =>
      switch (value) {
        'student_submit' => studentSubmit,
        'homework_deadline_auto_submit' => homeworkDeadline,
        'task_closed_auto_finalize' => taskClosed,
        _ => throw const FormatException(
          'Unsupported Homework Attempt finalization reason.',
        ),
      };
}

class StudentHomeworkAttempt {
  StudentHomeworkAttempt({
    required this.id,
    required this.assessmentId,
    required this.attemptNumber,
    required this.status,
    required this.startedAt,
    required this.submittedAt,
    required this.finalizedAt,
    required this.finalizationReason,
    required this.deadlineAt,
    required List<StudentQuestion> questions,
    required List<StudentAttemptAnswerState> answers,
  }) : assert(attemptNumber >= 1 && attemptNumber <= 3),
       questions = List<StudentQuestion>.unmodifiable(questions),
       answers = List<StudentAttemptAnswerState>.unmodifiable(answers);

  final String id;
  final String assessmentId;
  final int attemptNumber;
  final StudentHomeworkAttemptStatus status;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime? finalizedAt;
  final StudentHomeworkAttemptFinalizationReason? finalizationReason;
  final DateTime? deadlineAt;
  final List<StudentQuestion> questions;
  final List<StudentAttemptAnswerState> answers;
}

enum StudentHomeworkAttemptStartResultKind { created, resumed }

class StudentHomeworkAttemptStartResult {
  const StudentHomeworkAttemptStartResult({
    required this.attempt,
    required this.resultKind,
  });

  final StudentHomeworkAttempt attempt;
  final StudentHomeworkAttemptStartResultKind resultKind;
}

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
