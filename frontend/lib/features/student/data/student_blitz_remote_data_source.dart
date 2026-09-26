import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/student_blitz.dart';
import 'dto/student_blitz_dto.dart';
import 'dto/student_dto_parse.dart';

final studentBlitzRemoteDataSourceProvider =
    Provider<StudentBlitzRemoteDataSource>((ref) {
      return StudentBlitzRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class StudentBlitzRemoteDataSource {
  const StudentBlitzRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<StudentActiveBlitzListDto> fetchActiveBlitz() {
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/student/blitz/active',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Student active Blitz success status must be 200.',
        );
      }
      return StudentActiveBlitzListDto.fromJson(response.data);
    });
  }

  Future<StudentBlitzDetailDto> fetchBlitz(String blitzId) {
    if (!isCanonicalStudentBlitzId(blitzId)) {
      throw ArgumentError.value(
        blitzId,
        'blitzId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/student/blitz/${Uri.encodeComponent(blitzId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Student Blitz detail success status must be 200.',
        );
      }
      final envelope = readExactStudentMap(
        response.data,
        context: 'Student Blitz detail envelope',
        keys: const {'data'},
      );
      return StudentBlitzDetailDto.fromJson(envelope['data']);
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      // Dio wraps JSON decoding failures before a DTO can inspect the response.
      if (exception.type == DioExceptionType.unknown &&
          exception.error is FormatException) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'Student Blitz response contains invalid JSON.',
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
