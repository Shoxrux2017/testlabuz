import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_list_query.dart';
import '../domain/teacher_topic.dart';
import 'dto/teacher_blitz_dto.dart';
import 'dto/teacher_blitz_list_dto.dart';

final teacherBlitzRemoteDataSourceProvider =
    Provider<TeacherBlitzRemoteDataSource>((ref) {
      return TeacherBlitzRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class TeacherBlitzRemoteDataSource {
  const TeacherBlitzRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherBlitzListDto> fetchBlitzList(
    String topicId,
    TeacherBlitzListQuery query,
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
        '/teacher/blitz',
        queryParameters: <String, Object>{
          'topic_id': topicId,
          ...query.toQueryParameters(),
        },
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Blitz list success status must be 200.',
        );
      }
      return TeacherBlitzListDto.fromJson(
        response.data,
        expectedTopicId: topicId,
        requestedQuery: query,
      );
    });
  }

  Future<TeacherBlitzDetailDto> fetchBlitz(String blitzId) {
    if (!isCanonicalTeacherBlitzId(blitzId)) {
      throw ArgumentError.value(
        blitzId,
        'blitzId',
        'Must be a canonical UUID.',
      );
    }
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/blitz/${Uri.encodeComponent(blitzId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Blitz detail success status must be 200.',
        );
      }
      return TeacherBlitzDetailDto.fromJson(response.data);
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
