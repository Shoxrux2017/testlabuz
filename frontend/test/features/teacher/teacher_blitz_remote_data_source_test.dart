import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_list_query.dart';

import 'teacher_blitz_json_fixtures.dart';

void main() {
  group('TeacherBlitzRemoteDataSource', () {
    test('uses the exact Topic-scoped bodyless list GET', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          teacherBlitzListJson([teacherBlitzSummaryJson()], page: 2, total: 21),
        ),
      );
      final query = const TeacherBlitzListQuery.initial()
          .withStatus(TeacherBlitzStatus.active)
          .withPage(2);

      final list = await _source(
        adapter,
      ).fetchBlitzList(blitzJsonTopicId, query);

      expect(list.items.single.id, blitzJsonId);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/blitz');
      expect(request.uri.path, '/api/v1/teacher/blitz');
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
      expect(request.queryParameters, {
        'topic_id': blitzJsonTopicId,
        'page': 2,
        'per_page': 20,
        'status': 'active',
      });
    });

    test('omits the status filter and never sends unsupported keys', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, teacherBlitzListJson(const [])),
      );

      await _source(
        adapter,
      ).fetchBlitzList(blitzJsonTopicId, const TeacherBlitzListQuery.initial());

      expect(adapter.requests.single.queryParameters, {
        'topic_id': blitzJsonTopicId,
        'page': 1,
        'per_page': 20,
      });
      expect(
        adapter.requests.single.queryParameters.keys,
        isNot(
          anyOf(
            contains('group_id'),
            contains('search'),
            contains('assignment_mode'),
            contains('sort'),
            contains('direction'),
          ),
        ),
      );
    });

    test('uses the exact encoded bodyless detail GET without query', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'data': teacherBlitzJson()}),
      );

      final detail = await _source(adapter).fetchBlitz(blitzJsonId);

      expect(detail.blitz.id, blitzJsonId);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/blitz/$blitzJsonId');
      expect(request.uri.path, '/api/v1/teacher/blitz/$blitzJsonId');
      expect(request.queryParameters, isEmpty);
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
    });

    test(
      'requires 200 and maps malformed success to invalid response',
      () async {
        final cases = <({bool list, ResponseBody response})>[
          (
            list: true,
            response: _jsonResponse(201, teacherBlitzListJson(const [])),
          ),
          (list: false, response: _jsonResponse(204, null)),
          (
            list: true,
            response: _jsonResponse(
              200,
              teacherBlitzListJson([
                teacherBlitzSummaryJson(
                  topicId: '10000000-0000-0000-0000-000000000002',
                ),
              ]),
            ),
          ),
          (list: true, response: _jsonResponse(200, {'data': <Object?>[]})),
          (
            list: false,
            response: _jsonResponse(200, {
              'data': teacherBlitzJson(),
              'message': 'Unexpected.',
            }),
          ),
          (
            list: false,
            response: _jsonResponse(200, {
              'data': teacherBlitzJson()..['closed_at'] = blitzJsonClosedAt,
            }),
          ),
          (list: false, response: _jsonResponse(200, <Object?>[])),
        ];

        for (final testCase in cases) {
          final source = _source(_RecordingAdapter((_) => testCase.response));
          final operation = testCase.list
              ? source.fetchBlitzList(
                  blitzJsonTopicId,
                  const TeacherBlitzListQuery.initial(),
                )
              : source.fetchBlitz(blitzJsonId);

          await expectLater(
            operation,
            throwsA(_failureKind(ApiFailureKind.invalidResponse)),
          );
        }
      },
    );

    test(
      'maps non-2xx and transport failures through the shared mapper',
      () async {
        final notFound = _RecordingAdapter(
          (_) => _jsonResponse(404, {
            'message': 'Resource not found.',
            'code': 'resource_not_found',
            'request_id': 'req-1',
          }),
        );
        await expectLater(
          _source(notFound).fetchBlitz(blitzJsonId),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (error) => error.failure.kind,
                  'kind',
                  ApiFailureKind.server,
                )
                .having((error) => error.failure.statusCode, 'status', 404)
                .having(
                  (error) => error.failure.serverCode,
                  'code',
                  'resource_not_found',
                ),
          ),
        );

        final offline = _RecordingAdapter((options) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        });
        await expectLater(
          _source(offline).fetchBlitzList(
            blitzJsonTopicId,
            const TeacherBlitzListQuery.initial(),
          ),
          throwsA(_failureKind(ApiFailureKind.connection)),
        );

        final timeout = _RecordingAdapter((options) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        });
        await expectLater(
          _source(timeout).fetchBlitz(blitzJsonId),
          throwsA(_failureKind(ApiFailureKind.timeout)),
        );
      },
    );

    test('rejects malformed Topic and Blitz IDs before transport', () {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, teacherBlitzListJson(const [])),
      );
      final source = _source(adapter);

      for (final invalid in ['', 'not-a-uuid', ' $blitzJsonTopicId']) {
        expect(
          () => source.fetchBlitzList(
            invalid,
            const TeacherBlitzListQuery.initial(),
          ),
          throwsArgumentError,
        );
        expect(() => source.fetchBlitz(invalid), throwsArgumentError);
      }
      expect(adapter.requests, isEmpty);
    });
  });

  group('TeacherBlitzRepositoryImpl', () {
    test('converts list and detail DTOs to domain on every call', () async {
      final adapter = _RecordingAdapter((options) {
        if (options.path == '/teacher/blitz') {
          return _jsonResponse(
            200,
            teacherBlitzListJson([teacherBlitzSummaryJson()]),
          );
        }
        return _jsonResponse(200, {
          'data': teacherBlitzJson(status: TeacherBlitzStatus.closed),
        });
      });
      final repository = TeacherBlitzRepositoryImpl(
        remoteDataSource: _source(adapter),
      );

      final list = await repository.fetchBlitzList(
        blitzJsonTopicId,
        const TeacherBlitzListQuery.initial(),
      );
      final blitz = await repository.fetchBlitz(blitzJsonId);
      await repository.fetchBlitz(blitzJsonId);

      expect(list.items.single.title, 'Equation Blitz');
      expect(list.pagination.total, 1);
      expect(blitz.id, blitzJsonId);
      expect(blitz.status, TeacherBlitzStatus.closed);
      expect(blitz.questions, hasLength(9));
      expect(adapter.requests.map((request) => request.path), [
        '/teacher/blitz',
        '/teacher/blitz/$blitzJsonId',
        '/teacher/blitz/$blitzJsonId',
      ]);
      expect(adapter.requests.map((request) => request.method).toSet(), {
        'GET',
      });
    });

    test('rejects a detail identity that differs from the request', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': teacherBlitzJson()
            ..['id'] = '80000000-0000-0000-0000-000000000002',
        }),
      );
      final repository = TeacherBlitzRepositoryImpl(
        remoteDataSource: _source(adapter),
      );

      await expectLater(
        repository.fetchBlitz(blitzJsonId),
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );
      final uppercase = await TeacherBlitzRepositoryImpl(
        remoteDataSource: _source(
          _RecordingAdapter(
            (_) => _jsonResponse(200, {'data': teacherBlitzJson()}),
          ),
        ),
      ).fetchBlitz(blitzJsonId.toUpperCase());
      expect(uppercase.id, blitzJsonId);
    });
  });
}

TeacherBlitzRemoteDataSource _source(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return TeacherBlitzRemoteDataSource(
    dio: dio,
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

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    body == null ? '' : jsonEncode(body),
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
