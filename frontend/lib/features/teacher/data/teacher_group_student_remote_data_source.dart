import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_group_student.dart';
import '../domain/teacher_group_student_list_query.dart';
import 'dto/teacher_group_student_list_dto.dart';

final teacherGroupStudentRemoteDataSourceProvider =
    Provider<TeacherGroupStudentRemoteDataSource>((ref) {
      return TeacherGroupStudentRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class TeacherGroupStudentRemoteDataSource {
  const TeacherGroupStudentRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherGroupStudentListDto> fetchGroupStudents(
    String groupId,
    TeacherGroupStudentListQuery query,
  ) {
    if (!isCanonicalTeacherGroupId(groupId)) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/groups/${Uri.encodeComponent(groupId)}/students',
        queryParameters: query.toQueryParameters(),
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Group Student list success status must be 200.',
        );
      }
      return TeacherGroupStudentListDto.fromJson(
        response.data,
        requestedQuery: query,
      );
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
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
