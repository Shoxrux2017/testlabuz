import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/student/data/student_homework_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_homework_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_homework.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_list_query.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';

const _topicId = '10000000-abcd-0000-0000-000000000001';
const _homeworkId = '20000000-abcd-0000-0000-000000000001';

void main() {
  test(
    'list sends exact bodyless GET and default query without status',
    () async {
      final adapter = _RecordingAdapter((_) => _jsonResponse(200, _listJson()));
      final source = _source(adapter);
      final query = StudentHomeworkListQuery(topicId: _topicId);

      final result = await source.fetchHomework(query);

      expect(result.items.single.id, _homeworkId);
      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/student/homework');
      expect(adapter.request.uri.path, '/api/v1/student/homework');
      expect(adapter.request.data, isNull);
      expect(adapter.request.queryParameters, {
        'topic_id': _topicId,
        'page': 1,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
      });
    },
  );

  test(
    'list forwards selected status, page, size and supported ordering',
    () async {
      for (final status in StudentHomeworkStatus.values) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(
            200,
            _listJson(page: 3, perPage: 10, total: 21, lastPage: 3),
          ),
        );
        final query = StudentHomeworkListQuery(
          topicId: _topicId,
          status: status,
          page: 3,
          perPage: 10,
          sort: StudentHomeworkSort.deadlineAt,
          direction: StudentHomeworkSortDirection.asc,
        );
        await _source(adapter).fetchHomework(query);
        expect(adapter.request.queryParameters, {
          'topic_id': _topicId,
          'status': status.apiValue,
          'page': 3,
          'per_page': 10,
          'sort': 'deadline_at',
          'direction': 'asc',
        });
        expect(adapter.request.data, isNull);
      }
    },
  );

  test(
    'detail sends encoded canonical ID without body, query or redirects',
    () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'data': _detailJson()}),
      );
      final id = _homeworkId.toUpperCase();
      await _source(adapter).fetchHomeworkDetail(id);

      expect(adapter.request.method, 'GET');
      expect(
        adapter.request.path,
        '/student/homework/${Uri.encodeComponent(id)}',
      );
      expect(adapter.request.uri.path, '/api/v1/student/homework/$id');
      expect(adapter.request.data, isNull);
      expect(adapter.request.queryParameters, isEmpty);
      expect(adapter.request.followRedirects, isFalse);
    },
  );

  test('invalid Homework IDs fail before transport', () {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(200, {'data': _detailJson()}),
    );
    final source = _source(adapter);
    for (final invalid in [
      '',
      '../homework',
      '$_homeworkId/extra',
      ' $_homeworkId',
      _homeworkId.replaceAll('-', ''),
    ]) {
      expect(() => source.fetchHomeworkDetail(invalid), throwsArgumentError);
    }
    expect(adapter.requests, isEmpty);
  });

  test('read success must use status 200', () async {
    for (final status in [201, 202, 204]) {
      for (final detail in [false, true]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(
            status,
            detail ? {'data': _detailJson()} : _listJson(),
          ),
        );
        await expectLater(
          _read(_source(adapter), detail: detail),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    }
  });

  test(
    'malformed list envelopes, scope and requested pagination fail closed',
    () async {
      final wrongTopic = _summaryJson();
      (wrongTopic['topic']! as Map<String, Object?>)['id'] =
          '10000000-abcd-0000-0000-000000000002';
      final malformed = <Object?>[
        null,
        [],
        {},
        _listJson()..['unknown'] = true,
        _listJson()..remove('meta'),
        _listJson(rows: [wrongTopic]),
        _listJson(rows: [_summaryJson(), _summaryJson()], total: 2),
        _listJson(page: 2),
        _listJson(perPage: 10),
        _listJson(total: 21),
      ];
      for (final payload in malformed) {
        final adapter = _RecordingAdapter((_) => _jsonResponse(200, payload));
        final repository = StudentHomeworkRepositoryImpl(
          remoteDataSource: _source(adapter),
        );
        await expectLater(
          repository.fetchHomework(StudentHomeworkListQuery(topicId: _topicId)),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'malformed detail envelopes and protected Question fields never reach domain',
    () async {
      final payloads = <Object?>[
        null,
        [],
        {},
        {'data': _detailJson(), 'message': 'unexpected'},
        {'data': _detailJson()..remove('attempts')},
        {'data': _detailJson()..['score_visible'] = true},
      ];
      for (final key in [
        'is_correct',
        'correct_value',
        'accepted_answers',
        'correct_position',
        'match_key',
        'checking_mode',
        'configuration',
        'client_key',
      ]) {
        final protectedQuestion = _questionJson()..[key] = 'protected';
        payloads.add({'data': _detailJson(question: protectedQuestion)});
        final protectedAnswerUi = _questionJson()
          ..['answer_ui'] = {key: 'protected'};
        payloads.add({'data': _detailJson(question: protectedAnswerUi)});
      }
      for (final payload in payloads) {
        final adapter = _RecordingAdapter((_) => _jsonResponse(200, payload));
        final repository = StudentHomeworkRepositoryImpl(
          remoteDataSource: _source(adapter),
        );
        await expectLater(
          repository.fetchHomeworkDetail(_homeworkId),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'malformed JSON syntax in a success response maps to invalidResponse',
    () async {
      for (final detail in [false, true]) {
        final adapter = _RecordingAdapter(
          (_) => ResponseBody.fromString(
            '{"data":',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        await expectLater(
          _read(_source(adapter), detail: detail),
          throwsA(_failureKind(ApiFailureKind.invalidResponse)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'structured Dio failures retain machine codes and validation fields',
    () async {
      for (final failure in [
        (401, 'authentication_required'),
        (403, 'institution_inactive'),
        (404, 'resource_not_found'),
        (422, 'validation_failed'),
        (429, 'too_many_requests'),
      ]) {
        for (final detail in [false, true]) {
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(failure.$1, {
              'message': 'Safe API failure.',
              'code': failure.$2,
              'errors': {
                'status': ['Unsupported status.'],
              },
              'request_id': 'homework-request-1',
            }),
          );
          await expectLater(
            _read(_source(adapter), detail: detail),
            throwsA(
              isA<ApiRequestException>()
                  .having(
                    (error) => error.failure.kind,
                    'kind',
                    failure.$1 == 422
                        ? ApiFailureKind.validation
                        : ApiFailureKind.server,
                  )
                  .having(
                    (error) => error.failure.statusCode,
                    'status',
                    failure.$1,
                  )
                  .having(
                    (error) => error.failure.serverCode,
                    'code',
                    failure.$2,
                  )
                  .having(
                    (error) => error.failure.requestId,
                    'request ID',
                    'homework-request-1',
                  )
                  .having(
                    (error) => error.failure.fieldErrors,
                    'field errors',
                    {
                      'status': ['Unsupported status.'],
                    },
                  ),
            ),
          );
          expect(adapter.requests, hasLength(1));
        }
      }
    },
  );

  test('typed transport failures are preserved without retrying', () async {
    for (final failure in [
      (DioExceptionType.connectionError, ApiFailureKind.connection),
      (DioExceptionType.receiveTimeout, ApiFailureKind.timeout),
      (DioExceptionType.cancel, ApiFailureKind.cancelled),
      (DioExceptionType.unknown, ApiFailureKind.unknown),
    ]) {
      final adapter = _RecordingAdapter(
        (options) =>
            throw DioException(requestOptions: options, type: failure.$1),
      );
      await expectLater(
        _source(adapter).fetchHomeworkDetail(_homeworkId),
        throwsA(_failureKind(failure.$2)),
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test(
    'repository returns immutable typed Student read models without caching',
    () async {
      final adapter = _RecordingAdapter(
        (options) => _jsonResponse(
          200,
          options.path == '/student/homework'
              ? _listJson()
              : {'data': _detailJson()},
        ),
      );
      final repository = StudentHomeworkRepositoryImpl(
        remoteDataSource: _source(adapter),
      );
      final query = StudentHomeworkListQuery(topicId: _topicId);
      final page = await repository.fetchHomework(query);
      final detail = await repository.fetchHomeworkDetail(_homeworkId);

      expect(page, isA<StudentHomeworkList>());
      expect(page.items.single, isA<StudentHomeworkSummary>());
      expect(page.items.single.topic, isA<StudentHomeworkTopicSummary>());
      expect(page.items.single.attempts, isA<StudentHomeworkAttemptSummary>());
      expect(detail, isA<StudentHomeworkDetail>());
      expect(detail.questions.single, isA<StudentQuestion>());
      expect(detail.questions.single.answerUi, isA<StudentEmptyAnswerUi>());
      expect(detail.scoreVisible, isFalse);
      expect(detail.attempts.remaining, 3);
      expect(() => page.items.clear(), throwsUnsupportedError);
      expect(() => detail.questions.clear(), throwsUnsupportedError);
      await repository.fetchHomework(query);
      await repository.fetchHomeworkDetail(_homeworkId);
      expect(adapter.requests, hasLength(4));
      expect(
        adapter.requests.every(
          (request) => request.method == 'GET' && request.data == null,
        ),
        isTrue,
      );
    },
  );
}

Future<Object> _read(
  StudentHomeworkRemoteDataSource source, {
  required bool detail,
}) => detail
    ? source.fetchHomeworkDetail(_homeworkId)
    : source.fetchHomework(StudentHomeworkListQuery(topicId: _topicId));

Matcher _failureKind(ApiFailureKind kind) => isA<ApiRequestException>().having(
  (error) => error.failure.kind,
  'kind',
  kind,
);

StudentHomeworkRemoteDataSource _source(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return StudentHomeworkRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

Map<String, Object?> _summaryJson() => {
  'id': _homeworkId,
  'topic': <String, Object?>{'id': _topicId, 'title': 'Internet Basics'},
  'title': 'Homework 1',
  'status': 'active',
  'deadline_at': null,
  'attempts': <String, Object?>{
    'allowed': 3,
    'used': 0,
    'remaining': 3,
    'official_score_policy': 'highest_valid_completed',
  },
  'my_status': 'not_started',
  'score_visible': false,
};

Map<String, Object?> _listJson({
  List<Object?>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) => {
  'data': rows ?? [_summaryJson()],
  'meta': {
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
    },
  },
};

Map<String, Object?> _detailJson({Map<String, Object?>? question}) {
  final detail = _summaryJson();
  (detail['attempts']! as Map<String, Object?>)['in_progress_attempt'] = null;
  return detail..addAll({
    'description': null,
    'student_instructions': 'Read each question.',
    'total_possible_points': 2,
    'questions': [question ?? _questionJson()],
  });
}

Map<String, Object?> _questionJson() => {
  'id': '30000000-0000-0000-0000-000000000001',
  'type': 'true_false',
  'prompt': 'Read this statement.',
  'instructions': null,
  'points': 2,
  'position': 1,
  'answer_ui': <String, Object?>{},
};

ResponseBody _jsonResponse(int statusCode, Object? body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
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
