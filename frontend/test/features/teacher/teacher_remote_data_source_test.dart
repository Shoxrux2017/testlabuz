import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_group_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_list_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_group_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_list_query.dart';

void main() {
  group('Teacher Group remote data source', () {
    test('uses exact bodyless GET and approved query parameters', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _listJson([_groupJson()])),
      );
      final source = TeacherGroupListRemoteDataSource(
        dio: _dio(adapter),
        failureMapper: const DioFailureMapper(),
      );
      final query = const TeacherGroupListQuery.initial()
          .withSearch('  Group % _  ')
          .withPage(2);
      adapter.handler = (_) => _jsonResponse(
        200,
        _listJson(const [], page: 2, total: 20, lastPage: 1),
      );

      await source.fetchGroups(query);

      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/teacher/groups');
      expect(adapter.request.uri.path, '/api/v1/teacher/groups');
      expect(adapter.request.data, isNull);
      expect(adapter.request.queryParameters, {
        'page': 2,
        'per_page': 20,
        'sort': 'name',
        'direction': 'asc',
        'search': 'Group % _',
      });
    });

    test('maps malformed success and Dio failures', () async {
      final malformed = TeacherGroupListRemoteDataSource(
        dio: _dio(_RecordingAdapter((_) => _jsonResponse(200, {'data': []}))),
        failureMapper: const DioFailureMapper(),
      );
      await expectLater(
        malformed.fetchGroups(const TeacherGroupListQuery.initial()),
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );

      final failed = TeacherGroupListRemoteDataSource(
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
        failed.fetchGroups(const TeacherGroupListQuery.initial()),
        throwsA(_failureKind(ApiFailureKind.connection)),
      );
    });
  });

  group('Teacher Topic remote data source', () {
    test('uses exact bodyless GET and all approved optional filters', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _listJson([_topicJson()], page: 3, total: 41, lastPage: 3),
        ),
      );
      final source = TeacherTopicListRemoteDataSource(
        dio: _dio(adapter),
        failureMapper: const DioFailureMapper(),
      );
      final query = const TeacherTopicListQuery.initial()
          .withSearch('  Algebra  ')
          .withStatus(TeacherTopicStatus.archived)
          .withGroupId('00000000-0000-0000-0000-000000000001')
          .withPage(3);

      await source.fetchTopics(query);

      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/teacher/topics');
      expect(adapter.request.uri.path, '/api/v1/teacher/topics');
      expect(adapter.request.data, isNull);
      expect(adapter.request.queryParameters, {
        'page': 3,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
        'group_id': '00000000-0000-0000-0000-000000000001',
        'status': 'archived',
        'search': 'Algebra',
      });
    });

    test('requires exactly 200 and maps malformed success', () async {
      for (final response in [
        _jsonResponse(201, _listJson([_topicJson()])),
        _jsonResponse(200, _listJson([_topicJson()..['unknown'] = true])),
      ]) {
        final source = TeacherTopicListRemoteDataSource(
          dio: _dio(_RecordingAdapter((_) => response)),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          source.fetchTopics(const TeacherTopicListQuery.initial()),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
      }
    });
  });

  test('repositories delegate and convert typed DTO pages to domain', () async {
    final groupRepository = TeacherGroupListRepositoryImpl(
      remoteDataSource: TeacherGroupListRemoteDataSource(
        dio: _dio(
          _RecordingAdapter(
            (_) => _jsonResponse(200, _listJson([_groupJson()])),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      ),
    );
    final topicRepository = TeacherTopicListRepositoryImpl(
      remoteDataSource: TeacherTopicListRemoteDataSource(
        dio: _dio(
          _RecordingAdapter(
            (_) => _jsonResponse(200, _listJson([_topicJson()])),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      ),
    );

    final groupPage = await groupRepository.fetchGroups(
      const TeacherGroupListQuery.initial(),
    );
    final topicPage = await topicRepository.fetchTopics(
      const TeacherTopicListQuery.initial(),
    );

    expect(groupPage.groups.single.name, 'Group A');
    expect(topicPage.topics.single.title, 'Linear equations');
    expect(topicPage.pagination.total, 1);
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
    'name': 'Group A',
    'level': '7',
    'subject_direction': 'Mathematics',
    'status': 'active',
  };
}

Map<String, Object?> _topicJson() {
  return {
    'id': '10000000-0000-0000-0000-000000000001',
    'group': _groupJson(),
    'title': 'Linear equations',
    'description': null,
    'subject': 'Algebra',
    'student_instructions': 'Read the examples.',
    'lesson_at': '2026-08-25T08:00:00Z',
    'status': 'draft',
    'activated_at': null,
    'closed_at': null,
    'archived_at': null,
    'created_at': '2026-08-19T10:00:00Z',
    'updated_at': '2026-08-22T10:00:00Z',
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
