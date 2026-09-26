import 'student_blitz_attempt.dart';

/// High-risk Student Blitz execution mutation; there is no Attempt read.
abstract interface class StudentBlitzAttemptRepository {
  Future<StudentBlitzAttemptStartResult> start(
    String blitzId,
    StudentBlitzAttemptRequest request,
  );
}
