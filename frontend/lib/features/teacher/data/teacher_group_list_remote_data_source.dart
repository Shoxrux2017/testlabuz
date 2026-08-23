import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_group_list_query.dart';
import 'dto/teacher_group_list_dto.dart';

final teacherGroupListRemoteDataSourceProvider =
    Provider<TeacherGroupListRemoteDataSource>((ref) {
      return TeacherGroupListRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class TeacherGroupListRemoteDataSource {
  const TeacherGroupListRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherGroupListDto> fetchGroups(TeacherGroupListQuery query) {
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/groups',
        queryParameters: query.toQueryParameters(),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Group list success status must be 200.',
        );
      }

      return TeacherGroupListDto.fromJson(response.data, requestedQuery: query);
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
