import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_blitz_attempt_exception.dart';
import '../domain/teacher_blitz_list_query.dart';
import '../domain/teacher_blitz_mutation.dart';
import '../domain/teacher_blitz_schedule.dart';
import '../domain/teacher_question_mutation.dart';
import '../domain/teacher_topic.dart';
import 'dto/teacher_blitz_attempt_exception_dto.dart';
import 'dto/teacher_blitz_dto.dart';
import 'dto/teacher_blitz_list_dto.dart';
import 'dto/teacher_blitz_monitoring_dto.dart';
import 'dto/teacher_blitz_operation_dto.dart';
import 'dto/teacher_dto_parse.dart';
import 'dto/teacher_question_mutation_messages.dart';
import 'teacher_mutation_transport.dart';

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
    _requireTopicId(topicId);
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
    _requireCanonicalId(blitzId, 'blitzId');
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

  /// One read; the monitoring controller owns any repeated polling.
  Future<TeacherBlitzMonitoringDto> fetchMonitoring(String blitzId) {
    _requireCanonicalId(blitzId, 'blitzId');
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/blitz/${Uri.encodeComponent(blitzId)}/monitoring',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Blitz monitoring success status must be 200.',
        );
      }
      return TeacherBlitzMonitoringDto.fromJson(response.data);
    });
  }

  Future<TeacherBlitzMutationDto> createBlitz(
    String topicId,
    TeacherBlitzCreateRequest request,
  ) {
    _requireTopicId(topicId);
    return _sendBlitzMutation(
      () => dio.post<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}/blitz',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 201,
      expectedMessage: TeacherBlitzMutationDto.createSuccessMessage,
      conflictCodes: const {ApiErrorCodes.topicNotEditable},
    );
  }

  Future<TeacherBlitzMutationDto> updateBlitz(
    String blitzId,
    TeacherBlitzEditRequest request,
  ) {
    if (!canonicalUuidPattern.hasMatch(blitzId) || request.isEmpty) {
      throw ArgumentError(
        'Teacher Blitz PATCH requires a canonical target and changed fields.',
      );
    }
    return _sendBlitzMutation(
      () => dio.patch<Object?>(
        '/teacher/blitz/${Uri.encodeComponent(blitzId)}',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherBlitzMutationDto.updateSuccessMessage,
      conflictCodes: const {
        ApiErrorCodes.topicNotEditable,
        ApiErrorCodes.taskClosed,
        ApiErrorCodes.taskArchived,
        ApiErrorCodes.businessConflict,
        ApiErrorCodes.officialTaskRequiresGroupAssignment,
      },
    );
  }

  Future<TeacherBlitzMutationDto> addQuestion(
    String blitzId,
    TeacherQuestionCreateRequest request,
  ) {
    _requireCanonicalId(blitzId, 'blitzId');
    return _sendQuestionMutation(
      () => dio.post<Object?>(
        '/teacher/assessments/${Uri.encodeComponent(blitzId)}/questions',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 201,
      expectedMessage: TeacherQuestionMutationMessages.added,
      operation: TeacherQuestionMutationOperation.add,
    );
  }

  Future<TeacherBlitzMutationDto> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  ) {
    if (!canonicalUuidPattern.hasMatch(questionId) || request.isEmpty) {
      throw ArgumentError(
        'Teacher Question PATCH requires a canonical target and changed fields.',
      );
    }
    return _sendQuestionMutation(
      () => dio.patch<Object?>(
        '/teacher/questions/${Uri.encodeComponent(questionId)}',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherQuestionMutationMessages.updated,
      operation: TeacherQuestionMutationOperation.update,
    );
  }

  Future<TeacherBlitzMutationDto> deleteQuestion(String questionId) {
    _requireCanonicalId(questionId, 'questionId');
    return _sendQuestionMutation(
      () => dio.delete<Object?>(
        '/teacher/questions/${Uri.encodeComponent(questionId)}',
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherQuestionMutationMessages.deleted,
      operation: TeacherQuestionMutationOperation.delete,
    );
  }

  Future<TeacherBlitzMutationDto> reorderQuestions(
    String blitzId,
    TeacherQuestionReorderRequest request,
  ) {
    _requireCanonicalId(blitzId, 'blitzId');
    return _sendQuestionMutation(
      () => dio.post<Object?>(
        '/teacher/assessments/${Uri.encodeComponent(blitzId)}/questions/reorder',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherQuestionMutationMessages.reordered,
      operation: TeacherQuestionMutationOperation.reorder,
    );
  }

  Future<TeacherBlitzMutationDto> scheduleBlitz(
    String blitzId,
    TeacherBlitzScheduleRequest request,
  ) {
    _requireCanonicalId(blitzId, 'blitzId');
    return _sendBlitzMutation(
      () => dio.post<Object?>(
        '/teacher/blitz/${Uri.encodeComponent(blitzId)}/schedule',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherBlitzMutationDto.scheduleSuccessMessage,
      conflictCodes: const {
        ApiErrorCodes.taskClosed,
        ApiErrorCodes.taskArchived,
        ApiErrorCodes.businessConflict,
        ApiErrorCodes.topicNotEditable,
      },
    );
  }

  Future<TeacherBlitzMutationDto> activateBlitz(
    String blitzId, {
    required String idempotencyKey,
  }) {
    _requireCanonicalId(blitzId, 'blitzId');
    _requireCanonicalId(idempotencyKey, 'idempotencyKey');
    return _sendBlitzMutation(
      () => dio.post<Object?>(
        '/teacher/blitz/${Uri.encodeComponent(blitzId)}/activate',
        options: Options(
          followRedirects: false,
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherBlitzMutationDto.activateSuccessMessage,
      conflictCodes: const {
        ApiErrorCodes.idempotencyKeyReused,
        ApiErrorCodes.taskClosed,
        ApiErrorCodes.taskArchived,
        ApiErrorCodes.topicNotEditable,
        ApiErrorCodes.institutionSettingsIncomplete,
        ApiErrorCodes.assessmentHasNoScoreablePoints,
        ApiErrorCodes.assessmentNotAssigned,
        ApiErrorCodes.officialCohortMismatch,
        ApiErrorCodes.businessConflict,
      },
    );
  }

  Future<TeacherBlitzMutationDto> closeBlitz(String blitzId) {
    _requireCanonicalId(blitzId, 'blitzId');
    return _sendBlitzMutation(
      () => dio.post<Object?>(
        '/teacher/blitz/${Uri.encodeComponent(blitzId)}/close',
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherBlitzMutationDto.closeSuccessMessage,
      conflictCodes: const {
        ApiErrorCodes.taskNotActive,
        ApiErrorCodes.taskArchived,
        ApiErrorCodes.topicNotEditable,
        ApiErrorCodes.businessConflict,
      },
    );
  }

  Future<TeacherBlitzMutationDto> archiveBlitz(String blitzId) {
    _requireCanonicalId(blitzId, 'blitzId');
    return _sendBlitzMutation(
      () => dio.post<Object?>(
        '/teacher/blitz/${Uri.encodeComponent(blitzId)}/archive',
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherBlitzMutationDto.archiveSuccessMessage,
      conflictCodes: const {ApiErrorCodes.businessConflict},
    );
  }

  Future<TeacherBlitzAttemptExceptionDto> grantAttemptException(
    String blitzId,
    String studentId,
    TeacherBlitzAttemptExceptionRequest request, {
    required String idempotencyKey,
  }) {
    _requireCanonicalId(blitzId, 'blitzId');
    _requireCanonicalId(studentId, 'studentId');
    _requireCanonicalId(idempotencyKey, 'idempotencyKey');
    return sendTeacherMutation(
      send: () => dio.post<Object?>(
        '/teacher/blitz/${Uri.encodeComponent(blitzId)}/students/'
        '${Uri.encodeComponent(studentId)}/attempt-exception',
        data: request.toJson(),
        options: Options(
          followRedirects: false,
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      ),
      expectedStatus: 201,
      parse: (data) => TeacherBlitzAttemptExceptionDto.fromJson(
        data,
        expectedBlitzId: blitzId,
        expectedStudentId: studentId,
      ),
      conflictCodes: const {
        ApiErrorCodes.blitzAttemptExceptionAlreadyGranted,
        ApiErrorCodes.blitzAttemptExceptionNotAllowed,
        ApiErrorCodes.blitzNormalAttemptRequired,
        ApiErrorCodes.idempotencyKeyReused,
      },
      failureMapper: failureMapper,
      outcomeUnknown: () =>
          const TeacherBlitzAttemptExceptionOutcomeUnknownException(),
    );
  }

  Future<TeacherBlitzMutationDto> _sendBlitzMutation(
    Future<Response<Object?>> Function() send, {
    required int expectedStatus,
    required String expectedMessage,
    required Set<String> conflictCodes,
  }) {
    return sendTeacherMutation(
      send: send,
      expectedStatus: expectedStatus,
      parse: (data) => TeacherBlitzMutationDto.fromJson(
        data,
        expectedMessage: expectedMessage,
      ),
      conflictCodes: conflictCodes,
      failureMapper: failureMapper,
      outcomeUnknown: () => const TeacherBlitzMutationOutcomeUnknownException(),
    );
  }

  Future<TeacherBlitzMutationDto> _sendQuestionMutation(
    Future<Response<Object?>> Function() send, {
    required int expectedStatus,
    required String expectedMessage,
    required TeacherQuestionMutationOperation operation,
  }) {
    return sendTeacherMutation(
      send: send,
      expectedStatus: expectedStatus,
      parse: (data) => TeacherBlitzMutationDto.fromJson(
        data,
        expectedMessage: expectedMessage,
      ),
      conflictCodes: _blitzQuestionConflictCodes,
      failureMapper: failureMapper,
      outcomeUnknown: () =>
          TeacherQuestionMutationOutcomeUnknownException(operation),
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

// Result-pair locks and scoreable-point rules apply to Homework only.
const _blitzQuestionConflictCodes = {
  ApiErrorCodes.topicNotEditable,
  ApiErrorCodes.taskClosed,
  ApiErrorCodes.taskArchived,
  ApiErrorCodes.businessConflict,
};

void _requireTopicId(String topicId) {
  if (!isCanonicalTeacherTopicId(topicId)) {
    throw ArgumentError.value(topicId, 'topicId', 'Must be a canonical UUID.');
  }
}

void _requireCanonicalId(String value, String name) {
  if (!canonicalUuidPattern.hasMatch(value)) {
    throw ArgumentError.value(value, name, 'Must be a canonical UUID.');
  }
}
