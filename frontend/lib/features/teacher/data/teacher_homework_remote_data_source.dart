import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_list_query.dart';
import '../domain/teacher_topic.dart';
import 'dto/teacher_homework_dto.dart';
import 'dto/teacher_homework_list_dto.dart';

final teacherHomeworkRemoteDataSourceProvider =
    Provider<TeacherHomeworkRemoteDataSource>((ref) {
      return TeacherHomeworkRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class TeacherHomeworkRemoteDataSource {
  const TeacherHomeworkRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherHomeworkListDto> fetchHomeworkList(
    String topicId,
    TeacherHomeworkListQuery query,
  ) {
    if (!isCanonicalTeacherTopicId(topicId)) {
      throw ArgumentError.value(
        topicId,
        'topicId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}/homework',
        queryParameters: query.toQueryParameters(),
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Homework list success status must be 200.',
        );
      }
      return TeacherHomeworkListDto.fromJson(
        response.data,
        expectedTopicId: topicId,
        requestedQuery: query,
      );
    });
  }

  Future<TeacherHomeworkDetailDto> fetchHomework(String homeworkId) {
    if (!isCanonicalTeacherHomeworkId(homeworkId)) {
      throw ArgumentError.value(
        homeworkId,
        'homeworkId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/homework/${Uri.encodeComponent(homeworkId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Homework detail success status must be 200.',
        );
      }
      return TeacherHomeworkDetailDto.fromJson(response.data);
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
