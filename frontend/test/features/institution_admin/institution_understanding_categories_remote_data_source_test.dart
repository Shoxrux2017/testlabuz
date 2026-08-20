import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/config/app_config.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_client_provider.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_understanding_categories_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_understanding_categories.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_understanding_categories_repository.dart';

void main() {
  test(
    'GET uses the exact endpoint with no body, query or tenant authority',
    () async {
      final adapter = _RecordingAdapter((_) => _response(200, _resource()));

      final result = await _source(adapter).fetchCategories();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/institution/understanding-categories');
      expect(
        request.uri.toString(),
        'https://example.test/api/v1/institution/understanding-categories',
      );
      expect(request.data, isNull);
      expect(request.queryParameters, isEmpty);
      expect(adapter.requestBodies.single, isEmpty);
      expect(
        request.headers.keys.any(
          (key) =>
              key.toLowerCase().contains('institution') ||
              key.toLowerCase().contains('tenant'),
        ),
        isFalse,
      );
      expect(result.configuration.categories, hasLength(5));
    },
  );

  test('PUT sends exactly one canonical categories replacement', () async {
    final adapter = _RecordingAdapter((_) => _response(200, _resource()));
    final request = _updateRequest();

    final result = await _source(adapter).replaceCategories(request);

    final options = adapter.requests.single;
    expect(options.method, 'PUT');
    expect(options.path, '/institution/understanding-categories');
    expect(
      options.uri.toString(),
      'https://example.test/api/v1/institution/understanding-categories',
    );
    expect(options.queryParameters, isEmpty);
    expect(options.headers[Headers.contentTypeHeader], Headers.jsonContentType);
    expect(
      options.headers.keys.any(
        (key) =>
            key.toLowerCase() == 'idempotency-key' ||
            key.toLowerCase().contains('institution') ||
            key.toLowerCase().contains('tenant'),
      ),
      isFalse,
    );
    expect((options.data as Map<String, Object>).keys, ['categories']);
    final categories =
        (options.data as Map<String, Object>)['categories']! as List;
    expect(categories, hasLength(5));
    for (var index = 0; index < categories.length; index++) {
      final item = categories[index] as Map;
      expect(item.keys.toSet(), {
        'code',
        'min_score',
        'max_score',
        'sort_order',
      });
      expect(item['sort_order'], index + 1);
      expect(item['sort_order'], isA<int>());
      if (index < 4) {
        expect(item['min_score'], isA<int>());
        expect(item['max_score'], isA<int>());
      }
    }
    expect((categories.last as Map)['min_score'], isNull);
    final onWire = utf8.decode(adapter.requestBodies.single);
    expect(jsonDecode(onWire), options.data);
    for (final forbidden in [
      'label',
      'meta',
      'configured',
      'institution_id',
      'updated_by_user_id',
      'updated_at',
      'acceptable_score_difference',
    ]) {
      expect(onWire, isNot(contains(forbidden)));
    }
    expect(result.configuration.matches(request), isTrue);
  });

  test('only an exact matching 200 proves direct success', () async {
    final fixtures = [
      '{"data":{}}',
      _resource(firstMinimum: 87),
      _error('unexpected_success'),
    ];
    for (final body in fixtures) {
      final adapter = _RecordingAdapter((_) => _response(200, body));
      await expectLater(
        _source(adapter).replaceCategories(_updateRequest()),
        throwsA(
          isA<
            InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException
          >(),
        ),
        reason: body,
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test('maps only documented exact 401, 403, 422 and 429 failures', () async {
    final definite = <(int, String)>[
      (401, ApiErrorCodes.authenticationRequired),
      (403, ApiErrorCodes.forbidden),
      (403, ApiErrorCodes.userInactive),
      (403, ApiErrorCodes.institutionInactive),
      (403, ApiErrorCodes.passwordChangeRequired),
      (422, ApiErrorCodes.validationFailed),
      (429, ApiErrorCodes.rateLimited),
    ];
    for (final fixture in definite) {
      final adapter = _RecordingAdapter(
        (_) => _response(fixture.$1, _error(fixture.$2)),
      );
      await expectLater(
        _source(adapter).replaceCategories(_updateRequest()),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.serverCode,
            'code',
            fixture.$2,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    }

    for (final fixture in [
      (500, _error(ApiErrorCodes.serverError)),
      (422, '<html>invalid</html>'),
      (409, _error('conflict')),
      (201, _resource()),
    ]) {
      final adapter = _RecordingAdapter(
        (_) => _response(fixture.$1, fixture.$2),
      );
      await expectLater(
        _source(adapter).replaceCategories(_updateRequest()),
        throwsA(
          isA<
            InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException
          >(),
        ),
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test('never replays PUT after any transport failure', () async {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.cancel,
      DioExceptionType.unknown,
    ]) {
      final adapter = _RecordingAdapter(
        (options) => throw DioException(requestOptions: options, type: type),
      );
      await expectLater(
        _source(adapter).replaceCategories(_updateRequest()),
        throwsA(
          isA<
            InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException
          >(),
        ),
        reason: '$type',
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test(
    'GET accepts exact empty state and fails closed without retries',
    () async {
      final emptyAdapter = _RecordingAdapter(
        (_) => _response(200, '{"data":[],"meta":{"configured":false}}'),
      );
      final empty = await _source(emptyAdapter).fetchCategories();
      expect(empty.configuration.configured, isFalse);

      for (final handler in <FutureOr<ResponseBody> Function(RequestOptions)>[
        (_) => _response(200, '{"data":[]}'),
        (_) => _response(500, _error(ApiErrorCodes.serverError)),
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      ]) {
        final adapter = _RecordingAdapter(handler);
        await expectLater(
          _source(adapter).fetchCategories(),
          throwsA(isA<ApiRequestException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

InstitutionUnderstandingCategoriesRemoteDataSource _source(
  _RecordingAdapter adapter,
) {
  final dio = createDioClient(
    AppConfig.fromApiBaseUrl('https://example.test/api/v1'),
  );
  dio.httpClientAdapter = adapter;
  return InstitutionUnderstandingCategoriesRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

InstitutionUnderstandingCategoryUpdateRequest _updateRequest() =>
    InstitutionUnderstandingCategoryDraft.fromConfiguration(
      _configuration(),
    ).validate().request!;

InstitutionUnderstandingCategoryConfiguration _configuration() =>
    InstitutionUnderstandingCategoryConfiguration.configured(const [
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.understoodWell,
        minScore: 86,
        maxScore: 100,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.partiallyUnderstood,
        minScore: 71,
        maxScore: 85,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsRevision,
        minScore: 51,
        maxScore: 70,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.needsTeacherSupport,
        minScore: 0,
        maxScore: 50,
      ),
      InstitutionUnderstandingCategory(
        definition: UnderstandingCategoryDefinition.notCompleted,
        minScore: null,
        maxScore: null,
      ),
    ]);

String _resource({int firstMinimum = 86}) => jsonEncode({
  'data': [
    {
      'code': 'understood_well',
      'label': 'Understood well',
      'min_score': firstMinimum,
      'max_score': 100,
      'sort_order': 1,
    },
    {
      'code': 'partially_understood',
      'label': 'Partially understood',
      'min_score': 71,
      'max_score': 85,
      'sort_order': 2,
    },
    {
      'code': 'needs_revision',
      'label': 'Needs revision',
      'min_score': 51,
      'max_score': 70,
      'sort_order': 3,
    },
    {
      'code': 'needs_teacher_support',
      'label': 'Needs teacher support',
      'min_score': 0,
      'max_score': 50,
      'sort_order': 4,
    },
    {
      'code': 'not_completed',
      'label': 'Not completed',
      'min_score': null,
      'max_score': null,
      'sort_order': 5,
    },
  ],
});

String _error(String code) =>
    '{"message":"Safe error","code":"$code","errors":{}}';

ResponseBody _response(int statusCode, String body) => ResponseBody.fromString(
  body,
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];
  final requestBodies = <Uint8List>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    requestBodies.add(Uint8List.fromList(bytes));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
