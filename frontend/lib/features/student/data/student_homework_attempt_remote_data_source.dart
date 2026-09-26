import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_question.dart';
import '../domain/student_submission_upload.dart';
import 'dto/student_attempt_answer_mutation_dto.dart';
import 'dto/student_dto_parse.dart';
import 'dto/student_homework_attempt_dto.dart';
import 'dto/student_homework_submit_dto.dart';
import 'student_attempt_answer_remote_data_source.dart';

final studentHomeworkAttemptRemoteDataSourceProvider =
    Provider<StudentHomeworkAttemptRemoteDataSource>((ref) {
      return StudentHomeworkAttemptRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class StudentHomeworkAttemptRemoteDataSource {
  const StudentHomeworkAttemptRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<StudentHomeworkAttemptStartOperationDto> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) {
    _validateUuid(homeworkId, 'homeworkId');
    _validateUuid(idempotencyKey, 'idempotencyKey');
    return _mapFailures(() async {
      final response = await dio.post<Object?>(
        '/student/homework/${Uri.encodeComponent(homeworkId)}/attempts',
        data: const <String, Object?>{},
        options: Options(
          followRedirects: false,
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      );
      final resultKind = switch (response.statusCode) {
        201 => StudentHomeworkAttemptStartResultKind.created,
        200 => StudentHomeworkAttemptStartResultKind.resumed,
        _ => throw const FormatException(
          'Homework Attempt Start success status must be 200 or 201.',
        ),
      };
      return StudentHomeworkAttemptStartOperationDto(
        attempt: _readEnvelope(response.data),
        resultKind: resultKind,
      );
    });
  }

  Future<StudentHomeworkAttemptDto> fetchAttempt(String attemptId) {
    _validateUuid(attemptId, 'attemptId');
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/student/attempts/${Uri.encodeComponent(attemptId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Homework Attempt read success status must be 200.',
        );
      }
      return _readEnvelope(response.data);
    });
  }

  Future<StudentHomeworkSubmitDto> submitAttempt(
    String attemptId,
    String expectedHomeworkId,
    String idempotencyKey,
  ) {
    _validateUuid(attemptId, 'attemptId');
    _validateUuid(expectedHomeworkId, 'expectedHomeworkId');
    _validateUuid(idempotencyKey, 'idempotencyKey');
    return _mapFailures(() async {
      final response = await dio.post<Object?>(
        '/student/attempts/${Uri.encodeComponent(attemptId)}/submit',
        data: const <String, Object?>{},
        options: Options(
          followRedirects: false,
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Homework Submit success status must be 200.',
        );
      }
      return StudentHomeworkSubmitDto.fromJson(
        response.data,
        expectedAttemptId: attemptId,
        expectedHomeworkId: expectedHomeworkId,
      );
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      // Dio wraps JSON decoding failures before the exact DTO parser runs.
      if (exception.type == DioExceptionType.unknown &&
          exception.error is FormatException) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'Student Homework Attempt response contains invalid JSON.',
          ),
        );
      }
      throw ApiRequestException(failureMapper.map(exception));
    } on FormatException catch (exception) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: exception.message,
        ),
      );
    }
  }

  /// Thin delegate: the shared data source owns the one raw answer PUT.
  Future<StudentAttemptAnswerMutationDto> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) => _answers.saveAnswer(attemptId, question, mutation);

  /// Thin delegate: the shared data source owns the one raw file PUT.
  Future<StudentAttemptAnswerMutationDto> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) => _answers.uploadFileAnswer(
    attemptId,
    question,
    file,
    onProgress: onProgress,
  );

  StudentAttemptAnswerRemoteDataSource get _answers =>
      StudentAttemptAnswerRemoteDataSource(
        dio: dio,
        failureMapper: failureMapper,
      );
}

StudentHomeworkAttemptDto _readEnvelope(Object? json) {
  final envelope = readExactStudentMap(
    json,
    context: 'Student Homework Attempt envelope',
    keys: const {'data'},
  );
  return StudentHomeworkAttemptDto.fromJson(envelope['data']);
}

void _validateUuid(String value, String argument) {
  if (value.length != 36 || !canonicalStudentUuidPattern.hasMatch(value)) {
    throw ArgumentError.value(value, argument, 'Must be a canonical UUID.');
  }
}
