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
import 'package:testlabuz_client/features/student/application/student_material_transfer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_material_transfer_state.dart';
import 'package:testlabuz_client/features/student/application/student_topic_detail_controller.dart';
import 'package:testlabuz_client/features/student/application/student_topic_detail_state.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_topic.dart';

import 'student_test_support.dart';

void main() {
  group('Student Topic detail controller', () {
    test(
      'loads, refreshes with data retained, and rejects invalid target',
      () async {
        final pendingRefresh = Completer<StudentTopicDetail>();
        var fetches = 0;
        final repository = FakeStudentTopicRepository(
          onFetchTopic: (id) {
            fetches += 1;
            return fetches == 1
                ? Future.value(studentTopicDetail(id: id))
                : pendingRefresh.future;
          },
        );
        final container = _detailContainer(repository: repository);
        final subscription = _listenDetail(container, studentTopicId);
        await flushStudentControllers();
        expect(subscription.read().status, StudentTopicDetailStatus.data);

        container
            .read(studentTopicDetailControllerProvider(studentTopicId).notifier)
            .refresh();
        expect(subscription.read().status, StudentTopicDetailStatus.refreshing);
        expect(subscription.read().topic, isNotNull);
        pendingRefresh.complete(
          studentTopicDetail(id: studentTopicId, title: 'Refreshed Topic'),
        );
        await flushStudentControllers();
        expect(subscription.read().topic!.title, 'Refreshed Topic');

        final invalid = _listenDetail(container, 'invalid-topic');
        await flushStudentControllers();
        expect(invalid.read().status, StudentTopicDetailStatus.initial);
        expect(repository.detailIds, [studentTopicId, studentTopicId]);
      },
    );

    test('privacy-safe 404 becomes unavailable and invalidates list', () async {
      final repository = FakeStudentTopicRepository(
        onFetchTopic: (_) async => throw studentServerFailure(
          ApiErrorCodes.resourceNotFound,
          statusCode: 404,
        ),
      );
      final container = _detailContainer(repository: repository);
      final subscription = _listenDetail(container, studentTopicId);
      await flushStudentControllers();

      expect(subscription.read().status, StudentTopicDetailStatus.notFound);
    });

    test(
      'stale detail completion cannot publish after session replacement',
      () async {
        final pending = Completer<StudentTopicDetail>();
        final replacement = Completer<StudentTopicDetail>();
        var fetches = 0;
        final repository = FakeStudentTopicRepository(
          onFetchTopic: (_) {
            fetches += 1;
            return fetches == 1 ? pending.future : replacement.future;
          },
        );
        final auth = FakeStudentAuthSessionController.authenticated(
          studentUser('student-a'),
        );
        final container = _detailContainer(repository: repository, auth: auth);
        final subscription = _listenDetail(container, studentTopicId);
        await flushStudentControllers();

        auth.replaceUser(studentUser('student-b'));
        await flushStudentControllers();
        pending.complete(studentTopicDetail(title: 'Old session Topic'));
        await flushStudentControllers();

        expect(subscription.read().topic?.title, isNot('Old session Topic'));
        replacement.complete(studentTopicDetail(title: 'New session Topic'));
        await flushStudentControllers();
        expect(subscription.read().topic?.title, 'New session Topic');
      },
    );
  });

  group('Student protected Material transfer integration', () {
    test(
      'Open and Save As directly reuse shared providers on both surfaces',
      () async {
        for (final surface in [
          AppDeviceSurface.desktop,
          AppDeviceSurface.mobile,
        ]) {
          final adapter = _QueueAdapter([
            _downloadResponse(),
            _downloadResponse(),
          ]);
          final local = _FakeLocalAdapter()
            ..saveResult = Uri.file('saved.pptx');
          final harness = await _TransferHarness.ready(
            transfer: _transfer(adapter),
            local: local,
            surface: surface,
          );
          final controller = harness.container.read(
            studentMaterialTransferControllerProvider(studentTopicId).notifier,
          );

          await controller.open(studentMaterial());
          await controller.saveAs(studentMaterial());

          expect(local.openCalls, 1);
          expect(local.saveCalls, 1);
          expect(adapter.requests, hasLength(2));
          for (final request in adapter.requests) {
            expect(request.method, 'GET');
            expect(request.path, '/files/$studentFileId/download');
            expect(request.data, isNull);
            expect(request.queryParameters, isEmpty);
          }
        }
      },
    );

    test(
      'Material 404 refreshes authoritative detail and removes stale row',
      () async {
        var detailFetches = 0;
        final repository = FakeStudentTopicRepository(
          onFetchTopic: (id) async {
            detailFetches += 1;
            return studentTopicDetail(
              id: id,
              materials: detailFetches == 1 ? [studentMaterial()] : const [],
            );
          },
        );
        final harness = await _TransferHarness.ready(
          repository: repository,
          transfer: _transfer(
            _QueueAdapter([
              _errorResponse(404, ApiErrorCodes.resourceNotFound),
            ]),
          ),
          local: _FakeLocalAdapter(),
        );

        await harness.container
            .read(
              studentMaterialTransferControllerProvider(
                studentTopicId,
              ).notifier,
            )
            .open(studentMaterial());

        expect(detailFetches, 2);
        expect(harness.detail.topic!.materials, isEmpty);
        expect(
          harness.transfer.feedback,
          'This learning material is no longer available.',
        );
      },
    );

    test('Topic 404 after Material 404 transitions to unavailable', () async {
      var detailFetches = 0;
      final repository = FakeStudentTopicRepository(
        onFetchTopic: (id) async {
          detailFetches += 1;
          if (detailFetches == 1) {
            return studentTopicDetail(id: id);
          }
          throw studentServerFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          );
        },
      );
      final harness = await _TransferHarness.ready(
        repository: repository,
        transfer: _transfer(
          _QueueAdapter([_errorResponse(404, ApiErrorCodes.resourceNotFound)]),
        ),
        local: _FakeLocalAdapter(),
      );

      await harness.container
          .read(
            studentMaterialTransferControllerProvider(studentTopicId).notifier,
          )
          .open(studentMaterial());

      expect(harness.detail.status, StudentTopicDetailStatus.notFound);
      expect(harness.transfer.isBusy, isFalse);
    });

    test(
      'file_not_available keeps Material visible without detail refresh',
      () async {
        final repository = FakeStudentTopicRepository();
        final harness = await _TransferHarness.ready(
          repository: repository,
          transfer: _transfer(
            _QueueAdapter([
              _errorResponse(500, ApiErrorCodes.fileNotAvailable),
            ]),
          ),
          local: _FakeLocalAdapter(),
        );

        await harness.container
            .read(
              studentMaterialTransferControllerProvider(
                studentTopicId,
              ).notifier,
            )
            .open(studentMaterial());

        expect(repository.detailIds, [studentTopicId]);
        expect(harness.detail.topic!.materials, hasLength(1));
        expect(
          harness.transfer.feedback,
          'The file is temporarily unavailable. Try again.',
        );
      },
    );

    test('timeout has no automatic retry and allows manual retry', () async {
      final adapter = _QueueAdapter([
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.receiveTimeout,
        ),
        _downloadResponse(),
      ]);
      final local = _FakeLocalAdapter();
      final harness = await _TransferHarness.ready(
        transfer: _transfer(adapter),
        local: local,
      );
      final controller = harness.container.read(
        studentMaterialTransferControllerProvider(studentTopicId).notifier,
      );

      await controller.open(studentMaterial());
      expect(adapter.requests, hasLength(1));
      expect(harness.transfer.feedback, 'The download timed out. Try again.');
      await controller.open(studentMaterial());
      expect(adapter.requests, hasLength(2));
      expect(local.openCalls, 1);
    });

    test(
      'stale session and target completions cannot invoke local actions',
      () async {
        final response = Completer<ResponseBody>();
        final auth = FakeStudentAuthSessionController.authenticated(
          studentUser('student-a'),
        );
        final local = _FakeLocalAdapter()..saveResult = Uri.file('saved.pptx');
        final harness = await _TransferHarness.ready(
          transfer: _transfer(_PendingAdapter(response)),
          local: local,
          auth: auth,
        );
        final future = harness.container
            .read(
              studentMaterialTransferControllerProvider(
                studentTopicId,
              ).notifier,
            )
            .saveAs(studentMaterial());
        await flushStudentControllers();
        expect(
          harness.transfer.status,
          StudentMaterialTransferStatus.downloading,
        );

        auth.replaceUser(studentUser('student-b'));
        await flushStudentControllers();
        response.complete(_downloadResponse());
        await future;

        expect(local.saveCalls, 0);
        expect(local.openCalls, 0);
      },
    );

    test(
      'Material replacement during download prevents local action',
      () async {
        var detailFetches = 0;
        final repository = FakeStudentTopicRepository(
          onFetchTopic: (id) async {
            detailFetches += 1;
            return studentTopicDetail(
              id: id,
              materials: detailFetches == 1 ? [studentMaterial()] : const [],
            );
          },
        );
        final response = Completer<ResponseBody>();
        final local = _FakeLocalAdapter()..saveResult = Uri.file('saved.pptx');
        final harness = await _TransferHarness.ready(
          repository: repository,
          transfer: _transfer(_PendingAdapter(response)),
          local: local,
        );
        final future = harness.container
            .read(
              studentMaterialTransferControllerProvider(
                studentTopicId,
              ).notifier,
            )
            .saveAs(studentMaterial());
        await flushStudentControllers();
        harness.container
            .read(studentTopicDetailControllerProvider(studentTopicId).notifier)
            .refresh();
        await flushStudentControllers();
        expect(harness.detail.topic!.materials, isEmpty);

        response.complete(_downloadResponse());
        await future;

        expect(local.saveCalls, 0);
        expect(local.openCalls, 0);
      },
    );
  });
}

ProviderContainer _detailContainer({
  required FakeStudentTopicRepository repository,
  FakeStudentAuthSessionController? auth,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(
        () =>
            auth ??
            FakeStudentAuthSessionController.authenticated(
              studentUser('student-a'),
            ),
      ),
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      studentTopicRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<StudentTopicDetailState> _listenDetail(
  ProviderContainer container,
  String topicId,
) {
  final subscription = container.listen(
    studentTopicDetailControllerProvider(topicId),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  return subscription;
}

ProtectedLearningMaterialTransfer _transfer(HttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = adapter;
  return ProtectedLearningMaterialTransfer(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

ResponseBody _downloadResponse() {
  return ResponseBody.fromBytes(
    Uint8List.fromList([1, 2, 3]),
    200,
    headers: {
      Headers.contentTypeHeader: [
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      ],
      Headers.contentLengthHeader: ['3'],
      'content-disposition': ['attachment; filename="lesson.pptx"'],
      'cache-control': ['private, no-store'],
      'x-content-type-options': ['nosniff'],
    },
  );
}

ResponseBody _errorResponse(int status, String code) {
  return ResponseBody.fromBytes(
    Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'message': 'Safe error.',
          'code': code,
          'errors': <String, Object?>{},
        }),
      ),
    ),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<Object> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responses.removeAt(0);
    if (response is DioException) {
      throw DioException(
        requestOptions: options,
        type: response.type,
        response: response.response,
      );
    }
    return response as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}

class _PendingAdapter implements HttpClientAdapter {
  _PendingAdapter(this.response);

  final Completer<ResponseBody> response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => response.future;

  @override
  void close({bool force = false}) {}
}

class _FakeLocalAdapter implements LocalFilePlatformAdapter {
  int saveCalls = 0;
  int openCalls = 0;
  Uri? saveResult;

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
  }) async {
    saveCalls += 1;
    return saveResult;
  }
}

class _TransferHarness {
  _TransferHarness._(this.container);

  static Future<_TransferHarness> ready({
    required ProtectedLearningMaterialTransfer transfer,
    required _FakeLocalAdapter local,
    FakeStudentTopicRepository? repository,
    FakeStudentAuthSessionController? auth,
    AppDeviceSurface surface = AppDeviceSurface.desktop,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeStudentAuthSessionController.authenticated(
                studentUser('student-a'),
              ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        studentTopicRepositoryProvider.overrideWithValue(
          repository ?? FakeStudentTopicRepository(),
        ),
        protectedLearningMaterialTransferProvider.overrideWithValue(transfer),
        localFileActionsProvider.overrideWithValue(
          LocalFileActions(platform: local),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      studentTopicDetailControllerProvider(studentTopicId),
      (_, _) {},
      fireImmediately: true,
    );
    container.listen(
      studentMaterialTransferControllerProvider(studentTopicId),
      (_, _) {},
      fireImmediately: true,
    );
    await flushStudentControllers();
    await flushStudentControllers();
    return _TransferHarness._(container);
  }

  final ProviderContainer container;

  StudentTopicDetailState get detail =>
      container.read(studentTopicDetailControllerProvider(studentTopicId));

  StudentMaterialTransferState get transfer =>
      container.read(studentMaterialTransferControllerProvider(studentTopicId));
}
