import 'student_answer_mutation.dart';
import 'student_homework_attempt.dart';
import 'student_question.dart';

abstract interface class StudentHomeworkAttemptRepository {
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  );

  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId);

  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  );
}
