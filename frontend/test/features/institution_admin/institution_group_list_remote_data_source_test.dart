import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_list_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_query.dart';

void main() {
  group('InstitutionGroupListRemoteDataSource', () {
    test('uses exact bodyless GET and approved query parameters', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _listJson(page: 3, perPage: 50, total: 101, lastPage: 3),
        ),
      );
      final source = InstitutionGroupListRemoteDataSource(
        dio: _dio(adapter),
        failureMapper: const DioFailureMapper(),
      );
      final query = const InstitutionGroupListQuery.initial()
          .withSearch("  O'quvchi! % _ Ж  ")
          .withStatus(InstitutionGroupStatusFilter.archived)
          .withPerPage(50)
          .withSort(InstitutionGroupListSort.updatedAt)
          .copyWith(direction: InstitutionGroupSortDirection.desc, page: 3);

      await source.fetchGroups(query);

      expect(adapter.requests, hasLength(1));
      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/institution/groups');
      expect(adapter.request.uri.path, '/api/v1/institution/groups');
      expect(adapter.request.data, isNull);
      expect(adapter.request.queryParameters, {
        'page': 3,
        'per_page': 50,
        'sort': 'updated_at',
        'direction': 'desc',
        'search': "O'quvchi! % _ Ж",
        'status': 'archived',
      });
    });

    test('maps other 2xx and malformed success to invalidResponse', () async {
      for (final response in [
        _jsonResponse(201, _listJson()),
        _jsonResponse(200, {'data': <Object?>[]}),
      ]) {
        final source = InstitutionGroupListRemoteDataSource(
          dio: _dio(_RecordingAdapter((_) => response)),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          source.fetchGroups(const InstitutionGroupListQuery.initial()),
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    });

    test(
      'maps transport failures through the configured failure mapper',
      () async {
        final source = InstitutionGroupListRemoteDataSource(
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
          source.fetchGroups(const InstitutionGroupListQuery.initial()),
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.kind,
              'kind',
              ApiFailureKind.connection,
            ),
          ),
        );
      },
    );
  });
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

Map<String, Object?> _listJson({
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) {
  return {
    'data': [_groupJson()],
    'meta': {
      'pagination': {
        'page': page,
        'per_page': perPage,
        'total': total,
        'last_page': lastPage,
      },
    },
  };
}

Map<String, Object?> _groupJson() {
  return {
    'id': '00000000-0000-0000-0000-000000000001',
    'name': 'Group A',
    'level': null,
    'subject_direction': null,
    'description': null,
    'status': 'active',
    'teachers_count': 0,
    'students_count': 0,
    'archived_at': null,
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T16:00:00Z',
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
  _RecordingAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;
  final requests = <RequestOptions>[];

  RequestOptions get request => requests.single;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
