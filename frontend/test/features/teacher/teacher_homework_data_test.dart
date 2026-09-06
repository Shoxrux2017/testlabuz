import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list_query.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '20000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherHomeworkRemoteDataSource', () {
    test('uses exact bodyless list GET and approved query', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _listJson([_summaryJson()], page: 3, total: 41, lastPage: 3),
        ),
      );
      final source = _source(adapter);
      final query = const TeacherHomeworkListQuery.initial()
          .withSearch('  Algebra % _  ')
          .withStatus(TeacherHomeworkStatus.archived)
          .withAssignmentMode(TeacherHomeworkAssignmentMode.selectedStudents)
          .withPage(3);

      await source.fetchHomeworkList(_topicId, query);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/topics/$_topicId/homework');
      expect(request.uri.path, '/api/v1/teacher/topics/$_topicId/homework');
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
      expect(request.queryParameters, {
        'page': 3,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
        'search': 'Algebra % _',
        'status': 'archived',
        'assignment_mode': 'selected_students',
      });
    });

    test('omits optional list filters and sends fixed sort', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _listJson(const [], total: 0)),
      );

      await _source(
        adapter,
      ).fetchHomeworkList(_topicId, const TeacherHomeworkListQuery.initial());

      expect(adapter.requests.single.queryParameters, {
        'page': 1,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
      });
    });

    test('uses exact bodyless detail GET without query', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'data': _homeworkJson()}),
      );

      final dto = await _source(adapter).fetchHomework(_homeworkId);

      expect(dto.homework.id, _homeworkId);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/homework/$_homeworkId');
      expect(request.uri.path, '/api/v1/teacher/homework/$_homeworkId');
      expect(request.queryParameters, isEmpty);
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
    });

    test(
      'requires 200 and maps malformed success to invalid response',
      () async {
        for (final response in [
          _jsonResponse(201, _listJson([_summaryJson()])),
          _jsonResponse(200, {'data': _homeworkJson(), 'extra': true}),
          _jsonResponse(200, {'data': _homeworkJson()..['points'] = '1'}),
        ]) {
          final source = _source(_RecordingAdapter((_) => response));
          final operation = response.statusCode == 201
              ? source.fetchHomeworkList(
                  _topicId,
                  const TeacherHomeworkListQuery.initial(),
                )
              : source.fetchHomework(_homeworkId);

          await expectLater(
            operation,
            throwsA(_failureKind(ApiFailureKind.invalidResponse)),
          );
        }
      },
    );

    test('maps Dio read failures through the shared failure mapper', () async {
      final adapter = _RecordingAdapter((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      await expectLater(
        _source(adapter).fetchHomework(_homeworkId),
        throwsA(_failureKind(ApiFailureKind.connection)),
      );
    });

    test('rejects malformed target IDs before transport', () {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _listJson(const [], total: 0)),
      );
      final source = _source(adapter);

      expect(
        () => source.fetchHomeworkList(
          'invalid',
          const TeacherHomeworkListQuery.initial(),
        ),
        throwsArgumentError,
      );
      expect(() => source.fetchHomework('invalid'), throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });
  });

  group('TeacherHomeworkRepositoryImpl', () {
    test('converts strict list and detail DTOs to domain', () async {
      final adapter = _RecordingAdapter((options) {
        if (options.path.contains('/topics/')) {
          return _jsonResponse(200, _listJson([_summaryJson()]));
        }
        return _jsonResponse(200, {'data': _homeworkJson()});
      });
      final repository = TeacherHomeworkRepositoryImpl(
        remoteDataSource: _source(adapter),
      );

      final list = await repository.fetchHomeworkList(
        _topicId,
        const TeacherHomeworkListQuery.initial(),
      );
      final homework = await repository.fetchHomework(_homeworkId);

      expect(list.items.single.title, 'Homework');
      expect(list.pagination.total, 1);
      expect(homework.id, _homeworkId);
      expect(homework.questions, isEmpty);
    });

    test('rejects a detail identity that differs from request', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': _homeworkJson()
            ..['id'] = '20000000-0000-0000-0000-000000000002',
        }),
      );
      final repository = TeacherHomeworkRepositoryImpl(
        remoteDataSource: _source(adapter),
      );

      await expectLater(
        repository.fetchHomework(_homeworkId),
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );
    });
  });
}

TeacherHomeworkRemoteDataSource _source(_RecordingAdapter adapter) {
  return TeacherHomeworkRemoteDataSource(
    dio: _dio(adapter),
    failureMapper: const DioFailureMapper(),
  );
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

Map<String, Object?> _summaryJson() {
  return {
    'id': _homeworkId,
    'topic_id': _topicId,
    'title': 'Homework',
    'assignment_mode': 'group',
    'total_possible_points': 0,
    'question_count': 0,
    'deadline_at': null,
    'institution_timezone': 'Asia/Tashkent',
    'status': 'draft',
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
  };
}

Map<String, Object?> _homeworkJson() {
  return {
    'id': _homeworkId,
    'topic_id': _topicId,
    'title': 'Homework',
    'description': null,
    'student_instructions': 'Complete the Homework.',
    'assignment_mode': 'group',
    'student_ids': <Object?>[],
    'total_possible_points': 0,
    'deadline_at': null,
    'institution_timezone': 'Asia/Tashkent',
    'status': 'draft',
    'attempt_policy': {
      'normal_attempts': 3,
      'official_score_policy': 'highest_valid_completed',
    },
    'activated_at': null,
    'closed_at': null,
    'archived_at': null,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
    'questions': <Object?>[],
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

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
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
