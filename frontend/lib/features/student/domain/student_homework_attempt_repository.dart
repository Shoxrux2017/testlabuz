import 'student_homework_attempt.dart';

abstract interface class StudentHomeworkAttemptRepository {
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  );

  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId);
}
