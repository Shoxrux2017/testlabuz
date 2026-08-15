import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_list_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';

void main() {
  group('InstitutionUserListRemoteDataSource', () {
    test('uses exact bodyless GET and approved query parameters', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _listJson(page: 3, perPage: 50, total: 101, lastPage: 3),
        ),
      );
      final source = InstitutionUserListRemoteDataSource(
        dio: _dio(adapter),
        failureMapper: const DioFailureMapper(),
      );
      final query = const InstitutionUserListQuery.initial()
          .withSearch("  O'quvchi! % _ Ў  ")
          .withRole(InstitutionUserRole.parent)
          .withStatus(InstitutionUserStatusFilter.active)
          .withPerPage(50)
          .withSort(InstitutionUserListSort.updatedAt)
          .copyWith(direction: InstitutionUserSortDirection.desc, page: 3);

      await source.fetchUsers(query);

      expect(adapter.requests, hasLength(1));
      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/institution/users');
      expect(adapter.request.uri.path, '/api/v1/institution/users');
      expect(adapter.request.data, isNull);
      expect(adapter.request.queryParameters, {
        'page': 3,
        'per_page': 50,
        'sort': 'updated_at',
        'direction': 'desc',
        'role': 'parent',
        'status': 'active',
        'search': "O'quvchi! % _ Ў",
      });
    });

    test('repository preserves response order and metadata', () async {
      final source = InstitutionUserListRemoteDataSource(
        dio: _dio(
          _RecordingAdapter(
            (_) => _jsonResponse(
              200,
              _listJson(
                rows: [
                  _userJson(fullName: 'Teacher B'),
                  _userJson(
                    id: '00000000-0000-0000-0000-000000000002',
                    fullName: 'Student A',
                    role: 'student',
                  ),
                ],
                page: 2,
                perPage: 50,
                total: 52,
                lastPage: 2,
              ),
            ),
          ),
        ),
        failureMapper: const DioFailureMapper(),
      );
      final repository = InstitutionUserListRepositoryImpl(
        remoteDataSource: source,
      );

      final result = await repository.fetchUsers(
        const InstitutionUserListQuery.initial().copyWith(page: 2, perPage: 50),
      );

      expect(result.users.map((user) => user.fullName), [
        'Teacher B',
        'Student A',
      ]);
      expect(result.pagination.page, 2);
      expect(result.pagination.total, 52);
    });

    test('maps network and invalid response failures safely', () async {
      final networkSource = InstitutionUserListRemoteDataSource(
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
        networkSource.fetchUsers(const InstitutionUserListQuery.initial()),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.kind,
            'kind',
            ApiFailureKind.connection,
          ),
        ),
      );

      final invalidSource = InstitutionUserListRemoteDataSource(
        dio: _dio(
          _RecordingAdapter((_) => _jsonResponse(200, {'data': <Object?>[]})),
        ),
        failureMapper: const DioFailureMapper(),
      );
      final invalidRepository = InstitutionUserListRepositoryImpl(
        remoteDataSource: invalidSource,
      );
      await expectLater(
        invalidRepository.fetchUsers(const InstitutionUserListQuery.initial()),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('preserves the stable backend error matrix', () async {
      final cases = [
        (status: 401, code: ApiErrorCodes.authenticationRequired),
        (status: 403, code: ApiErrorCodes.passwordChangeRequired),
        (status: 403, code: ApiErrorCodes.userInactive),
        (status: 403, code: ApiErrorCodes.institutionInactive),
        (status: 403, code: ApiErrorCodes.forbidden),
        (status: 422, code: ApiErrorCodes.validationFailed),
        (status: 500, code: 'server_error'),
      ];

      for (final testCase in cases) {
        final source = InstitutionUserListRemoteDataSource(
          dio: _dio(
            _RecordingAdapter(
              (_) => _jsonResponse(testCase.status, _errorJson(testCase.code)),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          source.fetchUsers(const InstitutionUserListQuery.initial()),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (error) => error.failure.statusCode,
                  'statusCode',
                  testCase.status,
                )
                .having(
                  (error) => error.failure.serverCode,
                  'serverCode',
                  testCase.code,
                ),
          ),
        );
      }
    });
  });
}

Dio _dio(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
    ),
  );
  dio.httpClientAdapter = adapter;

  return dio;
}

Map<String, Object?> _listJson({
  List<Map<String, Object?>>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) {
  return {
    'data': rows ?? [_userJson()],
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

Map<String, Object?> _userJson({
  String id = '00000000-0000-0000-0000-000000000001',
  String role = 'teacher',
  String fullName = 'Teacher Name',
}) {
  return {
    'id': id,
    'role': role,
    'full_name': fullName,
    'login_name': 'user01',
    'email': null,
    'phone': null,
    'is_active': true,
    'must_change_password': false,
    'last_login_at': null,
    'deactivated_at': null,
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T16:00:00Z',
  };
}

Map<String, Object?> _errorJson(String code) {
  return {
    'message': 'Raw backend details must not be displayed.',
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
