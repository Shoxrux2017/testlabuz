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
import 'package:testlabuz_client/features/institution_admin/data/institution_assessment_settings_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings_repository.dart';

void main() {
  test('GET uses the exact endpoint and strict only-data response', () async {
    final adapter = _RecordingAdapter((_) => _rawResponse(200, _resource('5')));
    final source = _source(adapter);

    final result = await source.fetchSettings();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/institution/settings/assessment');
    expect(adapter.requests.single.data, isNull);
    expect(adapter.requests.single.queryParameters, isEmpty);
    expect(
      adapter.requests.single.uri.toString(),
      'https://example.test/api/v1/institution/settings/assessment',
    );
    expect(adapter.requestBodies.single, isEmpty);
    expect(
      adapter.requests.single.headers.keys.any(
        (key) =>
            key.toLowerCase().contains('institution') ||
            key.toLowerCase().contains('tenant'),
      ),
      isFalse,
    );
    expect(result.settings.homeworkNormalAttempts, 3);
  });

  test(
    'PUT sends exactly seven keys and an actual exact JSON number',
    () async {
      final adapter = _RecordingAdapter(
        (_) => _rawResponse(200, _resource('7.25')),
      );
      final source = _source(adapter);
      final request = _request('7.25000000');

      await source.updateSettings(request);

      final sent = adapter.requests.single.data as Map<String, Object>;
      expect(adapter.requests.single.method, 'PUT');
      expect(
        adapter.requests.single.uri.toString(),
        'https://example.test/api/v1/institution/settings/assessment',
      );
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(
        adapter.requests.single.headers[Headers.contentTypeHeader],
        Headers.jsonContentType,
      );
      expect(
        adapter.requests.single.headers.keys.any(
          (key) =>
              key.toLowerCase() == 'idempotency-key' ||
              key.toLowerCase().contains('institution') ||
              key.toLowerCase().contains('tenant'),
        ),
        isFalse,
      );
      expect(sent.keys.toSet(), {
        'acceptable_score_difference',
        'blitz_timer_start_mode',
        'student_result_release_mode',
        'parent_result_release_mode',
        'timezone',
        'learning_material_max_mb',
        'student_submission_max_mb',
      });
      expect(sent['acceptable_score_difference'], isA<num>());
      expect(jsonEncode(sent), contains('"acceptable_score_difference":7.25'));
      final onWire = utf8.decode(adapter.requestBodies.single);
      expect(jsonDecode(onWire), sent);
      expect(onWire, contains('"acceptable_score_difference":7.25'));
    },
  );

  test('configured Dio preserves every required decimal on wire', () async {
    for (final score in [
      '0',
      '100',
      '10.5',
      '0.00000001',
      '99.12345678',
      '100.00000000',
    ]) {
      final canonical = ExactAssessmentDecimal.parseUserInput(score);
      final adapter = _RecordingAdapter(
        (_) => _rawResponse(200, _resource(canonical.canonical)),
      );

      await _source(adapter).updateSettings(_request(score));

      final onWire = utf8.decode(adapter.requestBodies.single);
      final token = RegExp(
        r'"acceptable_score_difference"\s*:\s*([^,}]+)',
      ).firstMatch(onWire)!.group(1)!;
      expect(
        ExactAssessmentDecimal.parseJsonLexeme(token),
        canonical,
        reason: '$score serialized as $token',
      );
      expect(jsonDecode(onWire)['acceptable_score_difference'], isA<num>());
    }
  });

  test('malformed or mismatching 200 makes the PUT outcome unknown', () async {
    for (final body in ['{"data":{}}', _resource('8')]) {
      final source = _source(_RecordingAdapter((_) => _rawResponse(200, body)));
      expect(
        source.updateSettings(_request('7.25')),
        throwsA(
          isA<InstitutionAssessmentSettingsUpdateOutcomeUnknownException>(),
        ),
      );
    }
  });

  test(
    'documented exact 422 is definite but 5xx and malformed errors are unknown',
    () async {
      final exact422 = _source(
        _RecordingAdapter(
          (_) => _rawResponse(
            422,
            '{"message":"Invalid","code":"validation_failed","errors":{"timezone":["Invalid"]}}',
          ),
        ),
      );
      await expectLater(
        exact422.updateSettings(_request('7.25')),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.failure.serverCode,
            'server code',
            ApiErrorCodes.validationFailed,
          ),
        ),
      );

      for (final fixture in [
        (500, '{"message":"Down","code":"server_error","errors":{}}'),
        (422, '<html>bad</html>'),
      ]) {
        final source = _source(
          _RecordingAdapter((_) => _rawResponse(fixture.$1, fixture.$2)),
        );
        await expectLater(
          source.updateSettings(_request('7.25')),
          throwsA(
            isA<InstitutionAssessmentSettingsUpdateOutcomeUnknownException>(),
          ),
        );
      }
    },
  );

  test('maps every exact definite 401, 403, 422, and 429 pair', () async {
    final cases = <(int, String)>[
      (401, ApiErrorCodes.authenticationRequired),
      (403, ApiErrorCodes.forbidden),
      (403, ApiErrorCodes.userInactive),
      (403, ApiErrorCodes.institutionInactive),
      (403, ApiErrorCodes.passwordChangeRequired),
      (422, ApiErrorCodes.validationFailed),
      (429, ApiErrorCodes.rateLimited),
    ];
    for (final fixture in cases) {
      final adapter = _RecordingAdapter(
        (_) => _rawResponse(fixture.$1, _error(fixture.$2)),
      );

      await expectLater(
        _source(adapter).updateSettings(_request('5')),
        throwsA(
          isA<ApiRequestException>().having(
            (exception) => exception.failure.serverCode,
            'server code',
            fixture.$2,
          ),
        ),
        reason: '${fixture.$1}/${fixture.$2}',
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test('never replays PUT for transports or uncontracted statuses', () async {
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
        _source(adapter).updateSettings(_request('5')),
        throwsA(
          isA<InstitutionAssessmentSettingsUpdateOutcomeUnknownException>(),
        ),
        reason: '$type',
      );
      expect(adapter.requests, hasLength(1));
    }

    for (final status in [201, 204, 302, 409, 500, 503]) {
      final adapter = _RecordingAdapter(
        (_) => _rawResponse(status, _error('unexpected_status')),
      );
      await expectLater(
        _source(adapter).updateSettings(_request('5')),
        throwsA(
          isA<InstitutionAssessmentSettingsUpdateOutcomeUnknownException>(),
        ),
        reason: '$status',
      );
      expect(adapter.requests, hasLength(1));
    }
  });

  test(
    'GET maps exact failures and malformed responses without retrying',
    () async {
      for (final fixture in <FutureOr<ResponseBody> Function(RequestOptions)>[
        (_) => _rawResponse(500, _error(ApiErrorCodes.serverError)),
        (_) => _rawResponse(200, '{"data":{}}'),
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      ]) {
        final adapter = _RecordingAdapter(fixture);
        await expectLater(
          _source(adapter).fetchSettings(),
          throwsA(isA<ApiRequestException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

InstitutionAssessmentSettingsRemoteDataSource _source(
  _RecordingAdapter adapter,
) {
  final dio = createDioClient(
    AppConfig.fromApiBaseUrl('https://example.test/api/v1'),
  );
  dio.httpClientAdapter = adapter;
  return InstitutionAssessmentSettingsRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

InstitutionAssessmentSettingsUpdateRequest _request(String score) =>
    InstitutionAssessmentSettingsUpdateRequest(
      acceptableScoreDifference: ExactAssessmentDecimal.parseUserInput(score),
      blitzTimerStartMode: BlitzTimerStartMode.synchronized,
      studentResultReleaseMode: StudentResultReleaseMode.automatic,
      parentResultReleaseMode: ParentResultReleaseMode.withStudent,
      timezone: 'Asia/Tashkent',
      learningMaterialMaxMb: 25,
      studentSubmissionMaxMb: 15,
    );

String _resource(String score) =>
    '''{"data":{"educational_policy_configured":true,"acceptable_score_difference":$score,"blitz_timer_start_mode":"synchronized","student_result_release_mode":"automatic","parent_result_release_mode":"with_student","timezone":"Asia/Tashkent","upload_limits":{"learning_material_max_mb":25,"student_submission_max_mb":15,"platform_learning_material_max_mb":25,"platform_student_submission_max_mb":15},"fixed_attempt_rules":{"homework_normal_attempts":3,"blitz_normal_attempts":1,"blitz_max_additional_exception_attempts":1}}}''';

String _error(String code) =>
    '{"message":"Safe error","code":"$code","errors":{}}';

ResponseBody _rawResponse(int statusCode, String body) =>
    ResponseBody.fromString(
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
