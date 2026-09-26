import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_schedule.dart';

import 'teacher_blitz_json_fixtures.dart';

const _key = '3f1c2a4b-5d6e-4f70-8a9b-0c1d2e3f4a5b';

void main() {
  setUpAll(InstitutionTimezone.initialize);

  group('exact lifecycle requests', () {
    test(
      'Schedule posts only scheduled_at without an Idempotency-Key',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(
            200,
            _envelope(
              'Blitz task scheduled successfully.',
              TeacherBlitzStatus.scheduled,
            ),
          ),
        );

        final blitz = await _repository(
          adapter,
        ).scheduleBlitz(blitzJsonId, _scheduleRequest());

        expect(blitz.status, TeacherBlitzStatus.scheduled);
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/teacher/blitz/$blitzJsonId/schedule');
        expect(request.queryParameters, isEmpty);
        expect(request.followRedirects, isFalse);
        expect(request.data, {'scheduled_at': '2026-09-30T09:00:00+05:00'});
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      },
    );

    test('Activate sends the exact Idempotency-Key and no body', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _envelope(
            'Blitz task activated successfully.',
            TeacherBlitzStatus.active,
          ),
        ),
      );

      final blitz = await _repository(
        adapter,
      ).activateBlitz(blitzJsonId, idempotencyKey: _key);

      expect(blitz.status, TeacherBlitzStatus.active);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/teacher/blitz/$blitzJsonId/activate');
      expect(request.headers['Idempotency-Key'], _key);
      expect(request.data, isNull);
      expect(request.queryParameters, isEmpty);
      expect(request.followRedirects, isFalse);
    });

    test('Close and Archive post no body, query or Idempotency-Key', () async {
      for (final (segment, message, status) in [
        ('close', 'Blitz task closed successfully.', TeacherBlitzStatus.closed),
        (
          'archive',
          'Blitz task archived successfully.',
          TeacherBlitzStatus.archived,
        ),
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(200, _envelope(message, status)),
        );
        final repository = _repository(adapter);

        final blitz = segment == 'close'
            ? await repository.closeBlitz(blitzJsonId)
            : await repository.archiveBlitz(blitzJsonId);

        expect(blitz.status, status);
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/teacher/blitz/$blitzJsonId/$segment');
        expect(request.data, isNull);
        expect(request.queryParameters, isEmpty);
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
        expect(request.followRedirects, isFalse);
      }
    });

    test('rejects malformed targets and keys before transport', () {
      final adapter = _RecordingAdapter((_) => _jsonResponse(200, null));
      final source = _source(adapter);

      expect(
        () => source.scheduleBlitz('not-a-uuid', _scheduleRequest()),
        throwsArgumentError,
      );
      expect(
        () => source.activateBlitz(blitzJsonId, idempotencyKey: 'short'),
        throwsArgumentError,
      );
      expect(() => source.closeBlitz('bad'), throwsArgumentError);
      expect(() => source.archiveBlitz('bad'), throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });
  });

  group('possible success that is not proven', () {
    test('a wrong message, status or malformed body is outcome unknown', () {
      for (final response in [
        _jsonResponse(
          200,
          _envelope('Blitz task closed.', TeacherBlitzStatus.closed),
        ),
        _jsonResponse(
          201,
          _envelope(
            'Blitz task closed successfully.',
            TeacherBlitzStatus.closed,
          ),
        ),
        _jsonResponse(200, {'data': null, 'message': 'x'}),
      ]) {
        final adapter = _RecordingAdapter((_) => response);

        expect(
          _repository(adapter).closeBlitz(blitzJsonId),
          throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
        );
      }
    });

    test('a resource for another Blitz is outcome unknown', () {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': {
            ...teacherBlitzJson(status: TeacherBlitzStatus.archived),
            'id': '80000000-0000-0000-0000-0000000000ff',
          },
          'message': 'Blitz task archived successfully.',
        }),
      );

      expect(
        _repository(adapter).archiveBlitz(blitzJsonId),
        throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
      );
    });

    test('a completed replay may carry a later Closed lifecycle', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _envelope(
            'Blitz task activated successfully.',
            TeacherBlitzStatus.closed,
          ),
        ),
      );

      final blitz = await _repository(
        adapter,
      ).activateBlitz(blitzJsonId, idempotencyKey: _key);

      expect(blitz.status, TeacherBlitzStatus.closed);
    });

    test('a transport failure is outcome unknown and is not retried', () async {
      final adapter = _RecordingAdapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      await expectLater(
        _repository(adapter).activateBlitz(blitzJsonId, idempotencyKey: _key),
        throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
      );
      expect(adapter.requests, hasLength(1));
    });
  });

  group('documented definite failures', () {
    Future<void> expectDefinite(
      Future<Object?> Function(TeacherBlitzRepositoryImpl repository) call,
      int status,
      String code, {
      Map<String, Object?> errors = const {},
      Map<String, Object?>? meta,
    }) async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(status, _error(code, errors, meta: meta)),
      );
      await expectLater(
        call(_repository(adapter)),
        throwsA(
          isA<ApiRequestException>()
              .having((e) => e.failure.statusCode, 'status', status)
              .having((e) => e.failure.serverCode, 'code', code),
        ),
      );
    }

    test(
      'Schedule recognizes its delivered conflicts and validation',
      () async {
        for (final code in [
          ApiErrorCodes.taskClosed,
          ApiErrorCodes.taskArchived,
          ApiErrorCodes.businessConflict,
          ApiErrorCodes.topicNotEditable,
        ]) {
          await expectDefinite(
            (repository) =>
                repository.scheduleBlitz(blitzJsonId, _scheduleRequest()),
            409,
            code,
          );
        }
        await expectDefinite(
          (repository) =>
              repository.scheduleBlitz(blitzJsonId, _scheduleRequest()),
          422,
          ApiErrorCodes.validationFailed,
          errors: {
            'scheduled_at': ['The scheduled_at must be in the future.'],
          },
        );
      },
    );

    test('Activate recognizes every delivered conflict', () async {
      for (final code in [
        ApiErrorCodes.idempotencyKeyReused,
        ApiErrorCodes.taskClosed,
        ApiErrorCodes.taskArchived,
        ApiErrorCodes.topicNotEditable,
        ApiErrorCodes.assessmentHasNoScoreablePoints,
        ApiErrorCodes.assessmentNotAssigned,
        ApiErrorCodes.officialCohortMismatch,
        ApiErrorCodes.businessConflict,
      ]) {
        await expectDefinite(
          (repository) =>
              repository.activateBlitz(blitzJsonId, idempotencyKey: _key),
          409,
          code,
        );
      }
    });

    test('Activate accepts the documented settings meta envelope', () async {
      await expectDefinite(
        (repository) =>
            repository.activateBlitz(blitzJsonId, idempotencyKey: _key),
        409,
        ApiErrorCodes.institutionSettingsIncomplete,
        meta: {
          'missing_fields': ['blitz_timer_start_mode'],
        },
      );
      await expectDefinite(
        (repository) =>
            repository.activateBlitz(blitzJsonId, idempotencyKey: _key),
        409,
        ApiErrorCodes.institutionSettingsIncomplete,
      );
    });

    test('meta on any other error keeps the outcome unknown', () {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          409,
          _error(
            ApiErrorCodes.businessConflict,
            const {},
            meta: {
              'missing_fields': ['blitz_timer_start_mode'],
            },
          ),
        ),
      );

      expect(
        _repository(adapter).activateBlitz(blitzJsonId, idempotencyKey: _key),
        throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
      );
    });

    test('malformed settings meta keeps the outcome unknown', () {
      for (final meta in [
        {'missing_fields': 'blitz_timer_start_mode'},
        {
          'missing_fields': ['blitz_timer_start_mode'],
          'extra': true,
        },
        {
          'missing_fields': <String>[''],
        },
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(
            409,
            _error(
              ApiErrorCodes.institutionSettingsIncomplete,
              const {},
              meta: meta,
            ),
          ),
        );

        expect(
          _repository(adapter).activateBlitz(blitzJsonId, idempotencyKey: _key),
          throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
          reason: '$meta',
        );
      }
    });

    test('Close and Archive recognize their delivered conflicts', () async {
      for (final code in [
        ApiErrorCodes.taskNotActive,
        ApiErrorCodes.taskArchived,
        ApiErrorCodes.topicNotEditable,
        ApiErrorCodes.businessConflict,
      ]) {
        await expectDefinite(
          (repository) => repository.closeBlitz(blitzJsonId),
          409,
          code,
        );
      }
      await expectDefinite(
        (repository) => repository.archiveBlitz(blitzJsonId),
        409,
        ApiErrorCodes.businessConflict,
      );
      await expectDefinite(
        (repository) => repository.archiveBlitz(blitzJsonId),
        404,
        ApiErrorCodes.resourceNotFound,
      );
    });

    test('an undocumented conflict code stays outcome unknown', () {
      final adapter = _RecordingAdapter(
        (_) =>
            _jsonResponse(409, _error(ApiErrorCodes.taskNotActive, const {})),
      );

      expect(
        _repository(adapter).archiveBlitz(blitzJsonId),
        throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
      );
    });
  });
}

TeacherBlitzScheduleRequest _scheduleRequest() {
  return TeacherBlitzScheduleRequest.fromWallClock(
    const InstitutionWallClock(
      year: 2026,
      month: 9,
      day: 30,
      hour: 9,
      minute: 0,
    ),
    'Asia/Tashkent',
  );
}

Map<String, Object?> _envelope(String message, TeacherBlitzStatus status) {
  return {'data': teacherBlitzJson(status: status), 'message': message};
}

Map<String, Object?> _error(
  String code,
  Map<String, Object?> errors, {
  Map<String, Object?>? meta,
}) {
  return {
    'message': 'Server says no.',
    'code': code,
    'errors': errors,
    'meta': ?meta,
  };
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

TeacherBlitzRepositoryImpl _repository(_RecordingAdapter adapter) {
  return TeacherBlitzRepositoryImpl(remoteDataSource: _source(adapter));
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
