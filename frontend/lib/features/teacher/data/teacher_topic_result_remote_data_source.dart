import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_result.dart';
import '../domain/teacher_topic_result_list.dart';
import 'dto/teacher_dto_parse.dart';
import 'dto/teacher_topic_result_dto.dart';
import 'dto/teacher_topic_result_list_dto.dart';

final teacherTopicResultRemoteDataSourceProvider =
    Provider<TeacherTopicResultRemoteDataSource>((ref) {
      return TeacherTopicResultRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

/// The Teacher Topic result reads (docs/09 §§25.5-25.6).
class TeacherTopicResultRemoteDataSource {
  const TeacherTopicResultRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherTopicResultList> fetchResults(
    String topicId,
    TeacherTopicResultListQuery query,
  ) {
    _requireTopicId(topicId);
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        _resultsPath(topicId),
        queryParameters: query.toQueryParameters(),
        options: Options(followRedirects: false),
      );
      _requireOk(response, 'Teacher Topic result list');
      return TeacherTopicResultListDto.fromJson(
        response.data,
        query: query,
      ).toDomain();
    });
  }

  Future<TeacherTopicResultDetail> fetchResult(
    String topicId,
    String studentId,
  ) {
    _requireTopicId(topicId);
    if (!isCanonicalTeacherStudentId(studentId)) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '${_resultsPath(topicId)}/${Uri.encodeComponent(studentId)}',
        options: Options(followRedirects: false),
      );
      _requireOk(response, 'Teacher Topic result detail');
      final envelope = readExactTeacherMap(
        response.data,
        context: 'Teacher Topic result detail envelope',
        keys: const {'data'},
      );
      return TeacherTopicResultDetailDto.fromJson(envelope['data']).toDomain();
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

String _resultsPath(String topicId) {
  return '/teacher/topics/${Uri.encodeComponent(topicId)}/results';
}

void _requireTopicId(String topicId) {
  if (!isCanonicalTeacherTopicId(topicId)) {
    throw ArgumentError.value(topicId, 'topicId', 'Must be a canonical UUID.');
  }
}

void _requireOk(Response<Object?> response, String resource) {
  if (response.statusCode != 200) {
    throw FormatException('$resource success status must be 200.');
  }
}
