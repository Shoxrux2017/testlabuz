import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_list_query.dart';
import 'dto/student_dto_parse.dart';
import 'dto/student_homework_dto.dart';
import 'dto/student_homework_list_dto.dart';

final studentHomeworkRemoteDataSourceProvider =
    Provider<StudentHomeworkRemoteDataSource>((ref) {
      return StudentHomeworkRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class StudentHomeworkRemoteDataSource {
  const StudentHomeworkRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<StudentHomeworkListDto> fetchHomework(StudentHomeworkListQuery query) {
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/student/homework',
        queryParameters: query.toQueryParameters(),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Student Homework list success status must be 200.',
        );
      }
      return StudentHomeworkListDto.fromJson(
        response.data,
        requestedQuery: query,
      );
    });
  }

  Future<StudentHomeworkDetailDto> fetchHomeworkDetail(String homeworkId) {
    if (!isCanonicalStudentHomeworkId(homeworkId)) {
      throw ArgumentError.value(
        homeworkId,
        'homeworkId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/student/homework/${Uri.encodeComponent(homeworkId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Student Homework detail success status must be 200.',
        );
      }
      final envelope = readExactStudentMap(
        response.data,
        context: 'Student Homework detail envelope',
        keys: const {'data'},
      );
      return StudentHomeworkDetailDto.fromJson(envelope['data']);
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
            message: 'Student Homework response contains invalid JSON.',
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
