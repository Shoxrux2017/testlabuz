import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/files/local_file_actions.dart';
import 'package:testlabuz_client/core/files/protected_learning_material_transfer.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_list_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_transfer_controller.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_material_transfer_state.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_topic_detail_controller.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';

void main() {
  test(
    'Save As publishes download progress and cancel stays neutral',
    () async {
      final local = _FakeLocalAdapter();
      final harness = await _Harness.ready(
        transfer: _transfer(_ImmediateAdapter(_downloadResponse())),
        local: local,
      );

      await harness.container
          .read(teacherMaterialTransferControllerProvider(_topicId).notifier)
          .saveAs(teacherMaterial());

      expect(local.saveCalls, 1);
      expect(local.savedName, 'lesson.pdf');
      expect(harness.state.status, TeacherMaterialTransferStatus.idle);
      expect(harness.state.feedback, isNull);
    },
  );

  test('404 refreshes list and file_not_available keeps current row', () async {
    for (final pair in [
      (404, 'resource_not_found'),
      (500, 'file_not_available'),
    ]) {
      final materials = FakeTeacherLearningMaterialRepository();
      final harness = await _Harness.ready(
        materials: materials,
        transfer: _transfer(
          _ImmediateAdapter(_errorResponse(pair.$1, pair.$2)),
        ),
        local: _FakeLocalAdapter(),
      );

      await harness.container
          .read(teacherMaterialTransferControllerProvider(_topicId).notifier)
          .open(teacherMaterial());

      expect(
        harness.state.feedback,
        pair.$2 == 'resource_not_found'
            ? 'This learning material is no longer available.'
            : 'The file is temporarily unavailable. Try again.',
      );
      expect(
        materials.fetchIds,
        pair.$2 == 'resource_not_found' ? [_topicId, _topicId] : [_topicId],
      );
    }
  });

  test(
    'stale session completion cannot Save, Open, or publish feedback',
    () async {
      final response = Completer<ResponseBody>();
      final local = _FakeLocalAdapter()..saveResult = Uri.file('saved.pdf');
      final auth = FakeTeacherAuthSessionController.authenticated(
        teacherUser('teacher-a'),
      );
      final harness = await _Harness.ready(
        transfer: _transfer(_PendingAdapter(response)),
        local: local,
        auth: auth,
      );
      final future = harness.container
          .read(teacherMaterialTransferControllerProvider(_topicId).notifier)
          .saveAs(teacherMaterial());
      await flushTeacherControllers();
      expect(harness.state.status, TeacherMaterialTransferStatus.downloading);

      auth.replaceUser(teacherUser('teacher-b'));
      await flushTeacherControllers();
      response.complete(_downloadResponse());
      await future;

      expect(local.saveCalls, 0);
      expect(local.openCalls, 0);
      expect(harness.state.feedback, isNull);
    },
  );

  test(
    'target removal during download prevents local platform action',
    () async {
      var fetches = 0;
      final materials = FakeTeacherLearningMaterialRepository(
        onFetch: (_) async {
          fetches += 1;
          return teacherMaterialCollection(
            materials: fetches == 1 ? [teacherMaterial()] : [],
          );
        },
      );
      final response = Completer<ResponseBody>();
      final local = _FakeLocalAdapter()..saveResult = Uri.file('saved.pdf');
      final harness = await _Harness.ready(
        materials: materials,
        transfer: _transfer(_PendingAdapter(response)),
        local: local,
      );
      final future = harness.container
          .read(teacherMaterialTransferControllerProvider(_topicId).notifier)
          .saveAs(teacherMaterial());
      await flushTeacherControllers();

      await harness.container
          .read(teacherMaterialListControllerProvider(_topicId).notifier)
          .refreshAuthoritative();
      response.complete(_downloadResponse());
      await future;

      expect(local.saveCalls, 0);
    },
  );
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
      Headers.contentTypeHeader: ['application/pdf'],
      Headers.contentLengthHeader: ['3'],
      'content-disposition': ['attachment; filename="lesson.pdf"'],
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

class _ImmediateAdapter implements HttpClientAdapter {
  _ImmediateAdapter(this.response);

  final ResponseBody response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => response;

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
  String? savedName;

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
    savedName = fileName;
    return saveResult;
  }
}

class _Harness {
  _Harness._(this.container);

  static Future<_Harness> ready({
    required ProtectedLearningMaterialTransfer transfer,
    required _FakeLocalAdapter local,
    FakeTeacherLearningMaterialRepository? materials,
    FakeTeacherAuthSessionController? auth,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(
          () =>
              auth ??
              FakeTeacherAuthSessionController.authenticated(
                teacherUser('teacher-a'),
              ),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        teacherTopicRepositoryProvider.overrideWithValue(
          FakeTeacherTopicRepository(),
        ),
        teacherLearningMaterialRepositoryProvider.overrideWithValue(
          materials ?? FakeTeacherLearningMaterialRepository(),
        ),
        protectedLearningMaterialTransferProvider.overrideWithValue(transfer),
        localFileActionsProvider.overrideWithValue(
          LocalFileActions(platform: local),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      teacherTopicDetailControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
    container.listen(
      teacherMaterialListControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
    container.listen(
      teacherMaterialTransferControllerProvider(_topicId),
      (_, _) {},
      fireImmediately: true,
    );
    await flushTeacherControllers();
    await flushTeacherControllers();
    return _Harness._(container);
  }

  final ProviderContainer container;

  TeacherMaterialTransferState get state =>
      container.read(teacherMaterialTransferControllerProvider(_topicId));
}
