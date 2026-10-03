import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_result_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_result_mutation.dart';

import 'teacher_topic_result_test_support.dart';

const _otherStudentId = '60000000-0000-0000-0000-000000000002';
const _resultPath =
    '/teacher/topics/$teacherResultTopicId/results/$teacherResultStudentId';
const _resultsPath = '/teacher/topics/$teacherResultTopicId/results';

void main() {
  group('single result actions', () {
    test('a comment is sent trimmed and its detail returned', () async {
      final adapter = _RecordingAdapter(
        (_) => _detailResponse(
          teacherTopicResultJson(teacherComment: 'Revise question 4.'),
        ),
      );

      final detail = await _repository(adapter).updateComment(
        teacherResultTopicId,
        teacherResultStudentId,
        '  Revise question 4.\n',
      );

      expect(detail.result.teacherComment, 'Revise question 4.');
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '$_resultPath/comment');
      expect(request.data, {'teacher_comment': 'Revise question 4.'});
      expect(request.queryParameters, isEmpty);
      expect(request.followRedirects, isFalse);
    });

    test('an empty comment is sent as null and removes it', () async {
      final adapter = _RecordingAdapter(
        (_) => _detailResponse(teacherTopicResultJson()),
      );

      final detail = await _repository(
        adapter,
      ).updateComment(teacherResultTopicId, teacherResultStudentId, '   ');

      expect(detail.result.teacherComment, isNull);
      expect(adapter.requests.single.data, {'teacher_comment': null});
    });

    test('releases post an empty object to the audience path', () async {
      for (final (audience, segment, visibility) in [
        (
          TeacherTopicResultAudience.student,
          'student',
          teacherResultVisibilityJson(
            studentVisible: true,
            studentReleasedAt: '2026-10-05T09:00:00Z',
            canReleaseToStudent: false,
          ),
        ),
        (
          TeacherTopicResultAudience.parent,
          'parent',
          teacherResultVisibilityJson(
            studentMode: 'automatic',
            studentVisible: true,
            canReleaseToStudent: false,
            parentMode: 'manual_teacher',
            parentVisible: true,
            parentReleasedAt: '2026-10-05T09:00:00Z',
          ),
        ),
      ]) {
        final adapter = _RecordingAdapter(
          (_) =>
              _detailResponse(teacherTopicResultJson(visibility: visibility)),
        );

        final detail = await _repository(
          adapter,
        ).release(teacherResultTopicId, teacherResultStudentId, audience);

        expect(detail.result.visibility.studentVisible, isTrue);
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '$_resultPath/release/$segment');
        expect(request.data, <String, Object?>{});
        expect(request.followRedirects, isFalse);
      }
    });

    test(
      'a close posts an empty object and returns the closed result',
      () async {
        final adapter = _RecordingAdapter(
          (_) => _detailResponse(
            closedCalculatedTeacherTopicResultJson(),
            closureReason: 'teacher',
          ),
        );

        final detail = await _repository(
          adapter,
        ).close(teacherResultTopicId, teacherResultStudentId);

        expect(detail.result.status, TeacherTopicResultStatus.closed);
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '$_resultPath/close');
        expect(request.data, <String, Object?>{});
      },
    );

    test(
      'an answer that contradicts the action is an unknown outcome',
      () async {
        final repository = _repository(
          _RecordingAdapter((options) {
            final path = options.path;
            if (path.endsWith('/comment')) {
              return _detailResponse(
                teacherTopicResultJson(teacherComment: 'Old'),
              );
            }
            if (path.endsWith('/close')) {
              return _detailResponse(teacherTopicResultJson());
            }
            if (path.endsWith('/release/parent')) {
              return _detailResponse(teacherTopicResultJson());
            }
            return _detailResponse(
              teacherTopicResultJson(studentId: _otherStudentId),
            );
          }),
        );

        for (final call in <Future<Object?> Function()>[
          () => repository.updateComment(
            teacherResultTopicId,
            teacherResultStudentId,
            'New',
          ),
          () => repository.close(teacherResultTopicId, teacherResultStudentId),
          () => repository.release(
            teacherResultTopicId,
            teacherResultStudentId,
            TeacherTopicResultAudience.parent,
          ),
          () => repository.release(
            teacherResultTopicId,
            teacherResultStudentId,
            TeacherTopicResultAudience.student,
          ),
        ]) {
          await expectLater(call(), _throwsUnknownOutcome);
        }
      },
    );
  });

  test(
    'a Student release answered without its release time is unknown',
    () async {
      final adapter = _RecordingAdapter(
        (_) => _detailResponse(teacherTopicResultJson()),
      );

      await expectLater(
        _repository(adapter).release(
          teacherResultTopicId,
          teacherResultStudentId,
          TeacherTopicResultAudience.student,
        ),
        _throwsUnknownOutcome,
      );
    },
  );

  test(
    'an answer for another Student is unknown even if it shows the effect',
    () async {
      final adapter = _RecordingAdapter(
        (_) => _detailResponse(
          teacherTopicResultJson(
            studentId: _otherStudentId,
            visibility: teacherResultVisibilityJson(
              studentVisible: true,
              studentReleasedAt: '2026-10-05T09:00:00Z',
              canReleaseToStudent: false,
            ),
          ),
        ),
      );

      await expectLater(
        _repository(adapter).release(
          teacherResultTopicId,
          teacherResultStudentId,
          TeacherTopicResultAudience.student,
        ),
        _throwsUnknownOutcome,
      );
    },
  );

  group('bulk result actions', () {
    test('post an empty object and return the counts', () async {
      for (final (call, path)
          in <
            (
              Future<TeacherTopicResultBulkOutcome> Function(
                TeacherTopicResultRepositoryImpl repository,
              ),
              String,
            )
          >[
            (
              (repository) => repository.releaseAll(
                teacherResultTopicId,
                TeacherTopicResultAudience.student,
              ),
              '$_resultsPath/release/student',
            ),
            (
              (repository) => repository.releaseAll(
                teacherResultTopicId,
                TeacherTopicResultAudience.parent,
              ),
              '$_resultsPath/release/parent',
            ),
            (
              (repository) => repository.closeAll(teacherResultTopicId),
              '$_resultsPath/close',
            ),
          ]) {
        final adapter = _RecordingAdapter((_) => _bulkResponse(21, 3, 6));

        final outcome = await call(_repository(adapter));

        expect(
          [outcome.processed, outcome.alreadyDone, outcome.notReady],
          [21, 3, 6],
        );
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, path);
        expect(request.data, <String, Object?>{});
        expect(request.followRedirects, isFalse);
      }
    });

    test('malformed counts are an unknown outcome', () async {
      for (final body in <Object?>[
        {
          'data': {
            'processed': 1,
            'skipped': {'already_done': 0},
          },
          'message': 'Topic results closed.',
        },
        {
          'data': {
            'processed': -1,
            'skipped': {'already_done': 0, 'not_ready': 0},
          },
          'message': 'Topic results closed.',
        },
        {
          'data': {
            'processed': 1.5,
            'skipped': {'already_done': 0, 'not_ready': 0},
          },
          'message': 'Topic results closed.',
        },
        {
          'data': {
            'processed': 1,
            'skipped': {'already_done': 0, 'not_ready': 0},
          },
        },
      ]) {
        final adapter = _RecordingAdapter((_) => _jsonResponse(200, body));

        await expectLater(
          _repository(adapter).closeAll(teacherResultTopicId),
          _throwsUnknownOutcome,
          reason: '$body',
        );
      }
    });
  });

  test('only the documented failures of each call are definite', () async {
    final calls =
        <String, Future<Object?> Function(TeacherTopicResultRepositoryImpl)>{
          'comment': (repository) => repository.updateComment(
            teacherResultTopicId,
            teacherResultStudentId,
            'Text',
          ),
          'release student': (repository) => repository.release(
            teacherResultTopicId,
            teacherResultStudentId,
            TeacherTopicResultAudience.student,
          ),
          'release parent': (repository) => repository.release(
            teacherResultTopicId,
            teacherResultStudentId,
            TeacherTopicResultAudience.parent,
          ),
          'close': (repository) =>
              repository.close(teacherResultTopicId, teacherResultStudentId),
          'release all': (repository) => repository.releaseAll(
            teacherResultTopicId,
            TeacherTopicResultAudience.student,
          ),
          'release all to parents': (repository) => repository.releaseAll(
            teacherResultTopicId,
            TeacherTopicResultAudience.parent,
          ),
          'close all': (repository) =>
              repository.closeAll(teacherResultTopicId),
        };
    final definiteConflicts = {
      'comment': {ApiErrorCodes.resultClosed},
      'release student': {
        ApiErrorCodes.manualReleaseNotAllowed,
        ApiErrorCodes.resultNotReady,
      },
      'release parent': {
        ApiErrorCodes.manualReleaseNotAllowed,
        ApiErrorCodes.studentResultNotReleased,
      },
      'close': {ApiErrorCodes.resultNotReadyForClosure},
      'release all': {ApiErrorCodes.manualReleaseNotAllowed},
      'release all to parents': {ApiErrorCodes.manualReleaseNotAllowed},
      'close all': <String>{},
    };
    const conflicts = [
      ApiErrorCodes.resultClosed,
      ApiErrorCodes.manualReleaseNotAllowed,
      ApiErrorCodes.resultNotReady,
      ApiErrorCodes.studentResultNotReleased,
      ApiErrorCodes.resultNotReadyForClosure,
      ApiErrorCodes.businessConflict,
    ];

    for (final MapEntry(key: name, value: call) in calls.entries) {
      for (final code in conflicts) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(409, _errorJson(code)),
        );
        final definite = definiteConflicts[name]!.contains(code);

        await expectLater(
          call(_repository(adapter)),
          definite
              ? throwsA(
                  isA<ApiRequestException>().having(
                    (error) => error.failure.serverCode,
                    'code',
                    code,
                  ),
                )
              : _throwsUnknownOutcome,
          reason: '$name $code',
        );
        expect(adapter.requests, hasLength(1), reason: '$name sends once');
      }
      for (final (status, code) in [
        (404, ApiErrorCodes.resourceNotFound),
        (429, ApiErrorCodes.rateLimited),
        (403, ApiErrorCodes.userInactive),
      ]) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(status, _errorJson(code)),
        );
        await expectLater(
          call(_repository(adapter)),
          throwsA(isA<ApiRequestException>()),
          reason: '$name $status',
        );
      }
      for (final failure in <FutureOr<ResponseBody> Function(RequestOptions)>[
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
        (_) => _jsonResponse(500, _errorJson(ApiErrorCodes.serverError)),
        (_) => _jsonResponse(201, {'data': null, 'message': 'Done.'}),
      ]) {
        await expectLater(
          call(_repository(_RecordingAdapter(failure))),
          _throwsUnknownOutcome,
          reason: name,
        );
      }
    }
  });

  test('a rejected comment body is a definite failure', () async {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(422, {
        ..._errorJson(ApiErrorCodes.validationFailed),
        'errors': {
          'teacher_comment': ['Too long.'],
        },
      }),
    );

    await expectLater(
      _repository(
        adapter,
      ).updateComment(teacherResultTopicId, teacherResultStudentId, 'Text'),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.failure.statusCode,
          'status',
          422,
        ),
      ),
    );
  });

  test('non-canonical ids never reach the server', () {
    final adapter = _RecordingAdapter((_) => throw StateError('No request.'));
    final source = _source(adapter);

    expect(
      () => source.updateComment('topic-1', teacherResultStudentId, null),
      throwsArgumentError,
    );
    expect(
      () => source.release(
        teacherResultTopicId,
        'student-1',
        TeacherTopicResultAudience.student,
      ),
      throwsArgumentError,
    );
    expect(
      () => source.close(teacherResultTopicId, ' $teacherResultStudentId'),
      throwsArgumentError,
    );
    expect(
      () => source.releaseAll('topic-1', TeacherTopicResultAudience.parent),
      throwsArgumentError,
    );
    expect(() => source.closeAll('topic-1'), throwsArgumentError);
    expect(adapter.requests, isEmpty);
  });
}

final _throwsUnknownOutcome = throwsA(
  isA<TeacherTopicResultMutationOutcomeUnknownException>(),
);

ResponseBody _detailResponse(
  Map<String, Object?> item, {
  String? closureReason,
}) {
  return _jsonResponse(200, {
    'data': teacherTopicResultDetailJson(
      item: item,
      closureReason: closureReason,
    ),
    'message': 'Topic result saved.',
  });
}

ResponseBody _bulkResponse(int processed, int alreadyDone, int notReady) {
  return _jsonResponse(200, {
    'data': {
      'processed': processed,
      'skipped': {'already_done': alreadyDone, 'not_ready': notReady},
    },
    'message': 'Topic results released to Students.',
  });
}

TeacherTopicResultRepositoryImpl _repository(_RecordingAdapter adapter) {
  return TeacherTopicResultRepositoryImpl(remoteDataSource: _source(adapter));
}

TeacherTopicResultRemoteDataSource _source(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.testlabuz.example/api/v1',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return TeacherTopicResultRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

Map<String, Object?> _errorJson(String code) {
  return {
    'message': 'Safe server error.',
    'code': code,
    'errors': <String, Object?>{},
    'request_id': 'req-result-action-1',
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
