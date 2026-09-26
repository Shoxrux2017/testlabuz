import 'student_attempt_answer.dart';
import 'student_question.dart';

export 'student_attempt_answer.dart';

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
