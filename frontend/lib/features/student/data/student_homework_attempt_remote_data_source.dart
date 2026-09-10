import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_question.dart';
import 'dto/student_attempt_answer_mutation_dto.dart';
import 'dto/student_dto_parse.dart';
import 'dto/student_homework_attempt_dto.dart';

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
