import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';

import 'teacher_test_support.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '20000000-0000-0000-0000-000000000001';
const _otherHomeworkId = '20000000-0000-0000-0000-000000000002';
const _successMessage = 'Homework review deadline updated successfully.';
const _wallClock = InstitutionWallClock(
  year: 2026,
  month: 9,
  day: 20,
  hour: 18,
  minute: 30,
);

void main() {
  group('Teacher Homework review deadline request', () {
    test('serializes the Institution wall clock with its offset', () {
      final request = TeacherHomeworkReviewDueAtRequest.fromWallClock(
        _wallClock,
        'Asia/Tashkent',
      );

      expect(request.reviewDueAtSerialized, '2026-09-20T18:30:00+05:00');
      expect(request.reviewDueAtUtc, DateTime.utc(2026, 9, 20, 13, 30));
      expect(request.toJson(), {'review_due_at': '2026-09-20T18:30:00+05:00'});
    });

    test('a cleared deadline serializes as null', () {
      final request = TeacherHomeworkReviewDueAtRequest.fromWallClock(
        null,
        'Asia/Tashkent',
      );

      expect(request.reviewDueAtSerialized, isNull);
      expect(request.reviewDueAtUtc, isNull);
      expect(request.toJson(), {'review_due_at': null});
    });

    test('matches compares instants, and null only with null', () {
      final request = TeacherHomeworkReviewDueAtRequest.fromWallClock(
        _wallClock,
        'Asia/Tashkent',
      );
      final cleared = TeacherHomeworkReviewDueAtRequest.fromWallClock(
        null,
        'Asia/Tashkent',
      );

      expect(
        request.matches(
          teacherHomework(reviewDueAt: DateTime.utc(2026, 9, 20, 13, 30)),
        ),
        isTrue,
      );
      expect(
        request.matches(
          teacherHomework(reviewDueAt: DateTime.utc(2026, 9, 20, 13, 31)),
        ),
        isFalse,
      );
      expect(request.matches(teacherHomework()), isFalse);
      expect(cleared.matches(teacherHomework()), isTrue);
      expect(
        cleared.matches(
          teacherHomework(reviewDueAt: DateTime.utc(2026, 9, 20, 13, 30)),
        ),
        isFalse,
      );
    });

    test('a local time that does not exist throws', () {
      expect(
        () => TeacherHomeworkReviewDueAtRequest.fromWallClock(
          const InstitutionWallClock(
            year: 2026,
            month: 3,
            day: 29,
            hour: 2,
            minute: 30,
          ),
          'Europe/Berlin',
        ),
        throwsA(isA<InstitutionTimezoneException>()),
      );
    });
  });

  group('Teacher Homework review deadline data boundary', () {
    test('sends an exact PUT and parses the success envelope', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': _homeworkJson(reviewDueAt: '2026-09-20T13:30:00Z'),
          'message': _successMessage,
        }),
      );

      final dto = await _source(adapter).setReviewDueAt(
        _homeworkId,
        TeacherHomeworkReviewDueAtRequest.fromWallClock(
          _wallClock,
          'Asia/Tashkent',
        ),
      );

      expect(dto.homework.reviewDueAt, DateTime.utc(2026, 9, 20, 13, 30));
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/teacher/homework/$_homeworkId/review-due-at');
      expect(request.queryParameters, isEmpty);
      expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      expect(request.data, {'review_due_at': '2026-09-20T18:30:00+05:00'});
      expect(request.followRedirects, isFalse);
    });

    test('sends null to clear the deadline', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': _homeworkJson(),
          'message': _successMessage,
        }),
      );

      final dto = await _source(adapter).setReviewDueAt(
        _homeworkId,
        TeacherHomeworkReviewDueAtRequest.fromWallClock(null, 'Asia/Tashkent'),
      );

      expect(dto.homework.reviewDueAt, isNull);
      expect(adapter.requests.single.data, {'review_due_at': null});
    });

    test(
      'maps the documented conflicts and shared failures as definite',
      () async {
        final cases = <(int, String)>[
          (409, ApiErrorCodes.taskArchived),
          (409, ApiErrorCodes.topicNotEditable),
          (404, ApiErrorCodes.resourceNotFound),
          (422, ApiErrorCodes.validationFailed),
          (403, ApiErrorCodes.forbidden),
          (429, ApiErrorCodes.rateLimited),
        ];

        for (final (status, code) in cases) {
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(
              status,
              _errorEnvelope(
                code,
                errors: status == 422
                    ? const {
                        'review_due_at': [
                          'The review due at field is invalid.',
                        ],
                      }
                    : const {},
              ),
            ),
          );

          await expectLater(
            _source(adapter).setReviewDueAt(_homeworkId, _request()),
            throwsA(
              isA<ApiRequestException>().having(
                (exception) => exception.failure.serverCode,
                'serverCode',
                code,
              ),
            ),
            reason: code,
          );
        }
      },
    );

    test('treats other conflicts and ambiguous responses as unknown', () async {
      final responses = <FutureOr<ResponseBody> Function(RequestOptions)>[
        (_) => _jsonResponse(409, _errorEnvelope(ApiErrorCodes.taskClosed)),
        (_) =>
            _jsonResponse(409, _errorEnvelope(ApiErrorCodes.businessConflict)),
        (_) => _jsonResponse(200, {
          'data': _homeworkJson(),
          'message': 'Homework updated successfully.',
        }),
        (_) => _jsonResponse(201, {
          'data': _homeworkJson(),
          'message': _successMessage,
        }),
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      ];

      for (final response in responses) {
        final adapter = _RecordingAdapter(response);

        await expectLater(
          _source(adapter).setReviewDueAt(_homeworkId, _request()),
          throwsA(isA<TeacherHomeworkMutationOutcomeUnknownException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test('rejects a non-canonical target before transport', () {
      final adapter = _RecordingAdapter(
        (_) => throw StateError('Transport must not be reached.'),
      );

      expect(
        () => _source(adapter).setReviewDueAt('not-a-homework-id', _request()),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test(
      'the repository treats a different returned Homework as unknown',
      () async {
        final repository = TeacherHomeworkRepositoryImpl(
          remoteDataSource: _source(
            _RecordingAdapter(
              (_) => _jsonResponse(200, {
                'data': _homeworkJson(id: _otherHomeworkId),
                'message': _successMessage,
              }),
            ),
          ),
        );

        await expectLater(
          repository.setReviewDueAt(_homeworkId, _request()),
          throwsA(isA<TeacherHomeworkMutationOutcomeUnknownException>()),
        );
      },
    );

    test('the repository returns the updated domain Homework', () async {
      final repository = TeacherHomeworkRepositoryImpl(
        remoteDataSource: _source(
          _RecordingAdapter(
            (_) => _jsonResponse(200, {
              'data': _homeworkJson(reviewDueAt: '2026-09-20T13:30:00Z'),
              'message': _successMessage,
            }),
          ),
        ),
      );

      final homework = await repository.setReviewDueAt(_homeworkId, _request());

      expect(homework.id, _homeworkId);
      expect(homework.reviewDueAt, DateTime.utc(2026, 9, 20, 13, 30));
    });
  });
}

TeacherHomeworkReviewDueAtRequest _request() {
  return TeacherHomeworkReviewDueAtRequest.fromWallClock(
    _wallClock,
    'Asia/Tashkent',
  );
}

TeacherHomeworkRemoteDataSource _source(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return TeacherHomeworkRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

Map<String, Object?> _homeworkJson({
  String id = _homeworkId,
  String? reviewDueAt,
}) {
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
    'review_due_at': reviewDueAt,
    'review_summary': {'waiting_for_teacher_review': 0, 'overdue': 0},
    'institution_timezone': 'Asia/Tashkent',
    'status': 'closed',
    'attempt_policy': {
      'normal_attempts': 3,
      'official_score_policy': 'highest_valid_completed',
    },
    'activated_at': '2026-09-01T11:00:00Z',
    'closed_at': '2026-09-01T12:00:00Z',
    'archived_at': null,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T14:00:00Z',
    'questions': <Object?>[],
  };
}

Map<String, Object?> _errorEnvelope(
  String code, {
  Map<String, Object?> errors = const {},
}) {
  return {'message': 'Request failed.', 'code': code, 'errors': errors};
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
