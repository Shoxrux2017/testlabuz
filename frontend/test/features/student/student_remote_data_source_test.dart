import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/student_topic_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_topic_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_topic.dart';
import 'package:testlabuz_client/features/student/domain/student_topic_list_query.dart';

void main() {
  test('list uses exact bodyless GET and approved query parameters', () async {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(
        200,
        _listJson([_summaryJson()], page: 3, total: 41, lastPage: 3),
      ),
    );
    final source = StudentTopicRemoteDataSource(
      dio: _dio(adapter),
      failureMapper: const DioFailureMapper(),
    );
    final query = const StudentTopicListQuery.initial()
        .withSearch('  Internet  ')
        .withStatus(StudentTopicStatus.archived)
        .withPage(3);

    await source.fetchTopics(query);

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/student/topics');
    expect(adapter.request.uri.path, '/api/v1/student/topics');
    expect(adapter.request.data, isNull);
    expect(adapter.request.queryParameters, {
      'page': 3,
      'per_page': 20,
      'status': 'archived',
      'search': 'Internet',
    });
  });

  test('detail uses exact bodyless GET without query', () async {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(200, {'data': _detailJson()}),
    );
    final source = StudentTopicRemoteDataSource(
      dio: _dio(adapter),
      failureMapper: const DioFailureMapper(),
    );

    await source.fetchTopic(_topicId);

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/student/topics/$_topicId');
    expect(adapter.request.data, isNull);
    expect(adapter.request.queryParameters, isEmpty);
  });

  test('requires exactly 200 and maps malformed success', () async {
    for (final response in [
      _jsonResponse(201, _listJson([_summaryJson()])),
      _jsonResponse(200, {'data': _detailJson(), 'message': 'unexpected'}),
    ]) {
      final source = StudentTopicRemoteDataSource(
        dio: _dio(_RecordingAdapter((_) => response)),
        failureMapper: const DioFailureMapper(),
      );
      final operation = response.statusCode == 201
          ? source.fetchTopics(const StudentTopicListQuery.initial())
          : source.fetchTopic(_topicId);

      await expectLater(
        operation,
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );
    }
  });

  test('maps typed Dio failure and repository validates returned ID', () async {
    final failed = StudentTopicRemoteDataSource(
      dio: _dio(
        _RecordingAdapter((options) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }),
      ),
      failureMapper: const DioFailureMapper(),
    );
    await expectLater(
      failed.fetchTopics(const StudentTopicListQuery.initial()),
      throwsA(_failureKind(ApiFailureKind.connection)),
    );

    final wrongIdJson = _detailJson()
      ..['id'] = '10000000-0000-0000-0000-000000000002';
    final repository = StudentTopicRepositoryImpl(
      remoteDataSource: StudentTopicRemoteDataSource(
        dio: _dio(
          _RecordingAdapter((_) => _jsonResponse(200, {'data': wrongIdJson})),
        ),
        failureMapper: const DioFailureMapper(),
      ),
    );
    await expectLater(
      repository.fetchTopic(_topicId),
      throwsA(_failureKind(ApiFailureKind.invalidResponse)),
    );
  });
}

Matcher _failureKind(ApiFailureKind kind) {
  return isA<ApiRequestException>().having(
    (error) => error.failure.kind,
    'kind',
    kind,
  );
}

Dio _dio(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, Object?> _groupJson() {
  return {
    'id': '00000000-0000-0000-0000-000000000001',
    'name': '9-A',
    'level': 'Grade 9',
    'subject_direction': 'Informatics',
    'status': 'active',
  };
}

Map<String, Object?> _summaryJson() {
  return {
    'id': _topicId,
    'group': _groupJson(),
    'title': 'Internet Basics',
    'subject': 'Informatics',
    'lesson_at': null,
    'status': 'archived',
  };
}

Map<String, Object?> _detailJson() {
  return {
    'id': _topicId,
    'group': _groupJson(),
    'title': 'Internet Basics',
    'description': null,
    'subject': 'Informatics',
    'student_instructions': 'Study the materials.',
    'lesson_at': null,
    'status': 'active',
    'materials': <Object?>[],
    'homework': <Object?>[],
    'blitz_status': 'not_available',
    'result_status': 'waiting_for_homework',
  };
}

Map<String, Object?> _listJson(
  List<Object?> rows, {
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) {
  return {
    'data': rows,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': 20,
        'total': total,
        'last_page': lastPage,
      },
    },
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

  FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  RequestOptions get request => requests.single;

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

const _topicId = '10000000-0000-0000-0000-000000000001';
