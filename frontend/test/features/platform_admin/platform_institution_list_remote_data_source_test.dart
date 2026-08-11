import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_remote_data_source.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';

void main() {
  group('PlatformInstitutionListRemoteDataSource', () {
    test(
      'uses exact GET endpoint query keys and no body or client authority',
      () async {
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(200, _listJson()),
        );
        final dataSource = PlatformInstitutionListRemoteDataSource(
          dio: _plainDio(adapter),
          failureMapper: const DioFailureMapper(),
        );
        final query = const PlatformInstitutionListQuery.initial()
            .withSearch('  Oliy % _ maktab  ')
            .withStatus(PlatformInstitutionStatus.active)
            .withType(PlatformInstitutionType.learningCenter)
            .withSort(PlatformInstitutionListSort.updatedAt)
            .copyWith(direction: PlatformSortDirection.desc, page: 3);

        final dto = await dataSource.fetchInstitutions(query);

        expect(dto.institutions.single.name, 'Example School');
        expect(adapter.requests, hasLength(1));
        expect(adapter.singleRequest.method, 'GET');
        expect(adapter.singleRequest.path, '/platform/institutions');
        expect(adapter.singleRequest.uri.path, '/api/v1/platform/institutions');
        expect(adapter.singleRequest.data, isNull);
        expect(adapter.singleRequest.queryParameters, {
          'page': 3,
          'per_page': 20,
          'sort': 'updated_at',
          'direction': 'desc',
          'search': 'Oliy % _ maktab',
          'status': 'active',
          'type': 'learning_center',
        });
        expect(
          adapter.singleRequest.queryParameters.keys,
          isNot(
            containsAll([
              'institution_id',
              'role',
              'user_id',
              'created_by_user_id',
              'include',
              'address',
              'description',
              'activity',
              'role_counts',
            ]),
          ),
        );
      },
    );

    test(
      'success maps through repository preserving order and backend meta',
      () async {
        final dataSource = PlatformInstitutionListRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) => _jsonResponse(
                200,
                _listJson(
                  rows: [
                    _institutionJson(name: 'B School'),
                    _institutionJson(
                      id: '00000000-0000-0000-0000-000000000002',
                      name: 'A College',
                      type: 'college',
                      status: 'inactive',
                      userCounts: {'total': 4, 'active': 1},
                    ),
                  ],
                  page: 2,
                  perPage: 50,
                  total: 52,
                  lastPage: 3,
                ),
              ),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );
        final repository = PlatformInstitutionListRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final page = await repository.fetchInstitutions(
          const PlatformInstitutionListQuery.initial().copyWith(
            page: 2,
            perPage: 50,
          ),
        );

        expect(page.institutions.map((institution) => institution.name), [
          'B School',
          'A College',
        ]);
        expect(page.pagination.page, 2);
        expect(page.pagination.perPage, 50);
        expect(page.pagination.total, 52);
        expect(page.pagination.lastPage, 3);
      },
    );

    test('preserves stable backend failures as typed ApiFailure', () async {
      final cases = [
        (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
        (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
        (statusCode: 403, code: ApiErrorCodes.userInactive),
        (statusCode: 403, code: ApiErrorCodes.institutionInactive),
        (statusCode: 403, code: ApiErrorCodes.forbidden),
        (statusCode: 422, code: ApiErrorCodes.validationFailed),
        (statusCode: 500, code: 'server_error'),
      ];

      for (final testCase in cases) {
        final dataSource = PlatformInstitutionListRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter(
              (_) => _jsonResponse(
                testCase.statusCode,
                _errorJson(code: testCase.code),
              ),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          dataSource.fetchInstitutions(
            const PlatformInstitutionListQuery.initial(),
          ),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (exception) => exception.failure.statusCode,
                  'statusCode',
                  testCase.statusCode,
                )
                .having(
                  (exception) => exception.failure.serverCode,
                  'serverCode',
                  testCase.code,
                ),
          ),
        );
      }
    });

    test(
      'maps network and decode failures without raw response leakage',
      () async {
        final networkSource = PlatformInstitutionListRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((options) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              );
            }),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          networkSource.fetchInstitutions(
            const PlatformInstitutionListQuery.initial(),
          ),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.connection,
            ),
          ),
        );

        final decodeSource = PlatformInstitutionListRemoteDataSource(
          dio: _plainDio(
            RecordingAdapter((_) => _jsonResponse(200, {'data': {}})),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          decodeSource.fetchInstitutions(
            const PlatformInstitutionListQuery.initial(),
          ),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      },
    );
  });
}

Dio _plainDio(RecordingAdapter adapter) {
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
    'data': rows ?? [_institutionJson()],
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

Map<String, Object?> _institutionJson({
  String id = '00000000-0000-0000-0000-000000000001',
  String name = 'Example School',
  String type = 'school',
  String status = 'active',
  Map<String, Object?> userCounts = const {'total': 42, 'active': 40},
}) {
  return {
    'id': id,
    'name': name,
    'type': type,
    'status': status,
    'contact_email': 'info@example.uz',
    'contact_phone': '+998901234567',
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T16:00:00Z',
    'user_counts': userCounts,
  };
}

Map<String, Object?> _errorJson({required String code}) {
  return {
    'message': 'Backend internals must not be rendered.',
    'code': code,
    'errors': {},
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

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;
  final requests = <RequestOptions>[];

  RequestOptions get singleRequest => requests.single;

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
