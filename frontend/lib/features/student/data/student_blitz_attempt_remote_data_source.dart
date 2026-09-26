import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';
import 'dto/student_blitz_attempt_dto.dart';

final studentBlitzAttemptRemoteDataSourceProvider =
    Provider<StudentBlitzAttemptRemoteDataSource>((ref) {
      return StudentBlitzAttemptRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class StudentBlitzAttemptRemoteDataSource {
  const StudentBlitzAttemptRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  /// Sends the exact frozen intent body once; nothing retries it here.
  Future<StudentBlitzAttemptStartOperationDto> start(
    String blitzId,
    StudentBlitzAttemptRequest request,
  ) {
    if (!isCanonicalStudentBlitzId(blitzId)) {
      throw ArgumentError.value(
        blitzId,
        'blitzId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.post<Object?>(
        '/student/blitz/${Uri.encodeComponent(blitzId)}/attempts',
        data: request.toJson(),
        options: Options(
          followRedirects: false,
          headers: {'Idempotency-Key': request.idempotencyKey},
        ),
      );
      return StudentBlitzAttemptStartOperationDto.fromResponse(
        statusCode: response.statusCode,
        body: response.data,
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
            message: 'Student Blitz Attempt response contains invalid JSON.',
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
