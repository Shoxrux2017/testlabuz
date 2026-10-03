import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/application/teacher_review_queue_scope.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_submission_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_submission_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_official_score.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission_review.dart';

import 'teacher_submission_test_support.dart';

void main() {
  group('Teacher review queue scope', () {
    const topicId = '10000000-0000-0000-0000-000000000001';
    const blitzId = '80000000-0000-0000-0000-000000000001';

    test('a task scope sends its Topic and task and keeps them on changes', () {
      final scope = TeacherReviewQueueScope.task(
        topicId: topicId,
        assessmentId: blitzId,
        type: TeacherSubmissionTaskType.blitz,
      );
      final changed = scope.initialQuery
          .withOfficial(false)
          .withSort(TeacherSubmissionSort.finalizedAt)
          .withPage(2);

      expect(changed.toQueryParameters(), {
        'topic_id': topicId,
        'assessment_id': blitzId,
        'checking_status': 'waiting_for_teacher_review',
        'official': 'false',
        'sort': 'finalized_at',
        'direction': 'asc',
        'page': 2,
        'per_page': 25,
      });
      expect(
        scope,
        TeacherReviewQueueScope.task(
          topicId: topicId,
          assessmentId: blitzId,
          type: TeacherSubmissionTaskType.blitz,
        ),
      );
      expect(scope == TeacherReviewQueueScope.all, isFalse);
    });

    test('the global scope keeps the unscoped initial query', () {
      expect(
        TeacherReviewQueueScope.all.initialQuery,
        const TeacherSubmissionListQuery.initial(),
      );
      expect(TeacherReviewQueueScope.all.type, isNull);
    });

    test('a task scope rejects non-canonical ids', () {
      for (final (topic, task) in [
        ('not-a-topic', blitzId),
        (topicId, 'not-a-task'),
      ]) {
        expect(
          () => TeacherReviewQueueScope.task(
            topicId: topic,
            assessmentId: task,
            type: TeacherSubmissionTaskType.blitz,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('Teacher submission list query', () {
    test('defaults to waiting submissions in the recommended order', () {
      const query = TeacherSubmissionListQuery.initial();

      expect(
        query.checkingStatus,
        TeacherSubmissionCheckingFilter.waitingForTeacherReview,
      );
      expect(query.toQueryParameters(), {
        'checking_status': 'waiting_for_teacher_review',
        'sort': 'default',
        'page': 1,
        'per_page': 25,
      });
    });

    test('sends each filter only when it is in use', () {
      final query = const TeacherSubmissionListQuery.initial()
          .withCheckingStatus(null)
          .withType(TeacherSubmissionTaskType.blitz)
          .withOfficial(false)
          .withOverdueOnly(true)
          .withSort(TeacherSubmissionSort.studentName)
          .withDirection(TeacherSubmissionSortDirection.desc);

      expect(query.toQueryParameters(), {
        'type': 'blitz',
        'official': 'false',
        'overdue': 'true',
        'sort': 'student_name',
        'direction': 'desc',
        'page': 1,
        'per_page': 25,
      });
      expect(
        const TeacherSubmissionListQuery.initial()
            .withCheckingStatus(
              TeacherSubmissionCheckingFilter.automaticCheckingPending,
            )
            .withOfficial(true)
            .toQueryParameters(),
        {
          'checking_status': 'automatic_checking_pending',
          'official': 'true',
          'sort': 'default',
          'page': 1,
          'per_page': 25,
        },
      );
    });

    test('returning to the recommended order resets the direction', () {
      final query = const TeacherSubmissionListQuery.initial()
          .withSort(TeacherSubmissionSort.finalizedAt)
          .withDirection(TeacherSubmissionSortDirection.desc)
          .withSort(TeacherSubmissionSort.recommended);

      expect(query.direction, TeacherSubmissionSortDirection.asc);
      expect(query.toQueryParameters().containsKey('direction'), isFalse);
    });

    test('every filter or sort change returns to page 1', () {
      final paged = const TeacherSubmissionListQuery.initial().withPage(3);
      final changes =
          <TeacherSubmissionListQuery Function(TeacherSubmissionListQuery)>[
            (query) => query.withCheckingStatus(
              TeacherSubmissionCheckingFilter.checked,
            ),
            (query) => query.withType(TeacherSubmissionTaskType.homework),
            (query) => query.withOfficial(true),
            (query) => query.withOverdueOnly(true),
            (query) => query.withSort(TeacherSubmissionSort.reviewDueAt),
            (query) => query
                .withSort(TeacherSubmissionSort.studentName)
                .withPage(2)
                .withDirection(TeacherSubmissionSortDirection.desc),
          ];

      for (final change in changes) {
        expect(change(paged).page, 1);
      }
      expect(() => paged.withPage(0), throwsArgumentError);
    });
  });

  group('Teacher submission DTO', () {
    test('parses an official checked Homework item', () {
      final submission = TeacherSubmissionDto.fromJson(
        submissionJson(),
      ).toDomain();

      expect(submission.id, submissionId);
      expect(submission.taskType, TeacherSubmissionTaskType.homework);
      expect(submission.taskTitle, 'Equation practice');
      expect(submission.official, isTrue);
      expect(submission.topicTitle, 'Internet Basics');
      expect(submission.groupName, '7-A');
      expect(submission.studentName, 'Aziza Karimova');
      expect(submission.attemptNumber, 2);
      expect(submission.status, TeacherSubmissionStatus.checked);
      expect(submission.officialScoreEligible, isTrue);
      expect(
        submission.finalizationReason,
        TeacherSubmissionFinalizationReason.studentSubmit,
      );
      expect(submission.finalizedAt, DateTime.utc(2026, 9, 30, 10));
      expect([submission.waitingAnswers, submission.reviewedAnswers], [0, 2]);
      expect(submission.reviewDueAt, DateTime.utc(2026, 10, 2, 13));
      expect(submission.reviewOverdue, isFalse);
      expect(
        [
          submission.earnedPoints,
          submission.possiblePoints,
          submission.normalizedScore,
        ],
        [15.0, 20.0, 75.0],
      );
    });

    test(
      'parses every status, both task types and every finalization reason',
      () {
        for (final status in [
          'submitted',
          'timed_out_finalized',
          'waiting_for_teacher_review',
        ]) {
          final submission = TeacherSubmissionDto.fromJson(
            submissionJson(status: status, earned: null, normalized: null),
          ).toDomain();
          expect(submission.status.value, status);
          expect(submission.normalizedScore, isNull);
        }
        final blitz = TeacherSubmissionDto.fromJson(
          submissionJson(
            type: 'blitz',
            reviewDueAt: null,
            official: false,
            eligible: false,
          ),
        ).toDomain();
        expect(blitz.taskType, TeacherSubmissionTaskType.blitz);
        expect(blitz.officialScoreEligible, isFalse);
        for (final reason in [
          'student_submit',
          'timeout_auto_submit',
          'task_closed_auto_finalize',
          'homework_deadline_auto_submit',
        ]) {
          expect(
            TeacherSubmissionDto.fromJson(
              submissionJson(reason: reason),
            ).toDomain().finalizationReason.value,
            reason,
          );
        }
      },
    );

    test('rejects missing or unknown keys at every level', () {
      final mutations = <void Function(Map<String, Object?>)>[
        (json) => json['extra'] = true,
        (json) => json.remove('review_overdue'),
        (json) => (json['assessment']! as Map<String, Object?>)['extra'] = 1,
        (json) => (json['topic']! as Map<String, Object?>).remove('title'),
        (json) => (json['group']! as Map<String, Object?>)['extra'] = 1,
        (json) =>
            (json['student']! as Map<String, Object?>).remove('full_name'),
        (json) => (json['review']! as Map<String, Object?>)['extra'] = 1,
        (json) =>
            (json['score']! as Map<String, Object?>).remove('possible_points'),
      ];

      for (final mutate in mutations) {
        final json = submissionJson();
        mutate(json);
        expect(
          () => TeacherSubmissionDto.fromJson(json),
          throwsFormatException,
        );
      }
    });

    test('rejects contradictory or out-of-range values', () {
      final invalid = <Map<String, Object?>>[
        submissionJson(status: 'waiting_for_teacher_review'),
        submissionJson(earned: null),
        submissionJson(normalized: 100.5),
        submissionJson(earned: 25),
        submissionJson(possible: -1),
        submissionJson(type: 'blitz'),
        submissionJson(overdue: true),
        submissionJson(status: 'checked', overdue: true),
        submissionJson(
          status: 'waiting_for_teacher_review',
          earned: null,
          normalized: null,
          reviewDueAt: null,
          overdue: true,
        ),
        submissionJson(official: true, eligible: false),
        submissionJson(attemptNumber: 0),
        submissionJson(waiting: -1),
        submissionJson(status: 'in_progress', earned: null, normalized: null),
        submissionJson(type: 'quiz'),
        submissionJson(reason: 'teacher_close'),
        submissionJson(id: 'not-an-id'),
        submissionJson(studentName: '  '),
        submissionJson(normalized: null),
        submissionJson(status: 'waiting_for_teacher_review', earned: null),
        submissionJson(normalized: -1),
        submissionJson(earned: -1),
        submissionJson(reviewed: -1),
      ];

      for (final json in invalid) {
        expect(
          () => TeacherSubmissionDto.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });

    test('accepts an overdue waiting Homework item', () {
      final submission = TeacherSubmissionDto.fromJson(
        submissionJson(
          status: 'waiting_for_teacher_review',
          earned: null,
          normalized: null,
          overdue: true,
        ),
      ).toDomain();

      expect(submission.reviewOverdue, isTrue);
    });
  });

  group('Teacher submission detail data source', () {
    test('sends GET /teacher/submissions/{id} and parses the detail', () async {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(200, {'data': submissionDetailJson()}),
      );

      final dto = await _source(adapter).fetchSubmission(submissionId);

      expect(dto.toDomain().questions, hasLength(10));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/submissions/$submissionId');
      expect(request.queryParameters, isEmpty);
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
    });

    test('a wrong status or envelope is an invalid response', () async {
      final responses = <FutureOr<ResponseBody> Function(RequestOptions)>[
        (_) => jsonResponse(201, {'data': submissionDetailJson()}),
        (_) => jsonResponse(200, submissionDetailJson()),
        (_) =>
            jsonResponse(200, {'data': submissionDetailJson(), 'message': 'x'}),
        (_) => jsonResponse(200, {'data': submissionDetailJson(waiting: 3)}),
      ];

      for (final response in responses) {
        await expectLater(
          _source(RecordingAdapter(response)).fetchSubmission(submissionId),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    });

    test('a non-canonical id is rejected before transport', () {
      final adapter = RecordingAdapter(
        (_) => throw StateError('No transport.'),
      );

      expect(
        () => _source(adapter).fetchSubmission('not-an-id'),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test('the repository rejects a detail of another submission', () async {
      final other = submissionDetailJson()
        ..['id'] = '70000000-0000-0000-0000-000000000009';
      final repository = TeacherSubmissionRepositoryImpl(
        remoteDataSource: _source(
          RecordingAdapter((_) => jsonResponse(200, {'data': other})),
        ),
      );

      await expectLater(
        repository.fetchSubmission(submissionId),
        throwsA(
          isA<ApiRequestException>().having(
            (exception) => exception.failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('Teacher submission review data source', () {
    const message = 'Submission review saved successfully.';
    final request = TeacherSubmissionReviewRequest([
      TeacherAnswerReviewItem(
        answerId: detailId(206),
        awardedPoints: 2,
        feedback: 'Clear report.',
      ),
    ]);

    test(
      'sends PUT /teacher/submissions/{id}/review and parses the detail',
      () async {
        final adapter = RecordingAdapter(
          (_) => jsonResponse(200, {
            'data': reviewedDetailJson(),
            'message': message,
          }),
        );

        final dto = await _source(adapter).saveReview(submissionId, request);

        expect(request.matches(dto.toDomain()), isTrue);
        final sent = adapter.requests.single;
        expect(sent.method, 'PUT');
        expect(sent.path, '/teacher/submissions/$submissionId/review');
        expect(sent.queryParameters, isEmpty);
        expect(sent.data, request.toJson());
        expect(
          sent.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('idempotency-key')),
        );
        expect(sent.followRedirects, isFalse);
      },
    );

    test('an unexpected success leaves the outcome unknown', () async {
      final responses = <FutureOr<ResponseBody> Function(RequestOptions)>[
        (_) => jsonResponse(201, {
          'data': reviewedDetailJson(),
          'message': message,
        }),
        (_) => jsonResponse(200, {'data': reviewedDetailJson()}),
        (_) => jsonResponse(200, {
          'data': reviewedDetailJson(),
          'message': 'Saved.',
        }),
        (_) => jsonResponse(200, {
          'data': reviewedDetailJson(),
          'message': message,
          'meta': <String, Object?>{},
        }),
        (_) => jsonResponse(200, {
          'data': submissionDetailJson(waiting: 3),
          'message': message,
        }),
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
        (_) => jsonResponse(500, _error('server_error')),
        (_) => jsonResponse(409, _error('business_conflict')),
      ];

      for (final response in responses) {
        await expectLater(
          _source(RecordingAdapter(response)).saveReview(submissionId, request),
          throwsA(isA<TeacherSubmissionReviewOutcomeUnknownException>()),
        );
      }
    });

    test('an exact documented failure is definite', () async {
      final failures = <int, Map<String, Object?>>{
        409: _error(ApiErrorCodes.automaticCheckingPending),
        422: _error(ApiErrorCodes.validationFailed, {
          'answers.0.awarded_points': [
            'The awarded points must not exceed the Question points.',
          ],
        }),
        404: _error(ApiErrorCodes.resourceNotFound),
      };

      for (final MapEntry(key: status, value: body) in failures.entries) {
        await expectLater(
          _source(
            RecordingAdapter((_) => jsonResponse(status, body)),
          ).saveReview(submissionId, request),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (exception) => exception.failure.statusCode,
                  'status',
                  status,
                )
                .having(
                  (exception) => exception.failure.serverCode,
                  'code',
                  body['code'],
                )
                .having(
                  (exception) => exception.failure.fieldErrors.keys,
                  'field errors',
                  (body['errors']! as Map).keys,
                ),
          ),
        );
      }
    });

    test('a closed Topic result is a definite failure', () async {
      await expectLater(
        _source(
          RecordingAdapter(
            (_) => jsonResponse(409, _error(ApiErrorCodes.resultClosed)),
          ),
        ).saveReview(submissionId, request),
        throwsA(
          isA<ApiRequestException>().having(
            (exception) => exception.failure.serverCode,
            'code',
            ApiErrorCodes.resultClosed,
          ),
        ),
      );
    });

    test('a non-canonical id is rejected before transport', () {
      final adapter = RecordingAdapter(
        (_) => throw StateError('No transport.'),
      );

      expect(
        () => _source(adapter).saveReview('not-an-id', request),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test('the repository returns the saved detail', () async {
      final repository = TeacherSubmissionRepositoryImpl(
        remoteDataSource: _source(
          RecordingAdapter(
            (_) => jsonResponse(200, {
              'data': reviewedDetailJson(),
              'message': message,
            }),
          ),
        ),
      );

      final detail = await repository.saveReview(submissionId, request);

      expect(detail.submission.id, submissionId);
      expect(request.matches(detail), isTrue);
    });
  });

  group('Teacher official score data source', () {
    const path =
        '/teacher/assessments/$officialAssessmentId/students/$officialStudentId/official-score';

    test('sends GET and parses the official score', () async {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(200, {'data': officialScoreJson()}),
      );

      final dto = await _source(
        adapter,
      ).fetchOfficialScore(officialAssessmentId, officialStudentId);

      expect(dto.toDomain().normalizedScore, 87.25);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, path);
      expect(request.queryParameters, isEmpty);
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
    });

    test('a wrong status or envelope is an invalid response', () async {
      final responses = <FutureOr<ResponseBody> Function(RequestOptions)>[
        (_) => jsonResponse(201, {'data': officialScoreJson()}),
        (_) => jsonResponse(200, officialScoreJson()),
        (_) => jsonResponse(200, {'data': officialScoreJson(), 'message': 'x'}),
        (_) => jsonResponse(200, {
          'data': officialScoreJson()..['status'] = 'pending',
        }),
      ];

      for (final response in responses) {
        await expectLater(
          _source(
            RecordingAdapter(response),
          ).fetchOfficialScore(officialAssessmentId, officialStudentId),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    });

    test('non-canonical ids are rejected before transport', () {
      final adapter = RecordingAdapter(
        (_) => throw StateError('No transport.'),
      );

      expect(
        () =>
            _source(adapter).fetchOfficialScore('not-an-id', officialStudentId),
        throwsArgumentError,
      );
      expect(
        () => _source(adapter).fetchOfficialScore(officialAssessmentId, 'x'),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });

    test('the repository rejects a score of another target', () async {
      final target = TeacherOfficialScoreTarget(
        assessmentId: officialAssessmentId,
        studentId: officialStudentId,
        type: TeacherSubmissionTaskType.homework,
      );
      final others = [
        officialScoreJson()
          ..['assessment_id'] = '50000000-0000-0000-0000-000000000009',
        officialScoreJson()
          ..['student_id'] = '60000000-0000-0000-0000-000000000009',
        officialScoreJson(
          type: 'blitz',
          attemptNumber: 1,
          policy: 'valid_normal_blitz',
        ),
      ];

      const lettered = 'abcdef00-0000-4000-8000-00000000000a';
      const letteredStudent = 'fedcba00-0000-4000-8000-00000000000b';
      final matching =
          await TeacherSubmissionRepositoryImpl(
            remoteDataSource: _source(
              RecordingAdapter(
                (_) => jsonResponse(200, {
                  'data': officialScoreJson()
                    ..['assessment_id'] = lettered.toUpperCase()
                    ..['student_id'] = letteredStudent.toUpperCase(),
                }),
              ),
            ),
          ).fetchOfficialScore(
            TeacherOfficialScoreTarget(
              assessmentId: lettered,
              studentId: letteredStudent,
              type: TeacherSubmissionTaskType.homework,
            ),
          );
      expect(matching.status, TeacherOfficialScoreStatus.ready);

      for (final other in others) {
        final repository = TeacherSubmissionRepositoryImpl(
          remoteDataSource: _source(
            RecordingAdapter((_) => jsonResponse(200, {'data': other})),
          ),
        );
        await expectLater(
          repository.fetchOfficialScore(target),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    });
  });

  group('Teacher submission data source', () {
    test('sends GET /teacher/submissions with the query parameters', () async {
      final adapter = RecordingAdapter(
        (_) => jsonResponse(200, submissionListJson([submissionJson()])),
      );
      final query = const TeacherSubmissionListQuery.initial().withType(
        TeacherSubmissionTaskType.homework,
      );

      final list = await _source(adapter).fetchSubmissions(query);

      expect(list.items.single.id, submissionId);
      expect(list.pagination.total, 1);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/submissions');
      expect(request.queryParameters, query.toQueryParameters());
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
    });

    test('a wrong status or a bad envelope is an invalid response', () async {
      final responses = <FutureOr<ResponseBody> Function(RequestOptions)>[
        (_) => jsonResponse(201, submissionListJson([])),
        (_) => jsonResponse(200, {'data': <Object?>[]}),
        (_) =>
            jsonResponse(200, submissionListJson([submissionJson()], page: 2)),
        (_) => jsonResponse(
          200,
          submissionListJson([submissionJson(), submissionJson()], total: 2),
        ),
      ];

      for (final response in responses) {
        await expectLater(
          _source(
            RecordingAdapter(response),
          ).fetchSubmissions(const TeacherSubmissionListQuery.initial()),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    });
  });
}

TeacherSubmissionRemoteDataSource _source(RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return TeacherSubmissionRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

Map<String, Object?> _error(
  String code, [
  Map<String, List<String>> errors = const {},
]) => {'message': 'Failure.', 'code': code, 'errors': errors};

ResponseBody jsonResponse(int statusCode, Object? body) {
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
