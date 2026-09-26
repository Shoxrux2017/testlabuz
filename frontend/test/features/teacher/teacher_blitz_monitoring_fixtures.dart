import 'package:testlabuz_client/features/teacher/data/dto/teacher_blitz_attempt_exception_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_blitz_monitoring_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_attempt_exception.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_monitoring.dart';

import 'teacher_blitz_json_fixtures.dart';

const monitoringStudentA = 'a1000000-0000-0000-0000-000000000001';
const monitoringStudentB = 'a1000000-0000-0000-0000-000000000002';
const monitoringStudentC = 'a1000000-0000-0000-0000-000000000003';
const monitoringAttemptOne = 'a2000000-0000-0000-0000-000000000001';
const monitoringAttemptTwo = 'a2000000-0000-0000-0000-000000000002';
const monitoringExceptionId = 'a3000000-0000-0000-0000-000000000001';

Map<String, Object?> monitoringBlitzJson({
  String id = blitzJsonId,
  String status = 'active',
  int durationSeconds = blitzJsonDurationSeconds,
  String activatedAt = blitzJsonActivatedAt,
  String mode = 'synchronized',
  String? synchronizedEndsAt = blitzJsonSynchronizedEndsAt,
  String serverNow = '2026-09-18T04:05:00Z',
}) => {
  'id': id,
  'status': status,
  'duration_seconds': durationSeconds,
  'activated_at': activatedAt,
  'timing': {
    'mode': mode,
    'synchronized_ends_at': synchronizedEndsAt,
    'server_now': serverNow,
  },
};

Map<String, Object?> monitoringExceptionJson({
  String id = monitoringExceptionId,
  String invalidatedAttemptId = monitoringAttemptOne,
  String? replacementAttemptId,
  String reasonType = 'technical',
  String reason = 'The device lost power.',
  String grantedAt = '2026-09-18T04:06:00Z',
  bool? replacementAttemptAvailable,
}) => {
  'id': id,
  'invalidated_attempt_id': invalidatedAttemptId,
  'replacement_attempt_id': replacementAttemptId,
  'reason_type': reasonType,
  'reason': reason,
  'granted_at': grantedAt,
  'replacement_attempt_available':
      replacementAttemptAvailable ?? replacementAttemptId == null,
};

Map<String, Object?> monitoringRowJson(
  String studentId, {
  String fullName = 'Student Name',
  String status = 'not_started',
  int? attemptNumber,
  String? startedAt,
  String? deadlineAt,
  int? remainingSeconds,
  String? finalizationReason,
  Object? score,
  Map<String, Object?>? attemptException,
}) => {
  'student': {'id': studentId, 'full_name': fullName},
  'status': status,
  'attempt_number': attemptNumber,
  'started_at': startedAt,
  'deadline_at': deadlineAt,
  'remaining_seconds': remainingSeconds,
  'finalization_reason': finalizationReason,
  'score': score,
  'attempt_exception': attemptException,
};

Map<String, Object?> notStartedRowJson(
  String studentId, {
  String fullName = 'Student Name',
  int? remainingSeconds = 360,
  Map<String, Object?>? attemptException,
}) => monitoringRowJson(
  studentId,
  fullName: fullName,
  remainingSeconds: remainingSeconds,
  attemptException: attemptException,
);

Map<String, Object?> inProgressRowJson(
  String studentId, {
  String fullName = 'Student Name',
  int attemptNumber = 1,
  int remainingSeconds = 360,
  Map<String, Object?>? attemptException,
}) => monitoringRowJson(
  studentId,
  fullName: fullName,
  status: 'in_progress',
  attemptNumber: attemptNumber,
  startedAt: '2026-09-18T04:02:00Z',
  deadlineAt: '2026-09-18T04:11:00Z',
  remainingSeconds: remainingSeconds,
  attemptException: attemptException,
);

Map<String, Object?> terminalRowJson(
  String studentId, {
  String fullName = 'Student Name',
  String status = 'finalized',
  int attemptNumber = 1,
  String finalizationReason = 'student_submit',
  Map<String, Object?>? attemptException,
}) => monitoringRowJson(
  studentId,
  fullName: fullName,
  status: status,
  attemptNumber: attemptNumber,
  startedAt: '2026-09-18T04:02:00Z',
  deadlineAt: '2026-09-18T04:11:00Z',
  remainingSeconds: 0,
  finalizationReason: finalizationReason,
  attemptException: attemptException,
);

/// A monitoring envelope whose summary is derived from [students] unless
/// [summary] overrides it.
Map<String, Object?> monitoringJson({
  Map<String, Object?>? blitz,
  List<Map<String, Object?>>? students,
  Map<String, Object?>? summary,
}) {
  final rows = students ?? [notStartedRowJson(monitoringStudentA)];
  int count(String status) =>
      rows.where((row) => row['status'] == status).length;
  return {
    'data': {
      'blitz': blitz ?? monitoringBlitzJson(),
      'summary':
          summary ??
          {
            'assigned': rows.length,
            'not_started': count('not_started'),
            'in_progress': count('in_progress'),
            'finalized': count('finalized'),
            'waiting_for_teacher_review': count('waiting_for_teacher_review'),
            'attempt_exceptions_granted': rows
                .where((row) => row['attempt_exception'] != null)
                .length,
          },
      'students': rows,
    },
  };
}

Map<String, Object?> grantJson({
  String blitzId = blitzJsonId,
  String studentId = monitoringStudentA,
  String? replacementAttemptId,
  bool replacementAttemptAvailable = true,
  String reasonType = 'technical',
  String reason = 'The device lost power.',
  String message = 'One additional Blitz attempt has been granted.',
}) => {
  'data': {
    'id': monitoringExceptionId,
    'blitz_id': blitzId,
    'student_id': studentId,
    'invalidated_attempt_id': monitoringAttemptOne,
    'replacement_attempt_id': replacementAttemptId,
    'reason_type': reasonType,
    'reason': reason,
    'granted_at': '2026-09-18T04:06:00Z',
    'replacement_attempt_available': replacementAttemptAvailable,
  },
  'message': message,
};

/// A strictly parsed monitoring snapshot, so every test fixture is a snapshot
/// the real DTO accepts.
TeacherBlitzMonitoring teacherMonitoring({
  String blitzId = blitzJsonId,
  String mode = 'synchronized',
  String serverNow = '2026-09-18T04:05:00Z',
  List<Map<String, Object?>>? students,
}) => TeacherBlitzMonitoringDto.fromJson(
  monitoringJson(
    blitz: monitoringBlitzJson(
      id: blitzId,
      mode: mode,
      synchronizedEndsAt: mode == 'synchronized'
          ? blitzJsonSynchronizedEndsAt
          : null,
      serverNow: serverNow,
    ),
    students: students,
  ),
).toDomain();

TeacherBlitzAttemptException teacherGrant({
  String blitzId = blitzJsonId,
  String studentId = monitoringStudentA,
  String? replacementAttemptId,
  bool? replacementAttemptAvailable,
}) => TeacherBlitzAttemptExceptionDto.fromJson(
  grantJson(
    blitzId: blitzId,
    studentId: studentId,
    replacementAttemptId: replacementAttemptId,
    replacementAttemptAvailable:
        replacementAttemptAvailable ?? replacementAttemptId == null,
  ),
  expectedBlitzId: blitzId,
  expectedStudentId: studentId,
).toDomain();
