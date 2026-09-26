import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_question.dart';
import '../domain/student_submission_upload.dart';
import 'dto/student_attempt_answer_mutation_dto.dart';
import 'dto/student_dto_parse.dart';

final studentAttemptAnswerRemoteDataSourceProvider =
    Provider<StudentAttemptAnswerRemoteDataSource>((ref) {
      return StudentAttemptAnswerRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

/// The single raw implementation of the Assessment-type-neutral answer PUT.
/// Nothing here retries: the PUT is not idempotent at the transport level.
class StudentAttemptAnswerRemoteDataSource {
  const StudentAttemptAnswerRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<StudentAttemptAnswerMutationDto> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) {
    _validateUuid(attemptId, 'attemptId');
    _validateUuid(question.id, 'question.id');
    if (question.type != mutation.type) {
      throw ArgumentError('Mutation type does not match its Question.');
    }
    return _mapFailures(() async {
      final response = await dio.put<Object?>(
        '/student/attempts/${Uri.encodeComponent(attemptId)}/answers/'
        '${Uri.encodeComponent(question.id)}',
        data: mutation.toJson(),
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException('Answer save success status must be 200.');
      }
      return StudentAttemptAnswerMutationDto.fromJson(
        response.data,
        question: question,
        requestedType: mutation.type,
      );
    });
  }

  Future<StudentAttemptAnswerMutationDto> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) {
    _validateUuid(attemptId, 'attemptId');
    _validateUuid(question.id, 'question.id');
    if (question.type != StudentQuestionType.fileBased ||
        question.answerUi is! StudentFileAnswerUi) {
      throw ArgumentError('File upload requires a safe file Question.');
    }
    return _mapFailures(() async {
      final response = await dio.put<Object?>(
        '/student/attempts/${Uri.encodeComponent(attemptId)}/answers/'
        '${Uri.encodeComponent(question.id)}',
        data: FormData.fromMap({
          'type': 'file_based',
          'file': MultipartFile.fromStream(
            () => _readSelectedSource(file),
            file.length,
            filename: file.name,
          ),
        }),
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          followRedirects: false,
        ),
        onSendProgress: onProgress,
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'File answer upload success status must be 200.',
        );
      }
      return StudentAttemptAnswerMutationDto.fromJson(
        response.data,
        question: question,
        requestedType: StudentQuestionType.fileBased,
        selectedFile: file,
      );
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      Object? cause = exception;
      while (cause is DioException) {
        cause = cause.error;
      }
      if (cause is StudentSubmissionSourceUnavailable) {
        throw cause;
      }
      // Dio wraps JSON decoding failures before the exact DTO parser runs.
      if (exception.type == DioExceptionType.unknown &&
          exception.error is FormatException) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'Student answer response contains invalid JSON.',
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
}

Stream<List<int>> _readSelectedSource(StudentSubmissionUploadFile file) async* {
  try {
    await for (final chunk in file.openRead()) {
      yield chunk;
    }
  } catch (_) {
    // Preserve local read failures before Dio classifies its wrapped exception.
    throw const StudentSubmissionSourceUnavailable();
  }
}

void _validateUuid(String value, String argument) {
  if (value.length != 36 || !canonicalStudentUuidPattern.hasMatch(value)) {
    throw ArgumentError.value(value, argument, 'Must be a canonical UUID.');
  }
}
