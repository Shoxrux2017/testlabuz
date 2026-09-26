import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/idempotency_key_generator.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_active_blitz_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_attempt_start_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_execution_state.dart';
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/data/dto/student_question_dto.dart';
import 'package:testlabuz_client/features/student/data/student_attempt_answer_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/data/student_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_answer_mutation.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer_repository.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_execution_target.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

/// The eight non-file Question types, in wire position order 1..8.
const blitzNonFileTypes = [
  StudentQuestionType.singleChoice,
  StudentQuestionType.multipleChoice,
  StudentQuestionType.trueFalse,
  StudentQuestionType.shortWritten,
  StudentQuestionType.openWritten,
  StudentQuestionType.matching,
  StudentQuestionType.ordering,
  StudentQuestionType.fillInBlank,
];

final blitzRouteTarget = StudentBlitzRouteTarget(
  topicId: studentTopicId,
  blitzId: studentBlitzId,
);

final blitzExecutionTarget = StudentBlitzExecutionTarget(
  routeTarget: blitzRouteTarget,
  attemptId: studentBlitzAttemptId,
);

/// Safe Questions of [types] at positions 1..n (IDs `blitzUuid(100 + n)`).
List<StudentQuestion> blitzQuestions(List<StudentQuestionType> types) => [
  for (var index = 0; index < types.length; index++)
    StudentQuestionDto.fromJson(
      blitzQuestionJson(types[index], index + 1),
    ).toDomain(),
];

String blitzQuestionId(int position) => blitzUuid(100 + position);

StudentBlitzAttempt blitzExecutionAttempt({
  String id = studentBlitzAttemptId,
  int attemptNumber = 1,
  List<StudentQuestionType> types = const [
    StudentQuestionType.trueFalse,
    StudentQuestionType.openWritten,
    StudentQuestionType.fileBased,
  ],
  List<StudentAttemptAnswerState> answers = const [],
  StudentBlitzAttemptStatus status = StudentBlitzAttemptStatus.inProgress,
  StudentBlitzAttemptFinalizationReason? finalizationReason,
  int remainingSeconds = 300,
  DateTime? serverNow,
}) => studentBlitzAttempt(
  id: id,
  attemptNumber: attemptNumber,
  questions: blitzQuestions(types),
  answers: answers,
  status: status,
  finalizationReason: finalizationReason,
  remainingSeconds: remainingSeconds,
  serverNow: serverNow,
);

/// The four request shapes whose completed Start request a recovery replays.
enum BlitzRequestShape {
  startNormal,
  resumeFirst,
  resumeSecond,
  startReplacement;

  StudentBlitzAttemptIntent get intent => switch (this) {
    startNormal => StudentBlitzAttemptIntent.startNormal,
    resumeFirst || resumeSecond => StudentBlitzAttemptIntent.resume,
    startReplacement => StudentBlitzAttemptIntent.startReplacement,
  };

  bool get isSecond => this == resumeSecond || this == startReplacement;

  String get attemptId =>
      isSecond ? studentBlitzReplacementAttemptId : studentBlitzAttemptId;

  /// The exact original JSON body; only Resume carries an Attempt ID.
  Map<String, Object?> get body => {
    'intent': intent.apiValue,
    if (intent == StudentBlitzAttemptIntent.resume) 'attempt_id': attemptId,
  };

  /// The stored status the replay returns: Resume keys are always `200`.
  StudentBlitzAttemptStartResultKind get kind =>
      intent == StudentBlitzAttemptIntent.resume
      ? StudentBlitzAttemptStartResultKind.resumed
      : StudentBlitzAttemptStartResultKind.created;

  StudentBlitzExecutionAction get action => switch (this) {
    startNormal => StudentBlitzExecutionAction.startNormal,
    resumeFirst || resumeSecond => StudentBlitzExecutionAction.resume,
    startReplacement => StudentBlitzExecutionAction.startReplacement,
  };

  StudentBlitzDetail get detail => switch (this) {
    startNormal => studentBlitzDetail(),
    resumeFirst => inProgressBlitzDetail(),
    resumeSecond => inProgressBlitzDetail(
      attemptId: studentBlitzReplacementAttemptId,
      exceptionGranted: true,
    ),
    startReplacement => replacementBlitzDetail(),
  };

  StudentBlitzDetail get executingDetail => isSecond
      ? inProgressBlitzDetail(
          attemptId: studentBlitzReplacementAttemptId,
          exceptionGranted: true,
        )
      : inProgressBlitzDetail();

  StudentBlitzExecutionTarget get target => StudentBlitzExecutionTarget(
    routeTarget: blitzRouteTarget,
    attemptId: attemptId,
  );

  StudentBlitzAttempt attempt({
    StudentBlitzAttemptStatus status = StudentBlitzAttemptStatus.inProgress,
    StudentBlitzAttemptFinalizationReason? finalizationReason,
    List<StudentAttemptAnswerState> answers = const [],
  }) => blitzExecutionAttempt(
    id: attemptId,
    attemptNumber: isSecond ? 2 : 1,
    status: status,
    finalizationReason: finalizationReason,
    answers: answers,
  );
}

StudentAttemptAnswerState blitzSavedAnswer(
  int position,
  StudentQuestionType type,
  StudentAttemptAnswerValue value,
) => StudentAttemptAnswerState(
  questionId: blitzQuestionId(position),
  type: type,
  value: value,
  updatedAt: DateTime.utc(2026, 9, 17, 12, 1),
);

StudentSubmissionFile blitzServerFile({
  String name = 'blitz.pdf',
  int size = 2048,
}) => StudentSubmissionFile(
  id: blitzUuid(99),
  originalName: name,
  extension: name.split('.').last,
  sizeBytes: size,
);

StudentSubmissionUploadFile blitzUploadFile({
  String name = 'blitz.pdf',
  int length = 2048,
}) => StudentSubmissionUploadFile(
  name: name,
  length: length,
  openRead: () => Stream.value(List<int>.filled(length, 1)),
);

StudentAttemptAnswerMutationResult blitzMutationResult(
  int position,
  StudentQuestionType type,
  StudentAttemptAnswerValue? answer,
) => StudentAttemptAnswerMutationResult(
  questionId: blitzQuestionId(position),
  type: type,
  answer: answer,
  updatedAt: answer == null ? null : DateTime.utc(2026, 9, 17, 12, 2),
);

class BlitzAnswerSave {
  BlitzAnswerSave(this.attemptId, this.question, this.mutation);

  final String attemptId;
  final StudentQuestion question;
  final StudentAnswerMutation mutation;
  final completer = Completer<StudentAttemptAnswerMutationResult>();

  void complete(StudentAttemptAnswerMutationResult result) =>
      completer.complete(result);
  void fail(Object error) => completer.completeError(error);
}

class BlitzFileUpload {
  BlitzFileUpload(this.attemptId, this.question, this.file, this.onProgress);

  final String attemptId;
  final StudentQuestion question;
  final StudentSubmissionUploadFile file;
  final StudentSubmissionUploadProgress? onProgress;
  final completer = Completer<StudentAttemptAnswerMutationResult>();

  void complete(StudentAttemptAnswerMutationResult result) =>
      completer.complete(result);
  void fail(Object error) => completer.completeError(error);
}

class FakeStudentAttemptAnswerRepository
    implements StudentAttemptAnswerRepository {
  final saves = <BlitzAnswerSave>[];
  final uploads = <BlitzFileUpload>[];

  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) {
    final save = BlitzAnswerSave(attemptId, question, mutation);
    saves.add(save);
    return save.completer.future;
  }

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) {
    final upload = BlitzFileUpload(attemptId, question, file, onProgress);
    uploads.add(upload);
    return upload.completer.future;
  }
}

class FakeBlitzFilePicker implements StudentSubmissionFilePicker {
  final requests = <List<String>>[];
  final pending = <Completer<StudentSubmissionUploadFile?>>[];

  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) {
    requests.add(allowedExtensions);
    final completer = Completer<StudentSubmissionUploadFile?>();
    pending.add(completer);
    return completer.future;
  }
}

/// A Blitz route session with a real execution controller fed by a real
/// Start, so every recovery can be checked against the exact sent request.
class BlitzExecutionHarness {
  BlitzExecutionHarness({List<Override> overrides = const []}) {
    blitz.onFetchBlitz = (_) {
      final completer = Completer<StudentBlitzDetail>();
      pendingDetails.add(completer);
      return completer.future;
    };
    attempts.onStart = (_, _) {
      final completer = Completer<StudentBlitzAttemptStartResult>();
      pendingStarts.add(completer);
      return completer.future;
    };
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        studentBlitzRepositoryProvider.overrideWithValue(blitz),
        studentBlitzAttemptRepositoryProvider.overrideWithValue(attempts),
        studentAttemptAnswerRepositoryProvider.overrideWithValue(answers),
        studentSubmissionFilePickerProvider.overrideWithValue(picker),
        idempotencyKeyGeneratorProvider.overrideWithValue(keys),
        ...overrides,
      ],
    );
    for (final provider in <ProviderListenable<Object?>>[
      studentActiveBlitzControllerProvider,
      studentBlitzDetailControllerProvider(blitzRouteTarget),
      studentBlitzExecutionControllerProvider(blitzRouteTarget),
      studentBlitzAttemptStartControllerProvider(blitzRouteTarget),
    ]) {
      container.listen(provider, (_, _) {});
    }
  }

  /// A [shape] Start of [attempt], handed off and confirmed by detail.
  static Future<BlitzExecutionHarness> executing({
    StudentBlitzAttempt? attempt,
    BlitzRequestShape shape = BlitzRequestShape.startNormal,
    List<Override> overrides = const [],
  }) async {
    final harness = BlitzExecutionHarness(overrides: overrides)..shape = shape;
    await flushStudentControllers();
    harness.pendingDetails.single.complete(shape.detail);
    await flushStudentControllers();
    final start = harness.container
        .read(
          studentBlitzAttemptStartControllerProvider(blitzRouteTarget).notifier,
        )
        .start(shape.action);
    harness.pendingStarts.single.complete(
      studentBlitzStartResult(
        attempt: attempt ?? shape.attempt(),
        kind: shape.kind,
      ),
    );
    await start;
    await flushStudentControllers();
    harness.pendingDetails.last.complete(shape.executingDetail);
    await flushStudentControllers();
    return harness;
  }

  BlitzRequestShape shape = BlitzRequestShape.startNormal;

  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  final blitz = FakeStudentBlitzRepository();
  final attempts = FakeStudentBlitzAttemptRepository();
  final answers = FakeStudentAttemptAnswerRepository();
  final picker = FakeBlitzFilePicker();
  final keys = SequentialBlitzKeys();
  final pendingDetails = <Completer<StudentBlitzDetail>>[];
  final pendingStarts = <Completer<StudentBlitzAttemptStartResult>>[];
  late final ProviderContainer container;

  void listen(ProviderListenable<Object?> provider) =>
      container.listen(provider, (_, _) {});

  void dispose() => container.dispose();

  StudentBlitzExecutionState get execution =>
      container.read(studentBlitzExecutionControllerProvider(blitzRouteTarget));
  StudentBlitzExecutionController get executionController => container.read(
    studentBlitzExecutionControllerProvider(blitzRouteTarget).notifier,
  );

  /// The one completed Start request every recovery must resend unchanged.
  StudentBlitzAttemptRequest get completedRequest => attempts.requests.first;

  /// Replays sent after the original Start.
  List<StudentBlitzAttemptRequest> get replays =>
      attempts.requests.skip(1).toList();

  /// Answers the latest replay with [attempt] and the stored status.
  Future<void> completeReplay(StudentBlitzAttempt attempt) async {
    pendingStarts.last.complete(
      studentBlitzStartResult(attempt: attempt, kind: shape.kind),
    );
    await flushStudentControllers();
  }

  Future<void> failReplay(Object error) async {
    pendingStarts.last.completeError(error);
    await flushStudentControllers();
  }
}
