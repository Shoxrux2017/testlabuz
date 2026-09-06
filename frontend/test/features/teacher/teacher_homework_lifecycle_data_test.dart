import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_lifecycle.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '20000000-0000-0000-0000-000000000001';
const _otherHomeworkId = '20000000-0000-0000-0000-000000000002';

void main() {
  group('Teacher Homework lifecycle data boundary', () {
    test('uses exact bodyless POST paths and success messages', () async {
      final adapter = _RecordingAdapter((options) {
        final action = TeacherHomeworkLifecycleAction.values.singleWhere(
          (candidate) => options.path.endsWith('/${candidate.segment}'),
        );
        return _jsonResponse(200, {
          'data': _homeworkJson(status: action.expectedStatus),
          'message': action.successMessage,
        });
      });
      final source = _source(adapter);

      for (final action in TeacherHomeworkLifecycleAction.values) {
        final dto = await source.performLifecycleAction(_homeworkId, action);
        expect(dto.homework.status, action.expectedStatus);
      }

      expect(adapter.requests, hasLength(3));
      for (var index = 0; index < adapter.requests.length; index += 1) {
        final action = TeacherHomeworkLifecycleAction.values[index];
        final request = adapter.requests[index];
        expect(request.method, 'POST');
        expect(
          request.path,
          '/teacher/homework/$_homeworkId/${action.segment}',
        );
        expect(
          request.uri.path,
          '/api/v1/teacher/homework/$_homeworkId/${action.segment}',
        );
        expect(request.queryParameters, isEmpty);
        expect(request.data, isNull);
        expect(request.followRedirects, isFalse);
      }
    });

    test('maps exact shared lifecycle failures as definite', () async {
      final cases = <(int, String)>[
        (401, ApiErrorCodes.authenticationRequired),
        (403, ApiErrorCodes.forbidden),
        (404, ApiErrorCodes.resourceNotFound),
        (422, ApiErrorCodes.validationFailed),
        (429, ApiErrorCodes.rateLimited),
      ];

      for (final entry in cases) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(entry.$1, _errorEnvelope(entry.$2)),
        );

        await expectLater(
          _source(adapter).performLifecycleAction(
            _homeworkId,
            TeacherHomeworkLifecycleAction.activate,
          ),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (error) => error.failure.statusCode,
                  'statusCode',
                  entry.$1,
                )
                .having(
                  (error) => error.failure.serverCode,
                  'serverCode',
                  entry.$2,
                ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test(
      'maps every documented action-specific lifecycle conflict as definite',
      () async {
        final cases = <(TeacherHomeworkLifecycleAction, String)>[
          (
            TeacherHomeworkLifecycleAction.activate,
            ApiErrorCodes.topicNotEditable,
          ),
          (TeacherHomeworkLifecycleAction.activate, ApiErrorCodes.taskClosed),
          (TeacherHomeworkLifecycleAction.activate, ApiErrorCodes.taskArchived),
          (
            TeacherHomeworkLifecycleAction.activate,
            ApiErrorCodes.businessConflict,
          ),
          (
            TeacherHomeworkLifecycleAction.activate,
            ApiErrorCodes.resultPairLocked,
          ),
          (
            TeacherHomeworkLifecycleAction.activate,
            ApiErrorCodes.assessmentHasNoScoreablePoints,
          ),
          (
            TeacherHomeworkLifecycleAction.activate,
            ApiErrorCodes.assessmentNotAssigned,
          ),
          (
            TeacherHomeworkLifecycleAction.activate,
            ApiErrorCodes.deadlinePassed,
          ),
          (TeacherHomeworkLifecycleAction.close, ApiErrorCodes.taskNotActive),
          (TeacherHomeworkLifecycleAction.close, ApiErrorCodes.taskArchived),
          (
            TeacherHomeworkLifecycleAction.close,
            ApiErrorCodes.topicNotEditable,
          ),
          (
            TeacherHomeworkLifecycleAction.close,
            ApiErrorCodes.businessConflict,
          ),
          (
            TeacherHomeworkLifecycleAction.archive,
            ApiErrorCodes.businessConflict,
          ),
        ];

        for (final entry in cases) {
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(409, _errorEnvelope(entry.$2)),
          );

          await expectLater(
            _source(adapter).performLifecycleAction(_homeworkId, entry.$1),
            throwsA(
              isA<ApiRequestException>()
                  .having(
                    (error) => error.failure.statusCode,
                    'statusCode',
                    409,
                  )
                  .having(
                    (error) => error.failure.serverCode,
                    'serverCode',
                    entry.$2,
                  ),
            ),
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test(
      'treats cross-action and future lifecycle conflicts as unknown',
      () async {
        final cases = <(TeacherHomeworkLifecycleAction, String)>[
          (TeacherHomeworkLifecycleAction.close, ApiErrorCodes.deadlinePassed),
          (
            TeacherHomeworkLifecycleAction.close,
            ApiErrorCodes.resultPairLocked,
          ),
          (TeacherHomeworkLifecycleAction.archive, ApiErrorCodes.taskClosed),
          (
            TeacherHomeworkLifecycleAction.activate,
            ApiErrorCodes.taskNotActive,
          ),
          (
            TeacherHomeworkLifecycleAction.activate,
            'future_lifecycle_conflict',
          ),
        ];

        for (final entry in cases) {
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(409, _errorEnvelope(entry.$2)),
          );

          await expectLater(
            _source(adapter).performLifecycleAction(_homeworkId, entry.$1),
            throwsA(isA<TeacherHomeworkMutationOutcomeUnknownException>()),
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test(
      'treats every ambiguous response or transport result as unknown',
      () async {
        final responses = <FutureOr<ResponseBody> Function(RequestOptions)>[
          (_) => _jsonResponse(200, {
            'data': _homeworkJson(status: TeacherHomeworkStatus.active),
            'message': 'Homework closed successfully.',
          }),
          (_) => _jsonResponse(200, {
            'data': _homeworkJson(status: TeacherHomeworkStatus.active),
            'message': 'Homework activated successfully.',
            'extra': true,
          }),
          (_) => _jsonResponse(201, {
            'data': _homeworkJson(status: TeacherHomeworkStatus.active),
            'message': 'Homework activated successfully.',
          }),
          (_) => _jsonResponse(409, _errorEnvelope('unknown_conflict')),
          (_) => _jsonResponse(
            409,
            _errorEnvelope(
              ApiErrorCodes.resultPairLocked,
              errors: {
                'homework': ['must be empty'],
              },
            ),
          ),
          (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ];

        for (final response in responses) {
          final adapter = _RecordingAdapter(response);
          await expectLater(
            _source(adapter).performLifecycleAction(
              _homeworkId,
              TeacherHomeworkLifecycleAction.activate,
            ),
            throwsA(isA<TeacherHomeworkMutationOutcomeUnknownException>()),
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test('repository rejects a mismatched ID or lifecycle status', () async {
      for (final homework in [
        _homeworkJson(
          id: _otherHomeworkId,
          status: TeacherHomeworkStatus.active,
        ),
        _homeworkJson(status: TeacherHomeworkStatus.draft),
      ]) {
        final repository = TeacherHomeworkRepositoryImpl(
          remoteDataSource: _source(
            _RecordingAdapter(
              (_) => _jsonResponse(200, {
                'data': homework,
                'message': 'Homework activated successfully.',
              }),
            ),
          ),
        );

        await expectLater(
          repository.performLifecycleAction(
            _homeworkId,
            TeacherHomeworkLifecycleAction.activate,
          ),
          throwsA(isA<TeacherHomeworkMutationOutcomeUnknownException>()),
        );
      }
    });

    test('rejects a non-canonical lifecycle target before transport', () async {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('Transport must not be reached.'),
      );

      expect(
        () => _source(adapter).performLifecycleAction(
          'not-a-homework-id',
          TeacherHomeworkLifecycleAction.activate,
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });
}

TeacherHomeworkRemoteDataSource _source(_RecordingAdapter adapter) {
  return TeacherHomeworkRemoteDataSource(
    dio: _dio(adapter),
    failureMapper: const DioFailureMapper(),
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

Map<String, Object?> _homeworkJson({
  String id = _homeworkId,
  TeacherHomeworkStatus status = TeacherHomeworkStatus.draft,
}) {
  final activated = status != TeacherHomeworkStatus.draft;
  final closed =
      status == TeacherHomeworkStatus.closed ||
      status == TeacherHomeworkStatus.archived;
  final archived = status == TeacherHomeworkStatus.archived;
  return {
    'id': id,
    'topic_id': _topicId,
    'title': 'Homework',
    'description': null,
    'student_instructions': 'Complete the Homework.',
    'assignment_mode': 'group',
    'student_ids': <Object?>[],
    'total_possible_points': 0,
    'deadline_at': null,
    'institution_timezone': 'Asia/Tashkent',
    'status': status.name,
    'attempt_policy': {
      'normal_attempts': 3,
      'official_score_policy': 'highest_valid_completed',
    },
    'activated_at': activated ? '2026-09-01T11:00:00Z' : null,
    'closed_at': closed ? '2026-09-01T12:00:00Z' : null,
    'archived_at': archived ? '2026-09-01T13:00:00Z' : null,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T14:00:00Z',
    'questions': <Object?>[],
  };
}

Map<String, Object?> _errorEnvelope(
  String code, {
  Map<String, Object?> errors = const {},
}) {
  return {'message': 'Lifecycle failed.', 'code': code, 'errors': errors};
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
