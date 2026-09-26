import 'student_blitz_attempt.dart';
import 'student_blitz_submit.dart';

/// High-risk Student Blitz execution mutation; there is no Attempt read.
abstract interface class StudentBlitzAttemptRepository {
  Future<StudentBlitzAttemptStartResult> start(
    String blitzId,
    StudentBlitzAttemptRequest request,
  );

  /// Final Submit through the shared Attempt endpoint. [expectation] only
  /// selects which success the response may prove; it is never sent.
  Future<StudentBlitzSubmitResult> submitAttempt(
    String attemptId,
    String expectedBlitzId,
    String idempotencyKey, {
    required StudentBlitzSubmitResponseExpectation expectation,
  });
}
