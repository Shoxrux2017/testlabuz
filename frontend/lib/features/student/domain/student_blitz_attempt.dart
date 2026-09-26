import 'student_attempt_answer.dart';
import 'student_blitz.dart';
import 'student_question.dart';
import 'student_topic.dart';

enum StudentBlitzAttemptStatus {
  inProgress('in_progress'),
  submitted('submitted'),
  timedOutFinalized('timed_out_finalized'),
  waitingForReview('waiting_for_teacher_review'),
  checked('checked');

  const StudentBlitzAttemptStatus(this.apiValue);
  final String apiValue;

  static StudentBlitzAttemptStatus parse(String value) => switch (value) {
    'in_progress' => inProgress,
    'submitted' => submitted,
    'timed_out_finalized' => timedOutFinalized,
    'waiting_for_teacher_review' => waitingForReview,
    'checked' => checked,
    _ => throw const FormatException('Unsupported Blitz Attempt status.'),
  };
}

enum StudentBlitzAttemptFinalizationReason {
  studentSubmit('student_submit'),
  timeout('timeout_auto_submit'),
  taskClosed('task_closed_auto_finalize');

  const StudentBlitzAttemptFinalizationReason(this.apiValue);
  final String apiValue;

  static StudentBlitzAttemptFinalizationReason parse(String value) =>
      switch (value) {
        'student_submit' => studentSubmit,
        'timeout_auto_submit' => timeout,
        'task_closed_auto_finalize' => taskClosed,
        _ => throw const FormatException(
          'Unsupported Blitz Attempt finalization reason.',
        ),
      };
}

class StudentBlitzAttemptTiming {
  const StudentBlitzAttemptTiming({
    required this.serverNow,
    required this.mode,
    required this.remainingSeconds,
  });

  final DateTime serverNow;
  final StudentBlitzTimerMode mode;
  final int remainingSeconds;
}

class StudentBlitzAttempt {
  StudentBlitzAttempt({
    required this.id,
    required this.assessmentId,
    required this.attemptNumber,
    required this.status,
    required this.startedAt,
    required this.deadlineAt,
    required this.submittedAt,
    required this.finalizedAt,
    required this.finalizationReason,
    required this.timing,
    required List<StudentQuestion> questions,
    required List<StudentAttemptAnswerState> answers,
  }) : assert(attemptNumber == 1 || attemptNumber == 2),
       questions = List<StudentQuestion>.unmodifiable(questions),
       answers = List<StudentAttemptAnswerState>.unmodifiable(answers);

  final String id;
  final String assessmentId;

  /// `1` is the normal Attempt; `2` is the approved exception replacement.
  final int attemptNumber;
  final StudentBlitzAttemptStatus status;
  final DateTime startedAt;
  final DateTime deadlineAt;
  final DateTime? submittedAt;
  final DateTime? finalizedAt;
  final StudentBlitzAttemptFinalizationReason? finalizationReason;
  final StudentBlitzAttemptTiming timing;
  final List<StudentQuestion> questions;
  final List<StudentAttemptAnswerState> answers;
}

enum StudentBlitzAttemptStartResultKind { created, resumed }

class StudentBlitzAttemptStartResult {
  const StudentBlitzAttemptStartResult({
    required this.attempt,
    required this.resultKind,
  });

  final StudentBlitzAttempt attempt;
  final StudentBlitzAttemptStartResultKind resultKind;
}

enum StudentBlitzAttemptIntent {
  startNormal('start_normal'),
  resume('resume'),
  startReplacement('start_replacement');

  const StudentBlitzAttemptIntent(this.apiValue);
  final String apiValue;
}

/// One frozen logical execution request: intent, exact Attempt and key.
///
/// An uncertain Retry resends this same value; it is never rebuilt from a
/// newer detail, so a stale Resume cannot turn into a replacement Start.
class StudentBlitzAttemptRequest {
  factory StudentBlitzAttemptRequest.startNormal({
    required String idempotencyKey,
  }) => StudentBlitzAttemptRequest._validated(
    StudentBlitzAttemptIntent.startNormal,
    null,
    idempotencyKey,
  );

  factory StudentBlitzAttemptRequest.resume({
    required String attemptId,
    required String idempotencyKey,
  }) {
    if (!_isCanonicalUuid(attemptId)) {
      throw ArgumentError.value(
        attemptId,
        'attemptId',
        'Resume requires a canonical Attempt UUID.',
      );
    }
    return StudentBlitzAttemptRequest._validated(
      StudentBlitzAttemptIntent.resume,
      attemptId.toLowerCase(),
      idempotencyKey,
    );
  }

  factory StudentBlitzAttemptRequest.startReplacement({
    required String idempotencyKey,
  }) => StudentBlitzAttemptRequest._validated(
    StudentBlitzAttemptIntent.startReplacement,
    null,
    idempotencyKey,
  );

  factory StudentBlitzAttemptRequest._validated(
    StudentBlitzAttemptIntent intent,
    String? attemptId,
    String idempotencyKey,
  ) {
    if (!_isCanonicalUuid(idempotencyKey)) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
        'Must be a canonical UUID.',
      );
    }
    return StudentBlitzAttemptRequest._(intent, attemptId, idempotencyKey);
  }

  const StudentBlitzAttemptRequest._(
    this.intent,
    this.attemptId,
    this.idempotencyKey,
  );

  final StudentBlitzAttemptIntent intent;

  /// Non-null only for [StudentBlitzAttemptIntent.resume].
  final String? attemptId;
  final String idempotencyKey;

  Map<String, Object?> toJson() => {
    'intent': intent.apiValue,
    if (intent == StudentBlitzAttemptIntent.resume) 'attempt_id': attemptId,
  };
}

/// Whether a transport-valid `200/201` is authoritative for the exact pending
/// request. Server state advancing never authorizes a cross-intent result: a
/// normal Start is only #1, a replacement Start only #2, and a Resume only a
/// `200` with the requested Attempt (which may meanwhile be terminal).
bool isAcceptedStudentBlitzStartResult({
  required StudentBlitzAttemptRequest request,
  required String blitzId,
  required StudentBlitzAttemptStartResult result,
  StudentBlitzTimerMode? expectedMode,
}) {
  final attempt = result.attempt;
  if (attempt.assessmentId.toLowerCase() != blitzId.toLowerCase() ||
      (expectedMode != null && attempt.timing.mode != expectedMode)) {
    return false;
  }
  return switch (request.intent) {
    StudentBlitzAttemptIntent.startNormal => attempt.attemptNumber == 1,
    StudentBlitzAttemptIntent.startReplacement => attempt.attemptNumber == 2,
    StudentBlitzAttemptIntent.resume =>
      result.resultKind == StudentBlitzAttemptStartResultKind.resumed &&
          attempt.id.toLowerCase() == request.attemptId,
  };
}

bool _isCanonicalUuid(String value) =>
    canonicalStudentTopicIdPattern.hasMatch(value);
