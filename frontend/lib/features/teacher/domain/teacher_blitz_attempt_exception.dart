/// Why a Teacher grants one additional Blitz attempt; never a score reason.
enum TeacherBlitzAttemptExceptionReasonType {
  technical('technical'),
  otherValid('other_valid');

  const TeacherBlitzAttemptExceptionReasonType(this.value);

  final String value;

  static TeacherBlitzAttemptExceptionReasonType parse(String value) {
    return switch (value) {
      'technical' => TeacherBlitzAttemptExceptionReasonType.technical,
      'other_valid' => TeacherBlitzAttemptExceptionReasonType.otherValid,
      _ => throw const FormatException(
        'Unsupported Blitz attempt exception reason type.',
      ),
    };
  }
}

/// Longest reason, counted in Unicode code points as the backend does.
const teacherBlitzAttemptExceptionReasonMaxLength = 4000;

/// Whether [reason] is a valid stored/returned exception reason.
bool isValidTeacherBlitzAttemptExceptionReason(String reason) =>
    reason.trim().isNotEmpty &&
    reason.runes.length <= teacherBlitzAttemptExceptionReasonMaxLength;

/// One immutable grant body: the Student and Attempt come from the route.
class TeacherBlitzAttemptExceptionRequest {
  factory TeacherBlitzAttemptExceptionRequest({
    required TeacherBlitzAttemptExceptionReasonType reasonType,
    required String reason,
  }) {
    final error = validateReason(reason);
    if (error != null) {
      throw ArgumentError.value(reason, 'reason', error);
    }
    return TeacherBlitzAttemptExceptionRequest._(reasonType, reason.trim());
  }

  const TeacherBlitzAttemptExceptionRequest._(this.reasonType, this.reason);

  final TeacherBlitzAttemptExceptionReasonType reasonType;

  /// Trimmed reason; the trimmed value is what is sent and fingerprinted.
  final String reason;

  static String? validateReason(String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      return 'Enter a reason.';
    }
    if (trimmed.runes.length > teacherBlitzAttemptExceptionReasonMaxLength) {
      return 'Use no more than '
          '$teacherBlitzAttemptExceptionReasonMaxLength characters.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'reason_type': reasonType.value,
    'reason': reason,
  };
}

/// Where the granted replacement attempt stands in the grant resource.
enum TeacherBlitzAttemptExceptionReplacementState {
  /// Not started and the Student may still start it.
  available,

  /// Not started and the Blitz no longer allows starting it.
  noLongerAvailable,

  /// The Student already started the replacement attempt.
  started,
}

/// The grant/replay resource. Unlike Active monitoring, it may describe a
/// historical grant whose replacement can no longer be started.
class TeacherBlitzAttemptException {
  const TeacherBlitzAttemptException({
    required this.id,
    required this.blitzId,
    required this.studentId,
    required this.invalidatedAttemptId,
    required this.replacementAttemptId,
    required this.reasonType,
    required this.reason,
    required this.grantedAt,
    required this.replacementAttemptAvailable,
  });

  final String id;
  final String blitzId;
  final String studentId;
  final String invalidatedAttemptId;
  final String? replacementAttemptId;
  final TeacherBlitzAttemptExceptionReasonType reasonType;
  final String reason;
  final DateTime grantedAt;
  final bool replacementAttemptAvailable;

  TeacherBlitzAttemptExceptionReplacementState get replacementState =>
      replacementAttemptId != null
      ? TeacherBlitzAttemptExceptionReplacementState.started
      : replacementAttemptAvailable
      ? TeacherBlitzAttemptExceptionReplacementState.available
      : TeacherBlitzAttemptExceptionReplacementState.noLongerAvailable;
}

/// The grant POST outcome is unknown; only a same-key Retry or a monitoring
/// check may resolve it.
class TeacherBlitzAttemptExceptionOutcomeUnknownException implements Exception {
  const TeacherBlitzAttemptExceptionOutcomeUnknownException();
}
