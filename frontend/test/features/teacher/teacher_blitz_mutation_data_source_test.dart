import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_blitz_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_blitz_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_form.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_authoring.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

import 'teacher_blitz_json_fixtures.dart';

const _questionId = '90000000-0000-0000-0000-000000000001';

void main() {
  group('Blitz create and update transport', () {
    test(
      'Create sends the exact body once and parses the 201 envelope',
      () async {
        final adapter = _RecordingAdapter(
          (_) =>
              _jsonResponse(201, _envelope('Blitz task created successfully.')),
        );

        final created = await _source(
          adapter,
        ).createBlitz(blitzJsonTopicId, _createRequest());

        expect(created.blitz.id, blitzJsonId);
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/teacher/topics/$blitzJsonTopicId/blitz');
        expect(
          request.uri.path,
          '/api/v1/teacher/topics/$blitzJsonTopicId/blitz',
        );
        expect(request.queryParameters, isEmpty);
        expect(request.followRedirects, isFalse);
        expect(request.data, {
          'title': 'Topic Blitz',
          'description': null,
          'student_instructions': 'Answer quickly.',
          'assignment_mode': 'group',
          'student_ids': <String>[],
          'duration_seconds': 600,
          'scheduled_at': null,
          'questions': <Object?>[],
        });
      },
    );

    test(
      'Update sends only changed fields and parses the 200 envelope',
      () async {
        final adapter = _RecordingAdapter(
          (_) =>
              _jsonResponse(200, _envelope('Blitz task updated successfully.')),
        );

        await _source(adapter).updateBlitz(blitzJsonId, _editRequest());

        final request = adapter.requests.single;
        expect(request.method, 'PATCH');
        expect(request.path, '/teacher/blitz/$blitzJsonId');
        expect(request.queryParameters, isEmpty);
        expect(request.followRedirects, isFalse);
        expect(request.data, {
          'title': 'Renamed Blitz',
          'duration_seconds': 90,
        });
      },
    );

    test('rejects malformed targets and a no-op update before transport', () {
      final adapter = _RecordingAdapter((_) => _jsonResponse(200, null));
      final source = _source(adapter);
      final blitz = TeacherBlitzDto.fromJson(teacherBlitzJson()).toDomain();
      final noOp = TeacherBlitzEditRequest.fromForm(
        form: TeacherBlitzFormValue.fromBlitz(blitz),
        initial: TeacherBlitzEditSnapshot.fromBlitz(blitz),
      );

      expect(
        () => source.createBlitz('bad', _createRequest()),
        throwsArgumentError,
      );
      expect(
        () => source.updateBlitz('bad', _editRequest()),
        throwsArgumentError,
      );
      expect(() => source.updateBlitz(blitzJsonId, noOp), throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });

    test(
      'an unproven success is outcome-unknown and is never retried',
      () async {
        final cases = <ResponseBody Function()>[
          () =>
              _jsonResponse(200, _envelope('Blitz task created successfully.')),
          () =>
              _jsonResponse(201, _envelope('Blitz task updated successfully.')),
          () => _jsonResponse(201, {'data': teacherBlitzJson()}),
          () => _jsonResponse(201, {
            ..._envelope('Blitz task created successfully.'),
            'extra': true,
          }),
          () => _jsonResponse(201, {
            'data': teacherBlitzJson()..['status'] = 'running',
            'message': 'Blitz task created successfully.',
          }),
        ];
        for (final response in cases) {
          final adapter = _RecordingAdapter((_) => response());
          await expectLater(
            _source(adapter).createBlitz(blitzJsonTopicId, _createRequest()),
            throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test('only exact documented failures are definite', () async {
      final definite = <(bool, int, String, Map<String, Object?>)>[
        (true, 409, 'topic_not_editable', {}),
        (false, 409, 'topic_not_editable', {}),
        (false, 409, 'task_closed', {}),
        (false, 409, 'task_archived', {}),
        (false, 409, 'business_conflict', {}),
        (false, 409, 'official_task_requires_group_assignment', {}),
        (
          true,
          422,
          'validation_failed',
          {
            'student_ids': ['Invalid.'],
          },
        ),
        (false, 404, 'resource_not_found', {}),
        (true, 403, 'forbidden', {}),
        (true, 401, 'authentication_required', {}),
        (false, 429, 'rate_limited', {}),
      ];
      for (final (create, status, code, errors) in definite) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(status, _error(code, errors)),
        );
        final source = _source(adapter);
        await expectLater(
          create
              ? source.createBlitz(blitzJsonTopicId, _createRequest())
              : source.updateBlitz(blitzJsonId, _editRequest()),
          throwsA(
            isA<ApiRequestException>()
                .having((error) => error.failure.statusCode, 'status', status)
                .having((error) => error.failure.serverCode, 'code', code),
          ),
          reason: '$status $code',
        );
      }

      final unknown = <(bool, ResponseBody Function())>[
        (true, () => _jsonResponse(409, _error('task_closed', {}))),
        (true, () => _jsonResponse(409, _error('business_conflict', {}))),
        (false, () => _jsonResponse(409, _error('result_pair_locked', {}))),
        (
          false,
          () => _jsonResponse(
            409,
            _error('business_conflict', {
              'x': ['y'],
            }),
          ),
        ),
        (false, () => _jsonResponse(500, _error('server_error', {}))),
        (false, () => _jsonResponse(409, {'message': 'Conflict.'})),
      ];
      for (final (create, response) in unknown) {
        final adapter = _RecordingAdapter((_) => response());
        final source = _source(adapter);
        await expectLater(
          create
              ? source.createBlitz(blitzJsonTopicId, _createRequest())
              : source.updateBlitz(blitzJsonId, _editRequest()),
          throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
        );
      }

      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        final adapter = _RecordingAdapter((options) {
          throw DioException(requestOptions: options, type: type);
        });
        await expectLater(
          _source(adapter).updateBlitz(blitzJsonId, _editRequest()),
          throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
        );
        expect(adapter.requests, hasLength(1));
      }
    });
  });

  group('Blitz Question mutation transport', () {
    test(
      'uses the exact shared Question routes, statuses, and messages',
      () async {
        final adapter = _RecordingAdapter((options) {
          final (status, message) = switch ((options.method, options.path)) {
            ('POST', final path) when path.endsWith('/questions') => (
              201,
              'Question created successfully.',
            ),
            ('PATCH', _) => (200, 'Question updated successfully.'),
            ('DELETE', _) => (200, 'Question deleted successfully.'),
            ('POST', final path) when path.endsWith('/questions/reorder') => (
              200,
              'Questions reordered successfully.',
            ),
            _ => throw StateError('Unexpected Question request.'),
          };
          return _jsonResponse(status, _envelope(message));
        });
        final source = _source(adapter);

        final results = [
          await source.addQuestion(blitzJsonId, _questionCreateRequest()),
          await source.updateQuestion(_questionId, _questionEditRequest()),
          await source.deleteQuestion(_questionId),
          await source.reorderQuestions(blitzJsonId, _reorderRequest()),
        ];

        for (final result in results) {
          expect(result.blitz.id, blitzJsonId);
        }
        expect(
          adapter.requests.map(
            (request) => '${request.method} ${request.path}',
          ),
          [
            'POST /teacher/assessments/$blitzJsonId/questions',
            'PATCH /teacher/questions/$_questionId',
            'DELETE /teacher/questions/$_questionId',
            'POST /teacher/assessments/$blitzJsonId/questions/reorder',
          ],
        );
        expect(adapter.requests[0].data, _questionCreateRequest().toJson());
        expect(adapter.requests[1].data, {'prompt': 'Updated prompt.'});
        expect(adapter.requests[2].data, isNull);
        expect(adapter.requests[3].data, {
          'question_ids': [_questionId],
        });
        for (final request in adapter.requests) {
          expect(request.queryParameters, isEmpty);
          expect(request.followRedirects, isFalse);
        }
      },
    );

    test(
      'Blitz Question conflicts are definite; Homework-only codes are not',
      () async {
        for (final code in [
          'topic_not_editable',
          'task_closed',
          'task_archived',
          'business_conflict',
        ]) {
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(409, _error(code, {})),
          );
          await expectLater(
            _source(adapter).deleteQuestion(_questionId),
            throwsA(
              isA<ApiRequestException>().having(
                (error) => error.failure.serverCode,
                'code',
                code,
              ),
            ),
          );
        }
        for (final code in [
          'result_pair_locked',
          'assessment_has_no_scoreable_points',
          'official_task_requires_group_assignment',
        ]) {
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(409, _error(code, {})),
          );
          await expectLater(
            _source(adapter).deleteQuestion(_questionId),
            throwsA(
              isA<TeacherQuestionMutationOutcomeUnknownException>().having(
                (error) => error.operation,
                'operation',
                TeacherQuestionMutationOperation.delete,
              ),
            ),
          );
        }
      },
    );

    test(
      'an unproven Question success is outcome-unknown for its operation',
      () async {
        final adapter = _RecordingAdapter(
          (_) =>
              _jsonResponse(200, _envelope('Question updated successfully.')),
        );
        await expectLater(
          _source(adapter).addQuestion(blitzJsonId, _questionCreateRequest()),
          throwsA(
            isA<TeacherQuestionMutationOutcomeUnknownException>().having(
              (error) => error.operation,
              'operation',
              TeacherQuestionMutationOperation.add,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );

    test(
      'rejects malformed targets and a no-op Question edit before transport',
      () {
        final adapter = _RecordingAdapter((_) => _jsonResponse(200, null));
        final source = _source(adapter);
        final question = _question();
        final noOp = TeacherQuestionEditRequest.fromDraft(
          draft: TeacherQuestionDraft.fromQuestion(question),
          initial: TeacherQuestionEditSnapshot.fromQuestion(question),
        );

        expect(
          () => source.addQuestion('bad', _questionCreateRequest()),
          throwsArgumentError,
        );
        expect(
          () => source.updateQuestion(_questionId, noOp),
          throwsArgumentError,
        );
        expect(() => source.deleteQuestion('bad'), throwsArgumentError);
        expect(
          () => source.reorderQuestions('bad', _reorderRequest()),
          throwsArgumentError,
        );
        expect(adapter.requests, isEmpty);
      },
    );
  });

  group('TeacherBlitzRepositoryImpl mutations', () {
    test(
      'returns authoritative domain Blitz after confirmed mutations',
      () async {
        final adapter = _RecordingAdapter((options) {
          final message = switch (options.method) {
            'POST' when options.path.endsWith('/blitz') =>
              'Blitz task created successfully.',
            'PATCH' when options.path.startsWith('/teacher/blitz/') =>
              'Blitz task updated successfully.',
            _ => 'Question created successfully.',
          };
          final status = options.method == 'PATCH' ? 200 : 201;
          return _jsonResponse(status, _envelope(message));
        });
        final repository = _repository(adapter);

        final created = await repository.createBlitz(
          blitzJsonTopicId,
          _createRequest(),
        );
        final updated = await repository.updateBlitz(
          blitzJsonId,
          _editRequest(),
        );
        final added = await repository.addQuestion(
          blitzJsonId,
          _questionCreateRequest(),
        );

        expect(created, isA<TeacherBlitz>());
        expect(created.status, TeacherBlitzStatus.draft);
        expect(updated.id, blitzJsonId);
        expect(added.questions, hasLength(9));
      },
    );

    test('a returned resource for another target is outcome-unknown', () async {
      final otherTopic = _repository(
        _RecordingAdapter(
          (_) => _jsonResponse(201, {
            'data': teacherBlitzJson()
              ..['topic_id'] = '10000000-0000-0000-0000-000000000002',
            'message': 'Blitz task created successfully.',
          }),
        ),
      );
      await expectLater(
        otherTopic.createBlitz(blitzJsonTopicId, _createRequest()),
        throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
      );

      final otherBlitz = {
        'data': teacherBlitzJson()
          ..['id'] = '80000000-0000-0000-0000-000000000002',
      };
      await expectLater(
        _repository(
          _RecordingAdapter(
            (_) => _jsonResponse(200, {
              ...otherBlitz,
              'message': 'Blitz task updated successfully.',
            }),
          ),
        ).updateBlitz(blitzJsonId, _editRequest()),
        throwsA(isA<TeacherBlitzMutationOutcomeUnknownException>()),
      );
      await expectLater(
        _repository(
          _RecordingAdapter(
            (_) => _jsonResponse(201, {
              ...otherBlitz,
              'message': 'Question created successfully.',
            }),
          ),
        ).addQuestion(blitzJsonId, _questionCreateRequest()),
        throwsA(isA<TeacherQuestionMutationOutcomeUnknownException>()),
      );
      await expectLater(
        _repository(
          _RecordingAdapter(
            (_) => _jsonResponse(200, {
              ...otherBlitz,
              'message': 'Questions reordered successfully.',
            }),
          ),
        ).reorderQuestions(blitzJsonId, _reorderRequest()),
        throwsA(isA<TeacherQuestionMutationOutcomeUnknownException>()),
      );
    });
  });
}

Map<String, Object?> _envelope(String message) {
  return {'data': teacherBlitzJson(), 'message': message};
}

Map<String, Object?> _error(String code, Map<String, Object?> errors) {
  return {
    'message': 'Server says no.',
    'code': code,
    'errors': errors,
    'request_id': 'req-1',
  };
}

TeacherBlitzCreateRequest _createRequest() {
  return TeacherBlitzCreateRequest.fromForm(
    TeacherBlitzFormValue(
      title: 'Topic Blitz',
      studentInstructions: 'Answer quickly.',
      durationSecondsText: '600',
    ),
  );
}

TeacherBlitzEditRequest _editRequest() {
  final blitz = TeacherBlitzDto.fromJson(teacherBlitzJson()).toDomain();
  return TeacherBlitzEditRequest.fromForm(
    form: TeacherBlitzFormValue.fromBlitz(
      blitz,
    ).copyWith(title: 'Renamed Blitz', durationSecondsText: '90'),
    initial: TeacherBlitzEditSnapshot.fromBlitz(blitz),
  );
}

TeacherQuestionCreateRequest _questionCreateRequest() {
  return TeacherQuestionCreateRequest.fromDraft(
    draft: const TeacherQuestionDraft(
      type: TeacherQuestionType.trueFalse,
      prompt: 'Original prompt.',
      instructions: '',
      pointsText: '1.5',
      checkingMode: TeacherQuestionCheckingMode.automatic,
      configurationDraft: TeacherTrueFalseConfigurationDraft(
        correctValue: true,
      ),
    ),
    position: 10,
  );
}

TeacherQuestionEditRequest _questionEditRequest() {
  final question = _question();
  return TeacherQuestionEditRequest.fromDraft(
    draft: TeacherQuestionDraft.fromQuestion(
      question,
    ).copyWith(prompt: 'Updated prompt.'),
    initial: TeacherQuestionEditSnapshot.fromQuestion(question),
  );
}

TeacherQuestionReorderRequest _reorderRequest() {
  return TeacherQuestionReorderRequest(questionIds: const [_questionId]);
}

TeacherQuestion _question() {
  return const TeacherQuestion(
    id: _questionId,
    type: TeacherQuestionType.trueFalse,
    prompt: 'Original prompt.',
    instructions: null,
    points: 1.5,
    position: 1,
    checkingMode: TeacherQuestionCheckingMode.automatic,
    configuration: TeacherTrueFalseQuestionConfiguration(correctValue: true),
  );
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
