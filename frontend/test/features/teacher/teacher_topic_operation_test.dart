import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_remote_data_source.dart';
import 'package:testlabuz_client/features/teacher/data/teacher_topic_repository_impl.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_topic_mutation.dart';

import 'teacher_test_support.dart';

void main() {
  group('Teacher Topic form requests', () {
    test('create validates and serializes the exact normalized payload', () {
      final form = TeacherTopicFormValue(
        selectedGroup: teacherGroup(),
        title: '  Internet Basics  ',
        description: '   ',
        subject: '  Informatics ',
        studentInstructions: '  Study the materials. ',
        lessonAt: const InstitutionWallClock(
          year: 2026,
          month: 8,
          day: 25,
          hour: 9,
          minute: 0,
        ),
      );

      expect(
        form.validate(requireGroup: true, institutionTimezone: 'Asia/Tashkent'),
        isEmpty,
      );
      expect(
        TeacherTopicCreateRequest.fromForm(form, 'Asia/Tashkent').toJson(),
        {
          'group_id': '00000000-0000-0000-0000-000000000001',
          'title': 'Internet Basics',
          'description': null,
          'subject': 'Informatics',
          'student_instructions': 'Study the materials.',
          'lesson_at': '2026-08-25T09:00:00+05:00',
        },
      );
    });

    test(
      'title/subject limits and required instructions count code points',
      () {
        final form = TeacherTopicFormValue(
          selectedGroup: teacherGroup(),
          title: List.filled(256, '😀').join(),
          subject: List.filled(161, '😀').join(),
          studentInstructions: '   ',
        );
        final errors = form.validate(
          requireGroup: true,
          institutionTimezone: 'Asia/Tashkent',
        );

        expect(errors, contains(TeacherTopicFormField.title));
        expect(errors, contains(TeacherTopicFormField.subject));
        expect(errors, contains(TeacherTopicFormField.studentInstructions));
      },
    );

    test('edit sends only changed fields and explicit null clears', () {
      final topic = teacherTopic(description: 'Original description');
      final initial = TeacherTopicEditSnapshot.fromTopic(
        topic,
        'Asia/Tashkent',
      );
      final unchanged = TeacherTopicEditRequest.fromForm(
        form: TeacherTopicFormValue.fromTopic(topic, 'Asia/Tashkent'),
        initial: initial,
        institutionTimezone: 'Asia/Tashkent',
      );
      final cleared = TeacherTopicEditRequest.fromForm(
        form: TeacherTopicFormValue.fromTopic(
          topic,
          'Asia/Tashkent',
        ).copyWith(description: '   ', lessonAt: null),
        initial: initial,
        institutionTimezone: 'Asia/Tashkent',
      );

      expect(unchanged.isEmpty, isTrue);
      expect(cleared.toJson(), {'description': null, 'lesson_at': null});
      expect(cleared.toJson(), isNot(contains('group_id')));
    });
  });

  group('TeacherTopicRemoteDataSource', () {
    test('uses exact create/detail/update operations and payloads', () async {
      late _RecordingAdapter adapter;
      adapter = _RecordingAdapter((options) {
        return switch (options.method) {
          'POST' => _jsonResponse(201, {
            'data': _topicJson(TeacherTopicStatus.draft),
            'message': 'Topic created successfully.',
          }),
          'GET' => _jsonResponse(200, {
            'data': _topicJson(TeacherTopicStatus.draft),
          }),
          'PATCH' => _jsonResponse(200, {
            'data': _topicJson(TeacherTopicStatus.draft)..['title'] = 'Updated',
            'message': 'Topic updated successfully.',
          }),
          _ => throw StateError('Unexpected method.'),
        };
      });
      final source = TeacherTopicRemoteDataSource(
        dio: _dio(adapter),
        failureMapper: const DioFailureMapper(),
      );
      final create = TeacherTopicCreateRequest.fromForm(
        TeacherTopicFormValue(
          selectedGroup: teacherGroup(),
          title: 'Linear equations',
          subject: 'Algebra',
          studentInstructions: 'Read the examples.',
          lessonAt: const InstitutionWallClock(
            year: 2026,
            month: 8,
            day: 25,
            hour: 13,
            minute: 0,
          ),
        ),
        'Asia/Tashkent',
      );
      final topic = teacherTopic();
      final initial = TeacherTopicEditSnapshot.fromTopic(
        topic,
        'Asia/Tashkent',
      );
      final edit = TeacherTopicEditRequest.fromForm(
        form: TeacherTopicFormValue.fromTopic(
          topic,
          'Asia/Tashkent',
        ).copyWith(title: ' Updated '),
        initial: initial,
        institutionTimezone: 'Asia/Tashkent',
      );

      await source.createTopic(create);
      await source.fetchTopic(topic.id);
      await source.updateTopic(topic.id, edit);

      expect(adapter.requests[0].path, '/teacher/topics');
      expect(adapter.requests[0].queryParameters, isEmpty);
      expect(adapter.requests[0].data, create.toJson());
      expect(adapter.requests[1].method, 'GET');
      expect(adapter.requests[1].path, '/teacher/topics/${topic.id}');
      expect(adapter.requests[1].data, isNull);
      expect(adapter.requests[1].queryParameters, isEmpty);
      expect(adapter.requests[2].method, 'PATCH');
      expect(adapter.requests[2].data, {'title': 'Updated'});
      expect(adapter.requests[2].queryParameters, isEmpty);
    });

    test('lifecycle endpoints have no body or query', () async {
      final adapter = _RecordingAdapter((options) {
        final action = TeacherTopicLifecycleAction.values.singleWhere(
          (value) => options.path.endsWith('/${value.segment}'),
        );
        return _jsonResponse(200, {
          'data': _topicJson(action.expectedStatus),
          'message': action.successMessage,
        });
      });
      final source = TeacherTopicRemoteDataSource(
        dio: _dio(adapter),
        failureMapper: const DioFailureMapper(),
      );
      const topicId = '10000000-0000-0000-0000-000000000001';

      for (final action in TeacherTopicLifecycleAction.values) {
        await source.performLifecycleAction(topicId, action);
      }

      for (var index = 0; index < adapter.requests.length; index += 1) {
        final action = TeacherTopicLifecycleAction.values[index];
        final request = adapter.requests[index];
        expect(request.method, 'POST');
        expect(request.path, '/teacher/topics/$topicId/${action.segment}');
        expect(request.data, isNull);
        expect(request.queryParameters, isEmpty);
      }
    });

    test(
      'malformed success and transport ambiguity remain outcome unknown',
      () async {
        for (final handler in <FutureOr<ResponseBody> Function(RequestOptions)>[
          (_) => _jsonResponse(200, {
            'data': _topicJson(TeacherTopicStatus.draft),
          }),
          (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ]) {
          final source = TeacherTopicRemoteDataSource(
            dio: _dio(_RecordingAdapter(handler)),
            failureMapper: const DioFailureMapper(),
          );
          final request = TeacherTopicCreateRequest.fromForm(
            TeacherTopicFormValue(
              selectedGroup: teacherGroup(),
              title: 'Topic',
              subject: 'Subject',
              studentInstructions: 'Instructions',
            ),
            'Asia/Tashkent',
          );

          await expectLater(
            source.createTopic(request),
            throwsA(isA<TeacherTopicMutationOutcomeUnknownException>()),
          );
        }
      },
    );

    test(
      'update and lifecycle require strict status, resource, and message',
      () async {
        final topic = teacherTopic();
        final initial = TeacherTopicEditSnapshot.fromTopic(
          topic,
          'Asia/Tashkent',
        );
        final edit = TeacherTopicEditRequest.fromForm(
          form: TeacherTopicFormValue.fromTopic(
            topic,
            'Asia/Tashkent',
          ).copyWith(title: 'Updated'),
          initial: initial,
          institutionTimezone: 'Asia/Tashkent',
        );
        final updateSource = TeacherTopicRemoteDataSource(
          dio: _dio(
            _RecordingAdapter(
              (_) => _jsonResponse(200, {
                'data': _topicJson(TeacherTopicStatus.draft)
                  ..['title'] = 'Updated',
                'message': 'Unexpected update message.',
              }),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );
        final lifecycleSource = TeacherTopicRemoteDataSource(
          dio: _dio(
            _RecordingAdapter(
              (_) => _jsonResponse(200, {
                'data': _topicJson(TeacherTopicStatus.active),
                'message': 'Unexpected lifecycle message.',
              }),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );

        await expectLater(
          updateSource.updateTopic(topic.id, edit),
          throwsA(isA<TeacherTopicMutationOutcomeUnknownException>()),
        );
        await expectLater(
          lifecycleSource.performLifecycleAction(
            topic.id,
            TeacherTopicLifecycleAction.activate,
          ),
          throwsA(isA<TeacherTopicMutationOutcomeUnknownException>()),
        );
      },
    );

    test('maps only exact definite create failures', () async {
      final pairs = <(int, String)>[
        (401, 'authentication_required'),
        (403, 'forbidden'),
        (404, 'resource_not_found'),
        (422, 'validation_failed'),
        (429, 'rate_limited'),
      ];
      for (final pair in pairs) {
        final source = TeacherTopicRemoteDataSource(
          dio: _dio(
            _RecordingAdapter(
              (_) => _jsonResponse(pair.$1, {
                'message': 'Safe server error.',
                'code': pair.$2,
                'errors': pair.$1 == 422
                    ? {
                        'title': ['Raw validation message.'],
                      }
                    : <String, Object?>{},
                'request_id': 'req-1',
              }),
            ),
          ),
          failureMapper: const DioFailureMapper(),
        );
        final request = TeacherTopicCreateRequest.fromForm(
          TeacherTopicFormValue(
            selectedGroup: teacherGroup(),
            title: 'Topic',
            subject: 'Subject',
            studentInstructions: 'Instructions',
          ),
          'Asia/Tashkent',
        );

        await expectLater(
          source.createTopic(request),
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.serverCode,
              'serverCode',
              pair.$2,
            ),
          ),
        );
      }
    });
  });

  test('repository rejects a detail resource with a different ID', () async {
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(200, {
        'data': _topicJson(TeacherTopicStatus.draft)
          ..['id'] = '10000000-0000-0000-0000-000000000002',
      }),
    );
    final repository = TeacherTopicRepositoryImpl(
      remoteDataSource: TeacherTopicRemoteDataSource(
        dio: _dio(adapter),
        failureMapper: const DioFailureMapper(),
      ),
    );

    await expectLater(
      repository.fetchTopic('10000000-0000-0000-0000-000000000001'),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.failure.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });
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

Map<String, Object?> _groupJson() => {
  'id': '00000000-0000-0000-0000-000000000001',
  'name': 'Group A',
  'level': '7',
  'subject_direction': 'Mathematics',
  'status': 'active',
};

Map<String, Object?> _topicJson(TeacherTopicStatus status) {
  final activated = switch (status) {
    TeacherTopicStatus.draft => null,
    _ => '2026-08-20T10:00:00Z',
  };
  final closed = switch (status) {
    TeacherTopicStatus.draft || TeacherTopicStatus.active => null,
    _ => '2026-08-21T10:00:00Z',
  };
  return {
    'id': '10000000-0000-0000-0000-000000000001',
    'group': _groupJson(),
    'title': 'Linear equations',
    'description': null,
    'subject': 'Algebra',
    'student_instructions': 'Read the examples.',
    'lesson_at': '2026-08-25T08:00:00Z',
    'status': status.value,
    'activated_at': activated,
    'closed_at': closed,
    'archived_at': status == TeacherTopicStatus.archived
        ? '2026-08-22T10:00:00Z'
        : null,
    'created_at': '2026-08-19T10:00:00Z',
    'updated_at': '2026-08-22T10:00:00Z',
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
