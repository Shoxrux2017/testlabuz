import 'teacher_blitz.dart';
import 'teacher_blitz_attempt_exception.dart';

/// Operational Student state; not the raw Attempt persistence status.
enum TeacherBlitzMonitoringStudentStatus {
  notStarted('not_started'),
  inProgress('in_progress'),
  finalized('finalized'),
  waitingForTeacherReview('waiting_for_teacher_review');

  const TeacherBlitzMonitoringStudentStatus(this.value);

  final String value;

  static TeacherBlitzMonitoringStudentStatus parse(String value) {
    return switch (value) {
      'not_started' => TeacherBlitzMonitoringStudentStatus.notStarted,
      'in_progress' => TeacherBlitzMonitoringStudentStatus.inProgress,
      'finalized' => TeacherBlitzMonitoringStudentStatus.finalized,
      'waiting_for_teacher_review' =>
        TeacherBlitzMonitoringStudentStatus.waitingForTeacherReview,
      _ => throw const FormatException(
        'Unsupported Blitz monitoring Student status.',
      ),
    };
  }

  bool get isTerminal =>
      this == TeacherBlitzMonitoringStudentStatus.finalized ||
      this == TeacherBlitzMonitoringStudentStatus.waitingForTeacherReview;
}

enum TeacherBlitzMonitoringFinalizationReason {
  studentSubmit('student_submit'),
  timeout('timeout_auto_submit'),
  taskClosed('task_closed_auto_finalize');

  const TeacherBlitzMonitoringFinalizationReason(this.value);

  final String value;

  static TeacherBlitzMonitoringFinalizationReason parse(String value) {
    return switch (value) {
      'student_submit' =>
        TeacherBlitzMonitoringFinalizationReason.studentSubmit,
      'timeout_auto_submit' => TeacherBlitzMonitoringFinalizationReason.timeout,
      'task_closed_auto_finalize' =>
        TeacherBlitzMonitoringFinalizationReason.taskClosed,
      _ => throw const FormatException(
        'Unsupported Blitz finalization reason.',
      ),
    };
  }
}

class TeacherBlitzMonitoringTiming {
  const TeacherBlitzMonitoringTiming({
    required this.mode,
    required this.synchronizedEndsAt,
    required this.serverNow,
  });

  final TeacherBlitzTimerStartMode mode;
  final DateTime? synchronizedEndsAt;

  /// The server snapshot instant; never replaced by device time.
  final DateTime serverNow;
}

class TeacherBlitzMonitoringBlitz {
  const TeacherBlitzMonitoringBlitz({
    required this.id,
    required this.status,
    required this.durationSeconds,
    required this.activatedAt,
    required this.timing,
  });

  final String id;
  final TeacherBlitzStatus status;
  final int durationSeconds;
  final DateTime activatedAt;
  final TeacherBlitzMonitoringTiming timing;
}

class TeacherBlitzMonitoringSummary {
  const TeacherBlitzMonitoringSummary({
    required this.assigned,
    required this.notStarted,
    required this.inProgress,
    required this.finalized,
    required this.waitingForTeacherReview,
    required this.attemptExceptionsGranted,
  });

  final int assigned;
  final int notStarted;
  final int inProgress;
  final int finalized;
  final int waitingForTeacherReview;
  final int attemptExceptionsGranted;
}

class TeacherBlitzMonitoringStudentIdentity {
  const TeacherBlitzMonitoringStudentIdentity({
    required this.id,
    required this.fullName,
  });

  final String id;
  final String fullName;
}

/// An exception as Active monitoring shows it; its replacement is either
/// still available or already started.
class TeacherBlitzMonitoringAttemptException {
  const TeacherBlitzMonitoringAttemptException({
    required this.id,
    required this.invalidatedAttemptId,
    required this.replacementAttemptId,
    required this.reasonType,
    required this.reason,
    required this.grantedAt,
    required this.replacementAttemptAvailable,
  });

  final String id;
  final String invalidatedAttemptId;
  final String? replacementAttemptId;
  final TeacherBlitzAttemptExceptionReasonType reasonType;
  final String reason;
  final DateTime grantedAt;
  final bool replacementAttemptAvailable;
}

/// One assigned Student's current operational state. There is no score.
class TeacherBlitzMonitoringStudent {
  const TeacherBlitzMonitoringStudent({
    required this.student,
    required this.status,
    required this.attemptNumber,
    required this.startedAt,
    required this.deadlineAt,
    required this.remainingSeconds,
    required this.finalizationReason,
    required this.attemptException,
  });

  final TeacherBlitzMonitoringStudentIdentity student;
  final TeacherBlitzMonitoringStudentStatus status;
  final int? attemptNumber;
  final DateTime? startedAt;
  final DateTime? deadlineAt;

  /// Server snapshot; never recomputed from device time.
  final int? remainingSeconds;
  final TeacherBlitzMonitoringFinalizationReason? finalizationReason;
  final TeacherBlitzMonitoringAttemptException? attemptException;

  /// A finalized normal Attempt with no exception yet: a UX hint only, the
  /// backend decides.
  bool get isGrantCandidate =>
      attemptException == null && attemptNumber == 1 && status.isTerminal;
}

class TeacherBlitzMonitoring {
  TeacherBlitzMonitoring({
    required this.blitz,
    required this.summary,
    required List<TeacherBlitzMonitoringStudent> students,
  }) : students = List.unmodifiable(students);

  final TeacherBlitzMonitoringBlitz blitz;
  final TeacherBlitzMonitoringSummary summary;

  /// In server order.
  final List<TeacherBlitzMonitoringStudent> students;

  TeacherBlitzMonitoringStudent? studentById(String studentId) {
    for (final row in students) {
      if (row.student.id.toLowerCase() == studentId.toLowerCase()) {
        return row;
      }
    }
    return null;
  }
}
