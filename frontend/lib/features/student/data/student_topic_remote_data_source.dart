import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/student_topic.dart';
import '../domain/student_topic_list_query.dart';
import 'dto/student_dto_parse.dart';
import 'dto/student_topic_dto.dart';

final studentTopicRemoteDataSourceProvider =
    Provider<StudentTopicRemoteDataSource>((ref) {
      return StudentTopicRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class StudentTopicRemoteDataSource {
  const StudentTopicRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<StudentTopicListDto> fetchTopics(StudentTopicListQuery query) {
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/student/topics',
        queryParameters: query.toQueryParameters(),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Student Topic list success status must be 200.',
        );
      }

      return StudentTopicListDto.fromJson(response.data, requestedQuery: query);
    });
  }

  Future<StudentTopicDetailDto> fetchTopic(String topicId) {
    if (!isCanonicalStudentTopicId(topicId)) {
      throw ArgumentError.value(
        topicId,
        'topicId',
        'Must be a canonical UUID.',
      );
    }

    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/student/topics/${Uri.encodeComponent(topicId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Student Topic detail success status must be 200.',
        );
      }
      final envelope = readExactStudentMap(
        response.data,
        context: 'Student Topic detail envelope',
        keys: const {'data'},
      );

      return StudentTopicDetailDto.fromJson(envelope['data']);
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
