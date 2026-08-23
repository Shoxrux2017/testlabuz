import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_learning_material_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_learning_material_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _materialId = '20000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherLearningMaterialRemoteDataSource', () {
    test(
      'uses exact list and mutation requests with streaming transfers',
      () async {
        final adapter = _RecordingAdapter((options) {
          if (options.method == 'GET') {
            return _jsonResponse(200, _listJson());
          }
          if (options.path.endsWith('/replace')) {
            return _jsonResponse(200, {
              'data': _materialJson(),
              'message':
                  TeacherLearningMaterialRemoteDataSource.replaceSuccessMessage,
            });
          }
          if (options.method == 'PATCH') {
            return _jsonResponse(200, {
              'data': _materialJson()..['title'] = 'Updated title',
              'message':
                  TeacherLearningMaterialRemoteDataSource.updateSuccessMessage,
            });
          }
          if (options.method == 'DELETE') {
            return ResponseBody.fromString('', 204);
          }
          return _jsonResponse(201, {'data': _materialJson()});
        });
        final source = TeacherLearningMaterialRemoteDataSource(
          dio: _dio(adapter),
          failureMapper: const DioFailureMapper(),
        );
        var streamOpens = 0;
        final file = TeacherMaterialUploadFile(
          name: 'lesson.pptx',
          length: 4,
          openRead: () {
            streamOpens += 1;
            return Stream<List<int>>.value([1, 2, 3, 4]);
          },
        );
        final current = teacherMaterial();

        await source.fetchMaterials(_topicId);
        await source.uploadMaterial(topicId: _topicId, file: file, title: null);
        await source.replaceMaterialFile(
          topicId: _topicId,
          materialId: _materialId,
          file: file,
        );
        await source.updateMaterialTitle(
          topicId: _topicId,
          materialId: _materialId,
          title: 'Updated title',
        );
        await source.removeMaterial(topicId: _topicId, materialId: current.id);

        expect(streamOpens, 2);
        final list = adapter.requests[0];
        expect(list.method, 'GET');
        expect(list.path, '/teacher/topics/$_topicId/materials');
        expect(list.data, isNull);
        expect(list.queryParameters, isEmpty);

        final upload = adapter.requests[1];
        expect(upload.path, '/teacher/topics/$_topicId/materials');
        expect(upload.method, 'POST');
        expect(upload.queryParameters, isEmpty);
        expect(upload.sendTimeout, const Duration(minutes: 5));
        expect(upload.receiveTimeout, const Duration(seconds: 20));
        final uploadForm = upload.data! as FormData;
        expect(uploadForm.fields, isEmpty);
        expect(uploadForm.files.map((entry) => entry.key), ['file']);
        expect(uploadForm.files.single.value.filename, 'lesson.pptx');
        expect(uploadForm.files.single.value.length, 4);

        final replace = adapter.requests[2];
        expect(replace.path, '/teacher/materials/$_materialId/replace');
        expect(replace.queryParameters, isEmpty);
        expect(replace.sendTimeout, const Duration(minutes: 5));
        final replaceForm = replace.data! as FormData;
        expect(replaceForm.fields, isEmpty);
        expect(replaceForm.files.map((entry) => entry.key), ['file']);

        final patch = adapter.requests[3];
        expect(patch.method, 'PATCH');
        expect(patch.path, '/teacher/materials/$_materialId');
        expect(patch.queryParameters, isEmpty);
        expect(patch.data, {'title': 'Updated title'});
        expect(patch.sendTimeout, const Duration(seconds: 15));

        final remove = adapter.requests[4];
        expect(remove.method, 'DELETE');
        expect(remove.path, '/teacher/materials/$_materialId');
        expect(remove.data, isNull);
        expect(remove.queryParameters, isEmpty);
      },
    );

    test(
      'upload sends only non-null trimmed title supplied by application',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(201, {
            'data': _materialJson()..['title'] = 'Custom title',
          }),
        );
        final source = TeacherLearningMaterialRemoteDataSource(
          dio: _dio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        await source.uploadMaterial(
          topicId: _topicId,
          file: _uploadFile(),
          title: 'Custom title',
        );

        final fields = (adapter.requests.single.data! as FormData).fields;
        expect(fields, hasLength(1));
        expect(fields.single.key, 'title');
        expect(fields.single.value, 'Custom title');
      },
    );

    test(
      'strict malformed mutation success and transport stay unknown',
      () async {
        for (final handler in <FutureOr<ResponseBody> Function(RequestOptions)>[
          (_) => _jsonResponse(200, {'data': _materialJson()}),
          (_) =>
              _jsonResponse(201, {'data': _materialJson(), 'unexpected': true}),
          (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ]) {
          final source = TeacherLearningMaterialRemoteDataSource(
            dio: _dio(_RecordingAdapter(handler)),
            failureMapper: const DioFailureMapper(),
          );

          await expectLater(
            source.uploadMaterial(
              topicId: _topicId,
              file: _uploadFile(),
              title: null,
            ),
            throwsA(isA<TeacherMaterialMutationOutcomeUnknownException>()),
          );
        }
      },
    );

    test('defined machine errors map without mutation replay', () async {
      for (final pair in [
        (422, ApiErrorCodes.unsupportedFileType),
        (422, ApiErrorCodes.fileTooLarge),
        (500, ApiErrorCodes.fileUploadFailed),
        (409, ApiErrorCodes.topicNotEditable),
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(pair.$1, _error(pair.$2)),
        );
        final source = TeacherLearningMaterialRemoteDataSource(
          dio: _dio(adapter),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          source.uploadMaterial(
            topicId: _topicId,
            file: _uploadFile(),
            title: null,
          ),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.serverCode,
              'code',
              pair.$2,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test('strict list failures map to typed read failures', () async {
      final source = TeacherLearningMaterialRemoteDataSource(
        dio: _dio(
          _RecordingAdapter(
            (_) => _jsonResponse(200, {
              ..._listJson(),
              'message': 'Not allowed on success.',
            }),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );

      await expectLater(
        source.fetchMaterials(_topicId),
        throwsA(isA<ApiRequestException>()),
      );
    });
  });

  test(
    'repository enforces replace Material, File, Topic and title identity',
    () async {
      final response = _materialJson()
        ..['file'] = {
          ...(_materialJson()['file']! as Map<String, Object?>),
          'id': '30000000-0000-0000-0000-000000000002',
        };
      final repository = TeacherLearningMaterialRepositoryImpl(
        remoteDataSource: TeacherLearningMaterialRemoteDataSource(
          dio: _dio(
            _RecordingAdapter(
              (_) => _jsonResponse(200, {
                'data': response,
                'message': TeacherLearningMaterialRemoteDataSource
                    .replaceSuccessMessage,
              }),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        ),
      );

      await expectLater(
        repository.replaceMaterialFile(
          topicId: _topicId,
          current: teacherMaterial(),
          file: _uploadFile(),
        ),
        throwsA(isA<TeacherMaterialMutationOutcomeUnknownException>()),
      );
    },
  );
}

TeacherMaterialUploadFile _uploadFile() {
  return TeacherMaterialUploadFile(
    name: 'lesson.pptx',
    length: 4,
    openRead: () => Stream<List<int>>.value([1, 2, 3, 4]),
  );
}

Dio _dio(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, Object?> _listJson() {
  return {
    'data': [_materialJson()],
    'meta': {
      'upload': {
        'max_size_bytes': 20_971_520,
        'platform_max_size_bytes': 26_214_400,
        'allowed_extensions': ['pdf', 'docx', 'ppt', 'pptx'],
      },
    },
  };
}

Map<String, Object?> _materialJson() {
  return {
    'id': _materialId,
    'topic_id': _topicId,
    'title': 'Lesson slides',
    'file': {
      'id': '30000000-0000-0000-0000-000000000001',
      'original_name': 'lesson.pptx',
      'mime_type':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'extension': 'pptx',
      'size_bytes': 1_250_000,
    },
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T15:00:00Z',
  };
}

Map<String, Object?> _error(String code) {
  return {
    'message': 'Safe error.',
    'code': code,
    'errors': <String, Object?>{},
    'request_id': 'req-1',
  };
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
