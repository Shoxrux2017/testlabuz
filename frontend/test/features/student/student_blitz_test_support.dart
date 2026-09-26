import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_submit.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_test_support.dart';

const studentBlitzId = 'b1000000-0000-0000-0000-000000000001';
const otherStudentBlitzId = 'b1000000-0000-0000-0000-000000000002';
const studentBlitzAttemptId = 'b2000000-0000-0000-0000-000000000001';
const studentBlitzReplacementAttemptId = 'b2000000-0000-0000-0000-000000000002';
const studentBlitzQuestionPrefix = 'b3000000-0000-0000-0000-';

// --- Wire JSON ----------------------------------------------------------------

Map<String, Object?> blitzTopicJson({
  String id = studentTopicId,
  String title = 'Internet Basics',
}) => {'id': id, 'title': title};

Map<String, Object?> blitzAttemptsJson({
  int normalUsed = 0,
  String? inProgressAttemptId,
  bool exceptionGranted = false,
  bool replacementAvailable = false,
}) => {
  'normal_attempts': 1,
  'normal_used': normalUsed,
  'in_progress_attempt_id': inProgressAttemptId,
  'additional_exception_granted': exceptionGranted,
  'replacement_attempt_available': replacementAvailable,
};

Map<String, Object?> blitzTimingJson({
  String mode = 'synchronized',
  String serverNow = '2026-09-17T12:00:00Z',
  String? synchronizedEndsAt = '2026-09-17T12:05:00Z',
  String? deadlineAt = '2026-09-17T12:05:00Z',
  int? remainingSeconds = 300,
}) => {
  'mode': mode,
  'server_now': serverNow,
  'synchronized_ends_at': synchronizedEndsAt,
  'deadline_at': deadlineAt,
  'remaining_seconds': remainingSeconds,
};

/// Legitimate list/detail timing + attempt shapes delivered by the backend.
enum BlitzScenario {
  synchronizedNotStarted,
  synchronizedInProgress,
  individualNotStarted,
  individualInProgress,
  synchronizedReplacementAvailable,
  synchronizedReplacementInProgress,
  individualReplacementAvailable,
  individualReplacementInProgress,
}

(Map<String, Object?>, Map<String, Object?>) blitzScenarioJson(
  BlitzScenario scenario,
) => switch (scenario) {
  BlitzScenario.synchronizedNotStarted => (
    blitzTimingJson(),
    blitzAttemptsJson(),
  ),
  BlitzScenario.synchronizedInProgress => (
    blitzTimingJson(),
    blitzAttemptsJson(
      normalUsed: 1,
      inProgressAttemptId: studentBlitzAttemptId,
    ),
  ),
  BlitzScenario.individualNotStarted => (
    blitzTimingJson(
      mode: 'individual',
      synchronizedEndsAt: null,
      deadlineAt: null,
      remainingSeconds: null,
    ),
    blitzAttemptsJson(),
  ),
  BlitzScenario.individualInProgress => (
    blitzTimingJson(
      mode: 'individual',
      synchronizedEndsAt: null,
      deadlineAt: '2026-09-17T12:10:00Z',
      remainingSeconds: 600,
    ),
    blitzAttemptsJson(
      normalUsed: 1,
      inProgressAttemptId: studentBlitzAttemptId,
    ),
  ),
  BlitzScenario.synchronizedReplacementAvailable => (
    blitzTimingJson(
      serverNow: '2026-09-17T12:10:00Z',
      deadlineAt: null,
      remainingSeconds: null,
    ),
    blitzAttemptsJson(
      normalUsed: 1,
      exceptionGranted: true,
      replacementAvailable: true,
    ),
  ),
  BlitzScenario.synchronizedReplacementInProgress => (
    blitzTimingJson(
      serverNow: '2026-09-17T12:10:00Z',
      deadlineAt: '2026-09-17T12:20:00Z',
      remainingSeconds: 600,
    ),
    blitzAttemptsJson(
      normalUsed: 1,
      inProgressAttemptId: studentBlitzReplacementAttemptId,
      exceptionGranted: true,
    ),
  ),
  BlitzScenario.individualReplacementAvailable => (
    blitzTimingJson(
      mode: 'individual',
      synchronizedEndsAt: null,
      deadlineAt: null,
      remainingSeconds: null,
    ),
    blitzAttemptsJson(
      normalUsed: 1,
      exceptionGranted: true,
      replacementAvailable: true,
    ),
  ),
  BlitzScenario.individualReplacementInProgress => (
    blitzTimingJson(
      mode: 'individual',
      synchronizedEndsAt: null,
      deadlineAt: '2026-09-17T12:10:00Z',
      remainingSeconds: 600,
    ),
    blitzAttemptsJson(
      normalUsed: 1,
      inProgressAttemptId: studentBlitzReplacementAttemptId,
      exceptionGranted: true,
    ),
  ),
};

Map<String, Object?> activeBlitzJson({
  String id = studentBlitzId,
  BlitzScenario scenario = BlitzScenario.synchronizedNotStarted,
}) {
  final (timing, attempts) = blitzScenarioJson(scenario);
  return {
    'id': id,
    'topic': blitzTopicJson(),
    'title': 'Classroom Blitz',
    'status': 'active',
    'duration_seconds': 600,
    'timing': timing,
    'attempts': attempts,
  };
}

Map<String, Object?> blitzDetailJson({
  String id = studentBlitzId,
  BlitzScenario scenario = BlitzScenario.synchronizedNotStarted,
}) {
  final (timing, attempts) = blitzScenarioJson(scenario);
  return {
    'id': id,
    'topic': blitzTopicJson(),
    'title': 'Classroom Blitz',
    'description': 'Timed practice.',
    'student_instructions': 'Answer independently.',
    'status': 'active',
    'duration_seconds': 600,
    'total_possible_points': 5,
    'timing': timing,
    'attempts': attempts,
  };
}

Map<String, Object?> blitzAttemptJson({
  String id = studentBlitzAttemptId,
  String assessmentId = studentBlitzId,
  int attemptNumber = 1,
  String status = 'in_progress',
  String startedAt = '2026-09-17T12:00:00Z',
  String? deadlineAt = '2026-09-17T12:05:00Z',
  String? submittedAt,
  String? finalizedAt,
  String? finalizationReason,
  String mode = 'synchronized',
  String serverNow = '2026-09-17T12:00:00Z',
  int? remainingSeconds = 300,
  List<Object?>? questions,
  List<Object?>? answers,
}) => {
  'id': id,
  'assessment_id': assessmentId,
  'attempt_number': attemptNumber,
  'status': status,
  'started_at': startedAt,
  'deadline_at': deadlineAt,
  'submitted_at': submittedAt,
  'finalized_at': finalizedAt,
  'finalization_reason': finalizationReason,
  'timing': {
    'server_now': serverNow,
    'mode': mode,
    'remaining_seconds': remainingSeconds,
  },
  'questions':
      questions ?? [blitzQuestionJson(StudentQuestionType.trueFalse, 1)],
  'answers': answers ?? <Object?>[],
};

String blitzUuid(int id) =>
    '$studentBlitzQuestionPrefix${id.toString().padLeft(12, '0')}';

Map<String, Object?> _blitzItem(int id) => {
  'id': blitzUuid(id),
  'text': 'Item $id',
};

Map<String, Object?> blitzQuestionJson(
  StudentQuestionType type,
  int position,
) => {
  'id': blitzUuid(100 + position),
  'type': type.apiValue,
  'prompt': 'Blitz prompt $position',
  'instructions': null,
  'points': 1,
  'position': position,
  'answer_ui': switch (type) {
    StudentQuestionType.singleChoice => <String, Object?>{
      'options': [_blitzItem(1), _blitzItem(2)],
    },
    StudentQuestionType.multipleChoice => <String, Object?>{
      'options': [_blitzItem(1), _blitzItem(2)],
      'max_selections': 1,
    },
    StudentQuestionType.trueFalse ||
    StudentQuestionType.shortWritten ||
    StudentQuestionType.openWritten => <String, Object?>{},
    StudentQuestionType.fileBased => <String, Object?>{
      'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
      'max_size_bytes': 15_728_640,
    },
    StudentQuestionType.matching => <String, Object?>{
      'left_items': [_blitzItem(1), _blitzItem(2)],
      'right_items': [_blitzItem(3), _blitzItem(4)],
    },
    StudentQuestionType.ordering => <String, Object?>{
      'items': [_blitzItem(1), _blitzItem(2), _blitzItem(3)],
    },
    StudentQuestionType.fillInBlank => <String, Object?>{
      'blanks': [
        <String, Object?>{'id': blitzUuid(1), 'key': 'blank_1', 'position': 1},
      ],
    },
  },
};

Map<String, Object?> blitzAnswerJson(StudentQuestionType type, int position) =>
    {
      'question_id': blitzUuid(100 + position),
      'type': type.apiValue,
      'updated_at': '2026-09-17T12:01:00Z',
      'answer': switch (type) {
        StudentQuestionType.singleChoice ||
        StudentQuestionType.multipleChoice => <String, Object?>{
          'selected_option_ids': [blitzUuid(1)],
        },
        StudentQuestionType.trueFalse => <String, Object?>{'value': true},
        StudentQuestionType.shortWritten || StudentQuestionType.openWritten =>
          <String, Object?>{'text': '  Exact saved text\n'},
        StudentQuestionType.matching => <String, Object?>{
          'pairs': [
            <String, Object?>{
              'left_item_id': blitzUuid(1),
              'right_item_id': blitzUuid(3),
            },
          ],
        },
        StudentQuestionType.ordering => <String, Object?>{
          'items': [
            <String, Object?>{'item_id': blitzUuid(1), 'position': 2},
          ],
        },
        StudentQuestionType.fillInBlank => <String, Object?>{
          'values': [
            <String, Object?>{'blank_id': blitzUuid(1), 'text': 'Exact blank'},
          ],
        },
        StudentQuestionType.fileBased => <String, Object?>{
          'file': <String, Object?>{
            'id': blitzUuid(99),
            'original_name': 'blitz.pdf',
            'extension': 'pdf',
            'size_bytes': 2048,
          },
        },
      },
    };

// --- Domain -------------------------------------------------------------------

StudentBlitzTiming studentBlitzTiming({
  StudentBlitzTimerMode mode = StudentBlitzTimerMode.synchronized,
  DateTime? serverNow,
  DateTime? synchronizedEndsAt,
  DateTime? deadlineAt,
  int? remainingSeconds = 300,
  bool noDeadline = false,
}) {
  final synchronized = mode == StudentBlitzTimerMode.synchronized;
  return StudentBlitzTiming(
    mode: mode,
    serverNow: serverNow ?? DateTime.utc(2026, 9, 17, 12),
    synchronizedEndsAt: synchronized
        ? synchronizedEndsAt ?? DateTime.utc(2026, 9, 17, 12, 5)
        : null,
    deadlineAt: noDeadline
        ? null
        : deadlineAt ??
              (synchronized ? DateTime.utc(2026, 9, 17, 12, 5) : null),
    remainingSeconds: noDeadline ? null : remainingSeconds,
  );
}

StudentBlitzAttemptSummary studentBlitzAttemptSummary({
  int normalUsed = 0,
  String? inProgressAttemptId,
  bool exceptionGranted = false,
  bool replacementAvailable = false,
}) => StudentBlitzAttemptSummary(
  normalAttempts: 1,
  normalUsed: normalUsed,
  inProgressAttemptId: inProgressAttemptId,
  additionalExceptionGranted: exceptionGranted,
  replacementAttemptAvailable: replacementAvailable,
);

StudentBlitzDetail studentBlitzDetail({
  String id = studentBlitzId,
  String topicId = studentTopicId,
  String title = 'Classroom Blitz',
  String? description = 'Timed practice.',
  StudentBlitzTiming? timing,
  StudentBlitzAttemptSummary? attempts,
  int durationSeconds = 600,
}) => StudentBlitzDetail(
  id: id,
  topic: StudentBlitzTopicSummary(id: topicId, title: 'Internet Basics'),
  title: title,
  description: description,
  studentInstructions: 'Answer independently.',
  status: StudentBlitzStatus.active,
  durationSeconds: durationSeconds,
  totalPossiblePoints: 5,
  timing: timing ?? studentBlitzTiming(),
  attempts: attempts ?? studentBlitzAttemptSummary(),
);

StudentBlitzDetail individualBlitzDetail({
  StudentBlitzAttemptSummary? attempts,
}) => studentBlitzDetail(
  timing: studentBlitzTiming(
    mode: StudentBlitzTimerMode.individual,
    noDeadline: true,
  ),
  attempts: attempts,
);

StudentBlitzDetail inProgressBlitzDetail({
  String attemptId = studentBlitzAttemptId,
  StudentBlitzTimerMode mode = StudentBlitzTimerMode.synchronized,
  bool exceptionGranted = false,
  int remainingSeconds = 300,
  DateTime? serverNow,
}) => studentBlitzDetail(
  timing: studentBlitzTiming(
    mode: mode,
    serverNow: serverNow,
    deadlineAt: DateTime.utc(2026, 9, 17, 12, 5),
    remainingSeconds: remainingSeconds,
  ),
  attempts: studentBlitzAttemptSummary(
    normalUsed: 1,
    inProgressAttemptId: attemptId,
    exceptionGranted: exceptionGranted,
  ),
);

StudentBlitzDetail replacementBlitzDetail({
  StudentBlitzTimerMode mode = StudentBlitzTimerMode.synchronized,
}) => studentBlitzDetail(
  timing: studentBlitzTiming(
    mode: mode,
    serverNow: DateTime.utc(2026, 9, 17, 12, 10),
    noDeadline: true,
  ),
  attempts: studentBlitzAttemptSummary(
    normalUsed: 1,
    exceptionGranted: true,
    replacementAvailable: true,
  ),
);

StudentBlitzDetail finishedBlitzDetail({
  StudentBlitzTimerMode mode = StudentBlitzTimerMode.synchronized,
}) => studentBlitzDetail(
  timing: studentBlitzTiming(
    mode: mode,
    remainingSeconds: 0,
    deadlineAt: DateTime.utc(2026, 9, 17, 12, 5),
  ),
  attempts: studentBlitzAttemptSummary(normalUsed: 1),
);

StudentActiveBlitzSummary studentActiveBlitz({
  String id = studentBlitzId,
  String title = 'Classroom Blitz',
  StudentBlitzTiming? timing,
  StudentBlitzAttemptSummary? attempts,
}) => StudentActiveBlitzSummary(
  id: id,
  topic: const StudentBlitzTopicSummary(
    id: studentTopicId,
    title: 'Internet Basics',
  ),
  title: title,
  status: StudentBlitzStatus.active,
  durationSeconds: 600,
  timing: timing ?? studentBlitzTiming(),
  attempts: attempts ?? studentBlitzAttemptSummary(),
);

StudentQuestion studentBlitzQuestion(int position) => StudentQuestion(
  id: blitzUuid(100 + position),
  type: StudentQuestionType.trueFalse,
  prompt: 'Blitz prompt $position',
  instructions: null,
  points: 1,
  position: position,
  answerUi: const StudentEmptyAnswerUi(),
);

StudentBlitzAttempt studentBlitzAttempt({
  String id = studentBlitzAttemptId,
  String assessmentId = studentBlitzId,
  int attemptNumber = 1,
  StudentBlitzAttemptStatus status = StudentBlitzAttemptStatus.inProgress,
  StudentBlitzAttemptFinalizationReason? finalizationReason,
  StudentBlitzTimerMode mode = StudentBlitzTimerMode.synchronized,
  int remainingSeconds = 300,
  DateTime? serverNow,
  DateTime? deadlineAt,
  List<StudentQuestion>? questions,
  List<StudentAttemptAnswerState> answers = const [],
}) {
  final terminal = status != StudentBlitzAttemptStatus.inProgress;
  final deadline = deadlineAt ?? DateTime.utc(2026, 9, 17, 12, 5);
  final reason = terminal
      ? finalizationReason ??
            StudentBlitzAttemptFinalizationReason.studentSubmit
      : null;
  final finalizedAt = switch (reason) {
    null => null,
    StudentBlitzAttemptFinalizationReason.timeout => deadline,
    _ => DateTime.utc(2026, 9, 17, 12, 2),
  };
  return StudentBlitzAttempt(
    id: id,
    assessmentId: assessmentId,
    attemptNumber: attemptNumber,
    status: status,
    startedAt: DateTime.utc(2026, 9, 17, 12),
    deadlineAt: deadline,
    submittedAt: reason == StudentBlitzAttemptFinalizationReason.studentSubmit
        ? finalizedAt
        : null,
    finalizedAt: finalizedAt,
    finalizationReason: reason,
    timing: StudentBlitzAttemptTiming(
      serverNow: serverNow ?? DateTime.utc(2026, 9, 17, 12),
      mode: mode,
      remainingSeconds: terminal ? 0 : remainingSeconds,
    ),
    questions: questions ?? [studentBlitzQuestion(1), studentBlitzQuestion(2)],
    answers: answers,
  );
}

StudentBlitzAttemptStartResult studentBlitzStartResult({
  StudentBlitzAttempt? attempt,
  StudentBlitzAttemptStartResultKind kind =
      StudentBlitzAttemptStartResultKind.created,
}) => StudentBlitzAttemptStartResult(
  attempt: attempt ?? studentBlitzAttempt(),
  resultKind: kind,
);

// --- Fakes --------------------------------------------------------------------

class FakeStudentBlitzRepository implements StudentBlitzRepository {
  FakeStudentBlitzRepository({this.onFetchActive, this.onFetchBlitz});

  Future<List<StudentActiveBlitzSummary>> Function()? onFetchActive;
  Future<StudentBlitzDetail> Function(String blitzId)? onFetchBlitz;
  var activeCalls = 0;
  final detailIds = <String>[];

  @override
  Future<List<StudentActiveBlitzSummary>> fetchActiveBlitz() {
    activeCalls += 1;
    return onFetchActive?.call() ?? Future.value(const []);
  }

  @override
  Future<StudentBlitzDetail> fetchBlitz(String blitzId) {
    detailIds.add(blitzId);
    return onFetchBlitz?.call(blitzId) ??
        Future.value(studentBlitzDetail(id: blitzId));
  }
}

class FakeStudentBlitzAttemptRepository
    implements StudentBlitzAttemptRepository {
  FakeStudentBlitzAttemptRepository({this.onStart, this.onSubmit});

  Future<StudentBlitzAttemptStartResult> Function(
    String blitzId,
    StudentBlitzAttemptRequest request,
  )?
  onStart;
  final requests = <StudentBlitzAttemptRequest>[];
  final blitzIds = <String>[];

  @override
  Future<StudentBlitzAttemptStartResult> start(
    String blitzId,
    StudentBlitzAttemptRequest request,
  ) {
    blitzIds.add(blitzId);
    requests.add(request);
    return onStart?.call(blitzId, request) ??
        Future.value(studentBlitzStartResult());
  }

  Future<StudentBlitzSubmitResult> Function(BlitzSubmitCall call)? onSubmit;
  final submits = <BlitzSubmitCall>[];

  @override
  Future<StudentBlitzSubmitResult> submitAttempt(
    String attemptId,
    String expectedBlitzId,
    String idempotencyKey, {
    required StudentBlitzSubmitResponseExpectation expectation,
  }) {
    final call = BlitzSubmitCall(
      attemptId: attemptId,
      blitzId: expectedBlitzId,
      idempotencyKey: idempotencyKey,
      expectation: expectation,
    );
    submits.add(call);
    return onSubmit?.call(call) ??
        Future.value(
          StudentBlitzSubmitResult(
            attempt: studentBlitzAttempt(
              status: StudentBlitzAttemptStatus.submitted,
            ),
          ),
        );
  }
}

class BlitzSubmitCall {
  const BlitzSubmitCall({
    required this.attemptId,
    required this.blitzId,
    required this.idempotencyKey,
    required this.expectation,
  });

  final String attemptId;
  final String blitzId;
  final String idempotencyKey;
  final StudentBlitzSubmitResponseExpectation expectation;
}

// --- Transport ----------------------------------------------------------------

Dio blitzTestDio(BlitzRecordingAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;

ResponseBody blitzJsonResponse(int status, Object? payload) =>
    ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody blitzErrorResponse(int status, String code) =>
    blitzJsonResponse(status, {
      'message': 'Raw server failure.',
      'code': code,
      'errors': <String, Object?>{},
    });

class BlitzRecordingAdapter implements HttpClientAdapter {
  BlitzRecordingAdapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];
  RequestOptions get request => requests.single;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class SequentialBlitzKeys implements IdempotencyKeyGenerator {
  var calls = 0;

  @override
  String generate() {
    calls += 1;
    return blitzKey(calls);
  }
}

String blitzKey(int index) =>
    'c1000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';
