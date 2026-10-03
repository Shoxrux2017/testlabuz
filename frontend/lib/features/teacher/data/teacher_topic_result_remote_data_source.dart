import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_result.dart';
import '../domain/teacher_topic_result_list.dart';
import '../domain/teacher_topic_result_mutation.dart';
import 'dto/teacher_dto_parse.dart';
import 'dto/teacher_topic_result_dto.dart';
import 'dto/teacher_topic_result_list_dto.dart';
import 'dto/teacher_topic_result_mutation_dto.dart';
import 'teacher_mutation_transport.dart';

final teacherTopicResultRemoteDataSourceProvider =
    Provider<TeacherTopicResultRemoteDataSource>((ref) {
      return TeacherTopicResultRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

/// The Teacher Topic result reads and actions (docs/09 §§25.5-25.9,
/// 27.3-27.5).
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
    final path = _resultPath(topicId, studentId);
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        path,
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

  /// Sets the comment; [comment] is the trimmed text, or null to remove it.
  Future<TeacherTopicResultDetail> updateComment(
    String topicId,
    String studentId,
    String? comment,
  ) {
    final path = '${_resultPath(topicId, studentId)}/comment';
    return _sendDetailAction(
      () => dio.put<Object?>(
        path,
        data: <String, Object?>{'teacher_comment': comment},
        options: Options(followRedirects: false),
      ),
      conflictCodes: const {ApiErrorCodes.resultClosed},
    );
  }

  Future<TeacherTopicResultDetail> release(
    String topicId,
    String studentId,
    TeacherTopicResultAudience audience,
  ) {
    final path =
        '${_resultPath(topicId, studentId)}/release/${audience.segment}';
    return _sendDetailAction(
      () => _postEmpty(path),
      conflictCodes: switch (audience) {
        TeacherTopicResultAudience.student => const {
          ApiErrorCodes.manualReleaseNotAllowed,
          ApiErrorCodes.resultNotReady,
        },
        TeacherTopicResultAudience.parent => const {
          ApiErrorCodes.manualReleaseNotAllowed,
          ApiErrorCodes.studentResultNotReleased,
        },
      },
    );
  }

  Future<TeacherTopicResultDetail> close(String topicId, String studentId) {
    final path = '${_resultPath(topicId, studentId)}/close';
    return _sendDetailAction(
      () => _postEmpty(path),
      conflictCodes: const {ApiErrorCodes.resultNotReadyForClosure},
    );
  }

  Future<TeacherTopicResultBulkOutcome> releaseAll(
    String topicId,
    TeacherTopicResultAudience audience,
  ) {
    _requireTopicId(topicId);
    return _sendBulkAction(
      () => _postEmpty('${_resultsPath(topicId)}/release/${audience.segment}'),
      conflictCodes: const {ApiErrorCodes.manualReleaseNotAllowed},
    );
  }

  Future<TeacherTopicResultBulkOutcome> closeAll(String topicId) {
    _requireTopicId(topicId);
    return _sendBulkAction(
      () => _postEmpty('${_resultsPath(topicId)}/close'),
      conflictCodes: const {},
    );
  }

  Future<Response<Object?>> _postEmpty(String path) {
    return dio.post<Object?>(
      path,
      data: const <String, Object?>{},
      options: Options(followRedirects: false),
    );
  }

  Future<TeacherTopicResultDetail> _sendDetailAction(
    Future<Response<Object?>> Function() send, {
    required Set<String> conflictCodes,
  }) {
    return sendTeacherMutation(
      send: send,
      expectedStatus: 200,
      parse: readTeacherTopicResultActionResponse,
      conflictCodes: conflictCodes,
      failureMapper: failureMapper,
      outcomeUnknown: () =>
          const TeacherTopicResultMutationOutcomeUnknownException(),
    );
  }

  Future<TeacherTopicResultBulkOutcome> _sendBulkAction(
    Future<Response<Object?>> Function() send, {
    required Set<String> conflictCodes,
  }) {
    return sendTeacherMutation(
      send: send,
      expectedStatus: 200,
      parse: readTeacherTopicResultBulkResponse,
      conflictCodes: conflictCodes,
      failureMapper: failureMapper,
      outcomeUnknown: () =>
          const TeacherTopicResultMutationOutcomeUnknownException(),
    );
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

String _resultPath(String topicId, String studentId) {
  _requireTopicId(topicId);
  if (!isCanonicalTeacherStudentId(studentId)) {
    throw ArgumentError.value(
      studentId,
      'studentId',
      'Must be a canonical UUID.',
    );
  }
  return '${_resultsPath(topicId)}/${Uri.encodeComponent(studentId)}';
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
