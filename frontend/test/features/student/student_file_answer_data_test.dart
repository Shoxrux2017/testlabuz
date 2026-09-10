import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_controller.dart';
import 'package:testlabuz_client/features/student/application/student_file_answer_state.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_controller.dart';
import 'package:testlabuz_client/features/student/application/student_homework_attempt_state.dart';
import 'package:testlabuz_client/features/student/application/student_submission_file_picker.dart';
import 'package:testlabuz_client/features/student/data/dto/student_attempt_answer_mutation_dto.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_remote_data_source.dart';
import 'package:testlabuz_client/features/student/data/student_homework_attempt_repository_impl.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt.dart';
import 'package:testlabuz_client/features/student/domain/student_homework_attempt_route_target.dart';
import 'package:testlabuz_client/features/student/domain/student_question.dart';
import 'package:testlabuz_client/features/student/domain/student_submission_upload.dart';

import 'student_test_support.dart';

void main() {
  test(
    'valid 200 replacement with changed File ID remains uncertain without replay',
    () async {
      final target = StudentHomeworkAttemptRouteTarget(
        topicId: studentTopicId,
        homeworkId: _otherId,
        attemptId: _attemptId,
      );
      const previousFile = StudentSubmissionFile(
        id: _fileId,
        originalName: 'previous.pdf',
        extension: 'pdf',
        sizeBytes: 3,
      );
      final attempt = StudentHomeworkAttempt(
        id: _attemptId,
        assessmentId: target.homeworkId,
        attemptNumber: 1,
        status: StudentHomeworkAttemptStatus.inProgress,
        startedAt: DateTime.utc(2026, 9, 8, 12),
        submittedAt: null,
        finalizedAt: null,
        finalizationReason: null,
        deadlineAt: null,
        questions: [_question()],
        answers: [
          StudentAttemptAnswerState(
            questionId: _questionId,
            type: StudentQuestionType.fileBased,
            value: const StudentFileAnswerValue(file: previousFile),
            updatedAt: DateTime.utc(2026, 9, 8, 12),
          ),
        ],
      );
      final selected = _selected();
      final adapter = _UploadAdapter(
        (_) => _response(200, {
          'data': _result(selected)
            ..['answer'] = {
              'file': {..._metadata(selected), 'id': _otherId},
            },
        }),
      );
      final container = ProviderContainer(
        overrides: [
          authSessionControllerProvider.overrideWith(
            () => FakeStudentAuthSessionController.authenticated(
              studentUser('student-a'),
            ),
          ),
          appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
          studentHomeworkAttemptControllerProvider(
            target,
          ).overrideWith(() => _UploadTestParent(target, attempt)),
          studentHomeworkAttemptRepositoryProvider.overrideWithValue(
            _repository(adapter),
          ),
          studentSubmissionFilePickerProvider.overrideWithValue(
            _UploadTestPicker(selected),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        studentFileAnswerControllerProvider(target),
        (_, _) {},
      );
      final controller = container.read(
        studentFileAnswerControllerProvider(target).notifier,
      );
      await controller.chooseFile(_questionId);
      expect(
        subscription.read().questions[_questionId]!.selectedFile,
        same(selected),
      );
      await controller.uploadAnswer(_questionId);
      final uncertain = subscription.read().questions[_questionId]!;
      expect(uncertain.status, StudentFileAnswerStatus.uncertain);
      expect(uncertain.failure!.kind, ApiFailureKind.invalidResponse);
      expect(uncertain.serverFile, same(previousFile));
      expect(uncertain.selectedFile, same(selected));
      expect(subscription.read().hasUncertainUpload, isTrue);
      expect(subscription.read().canUpload(_questionId), isFalse);
      await controller.uploadAnswer(_questionId);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.bodies.single, isNotEmpty);
    },
  );

  test(
    'upload streams exact multipart PUT with generated boundary and progress',
    () async {
      final bytes = <int>[0, 1, 127, 128, 255];
      var reads = 0;
      final selected = StudentSubmissionUploadFile(
        name: 'Работа 🙂.PDF',
        length: bytes.length,
        openRead: () {
          reads++;
          return Stream.fromIterable([bytes.sublist(0, 2), bytes.sublist(2)]);
        },
      );
      final progress = <(int, int)>[];
      final adapter = _UploadAdapter(
        (_) => _response(200, _envelope(selected)),
      );
      final result = await _repository(adapter).uploadFileAnswer(
        _attemptId.toUpperCase(),
        _question(),
        selected,
        onProgress: (sent, total) => progress.add((sent, total)),
      );
      expect(reads, 1);
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(
        request.path,
        '/student/attempts/${_attemptId.toUpperCase()}/answers/$_questionId',
      );
      expect(
        request.uri.path,
        '/api/v1/student/attempts/${_attemptId.toUpperCase()}/answers/$_questionId',
      );
      expect(request.queryParameters, isEmpty);
      expect(request.followRedirects, isFalse);
      expect(request.sendTimeout, const Duration(minutes: 5));
      expect(
        request.headers.keys.any(
          (name) => name.toLowerCase() == 'idempotency-key',
        ),
        isFalse,
      );
      final form = request.data as FormData;
      expect(form.fields.map((field) => (field.key, field.value)), [
        ('type', 'file_based'),
      ]);
      expect(form.files, hasLength(1));
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, selected.name);
      expect(form.files.single.value.length, bytes.length);
      expect(form.boundary, isNotEmpty);
      expect(
        request.contentType,
        '${Headers.multipartFormDataContentType}; boundary=${form.boundary}',
      );
      final body = adapter.bodies.single;
      final wireText = latin1.decode(body);
      expect(wireText, startsWith('--${form.boundary}\r\n'));
      expect(wireText, endsWith('--${form.boundary}--\r\n'));
      expect(wireText, contains('name="type"\r\n\r\nfile_based'));
      final fileHeader = wireText.indexOf('name="file"; filename=');
      expect(fileHeader, greaterThan(0));
      final fileStart = wireText.indexOf('\r\n\r\n', fileHeader) + 4;
      expect(body.sublist(fileStart, fileStart + bytes.length), bytes);
      expect(progress, isNotEmpty);
      expect(progress.last, (body.length, body.length));
      expect(progress.every((value) => value.$1 <= value.$2), isTrue);
      expect(result.type, StudentQuestionType.fileBased);
      expect(result.questionId, _questionId);
      final saved = (result.answer as StudentFileAnswerValue).file;
      expect(saved.id, _fileId);
      expect(saved.originalName, selected.name);
      expect(saved.extension, 'pdf');
      expect(saved.sizeBytes, bytes.length);
      expect(result.updatedAt, DateTime.utc(2026, 9, 8, 12, 10));
    },
  );

  test(
    'only HTTP 200 confirms upload and unexpected 2xx never replay',
    () async {
      final selected = _selected();
      for (var status = 201; status < 300; status++) {
        final adapter = _UploadAdapter(
          (_) => _response(status, _envelope(selected)),
        );
        await expectLater(
          _repository(
            adapter,
          ).uploadFileAnswer(_attemptId, _question(), selected),
          throwsA(_invalidResponse),
        );
        expect(adapter.requests, hasLength(1), reason: 'HTTP $status');
      }
    },
  );

  test(
    'rejects malformed file answer envelope, target, metadata and timestamp',
    () async {
      final selected = _selected();
      final malformed = <Object?>[
        null,
        [],
        {},
        {'data': null},
        {..._envelope(selected), 'extra': true},
        {'data': _result(selected)..['answer'] = null},
        {'data': _result(selected)..['updated_at'] = null},
        {'data': _result(selected)..['question_id'] = _otherId},
        {'data': _result(selected)..['question_id'] = 'bad'},
        {'data': _result(selected)..['type'] = 'short_written'},
        {'data': _result(selected)..['storage'] = 'private'},
        for (final timestamp in [
          '2026-09-08T12:10Z',
          '2026-09-08T12:10:00.000Z',
          '2026-09-08T12:10:00+00:00',
          '2026-09-08 12:10:00Z',
          '2026-02-30T12:10:00Z',
          '2026-09-08T12:10:00Z\n',
        ])
          {'data': _result(selected)..['updated_at'] = timestamp},
        for (final metadata in [
          {..._metadata(selected), 'id': 'bad'},
          {..._metadata(selected), 'original_name': 'different.pdf'},
          {..._metadata(selected), 'original_name': ' '},
          {..._metadata(selected), 'extension': 'docx'},
          {..._metadata(selected), 'extension': 'exe'},
          {..._metadata(selected), 'size_bytes': selected.length + 1},
          {..._metadata(selected), 'size_bytes': 0},
          {..._metadata(selected), 'size_bytes': 15728641},
          {..._metadata(selected), 'storage_path': 'private'},
          {..._metadata(selected), 'checksum': 'hidden'},
        ])
          {
            'data': _result(selected)..['answer'] = {'file': metadata},
          },
        {
          'data': _result(selected)
            ..['answer'] = {'file': _metadata(selected), 'extra': true},
        },
      ];
      for (final payload in malformed) {
        final adapter = _UploadAdapter((_) => _response(200, payload));
        await expectLater(
          _repository(
            adapter,
          ).uploadFileAnswer(_attemptId, _question(), selected),
          throwsA(_invalidResponse),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'current mutation validates safe Question policy below platform cap',
    () async {
      final selected = _selected();
      for (final question in [
        _question(allowedExtensions: const ['docx']),
        _question(maxSizeBytes: selected.length - 1),
      ]) {
        final adapter = _UploadAdapter(
          (_) => _response(200, _envelope(selected)),
        );
        await expectLater(
          _repository(adapter).uploadFileAnswer(_attemptId, question, selected),
          throwsA(_invalidResponse),
        );
        expect(adapter.requests, hasLength(1));
      }
      final dto = StudentAttemptAnswerMutationDto.fromJson(
        _envelope(selected),
        question: _question(maxSizeBytes: selected.length),
        requestedType: StudentQuestionType.fileBased,
        selectedFile: selected,
      );
      expect(dto.answer, isA<StudentFileAnswerValue>());
    },
  );

  test('invalid request IDs and non-file Question never reach transport', () {
    final selected = _selected();
    final adapter = _UploadAdapter((_) => _response(200, _envelope(selected)));
    final source = _source(adapter);
    for (final id in ['', '../attempt', '$_attemptId/extra', '$_attemptId\n']) {
      expect(
        () => source.uploadFileAnswer(id, _question(), selected),
        throwsArgumentError,
      );
      expect(
        () => source.uploadFileAnswer(_attemptId, _question(id: id), selected),
        throwsArgumentError,
      );
    }
    for (final question in [
      _question(type: StudentQuestionType.shortWritten),
      _question(answerUi: const StudentEmptyAnswerUi()),
    ]) {
      expect(
        () => source.uploadFileAnswer(_attemptId, question, selected),
        throwsArgumentError,
      );
    }
    expect(adapter.requests, isEmpty);
  });

  test(
    'synchronous and emitted source failures survive Dio wrapping as local marker',
    () async {
      for (final openRead in <Stream<List<int>> Function()>[
        () => throw StateError('Private local source path unavailable.'),
        () => Stream<List<int>>.error(StateError('Local read unavailable.')),
        () async* {
          yield [1];
          throw StateError('Local read failed after a chunk.');
        },
      ]) {
        final selected = StudentSubmissionUploadFile(
          name: 'answer.pdf',
          length: 3,
          openRead: openRead,
        );
        final adapter = _UploadAdapter(
          (_) => _response(200, _envelope(selected)),
          wrapStreamError: true,
        );
        await expectLater(
          _repository(
            adapter,
          ).uploadFileAnswer(_attemptId, _question(), selected),
          throwsA(isA<StudentSubmissionSourceUnavailable>()),
        );
        expect(adapter.requests, hasLength(1));
        expect(adapter.streamError, isA<StudentSubmissionSourceUnavailable>());
      }
    },
  );

  test(
    'ordinary transport failures preserve API category without retry',
    () async {
      for (final failure in [
        (DioExceptionType.connectionError, ApiFailureKind.connection),
        (DioExceptionType.sendTimeout, ApiFailureKind.timeout),
        (DioExceptionType.receiveTimeout, ApiFailureKind.timeout),
        (DioExceptionType.cancel, ApiFailureKind.cancelled),
        (DioExceptionType.unknown, ApiFailureKind.unknown),
      ]) {
        final adapter = _UploadAdapter(
          (request) =>
              throw DioException(requestOptions: request, type: failure.$1),
        );
        await expectLater(
          _repository(
            adapter,
          ).uploadFileAnswer(_attemptId, _question(), _selected()),
          throwsA(
            isA<ApiRequestException>().having(
              (error) => error.failure.kind,
              'kind',
              failure.$2,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'file and lifecycle server failures retain status and machine code',
    () async {
      for (final failure in [
        (404, 'resource_not_found'),
        (409, 'task_not_active'),
        (409, 'task_closed'),
        (409, 'task_archived'),
        (409, 'deadline_passed'),
        (409, 'attempt_not_editable'),
        (409, 'business_conflict'),
        (422, 'validation_failed'),
        (422, 'unsupported_file_type'),
        (422, 'file_too_large'),
        (500, 'file_upload_failed'),
      ]) {
        final adapter = _UploadAdapter(
          (_) => _response(failure.$1, {
            'message': 'Safe failure.',
            'code': failure.$2,
            'errors': <String, Object?>{},
            'request_id': 'file-request',
          }),
        );
        await expectLater(
          _repository(
            adapter,
          ).uploadFileAnswer(_attemptId, _question(), _selected()),
          throwsA(
            isA<ApiRequestException>()
                .having(
                  (error) => error.failure.statusCode,
                  'status',
                  failure.$1,
                )
                .having(
                  (error) => error.failure.serverCode,
                  'code',
                  failure.$2,
                ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
}

final _invalidResponse = isA<ApiRequestException>().having(
  (error) => error.failure.kind,
  'kind',
  ApiFailureKind.invalidResponse,
);

class _UploadTestParent extends StudentHomeworkAttemptController {
  _UploadTestParent(super.target, this.attempt);
  final StudentHomeworkAttempt attempt;

  @override
  StudentHomeworkAttemptState build() => StudentHomeworkAttemptState(
    status: StudentHomeworkAttemptLoadStatus.data,
    attempt: attempt,
  );

  @override
  void refresh() =>
      throw StateError('Uncertain replacement requires explicit recovery.');
}

class _UploadTestPicker implements StudentSubmissionFilePicker {
  const _UploadTestPicker(this.selected);
  final StudentSubmissionUploadFile selected;

  @override
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  }) async => selected;
}

StudentHomeworkAttemptRepositoryImpl _repository(_UploadAdapter adapter) =>
    StudentHomeworkAttemptRepositoryImpl(remoteDataSource: _source(adapter));

StudentHomeworkAttemptRemoteDataSource _source(_UploadAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.test/api/v1',
      contentType: Headers.jsonContentType,
    ),
  );
  dio.httpClientAdapter = adapter;
  return StudentHomeworkAttemptRemoteDataSource(
    dio: dio,
    failureMapper: const DioFailureMapper(),
  );
}

class _UploadAdapter implements HttpClientAdapter {
  _UploadAdapter(this.respond, {this.wrapStreamError = false});
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final bool wrapStreamError;
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];
  Object? streamError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    try {
      bodies.add(
        await requestStream!.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        ),
      );
    } catch (error) {
      streamError = error;
      if (wrapStreamError) {
        throw DioException(
          requestOptions: options,
          error: DioException(requestOptions: options, error: error),
        );
      }
      rethrow;
    }
    return await respond(options);
  }

  @override
  void close({bool force = false}) {}
}

StudentQuestion _question({
  String id = _questionId,
  StudentQuestionType type = StudentQuestionType.fileBased,
  List<String> allowedExtensions = const ['pdf', 'docx', 'ppt', 'pptx'],
  int maxSizeBytes = 1024,
  StudentAnswerUi? answerUi,
}) => StudentQuestion(
  id: id,
  type: type,
  prompt: 'Upload an answer',
  instructions: null,
  points: 1,
  position: 1,
  answerUi:
      answerUi ??
      StudentFileAnswerUi(
        allowedExtensions: allowedExtensions,
        maxSizeBytes: maxSizeBytes,
      ),
);

StudentSubmissionUploadFile _selected() => StudentSubmissionUploadFile(
  name: 'answer.pdf',
  length: 3,
  openRead: () => Stream.value([1, 2, 3]),
);

Map<String, Object?> _metadata(StudentSubmissionUploadFile selected) => {
  'id': _fileId,
  'original_name': selected.name,
  'extension': selected.extension,
  'size_bytes': selected.length,
};
Map<String, Object?> _result(StudentSubmissionUploadFile selected) => {
  'question_id': _questionId,
  'type': 'file_based',
  'answer': {'file': _metadata(selected)},
  'updated_at': '2026-09-08T12:10:00Z',
};
Map<String, Object?> _envelope(StudentSubmissionUploadFile selected) => {
  'data': _result(selected),
};

ResponseBody _response(int status, Object? payload) => ResponseBody.fromString(
  jsonEncode(payload),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _attemptId = 'a1000000-0000-0000-0000-000000000001';
const _questionId = 'a2000000-0000-0000-0000-000000000001';
const _fileId = 'a3000000-0000-0000-0000-000000000001';
const _otherId = 'a4000000-0000-0000-0000-000000000001';
