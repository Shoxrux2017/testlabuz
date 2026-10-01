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
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_submission_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_submission_detail_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_submission_file_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_submission_file_state.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_submission_detail_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_detail.dart';

import 'teacher_submission_test_support.dart';
import 'teacher_test_support.dart';

const _file = TeacherReviewFile(
  id: detailFileId,
  originalName: 'report.pdf',
  extension: 'pdf',
  sizeBytes: 2048,
);

void main() {
  group('TeacherSubmissionDetailController', () {
    test('loads the submission on desktop', () async {
      final harness = _Harness();
      final state = harness.listenDetail();
      expect(state.read().status, TeacherSubmissionDetailStatus.loading);
      await flushTeacherControllers();

      expect(harness.submissions.detailIds, [submissionId]);
      expect(state.read().status, TeacherSubmissionDetailStatus.data);
      expect(state.read().detail?.questions, hasLength(10));
    });

    test('is inactive on mobile', () async {
      final harness = _Harness(surface: AppDeviceSurface.mobile);
      final state = harness.listenDetail();
      await flushTeacherControllers();

      expect(harness.submissions.detailIds, isEmpty);
      expect(state.read().status, TeacherSubmissionDetailStatus.initial);
    });

    test('a missing submission is not found', () async {
      final harness = _Harness(
        onFetchDetail: (_) async => throw teacherServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      );
      final state = harness.listenDetail();
      await flushTeacherControllers();

      expect(state.read().status, TeacherSubmissionDetailStatus.notFound);
      expect(state.read().detail, isNull);
    });

    test('a first-load failure can be retried', () async {
      var calls = 0;
      final harness = _Harness(
        onFetchDetail: (_) async {
          calls += 1;
          if (calls == 1) {
            throw teacherLocalFailure(ApiFailureKind.connection);
          }
          return _detail();
        },
      );
      final state = harness.listenDetail();
      await flushTeacherControllers();
      expect(state.read().status, TeacherSubmissionDetailStatus.error);
      expect(state.read().isStale, isFalse);

      harness.detailController.retry();
      await flushTeacherControllers();

      expect(state.read().status, TeacherSubmissionDetailStatus.data);
    });

    test('a failed refresh keeps the detail and marks it stale', () async {
      var calls = 0;
      final harness = _Harness(
        onFetchDetail: (_) async {
          calls += 1;
          if (calls == 2) {
            throw teacherLocalFailure(ApiFailureKind.timeout);
          }
          return _detail();
        },
      );
      final state = harness.listenDetail();
      await flushTeacherControllers();

      harness.detailController.refresh();
      expect(state.read().status, TeacherSubmissionDetailStatus.refreshing);
      await flushTeacherControllers();

      expect(state.read().status, TeacherSubmissionDetailStatus.error);
      expect(state.read().isStale, isTrue);
      expect(state.read().detail, isNotNull);
    });

    test('a load from a previous session is dropped', () async {
      final first = Completer<TeacherSubmissionDetail>();
      var calls = 0;
      final harness = _Harness(
        onFetchDetail: (_) {
          calls += 1;
          return calls == 1 ? first.future : Future.value(_detail());
        },
      );
      final state = harness.listenDetail();
      await flushTeacherControllers();

      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      first.complete(
        TeacherSubmissionDetailDto.fromJson(
          submissionDetailJson(submittedAt: null),
        ).toDomain(),
      );
      await flushTeacherControllers();

      expect(harness.submissions.detailIds, [submissionId, submissionId]);
      expect(state.read().status, TeacherSubmissionDetailStatus.data);
      expect(state.read().detail?.submittedAt, isNotNull);
    });

    test('a session failure clears the controller', () async {
      final harness = _Harness(
        onFetchDetail: (_) async =>
            throw teacherServerFailure(ApiErrorCodes.institutionInactive),
      );
      final state = harness.listenDetail();
      await flushTeacherControllers();

      expect(state.read().status, TeacherSubmissionDetailStatus.initial);
      expect(harness.auth.bootstrapCalls, 1);
    });
  });

  group('TeacherSubmissionFileController', () {
    test('downloads and saves a submitted file', () async {
      final harness = _Harness();
      final state = harness.listenFile();
      await flushTeacherControllers();

      await harness.fileController.saveFile(_file);

      expect(
        harness.adapter.requests.single.path,
        '/files/$detailFileId/download',
      );
      expect(harness.local.saveCalls, 1);
      expect(harness.local.savedTitle, 'Save submitted file');
      expect(state.read().status, TeacherSubmissionFileStatus.idle);
      expect(state.read().feedback, 'File saved.');

      harness.fileController.consumeFeedback();
      expect(state.read().feedback, isNull);
    });

    test('a cancelled save leaves no feedback', () async {
      final harness = _Harness();
      harness.local.cancel = true;
      final state = harness.listenFile();
      await flushTeacherControllers();

      await harness.fileController.saveFile(_file);

      expect(state.read().status, TeacherSubmissionFileStatus.idle);
      expect(state.read().feedback, isNull);
    });

    test('each failure has its own message', () async {
      final cases = <(FutureOr<ResponseBody> Function(RequestOptions), String)>[
        (
          (_) => _error(404, ApiErrorCodes.resourceNotFound),
          'This file is no longer available.',
        ),
        (
          (_) => _error(500, ApiErrorCodes.fileNotAvailable),
          'The file is temporarily unavailable. Try again.',
        ),
        (
          (_) => _download(contentType: 'text/html'),
          'The server returned an unexpected file response.',
        ),
        (
          (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
          'The download timed out. Try again.',
        ),
        (
          (_) => _error(403, ApiErrorCodes.forbidden),
          'The file could not be downloaded.',
        ),
      ];

      for (final (handler, message) in cases) {
        final harness = _Harness(handler: handler);
        final state = harness.listenFile();
        await flushTeacherControllers();

        await harness.fileController.saveFile(_file);

        expect(
          state.read().status,
          TeacherSubmissionFileStatus.failure,
          reason: message,
        );
        expect(state.read().feedback, message);
        expect(state.read().fileId, detailFileId);
        expect(harness.local.saveCalls, 0);
      }
    });

    test('only one transfer runs at a time', () async {
      final release = Completer<ResponseBody>();
      final harness = _Harness(handler: (_) => release.future);
      final state = harness.listenFile();
      await flushTeacherControllers();

      final first = harness.fileController.saveFile(_file);
      await flushTeacherControllers();
      expect(state.read().status, TeacherSubmissionFileStatus.downloading);
      expect(state.read().fileId, detailFileId);
      await harness.fileController.saveFile(_file);
      release.complete(_download());
      await first;

      expect(harness.adapter.requests, hasLength(1));
      expect(harness.local.saveCalls, 1);
    });

    test('a session failure clears the transfer', () async {
      final harness = _Harness(
        handler: (_) => _error(401, ApiErrorCodes.authenticationRequired),
      );
      final state = harness.listenFile();
      await flushTeacherControllers();

      await harness.fileController.saveFile(_file);

      expect(state.read().status, TeacherSubmissionFileStatus.idle);
      expect(state.read().feedback, isNull);
    });

    test('a download from a previous session is dropped', () async {
      final release = Completer<ResponseBody>();
      final harness = _Harness(handler: (_) => release.future);
      final state = harness.listenFile();
      await flushTeacherControllers();

      final saving = harness.fileController.saveFile(_file);
      await flushTeacherControllers();
      harness.auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      release.complete(_download());
      await saving;

      expect(harness.local.saveCalls, 0);
      expect(state.read().status, TeacherSubmissionFileStatus.idle);
      expect(state.read().feedback, isNull);
    });

    test('is inactive on mobile', () async {
      final harness = _Harness(surface: AppDeviceSurface.mobile);
      harness.listenFile();
      await flushTeacherControllers();

      await harness.fileController.saveFile(_file);

      expect(harness.adapter.requests, isEmpty);
    });
  });
}

TeacherSubmissionDetail _detail() =>
    TeacherSubmissionDetailDto.fromJson(submissionDetailJson()).toDomain();

class _Harness {
  _Harness({
    Future<TeacherSubmissionDetail> Function(String submissionId)?
    onFetchDetail,
    FutureOr<ResponseBody> Function(RequestOptions)? handler,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) : auth = FakeTeacherAuthSessionController.authenticated(
         teacherUser('teacher-a'),
       ),
       submissions = FakeTeacherSubmissionRepository()
         ..onFetchDetail = onFetchDetail,
       adapter = _Adapter(handler ?? (_) => _download()),
       local = _LocalAdapter() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(() => auth),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        teacherSubmissionRepositoryProvider.overrideWithValue(submissions),
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
    addTearDown(container.dispose);
  }

  final FakeTeacherAuthSessionController auth;
  final FakeTeacherSubmissionRepository submissions;
  final _Adapter adapter;
  final _LocalAdapter local;
  late final ProviderContainer container;

  ProviderSubscription<TeacherSubmissionDetailState> listenDetail() =>
      container.listen(
        teacherSubmissionDetailControllerProvider(submissionId),
        (_, _) {},
        fireImmediately: true,
      );

  ProviderSubscription<TeacherSubmissionFileState> listenFile() =>
      container.listen(
        teacherSubmissionFileControllerProvider(submissionId),
        (_, _) {},
        fireImmediately: true,
      );

  TeacherSubmissionDetailController get detailController => container.read(
    teacherSubmissionDetailControllerProvider(submissionId).notifier,
  );

  TeacherSubmissionFileController get fileController => container.read(
    teacherSubmissionFileControllerProvider(submissionId).notifier,
  );
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _LocalAdapter implements LocalFilePlatformAdapter {
  int saveCalls = 0;
  String? savedTitle;
  bool cancel = false;

  @override
  Future<LocalFileOpenOutcome> openTemporaryFile({
    required String fileId,
    required String extension,
    required String mimeType,
    required Uint8List bytes,
  }) async => LocalFileOpenOutcome.opened;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String dialogTitle,
  }) async {
    saveCalls += 1;
    savedTitle = dialogTitle;
    return cancel ? null : Uri.file('saved.pdf');
  }
}

ResponseBody _download({String contentType = 'application/pdf'}) =>
    ResponseBody.fromBytes(
      const [1, 2, 3, 4],
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
        'content-disposition': ['attachment; filename="report.pdf"'],
        'cache-control': ['no-store, private'],
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
