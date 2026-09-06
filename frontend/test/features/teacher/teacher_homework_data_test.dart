import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_homework_dto.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_homework_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_form.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_list_query.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_homework_mutation.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_authoring.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_question_mutation.dart';

const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '20000000-0000-0000-0000-000000000001';
const _questionId = '70000000-0000-0000-0000-000000000001';

void main() {
  group('TeacherHomeworkRemoteDataSource', () {
    test('uses exact create and update mutation requests', () async {
      final adapter = _RecordingAdapter((options) {
        return switch (options.method) {
          'POST' => _jsonResponse(201, {
            'data': _homeworkJson(),
            'message': 'Homework created successfully.',
          }),
          'PATCH' => _jsonResponse(200, {
            'data': _homeworkJson()..['title'] = 'Updated Homework',
            'message': 'Homework updated successfully.',
          }),
          _ => throw StateError('Unexpected request method.'),
        };
      });
      final source = _source(adapter);

      final created = await source.createHomework(_topicId, _createRequest());
      final updated = await source.updateHomework(
        _homeworkId,
        _editTitleRequest(),
      );

      expect(created.homework.id, _homeworkId);
      expect(updated.homework.title, 'Updated Homework');
      final create = adapter.requests[0];
      expect(create.method, 'POST');
      expect(create.path, '/teacher/topics/$_topicId/homework');
      expect(create.uri.path, '/api/v1/teacher/topics/$_topicId/homework');
      expect(create.queryParameters, isEmpty);
      expect(create.data, _createRequest().toJson());
      expect(create.followRedirects, isFalse);
      final update = adapter.requests[1];
      expect(update.method, 'PATCH');
      expect(update.path, '/teacher/homework/$_homeworkId');
      expect(update.uri.path, '/api/v1/teacher/homework/$_homeworkId');
      expect(update.queryParameters, isEmpty);
      expect(update.data, {'title': 'Updated Homework'});
      expect(update.followRedirects, isFalse);
    });

    test('uses exact Question mutation paths, bodies, and messages', () async {
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
          _ => throw StateError('Unexpected Question mutation request.'),
        };
        return _jsonResponse(status, {
          'data': _homeworkJson()..['questions'] = [_questionJson()],
          'message': message,
        });
      });
      final source = _source(adapter);
      final createRequest = _questionCreateRequest();
      final editRequest = _questionEditRequest();
      final reorderRequest = _questionReorderRequest();

      final added = await source.addQuestion(_homeworkId, createRequest);
      final updated = await source.updateQuestion(_questionId, editRequest);
      final deleted = await source.deleteQuestion(_questionId);
      final reordered = await source.reorderQuestions(
        _homeworkId,
        reorderRequest,
      );

      for (final mutation in [added, updated, deleted, reordered]) {
        expect(mutation.homework.id, _homeworkId);
        expect(mutation.homework.questions.single.id, _questionId);
      }

      final add = adapter.requests[0];
      expect(add.method, 'POST');
      expect(add.path, '/teacher/assessments/$_homeworkId/questions');
      expect(
        add.uri.path,
        '/api/v1/teacher/assessments/$_homeworkId/questions',
      );
      expect(add.data, createRequest.toJson());

      final update = adapter.requests[1];
      expect(update.method, 'PATCH');
      expect(update.path, '/teacher/questions/$_questionId');
      expect(update.uri.path, '/api/v1/teacher/questions/$_questionId');
      expect(update.data, {'prompt': 'Updated prompt.'});

      final delete = adapter.requests[2];
      expect(delete.method, 'DELETE');
      expect(delete.path, '/teacher/questions/$_questionId');
      expect(delete.uri.path, '/api/v1/teacher/questions/$_questionId');
      expect(delete.data, isNull);

      final reorder = adapter.requests[3];
      expect(reorder.method, 'POST');
      expect(
        reorder.path,
        '/teacher/assessments/$_homeworkId/questions/reorder',
      );
      expect(
        reorder.uri.path,
        '/api/v1/teacher/assessments/$_homeworkId/questions/reorder',
      );
      expect(reorder.data, reorderRequest.toJson());

      for (final request in adapter.requests) {
        expect(request.queryParameters, isEmpty);
        expect(request.followRedirects, isFalse);
      }
    });

    test('uses exact bodyless list GET and approved query', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(
          200,
          _listJson([_summaryJson()], page: 3, total: 41, lastPage: 3),
        ),
      );
      final source = _source(adapter);
      final query = const TeacherHomeworkListQuery.initial()
          .withSearch('  Algebra % _  ')
          .withStatus(TeacherHomeworkStatus.archived)
          .withAssignmentMode(TeacherHomeworkAssignmentMode.selectedStudents)
          .withPage(3);

      await source.fetchHomeworkList(_topicId, query);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/topics/$_topicId/homework');
      expect(request.uri.path, '/api/v1/teacher/topics/$_topicId/homework');
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
      expect(request.queryParameters, {
        'page': 3,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
        'search': 'Algebra % _',
        'status': 'archived',
        'assignment_mode': 'selected_students',
      });
    });

    test('omits optional list filters and sends fixed sort', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _listJson(const [], total: 0)),
      );

      await _source(
        adapter,
      ).fetchHomeworkList(_topicId, const TeacherHomeworkListQuery.initial());

      expect(adapter.requests.single.queryParameters, {
        'page': 1,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
      });
    });

    test('uses exact bodyless detail GET without query', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {'data': _homeworkJson()}),
      );

      final dto = await _source(adapter).fetchHomework(_homeworkId);

      expect(dto.homework.id, _homeworkId);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/teacher/homework/$_homeworkId');
      expect(request.uri.path, '/api/v1/teacher/homework/$_homeworkId');
      expect(request.queryParameters, isEmpty);
      expect(request.data, isNull);
      expect(request.followRedirects, isFalse);
    });

    test(
      'requires 200 and maps malformed success to invalid response',
      () async {
        for (final response in [
          _jsonResponse(201, _listJson([_summaryJson()])),
          _jsonResponse(200, {'data': _homeworkJson(), 'extra': true}),
          _jsonResponse(200, {'data': _homeworkJson()..['points'] = '1'}),
        ]) {
          final source = _source(_RecordingAdapter((_) => response));
          final operation = response.statusCode == 201
              ? source.fetchHomeworkList(
                  _topicId,
                  const TeacherHomeworkListQuery.initial(),
                )
              : source.fetchHomework(_homeworkId);

          await expectLater(
            operation,
            throwsA(_failureKind(ApiFailureKind.invalidResponse)),
          );
        }
      },
    );

    test('maps Dio read failures through the shared failure mapper', () async {
      final adapter = _RecordingAdapter((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      await expectLater(
        _source(adapter).fetchHomework(_homeworkId),
        throwsA(_failureKind(ApiFailureKind.connection)),
      );
    });

    test('maps only exact recognized mutation failures as definite', () async {
      final common = <(int, String)>[
        (401, 'authentication_required'),
        (403, 'forbidden'),
        (403, 'password_change_required'),
        (403, 'user_inactive'),
        (403, 'institution_inactive'),
        (404, 'resource_not_found'),
        (422, 'validation_failed'),
        (429, 'rate_limited'),
      ];
      final cases = <({bool create, int status, String code})>[
        for (final pair in common)
          (create: true, status: pair.$1, code: pair.$2),
        (create: true, status: 409, code: 'topic_not_editable'),
        for (final pair in common)
          (create: false, status: pair.$1, code: pair.$2),
        (create: false, status: 409, code: 'topic_not_editable'),
        (create: false, status: 409, code: 'task_closed'),
        (create: false, status: 409, code: 'task_archived'),
        (create: false, status: 409, code: 'business_conflict'),
        (
          create: false,
          status: 409,
          code: 'official_task_requires_group_assignment',
        ),
      ];

      for (final mutationCase in cases) {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(mutationCase.status, {
            'message': 'Safe server error.',
            'code': mutationCase.code,
            'errors': mutationCase.status == 422
                ? {
                    'title': ['The title is invalid.'],
                  }
                : <String, Object?>{},
            'request_id': 'request-1',
          }),
        );
        final source = _source(adapter);
        final operation = mutationCase.create
            ? source.createHomework(_topicId, _createRequest())
            : source.updateHomework(_homeworkId, _editTitleRequest());

        await expectLater(
          operation,
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.serverCode,
              'serverCode',
              mutationCase.code,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    });

    test('maps exact documented Question failures as definite', () async {
      final cases = <(int, String)>[
        (401, 'authentication_required'),
        (403, 'forbidden'),
        (403, 'password_change_required'),
        (403, 'user_inactive'),
        (403, 'institution_inactive'),
        (404, 'resource_not_found'),
        (409, 'topic_not_editable'),
        (409, 'task_closed'),
        (409, 'task_archived'),
        (409, 'business_conflict'),
        (409, 'result_pair_locked'),
        (409, 'assessment_has_no_scoreable_points'),
        (422, 'validation_failed'),
        (429, 'rate_limited'),
      ];

      for (final operation in TeacherQuestionMutationOperation.values) {
        for (final (status, code) in cases) {
          final adapter = _RecordingAdapter(
            (_) => _jsonResponse(status, {
              'message': 'Safe server error.',
              'code': code,
              'errors': status == 422
                  ? {
                      'prompt': ['The prompt is invalid.'],
                    }
                  : <String, Object?>{},
              'request_id': 'request-1',
            }),
          );

          await expectLater(
            _performQuestionMutation(_source(adapter), operation),
            throwsA(
              isA<ApiRequestException>().having(
                (error) => error.failure.serverCode,
                'serverCode',
                code,
              ),
            ),
          );
          expect(adapter.requests, hasLength(1));
        }
      }
    });

    test(
      'preserves Question operation identity for ambiguous failures',
      () async {
        for (final operation in TeacherQuestionMutationOperation.values) {
          final adapter = _RecordingAdapter((options) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          });

          await expectLater(
            _performQuestionMutation(_source(adapter), operation),
            throwsA(
              isA<TeacherQuestionMutationOutcomeUnknownException>().having(
                (error) => error.operation,
                'operation',
                operation,
              ),
            ),
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test(
      'malformed success, network ambiguity, and unknown errors stay unknown',
      () async {
        final handlers = <FutureOr<ResponseBody> Function(RequestOptions)>[
          (_) => _jsonResponse(201, {'data': _homeworkJson()}),
          (_) => _jsonResponse(201, {
            'data': _homeworkJson(),
            'message': 'Unexpected message.',
          }),
          (_) => _jsonResponse(201, {
            'data': _homeworkJson(),
            'message': 'Homework created successfully.',
            'extra': true,
          }),
          (_) => _jsonResponse(200, {
            'data': _homeworkJson(),
            'message': 'Homework created successfully.',
          }),
          (_) => _jsonResponse(201, {
            'data': _homeworkJson()..remove('status'),
            'message': 'Homework created successfully.',
          }),
          (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
          (_) => _jsonResponse(409, {
            'message': 'Unknown conflict.',
            'code': 'future_conflict',
            'errors': <String, Object?>{},
          }),
          (_) => _jsonResponse(409, {
            'message': 'Known code but invalid errors.',
            'code': 'topic_not_editable',
            'errors': {
              'field': ['Must be empty for non-validation errors.'],
            },
          }),
        ];

        for (final handler in handlers) {
          final adapter = _RecordingAdapter(handler);
          await expectLater(
            _source(adapter).createHomework(_topicId, _createRequest()),
            throwsA(isA<TeacherHomeworkMutationOutcomeUnknownException>()),
          );
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test(
      'Question malformed success, ambiguity, and unknown errors stay unknown',
      () async {
        final handlers = <FutureOr<ResponseBody> Function(RequestOptions)>[
          (_) => _jsonResponse(200, {'data': _homeworkJson()}),
          (_) => _jsonResponse(200, {
            'data': _homeworkJson(),
            'message': 'Unexpected message.',
          }),
          (_) => _jsonResponse(200, {
            'data': _homeworkJson(),
            'message': 'Question deleted successfully.',
            'extra': true,
          }),
          (_) => _jsonResponse(201, {
            'data': _homeworkJson(),
            'message': 'Question deleted successfully.',
          }),
          (_) => _jsonResponse(200, {
            'data': _homeworkJson()..remove('status'),
            'message': 'Question deleted successfully.',
          }),
          (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
          (_) => _jsonResponse(409, {
            'message': 'Unknown conflict.',
            'code': 'future_conflict',
            'errors': <String, Object?>{},
          }),
          (_) => _jsonResponse(409, {
            'message': 'Known code but invalid errors.',
            'code': 'result_pair_locked',
            'errors': {
              'field': ['Must be empty for non-validation errors.'],
            },
          }),
        ];

        for (final handler in handlers) {
          final adapter = _RecordingAdapter(handler);
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
          expect(adapter.requests, hasLength(1));
        }
      },
    );

    test('unexpected update success message stays outcome unknown', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': _homeworkJson()..['title'] = 'Updated Homework',
          'message': 'Unexpected update message.',
        }),
      );

      await expectLater(
        _source(adapter).updateHomework(_homeworkId, _editTitleRequest()),
        throwsA(isA<TeacherHomeworkMutationOutcomeUnknownException>()),
      );
      expect(adapter.requests, hasLength(1));
    });

    test(
      'rejects malformed mutation targets and empty PATCH before transport',
      () {
        final adapter = _RecordingAdapter(
          (_) => _jsonResponse(201, {
            'data': _homeworkJson(),
            'message': 'Homework created successfully.',
          }),
        );
        final source = _source(adapter);

        expect(
          () => source.createHomework('invalid', _createRequest()),
          throwsArgumentError,
        );
        expect(
          () => source.updateHomework('invalid', _editTitleRequest()),
          throwsArgumentError,
        );
        expect(
          () => source.updateHomework(
            _homeworkId,
            TeacherHomeworkEditRequest.empty(),
          ),
          throwsArgumentError,
        );
        expect(
          () => source.addQuestion('invalid', _questionCreateRequest()),
          throwsArgumentError,
        );
        expect(
          () => source.updateQuestion('invalid', _questionEditRequest()),
          throwsArgumentError,
        );
        expect(
          () => source.updateQuestion(_questionId, _emptyQuestionEditRequest()),
          throwsArgumentError,
        );
        expect(() => source.deleteQuestion('invalid'), throwsArgumentError);
        expect(
          () => source.reorderQuestions('invalid', _questionReorderRequest()),
          throwsArgumentError,
        );
        expect(adapter.requests, isEmpty);
      },
    );

    test('rejects malformed target IDs before transport', () {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, _listJson(const [], total: 0)),
      );
      final source = _source(adapter);

      expect(
        () => source.fetchHomeworkList(
          'invalid',
          const TeacherHomeworkListQuery.initial(),
        ),
        throwsArgumentError,
      );
      expect(() => source.fetchHomework('invalid'), throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });
  });

  group('TeacherHomeworkRepositoryImpl', () {
    test('converts strict list and detail DTOs to domain', () async {
      final adapter = _RecordingAdapter((options) {
        if (options.path.contains('/topics/')) {
          return _jsonResponse(200, _listJson([_summaryJson()]));
        }
        return _jsonResponse(200, {'data': _homeworkJson()});
      });
      final repository = TeacherHomeworkRepositoryImpl(
        remoteDataSource: _source(adapter),
      );

      final list = await repository.fetchHomeworkList(
        _topicId,
        const TeacherHomeworkListQuery.initial(),
      );
      final homework = await repository.fetchHomework(_homeworkId);

      expect(list.items.single.title, 'Homework');
      expect(list.pagination.total, 1);
      expect(homework.id, _homeworkId);
      expect(homework.questions, isEmpty);
    });

    test('rejects a detail identity that differs from request', () async {
      final adapter = _RecordingAdapter(
        (_) => _jsonResponse(200, {
          'data': _homeworkJson()
            ..['id'] = '20000000-0000-0000-0000-000000000002',
        }),
      );
      final repository = TeacherHomeworkRepositoryImpl(
        remoteDataSource: _source(adapter),
      );

      await expectLater(
        repository.fetchHomework(_homeworkId),
        throwsA(_failureKind(ApiFailureKind.invalidResponse)),
      );
    });

    test(
      'returns confirmed mutations and rejects mismatched authority',
      () async {
        late bool returnWrongTopic;
        returnWrongTopic = false;
        final adapter = _RecordingAdapter((options) {
          final homework = _homeworkJson();
          if (options.method == 'PATCH') {
            homework['title'] = 'Updated Homework';
          }
          if (returnWrongTopic) {
            homework['topic_id'] = '10000000-0000-0000-0000-000000000002';
          }
          return _jsonResponse(options.method == 'POST' ? 201 : 200, {
            'data': homework,
            'message': options.method == 'POST'
                ? 'Homework created successfully.'
                : 'Homework updated successfully.',
          });
        });
        final repository = TeacherHomeworkRepositoryImpl(
          remoteDataSource: _source(adapter),
        );

        expect(
          (await repository.createHomework(_topicId, _createRequest())).id,
          _homeworkId,
        );
        expect(
          (await repository.updateHomework(
            _homeworkId,
            _editTitleRequest(),
          )).title,
          'Updated Homework',
        );

        returnWrongTopic = true;
        await expectLater(
          repository.createHomework(_topicId, _createRequest()),
          throwsA(isA<TeacherHomeworkMutationOutcomeUnknownException>()),
        );
      },
    );

    test(
      'accepts authoritative update success when intended fields differ',
      () async {
        final repository = TeacherHomeworkRepositoryImpl(
          remoteDataSource: _source(
            _RecordingAdapter(
              (_) => _jsonResponse(200, {
                'data': _homeworkJson(),
                'message': 'Homework updated successfully.',
              }),
            ),
          ),
        );

        final updated = await repository.updateHomework(
          _homeworkId,
          _editTitleRequest(),
        );

        expect(updated.id, _homeworkId);
        expect(updated.title, 'Homework');
      },
    );

    test(
      'returns Question mutations and rejects mismatched add/reorder targets',
      () async {
        var returnedHomeworkId = _homeworkId;
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
            _ => throw StateError('Unexpected Question mutation request.'),
          };
          return _jsonResponse(status, {
            'data': _homeworkJson()..['id'] = returnedHomeworkId,
            'message': message,
          });
        });
        final repository = TeacherHomeworkRepositoryImpl(
          remoteDataSource: _source(adapter),
        );

        expect(
          (await repository.addQuestion(
            _homeworkId,
            _questionCreateRequest(),
          )).id,
          _homeworkId,
        );
        expect(
          (await repository.updateQuestion(
            _questionId,
            _questionEditRequest(),
          )).id,
          _homeworkId,
        );
        expect((await repository.deleteQuestion(_questionId)).id, _homeworkId);
        expect(
          (await repository.reorderQuestions(
            _homeworkId,
            _questionReorderRequest(),
          )).id,
          _homeworkId,
        );

        returnedHomeworkId = '20000000-0000-0000-0000-000000000002';
        await expectLater(
          repository.addQuestion(_homeworkId, _questionCreateRequest()),
          throwsA(
            isA<TeacherQuestionMutationOutcomeUnknownException>().having(
              (error) => error.operation,
              'operation',
              TeacherQuestionMutationOperation.add,
            ),
          ),
        );
        await expectLater(
          repository.reorderQuestions(_homeworkId, _questionReorderRequest()),
          throwsA(
            isA<TeacherQuestionMutationOutcomeUnknownException>().having(
              (error) => error.operation,
              'operation',
              TeacherQuestionMutationOperation.reorder,
            ),
          ),
        );
      },
    );
  });
}

TeacherHomeworkCreateRequest _createRequest() {
  return TeacherHomeworkCreateRequest.fromForm(
    TeacherHomeworkFormValue(
      title: 'Homework',
      studentInstructions: 'Complete the Homework.',
    ),
    'Asia/Tashkent',
  );
}

TeacherHomeworkEditRequest _editTitleRequest() {
  final homework = TeacherHomeworkDto.fromJson(_homeworkJson()).toDomain();
  return TeacherHomeworkEditRequest.fromForm(
    form: TeacherHomeworkFormValue.fromHomework(
      homework,
      'Asia/Tashkent',
    ).copyWith(title: 'Updated Homework'),
    initial: TeacherHomeworkEditSnapshot.fromHomework(homework),
    institutionTimezone: 'Asia/Tashkent',
  );
}

TeacherQuestionCreateRequest _questionCreateRequest() {
  return TeacherQuestionCreateRequest.fromDraft(
    draft: _questionDraft(),
    position: 1,
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

TeacherQuestionEditRequest _emptyQuestionEditRequest() {
  final question = _question();
  return TeacherQuestionEditRequest.fromDraft(
    draft: TeacherQuestionDraft.fromQuestion(question),
    initial: TeacherQuestionEditSnapshot.fromQuestion(question),
  );
}

TeacherQuestionReorderRequest _questionReorderRequest() {
  return TeacherQuestionReorderRequest(questionIds: const [_questionId]);
}

Future<Object?> _performQuestionMutation(
  TeacherHomeworkRemoteDataSource source,
  TeacherQuestionMutationOperation operation,
) {
  return switch (operation) {
    TeacherQuestionMutationOperation.add => source.addQuestion(
      _homeworkId,
      _questionCreateRequest(),
    ),
    TeacherQuestionMutationOperation.update => source.updateQuestion(
      _questionId,
      _questionEditRequest(),
    ),
    TeacherQuestionMutationOperation.delete => source.deleteQuestion(
      _questionId,
    ),
    TeacherQuestionMutationOperation.reorder => source.reorderQuestions(
      _homeworkId,
      _questionReorderRequest(),
    ),
  };
}

TeacherQuestionDraft _questionDraft() {
  return const TeacherQuestionDraft(
    type: TeacherQuestionType.trueFalse,
    prompt: 'Original prompt.',
    instructions: '',
    pointsText: '1.5',
    checkingMode: TeacherQuestionCheckingMode.automatic,
    configurationDraft: TeacherTrueFalseConfigurationDraft(correctValue: true),
  );
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

TeacherHomeworkRemoteDataSource _source(_RecordingAdapter adapter) {
  return TeacherHomeworkRemoteDataSource(
    dio: _dio(adapter),
    failureMapper: const DioFailureMapper(),
  );
}

Matcher _failureKind(ApiFailureKind kind) {
  return isA<ApiRequestException>().having(
    (error) => error.failure.kind,
    'kind',
    kind,
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

Map<String, Object?> _summaryJson() {
  return {
    'id': _homeworkId,
    'topic_id': _topicId,
    'title': 'Homework',
    'assignment_mode': 'group',
    'total_possible_points': 0,
    'question_count': 0,
    'deadline_at': null,
    'institution_timezone': 'Asia/Tashkent',
    'status': 'draft',
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
  };
}

Map<String, Object?> _homeworkJson() {
  return {
    'id': _homeworkId,
    'topic_id': _topicId,
    'title': 'Homework',
    'description': null,
    'student_instructions': 'Complete the Homework.',
    'assignment_mode': 'group',
    'student_ids': <Object?>[],
    'total_possible_points': 0,
    'deadline_at': null,
    'institution_timezone': 'Asia/Tashkent',
    'status': 'draft',
    'attempt_policy': {
      'normal_attempts': 3,
      'official_score_policy': 'highest_valid_completed',
    },
    'activated_at': null,
    'closed_at': null,
    'archived_at': null,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
    'questions': <Object?>[],
  };
}

Map<String, Object?> _questionJson() {
  return {
    'id': _questionId,
    'type': 'true_false',
    'prompt': 'Original prompt.',
    'instructions': null,
    'points': 1.5,
    'position': 1,
    'checking_mode': 'automatic',
    'configuration': {'correct_value': true},
  };
}

Map<String, Object?> _listJson(
  List<Object?> rows, {
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) {
  return {
    'data': rows,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': 20,
        'total': total,
        'last_page': lastPage,
      },
    },
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
