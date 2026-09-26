import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/files/local_file_actions.dart';
import 'package:testlabuz_client/core/files/protected_learning_material_transfer.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_blitz_submission_transfer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_submission_transfer_state.dart';
import 'package:testlabuz_client/features/student/domain/student_attempt_answer.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

import 'student_blitz_execution_test_support.dart';
import 'student_blitz_test_support.dart';
import 'student_test_support.dart';

void main() {
  test('opens only the current authoritative submitted file', () async {
    final h = await _Harness.create();
    expect(h.controller.canTransfer(_question, _fileId), isTrue);
    final open = h.controller.open(_question, _fileId);
    await h.adapter.started.future;
    expect(h.state.status, StudentSubmissionTransferStatus.downloading);
    expect(h.state.isBusyForQuestion(_question), isTrue);
    await open;
    expect(
      h.adapter.requests.single.uri.path,
      '/api/v1/files/$_fileId/download',
    );
    expect(h.local.openCalls, 1);
    expect(h.state.status, StudentSubmissionTransferStatus.idle);
  });

  test('Save As writes the verified bytes', () async {
    final h = await _Harness.create();
    await h.controller.saveAs(_question, _fileId);
    expect(h.local.saveCalls, 1);
    expect(h.local.savedTitle, 'Save submitted answer');
    expect(h.state.feedback, 'Submitted file saved.');
  });

  test('reports download progress', () async {
    final response = Completer<ResponseBody>();
    final h = await _Harness.create(handler: (_) => response.future);
    final open = h.controller.open(_question, _fileId);
    await h.adapter.started.future;
    expect(h.state.progress, isNull);
    response.complete(_download());
    await open;
    expect(h.local.openCalls, 1);
  });

  test('a response that does not match the file is never opened', () async {
    final h = await _Harness.create(
      handler: (_) => _download(bytes: const [1, 2, 3]),
    );
    await h.controller.open(_question, _fileId);
    expect(h.local.openCalls, 0);
    expect(h.state.status, StudentSubmissionTransferStatus.failure);
    expect(
      h.state.feedback,
      'The server returned an unexpected file response.',
    );
  });

  test('404 reconciles the Attempt and shows a privacy-safe message', () async {
    final h = await _Harness.create(
      handler: (_) => _error(404, ApiErrorCodes.resourceNotFound),
    );
    await h.controller.open(_question, _fileId);
    await flushStudentControllers();
    expect(h.h.replays.single, same(h.h.completedRequest));
    expect(h.state.feedback, 'The submitted file is no longer available.');
    expect(h.local.openCalls, 0);
    await h.h.completeReplay(blitzExecutionAttempt());
    expect(h.controller.canTransfer(_question, _fileId), isFalse);
  });

  test('404 on a final Attempt revokes that file link', () async {
    final h = await _Harness.create(
      handler: (_) => _error(404, ApiErrorCodes.resourceNotFound),
    );
    h.h.executionController.acceptSubmittedAttempt(
      blitzExecutionAttempt(
        status: StudentBlitzAttemptStatus.submitted,
        answers: [_savedFile()],
      ),
    );
    await flushStudentControllers();
    expect(h.controller.canTransfer(_question, _fileId), isTrue);
    await h.controller.open(_question, _fileId);
    await flushStudentControllers();
    expect(h.state.feedback, 'The submitted file is no longer available.');
    expect(h.controller.canTransfer(_question, _fileId), isFalse);
  });

  test('a file confirmed again by the re-read is transferable again', () async {
    final h = await _Harness.create(
      handler: (_) => _error(404, ApiErrorCodes.resourceNotFound),
    );
    await h.controller.open(_question, _fileId);
    await flushStudentControllers();
    expect(h.controller.canTransfer(_question, _fileId), isFalse);
    await h.h.completeReplay(blitzExecutionAttempt(answers: [_savedFile()]));
    expect(h.controller.canTransfer(_question, _fileId), isTrue);
  });

  test('a stale, foreign or unsaved file cannot be transferred', () async {
    final h = await _Harness.create();
    for (final (question, file) in [
      (_question, blitzUuid(98)),
      (blitzQuestionId(1), _fileId),
      (_question, 'not-a-uuid'),
    ]) {
      expect(h.controller.canTransfer(question, file), isFalse);
      await h.controller.open(question, file);
    }
    expect(h.adapter.requests, isEmpty);

    final unsaved = await _Harness.create(attempt: blitzExecutionAttempt());
    expect(unsaved.controller.canTransfer(_question, _fileId), isFalse);
  });

  test('an upload in flight revokes the current file link', () async {
    final h = await _Harness.create();
    h.h.listen(studentBlitzFileAnswerControllerProvider(blitzExecutionTarget));
    final files = h.h.container.read(
      studentBlitzFileAnswerControllerProvider(blitzExecutionTarget).notifier,
    );
    final choose = files.chooseFile(_question);
    h.h.picker.pending.single.complete(blitzUploadFile(name: 'new.pdf'));
    await choose;
    expect(h.controller.canTransfer(_question, _fileId), isTrue);
    final upload = files.uploadAnswer(_question);
    expect(h.controller.canTransfer(_question, _fileId), isFalse);
    h.h.answers.uploads.single.fail(
      studentServerFailure('server_error', statusCode: 503),
    );
    await upload;
    expect(h.controller.canTransfer(_question, _fileId), isFalse);
  });

  test('a terminal Attempt keeps its submitted file transferable', () async {
    final h = await _Harness.create();
    expect(
      h.h.executionController.acceptSubmittedAttempt(
        blitzExecutionAttempt(
          status: StudentBlitzAttemptStatus.submitted,
          answers: [_savedFile()],
        ),
      ),
      isTrue,
    );
    await flushStudentControllers();
    expect(h.controller.canTransfer(_question, _fileId), isTrue);
    await h.controller.open(_question, _fileId);
    expect(h.local.openCalls, 1);
  });

  test('a completion after a session switch is ignored', () async {
    final response = Completer<ResponseBody>();
    final h = await _Harness.create(handler: (_) => response.future);
    final open = h.controller.open(_question, _fileId);
    await h.adapter.started.future;
    h.h.auth.replaceUser(studentUser('student-b'));
    await flushStudentControllers();
    response.complete(_download());
    await open;
    expect(h.local.openCalls, 0);
    expect(h.state.status, StudentSubmissionTransferStatus.idle);
  });
}

final _question = blitzQuestionId(3);
final _fileId = blitzUuid(99);

StudentAttemptAnswerState _savedFile() => blitzSavedAnswer(
  3,
  StudentQuestionType.fileBased,
  StudentFileAnswerValue(file: blitzServerFile(size: 4)),
);

class _Harness {
  _Harness(this.h, this.adapter, this.local) {
    h.listen(
      studentBlitzSubmissionTransferControllerProvider(blitzExecutionTarget),
    );
  }

  static Future<_Harness> create({
    StudentBlitzAttempt? attempt,
    FutureOr<ResponseBody> Function(RequestOptions)? handler,
  }) async {
    final adapter = _Adapter(handler ?? (_) => _download());
    final local = _LocalAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    final harness = _Harness(
      await BlitzExecutionHarness.executing(
        attempt: attempt ?? blitzExecutionAttempt(answers: [_savedFile()]),
        overrides: [
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
      ),
      adapter,
      local,
    );
    addTearDown(harness.h.dispose);
    await flushStudentControllers();
    return harness;
  }

  final BlitzExecutionHarness h;
  final _Adapter adapter;
  final _LocalAdapter local;

  StudentBlitzSubmissionTransferController get controller => h.container.read(
    studentBlitzSubmissionTransferControllerProvider(
      blitzExecutionTarget,
    ).notifier,
  );
  StudentSubmissionTransferState get state => h.container.read(
    studentBlitzSubmissionTransferControllerProvider(blitzExecutionTarget),
  );
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
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

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    openCalls += 1;
    return LocalFileOpenOutcome.opened;
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
    return Uri.file('saved.pdf');
  }
}

ResponseBody _download({List<int> bytes = const [1, 2, 3, 4]}) =>
    ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/pdf'],
        Headers.contentLengthHeader: ['${bytes.length}'],
        'content-disposition': ['attachment; filename="safe.pdf"'],
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
