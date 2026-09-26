import 'student_blitz_attempt.dart';

/// Which success a Submit `200` may prove. It is frontend operation context
/// for response validation only and is never sent to the backend.
enum StudentBlitzSubmitResponseExpectation {
  /// The first logical Submit POST: only `submitted + student_submit`.
  fresh,

  /// A same-key Retry: the stored Submit replayed on the current Attempt,
  /// which may meanwhile be waiting for review or checked.
  completedReplay,
}

class StudentBlitzSubmitResult {
  const StudentBlitzSubmitResult({required this.attempt});

  /// The complete authoritative terminal Attempt. It carries no score.
  final StudentBlitzAttempt attempt;
}
