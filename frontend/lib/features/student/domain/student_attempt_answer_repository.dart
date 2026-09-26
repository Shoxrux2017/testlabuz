import 'student_answer_mutation.dart';
import 'student_question.dart';
import 'student_submission_upload.dart';

/// Answer mutation shared by every Student Attempt, whatever its Assessment.
abstract interface class StudentAttemptAnswerRepository {
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
