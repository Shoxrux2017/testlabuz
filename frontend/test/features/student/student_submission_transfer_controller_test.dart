import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/files/local_file_actions.dart';
import 'package:testlabuz_client/core/files/protected_learning_material_transfer.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_attempt_answer_editor_controller.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_submission_transfer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_submission_transfer_state.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_test_support.dart';

const _homeworkId = '40000000-0000-0000-0000-000000000001';
const _attemptId = '60000000-0000-0000-0000-000000000001';
const _questionId = '50000000-0000-0000-0000-000000000001';
const _otherQuestionId = '50000000-0000-0000-0000-000000000002';
const _fileId = '30000000-0000-0000-0000-000000000001';
const _otherFileId = '30000000-0000-0000-0000-000000000002';

void main() {
  for (final surface in [AppDeviceSurface.desktop, AppDeviceSurface.mobile]) {
    test(
      'current data opens and saves through protected GET on $surface',
      () async {
        final harness = _Harness(surface: surface);
        await harness.controller.open(_questionId, _fileId);
        await harness.controller.saveAs(_questionId, _fileId);
        expect(harness.local.openCalls, 1);
        expect(harness.local.saveCalls, 1);
        expect(harness.local.savedTitle, 'Save submitted answer');
        expect(harness.local.savedName, 'safe.pdf');
        expect(harness.adapter.requests, hasLength(2));
        for (final request in harness.adapter.requests) {
          expect(request.method, 'GET');
          expect(request.path, '/files/$_fileId/download');
          expect(request.data, isNull);
          expect(request.queryParameters, isEmpty);
        }
      },
    );
  }

  for (final status in StudentHomeworkAttemptLoadStatus.values.where(
    (status) => status != StudentHomeworkAttemptLoadStatus.data,
  )) {
    test(
      '$status retained in-progress data cannot authorize transfer',
      () async {
        final harness = _Harness(
          initial: StudentHomeworkAttemptState(
            status: status,
            attempt: _attempt(),
          ),
        );
        expect(harness.controller.canTransfer(_questionId, _fileId), isFalse);
        await harness.controller.open(_questionId, _fileId);
        await harness.controller.saveAs(_questionId, _fileId);
        expect(harness.adapter.requests, isEmpty);
      },
    );
  }

  for (final status in StudentHomeworkAttemptStatus.values) {
    test('current $status Attempt retains saved file actions', () async {
      final harness = _Harness(initial: _data(_attempt(status: status)));
      await harness.controller.open(_questionId, _fileId);
      await harness.controller.saveAs(_questionId, _fileId);
      expect(harness.local.openCalls, 1);
      expect(harness.local.saveCalls, 1);
    });
  }

  for (final status in [
    StudentHomeworkAttemptLoadStatus.refreshing,
    StudentHomeworkAttemptLoadStatus.error,
  ]) {
    test(
      'accepted terminal file authorizes both actions through later $status',
      () async {
        final harness = _Harness();
        harness.parent.publish(
          _data(_attempt(status: StudentHomeworkAttemptStatus.submitted)),
        );
        await harness.flush();
        expect(
          harness.container
              .read(studentAttemptAnswerEditorControllerProvider(_target()))
              .terminalAttempt,
          isNotNull,
        );
        harness.parent.publish(
          StudentHomeworkAttemptState(
            status: status,
            attempt: _attempt(fileId: _otherFileId),
          ),
        );
        await harness.flush();
        expect(harness.controller.canTransfer(_questionId, _fileId), isTrue);
        expect(
          harness.controller.canTransfer(_questionId, _otherFileId),
          isFalse,
        );
        await harness.controller.open(_questionId, _fileId);
        await harness.controller.saveAs(_questionId, _fileId);
        expect(harness.local.openCalls, 1);
        expect(harness.local.saveCalls, 1);
      },
    );
  }

  test(
    'missing parent data and malformed or mismatching identities never transfer',
    () async {
      final harness = _Harness();
      for (final parent in [
        const StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.data,
        ),
        _data(_attempt(id: 'invalid')),
        _data(_attempt(id: '60000000-0000-0000-0000-000000000002')),
        _data(_attempt(homeworkId: 'invalid')),
        _data(_attempt(homeworkId: '40000000-0000-0000-0000-000000000002')),
        _data(_attempt(includeFile: false)),
      ]) {
        harness.parent.publish(parent);
        await harness.flush();
        await harness.controller.open(_questionId, _fileId);
      }
      expect(harness.adapter.requests, isEmpty);
    },
  );

  test('stale Question or File IDs cannot dispatch', () async {
    final harness = _Harness();
    for (final (questionId, fileId) in [
      (_otherQuestionId, _fileId),
      (_questionId, _otherFileId),
      ('invalid', _fileId),
      (_questionId, 'invalid'),
    ]) {
      await harness.controller.open(questionId, fileId);
    }
    expect(harness.adapter.requests, isEmpty);
  });

  test(
    'saved file remains transferable with selection but uploading and uncertain block it',
    () async {
      final harness = _Harness();
      for (final status in [
        StudentFileAnswerStatus.ready,
        StudentFileAnswerStatus.uploading,
        StudentFileAnswerStatus.uncertain,
      ]) {
        harness.files.publish(status);
        await harness.flush();
        await harness.controller.open(_questionId, _fileId);
      }
      expect(harness.adapter.requests, hasLength(1));
      expect(harness.local.openCalls, 1);
    },
  );

  for (final response in [
    _download(bytes: [1, 2]),
    _download(extension: 'ppt', mime: 'application/vnd.ms-powerpoint'),
    _download(bytes: const []),
    _download(bytes: Uint8List(15728641)),
    _download(mime: 'text/plain'),
  ]) {
    test(
      'invalid protected response cannot reach a local action (${response.headers})',
      () async {
        final harness = _Harness(handler: (_) => response);
        await harness.controller.open(_questionId, _fileId);
        expect(harness.local.openCalls, 0);
        expect(harness.local.saveCalls, 0);
        expect(
          harness.state.feedback,
          'The server returned an unexpected file response.',
        );
      },
    );
  }

  test(
    'submission cap rejects matching bytes above 15 MB accepted by shared transport',
    () async {
      final harness = _Harness(
        initial: _data(_attempt(sizeBytes: 15728641)),
        handler: (_) => _download(bytes: Uint8List(15728641)),
      );
      await harness.controller.saveAs(_questionId, _fileId);
      expect(harness.local.saveCalls, 0);
      expect(
        harness.state.feedback,
        'The server returned an unexpected file response.',
      );
    },
  );

  test(
    'Open without application has safe local feedback and Save As cancellation is neutral',
    () async {
      final harness = _Harness();
      harness.local.openOutcome = LocalFileOpenOutcome.noApplication;
      await harness.controller.open(_questionId, _fileId);
      expect(
        harness.state.feedback,
        'No application is available to open this file. Save the file instead.',
      );
      harness.local.saveResult = null;
      await harness.controller.saveAs(_questionId, _fileId);
      expect(harness.state.status, StudentSubmissionTransferStatus.idle);
      expect(harness.state.feedback, isNull);
    },
  );

  for (final (status, code, message) in [
    (
      404,
      ApiErrorCodes.resourceNotFound,
      'This submitted file is no longer available.',
    ),
    (
      500,
      ApiErrorCodes.fileNotAvailable,
      'The file is temporarily unavailable. Try again.',
    ),
  ]) {
    test(
      '$code maps safe feedback and only missing files refresh Attempt',
      () async {
        final harness = _Harness(handler: (_) => _error(status, code));
        await harness.controller.open(_questionId, _fileId);
        expect(harness.state.feedback, message);
        expect(harness.parent.refreshCalls, status == 404 ? 1 : 0);
        expect(harness.local.openCalls, 0);
        expect(harness.adapter.requests, hasLength(1));
      },
    );
  }

  for (final (type, message) in [
    (DioExceptionType.receiveTimeout, 'The download timed out. Try again.'),
    (
      DioExceptionType.connectionError,
      'The download could not connect. Try again.',
    ),
  ]) {
    test('$type is manually retryable without automatic request', () async {
      final harness = _Harness(
        handler: (options) =>
            throw DioException(requestOptions: options, type: type),
      );
      await harness.controller.open(_questionId, _fileId);
      expect(harness.state.feedback, message);
      expect(harness.adapter.requests, hasLength(1));
      harness.adapter.handler = (_) => _download();
      await harness.controller.open(_questionId, _fileId);
      expect(harness.local.openCalls, 1);
    });
  }

  test(
    'one active transfer owns progress and blocks duplicate Open and Save As',
    () async {
      final response = Completer<ResponseBody>();
      final harness = _Harness(handler: (_) => response.future);
      final pending = harness.controller.open(_questionId, _fileId);
      await harness.adapter.started.future;
      await harness.flush();
      expect(harness.state.status, StudentSubmissionTransferStatus.downloading);
      harness.adapter.requests.single.onReceiveProgress!(2, 3);
      expect(harness.state.receivedBytes, 2);
      expect(harness.state.progress, closeTo(2 / 3, .001));
      await harness.controller.open(_questionId, _fileId);
      await harness.controller.saveAs(_questionId, _fileId);
      expect(harness.adapter.requests, hasLength(1));
      response.complete(_download());
      await pending;
      expect(harness.local.openCalls, 1);
    },
  );

  for (final terminal in [false, true]) {
    for (final change in [
      'notFound',
      'logout',
      'student',
      'target',
      'file',
      'metadata',
      'disposed',
    ]) {
      test(
        '$change aborts late transfer under ${terminal ? 'terminal' : 'data'} authority',
        () async {
          final response = Completer<ResponseBody>();
          final harness = _Harness(
            initial: _data(
              _attempt(
                status: terminal
                    ? StudentHomeworkAttemptStatus.submitted
                    : StudentHomeworkAttemptStatus.inProgress,
              ),
            ),
            handler: (_) => response.future,
          );
          final pending = harness.controller.saveAs(_questionId, _fileId);
          await harness.adapter.started.future;
          await harness.flush();
          switch (change) {
            case 'notFound':
              harness.parent.publish(
                const StudentHomeworkAttemptState(
                  status: StudentHomeworkAttemptLoadStatus.notFound,
                ),
              );
            case 'logout':
              harness.auth.logOut();
            case 'student':
              harness.auth.replaceUser(studentUser('student-b'));
            case 'target':
            case 'disposed':
              harness.close();
            case 'file':
              harness.parent.publish(
                _data(
                  _attempt(
                    fileId: _otherFileId,
                    status: terminal
                        ? StudentHomeworkAttemptStatus.submitted
                        : StudentHomeworkAttemptStatus.inProgress,
                  ),
                ),
              );
            case 'metadata':
              harness.parent.publish(
                _data(
                  _attempt(
                    name: 'replaced.pdf',
                    status: terminal
                        ? StudentHomeworkAttemptStatus.submitted
                        : StudentHomeworkAttemptStatus.inProgress,
                  ),
                ),
              );
          }
          if (!harness.closed) await harness.flush();
          response.complete(_download());
          await pending;
          expect(harness.local.openCalls, 0);
          expect(harness.local.saveCalls, 0);
          if (!harness.closed) expect(harness.state.isBusy, isFalse);
        },
      );
    }
  }

  for (final status in [
    StudentHomeworkAttemptLoadStatus.refreshing,
    StudentHomeworkAttemptLoadStatus.error,
  ]) {
    test(
      '$status revokes delayed in-progress action but preserves accepted terminal action',
      () async {
        for (final terminal in [false, true]) {
          final response = Completer<ResponseBody>();
          final harness = _Harness(
            initial: _data(
              _attempt(
                status: terminal
                    ? StudentHomeworkAttemptStatus.submitted
                    : StudentHomeworkAttemptStatus.inProgress,
              ),
            ),
            handler: (_) => response.future,
          );
          final pending = harness.controller.open(_questionId, _fileId);
          await harness.adapter.started.future;
          await harness.flush();
          harness.parent.publish(
            StudentHomeworkAttemptState(status: status, attempt: _attempt()),
          );
          await harness.flush();
          response.complete(_download());
          await pending;
          expect(harness.local.openCalls, terminal ? 1 : 0);
          expect(harness.state.isBusy, isFalse);
        }
      },
    );
  }

  for (final code in [
    ApiErrorCodes.authenticationRequired,
    ApiErrorCodes.passwordChangeRequired,
    ApiErrorCodes.userInactive,
    ApiErrorCodes.institutionInactive,
  ]) {
    test(
      '$code clears transfer and follows shared session reconciliation',
      () async {
        final harness = _Harness(handler: (_) => _error(401, code));
        await harness.controller.open(_questionId, _fileId);
        expect(harness.state.isBusy, isFalse);
        expect(harness.state.feedback, isNull);
        expect(
          harness.auth.bootstrapCalls,
          code == ApiErrorCodes.authenticationRequired ? 0 : 1,
        );
        expect(harness.local.openCalls, 0);
      },
    );
  }
}

class _Harness {
  _Harness({
    StudentHomeworkAttemptState? initial,
    FutureOr<ResponseBody> Function(RequestOptions)? handler,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) {
    parent = _Parent(initial ?? _data(_attempt()));
    adapter = _Adapter(handler ?? (_) => _download());
    final dio = Dio(
      BaseOptions(baseUrl: 'https://api.testlabuz.example/api/v1'),
    )..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentHomeworkAttemptControllerProvider(
          _target(),
        ).overrideWith(() => parent),
        studentFileAnswerControllerProvider(
          _target(),
        ).overrideWith(() => files),
        protectedLearningMaterialTransferProvider.overrideWithValue(
          ProtectedLearningMaterialTransfer(
            dio: dio,
            failureMapper: const DioFailureMapper(),
          ),
        ),
        localFileActionsProvider.overrideWithValue(
          LocalFileActions(platform: local),
        ),
      ],
    );
    container.listen(
      studentSubmissionTransferControllerProvider(_target()),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(close);
  }

  final auth = FakeStudentAuthSessionController.authenticated(
    studentUser('student-a'),
  );
  final local = _LocalAdapter();
  final files = _Files();
  late final _Parent parent;
  late final _Adapter adapter;
  late final ProviderContainer container;
  bool closed = false;

  StudentSubmissionTransferController get controller => container.read(
    studentSubmissionTransferControllerProvider(_target()).notifier,
  );
  StudentSubmissionTransferState get state =>
      container.read(studentSubmissionTransferControllerProvider(_target()));
  Future<void> flush() async {
    await Future<void>.value();
    await container.pump();
    await Future<void>.value();
    await container.pump();
  }

  void close() {
    if (!closed) {
      closed = true;
      container.dispose();
    }
  }
}

class _Parent extends StudentHomeworkAttemptController {
  _Parent(this.initial) : super(_target());
  final StudentHomeworkAttemptState initial;
  int refreshCalls = 0;
  @override
  StudentHomeworkAttemptState build() => initial;
  void publish(StudentHomeworkAttemptState next) => state = next;
  @override
  void refresh() {
    refreshCalls += 1;
    state = StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.refreshing,
      attempt: state.attempt,
    );
  }
}

class _Files extends StudentFileAnswerController {
  _Files() : super(_target());
  @override
  StudentFileAnswerState build() => StudentFileAnswerState();
  void publish(StudentFileAnswerStatus status) {
    state = StudentFileAnswerState(
      questions: {
        _questionId: StudentFileQuestionAnswerState(
          question: _question(),
          status: status,
        ),
      },
    );
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  FutureOr<ResponseBody> Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  final started = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!started.isCompleted) started.complete();
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _LocalAdapter implements LocalFilePlatformAdapter {
  int openCalls = 0;
  int saveCalls = 0;
  String? savedTitle;
  String? savedName;
  Uri? saveResult = Uri.file('saved.pdf');
  LocalFileOpenOutcome openOutcome = LocalFileOpenOutcome.opened;

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    openCalls += 1;
    return openOutcome;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String dialogTitle,
  }) async {
    saveCalls += 1;
    savedTitle = dialogTitle;
    savedName = fileName;
    return saveResult;
  }
}

ResponseBody _download({
  List<int> bytes = const [1, 2, 3],
  String extension = 'pdf',
  String mime = 'application/pdf',
}) => ResponseBody.fromBytes(
  bytes,
  200,
  headers: {
    Headers.contentTypeHeader: [mime],
    Headers.contentLengthHeader: ['${bytes.length}'],
    'content-disposition': ['attachment; filename="safe.$extension"'],
    'cache-control': ['private, no-store'],
    'x-content-type-options': ['nosniff'],
  },
);

ResponseBody _error(int status, String code) => ResponseBody.fromString(
  jsonEncode({
    'message': 'Safe failure.',
    'code': code,
    'errors': <String, Object?>{},
  }),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

StudentHomeworkAttemptRouteTarget _target() =>
    StudentHomeworkAttemptRouteTarget(
      topicId: studentTopicId,
      homeworkId: _homeworkId,
      attemptId: _attemptId,
    );
StudentHomeworkAttemptState _data(StudentHomeworkAttempt attempt) =>
    StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.data,
      attempt: attempt,
    );
StudentQuestion _question() => StudentQuestion(
  id: _questionId,
  type: StudentQuestionType.fileBased,
  prompt: 'Upload answer.',
  instructions: null,
  points: 1,
  position: 1,
  answerUi: StudentFileAnswerUi(allowedExtensions: ['pdf'], maxSizeBytes: 1),
);
StudentHomeworkAttempt _attempt({
  String id = _attemptId,
  String homeworkId = _homeworkId,
  String fileId = _fileId,
  String name = 'original.pdf',
  int sizeBytes = 3,
  bool includeFile = true,
  StudentHomeworkAttemptStatus status = StudentHomeworkAttemptStatus.inProgress,
}) => StudentHomeworkAttempt(
  id: id,
  assessmentId: homeworkId,
  attemptNumber: 1,
  status: status,
  startedAt: DateTime.utc(2026, 9, 1),
  submittedAt: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : DateTime.utc(2026, 9, 1, 1),
  finalizedAt: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : DateTime.utc(2026, 9, 1, 1),
  finalizationReason: status == StudentHomeworkAttemptStatus.inProgress
      ? null
      : StudentHomeworkAttemptFinalizationReason.studentSubmit,
  deadlineAt: null,
  questions: [_question()],
  answers: includeFile
      ? [
          StudentAttemptAnswerState(
            questionId: _questionId,
            type: StudentQuestionType.fileBased,
            value: StudentFileAnswerValue(
              file: StudentSubmissionFile(
                id: fileId,
                originalName: name,
                extension: 'pdf',
                sizeBytes: sizeBytes,
              ),
            ),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ]
      : [],
);
