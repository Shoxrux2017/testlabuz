import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_profile_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_profile_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_update.dart';

void main() {
  group('InstitutionProfileRemoteDataSource', () {
    test('uses one exact GET without body query or tenant input', () async {
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(200, {'data': _resource()}),
      );
      final source = _source(adapter);

      final response = await source.fetchProfile();

      expect(response.profile.id, _institutionId);
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/institution/profile');
      expect(request.uri.path, '/api/v1/institution/profile');
      expect(request.queryParameters, isEmpty);
      expect(request.data, isNull);
      expect(request.headers.keys, isNot(contains('institution_id')));
      expect(request.headers.keys, isNot(contains('X-Institution-Id')));
    });

    test('PATCH sends only one exact non-empty changed-fields map', () async {
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': _resource()..['name'] = 'Renamed School',
          'message': institutionProfileUpdateSuccessMessage,
        }),
      );
      final source = _source(adapter);
      final request = InstitutionProfileUpdateRequest.fromChanges({
        'name': 'Renamed School',
        'contact_email': null,
      });

      final response = await source.updateProfile(request);

      expect(response.profile.name, 'Renamed School');
      expect(adapter.requests, hasLength(1));
      final recorded = adapter.requests.single;
      expect(recorded.method, 'PATCH');
      expect(recorded.path, '/institution/profile');
      expect(recorded.uri.path, '/api/v1/institution/profile');
      expect(recorded.queryParameters, isEmpty);
      expect(recorded.data, {'name': 'Renamed School', 'contact_email': null});
      expect(recorded.data.toString(), isNot(contains('institution_id')));
    });

    test('rejects an empty PATCH before transport', () async {
      final adapter = RecordingAdapter(
        (_) => _jsonResponse(500, const <String, Object?>{}),
      );
      final source = _source(adapter);
      final empty = InstitutionProfileUpdateRequest.fromForm(
        form: const InstitutionProfileEditFormValue(
          name: 'School',
          contactEmail: '',
          contactPhone: '',
          address: '',
          description: '',
        ),
        baseline: const InstitutionProfileEditSnapshot(
          name: 'School',
          contactEmail: null,
          contactPhone: null,
          address: null,
          description: null,
        ),
      );

      await expectLater(source.updateProfile(empty), throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });

    test(
      'maps GET malformed success and transport errors as definite',
      () async {
        final malformed = _source(
          RecordingAdapter((_) => _jsonResponse(200, const {})),
        );
        await expectLater(
          malformed.fetchProfile(),
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );

        for (final type in DioExceptionType.values) {
          final source = _source(
            RecordingAdapter((options) {
              throw DioException(requestOptions: options, type: type);
            }),
          );
          await expectLater(
            source.fetchProfile(),
            throwsA(isA<ApiRequestException>()),
            reason: type.name,
          );
        }
      },
    );

    test('only exact allowed status and code pairs are definite', () async {
      final cases = <(int, String)>[
        (401, ApiErrorCodes.authenticationRequired),
        (403, ApiErrorCodes.forbidden),
        (403, ApiErrorCodes.passwordChangeRequired),
        (403, ApiErrorCodes.userInactive),
        (403, ApiErrorCodes.institutionInactive),
        (404, ApiErrorCodes.resourceNotFound),
        (422, ApiErrorCodes.validationFailed),
        (429, ApiErrorCodes.rateLimited),
      ];

      for (final fixture in cases) {
        final adapter = RecordingAdapter(
          (_) => _jsonResponse(
            fixture.$1,
            _errorEnvelope(
              fixture.$2,
              errors: fixture.$1 == 422
                  ? {
                      'name': ['Review the name.'],
                    }
                  : const {},
            ),
          ),
        );

        await expectLater(
          _source(adapter).updateProfile(_request()),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (error) => error.failure.statusCode,
                  'status',
                  fixture.$1,
                )
                .having(
                  (error) => error.failure.serverCode,
                  'code',
                  fixture.$2,
                ),
          ),
          reason: '${fixture.$1}/${fixture.$2}',
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test(
      '500 and unknown or malformed 4xx responses are unknown without replay',
      () async {
        final fixtures = <(int, Object?)>[
          (500, _errorEnvelope(ApiErrorCodes.serverError)),
          (401, _errorEnvelope(ApiErrorCodes.forbidden)),
          (403, _errorEnvelope(ApiErrorCodes.resourceNotFound)),
          (404, _errorEnvelope(ApiErrorCodes.forbidden)),
          (409, _errorEnvelope('unexpected_conflict')),
          (422, _errorEnvelope(ApiErrorCodes.forbidden)),
          (429, _errorEnvelope(ApiErrorCodes.forbidden)),
          (403, {'message': 'Missing fields.'}),
          (
            403,
            {..._errorEnvelope(ApiErrorCodes.forbidden), 'unexpected': true},
          ),
          (
            403,
            _errorEnvelope(
              ApiErrorCodes.forbidden,
              errors: {
                'name': ['Must be empty for non-validation errors.'],
              },
            ),
          ),
          (422, _errorEnvelope(ApiErrorCodes.validationFailed, errors: 'bad')),
        ];

        for (final fixture in fixtures) {
          final adapter = RecordingAdapter(
            (_) => _jsonResponse(fixture.$1, fixture.$2),
          );
          await expectLater(
            _source(adapter).updateProfile(_request()),
            throwsA(isA<InstitutionProfileUpdateOutcomeUnknownException>()),
            reason: '${fixture.$1}/${fixture.$2}',
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test(
      'classifies every ambiguous PATCH outcome as unknown with no replay',
      () async {
        final uncertainTypes = [
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.transformTimeout,
          DioExceptionType.connectionError,
          DioExceptionType.badCertificate,
          DioExceptionType.cancel,
          DioExceptionType.unknown,
        ];
        for (final type in uncertainTypes) {
          final adapter = RecordingAdapter((options) {
            throw DioException(requestOptions: options, type: type);
          });
          await expectLater(
            _source(adapter).updateProfile(_request()),
            throwsA(isA<InstitutionProfileUpdateOutcomeUnknownException>()),
            reason: type.name,
          );
          expect(adapter.requests, hasLength(1));
        }

        final ambiguousBodies = <ResponseBody>[
          _jsonResponse(201, {
            'data': _resource(),
            'message': institutionProfileUpdateSuccessMessage,
          }),
          _jsonResponse(200, const {}),
          _jsonResponse(200, {'data': _resource()}),
          _jsonResponse(200, {
            'data': _resource(),
            'message': 'Almost correct',
          }),
          _jsonResponse(200, {
            'data': _resource(),
            'message': institutionProfileUpdateSuccessMessage,
          }),
          _jsonResponse(200, {
            'data': _resource(),
            'message': institutionProfileUpdateSuccessMessage,
            'unexpected': true,
          }),
          _jsonResponse(200, {
            'data': _resource()..['unexpected'] = true,
            'message': institutionProfileUpdateSuccessMessage,
          }),
        ];
        for (final body in ambiguousBodies) {
          final adapter = RecordingAdapter((_) => body);
          await expectLater(
            _source(adapter).updateProfile(_request()),
            throwsA(isA<InstitutionProfileUpdateOutcomeUnknownException>()),
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );
  });
}

Map<String, Object?> _errorEnvelope(
  String code, {
  Object errors = const <String, Object?>{},
}) {
  return {
    'message': 'Controlled error.',
    'code': code,
    'errors': errors,
    'request_id': 'request-1',
  };
}

const _institutionId = '550e8400-e29b-41d4-a716-446655440000';

InstitutionProfileRemoteDataSource _source(RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return InstitutionProfileRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

InstitutionProfileUpdateRequest _request() {
  return InstitutionProfileUpdateRequest.fromChanges({'name': 'Renamed'});
}

Map<String, Object?> _resource() {
  return {
    'id': _institutionId,
    'name': 'Example School',
    'type': 'school',
    'status': 'active',
    'contact_email': null,
    'contact_phone': null,
    'address': null,
    'description': null,
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T15:00:00Z',
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
  RecordingAdapter(this.handler);

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
