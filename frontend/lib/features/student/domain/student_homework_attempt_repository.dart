import 'student_answer_mutation.dart';
import 'student_homework_attempt.dart';
import 'student_homework_submit.dart';
import 'student_question.dart';
import 'student_submission_upload.dart';

abstract interface class StudentHomeworkAttemptRepository {
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  );

  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId);

  Future<StudentHomeworkSubmitResult> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  );

  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  );

  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  });
}
