import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_lifecycle.dart';
import '../domain/teacher_homework_list_query.dart';
import '../domain/teacher_homework_mutation.dart';
import '../domain/teacher_question_mutation.dart';
import '../domain/teacher_topic.dart';
import 'dto/teacher_homework_dto.dart';
import 'dto/teacher_homework_list_dto.dart';
import 'dto/teacher_homework_operation_dto.dart';
import 'teacher_mutation_transport.dart';

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

  Future<TeacherHomeworkMutationDto> createHomework(
    String topicId,
    TeacherHomeworkCreateRequest request,
  ) {
    if (!isCanonicalTeacherTopicId(topicId)) {
      throw ArgumentError.value(
        topicId,
        'topicId',
        'Must be a canonical UUID.',
      );
    }
    return _sendMutation(
      () => dio.post<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}/homework',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 201,
      expectedMessage: TeacherHomeworkMutationDto.createSuccessMessage,
      operation: _TeacherHomeworkMutationOperation.create,
    );
  }

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

  Future<TeacherHomeworkMutationDto> updateHomework(
    String homeworkId,
    TeacherHomeworkEditRequest request,
  ) {
    if (!isCanonicalTeacherHomeworkId(homeworkId) || request.isEmpty) {
      throw ArgumentError(
        'Teacher Homework PATCH requires a canonical target and changed fields.',
      );
    }
    return _sendMutation(
      () => dio.patch<Object?>(
        '/teacher/homework/${Uri.encodeComponent(homeworkId)}',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherHomeworkMutationDto.updateSuccessMessage,
      operation: _TeacherHomeworkMutationOperation.update,
    );
  }

  Future<TeacherHomeworkMutationDto> performLifecycleAction(
    String homeworkId,
    TeacherHomeworkLifecycleAction action,
  ) {
    if (!isCanonicalTeacherHomeworkId(homeworkId)) {
      throw ArgumentError.value(
        homeworkId,
        'homeworkId',
        'Must be a canonical UUID.',
      );
    }
    return _sendMutation(
      () => dio.post<Object?>(
        '/teacher/homework/${Uri.encodeComponent(homeworkId)}/${action.segment}',
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherHomeworkMutationDto.lifecycleSuccessMessage(
        action,
      ),
      operation: _TeacherHomeworkMutationOperation.lifecycle,
      lifecycleAction: action,
    );
  }

  Future<TeacherHomeworkMutationDto> addQuestion(
    String homeworkId,
    TeacherQuestionCreateRequest request,
  ) {
    if (!isCanonicalTeacherHomeworkId(homeworkId)) {
      throw ArgumentError.value(
        homeworkId,
        'homeworkId',
        'Must be a canonical UUID.',
      );
    }
    return _sendQuestionMutation(
      () => dio.post<Object?>(
        '/teacher/assessments/${Uri.encodeComponent(homeworkId)}/questions',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 201,
      expectedMessage: TeacherHomeworkMutationDto.addQuestionSuccessMessage,
      operation: TeacherQuestionMutationOperation.add,
    );
  }

  Future<TeacherHomeworkMutationDto> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  ) {
    if (!isCanonicalTeacherHomeworkId(questionId) || request.isEmpty) {
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
      expectedMessage: TeacherHomeworkMutationDto.updateQuestionSuccessMessage,
      operation: TeacherQuestionMutationOperation.update,
    );
  }

  Future<TeacherHomeworkMutationDto> deleteQuestion(String questionId) {
    if (!isCanonicalTeacherHomeworkId(questionId)) {
      throw ArgumentError.value(
        questionId,
        'questionId',
        'Must be a canonical UUID.',
      );
    }
    return _sendQuestionMutation(
      () => dio.delete<Object?>(
        '/teacher/questions/${Uri.encodeComponent(questionId)}',
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherHomeworkMutationDto.deleteQuestionSuccessMessage,
      operation: TeacherQuestionMutationOperation.delete,
    );
  }

  Future<TeacherHomeworkMutationDto> reorderQuestions(
    String homeworkId,
    TeacherQuestionReorderRequest request,
  ) {
    if (!isCanonicalTeacherHomeworkId(homeworkId)) {
      throw ArgumentError.value(
        homeworkId,
        'homeworkId',
        'Must be a canonical UUID.',
      );
    }
    return _sendQuestionMutation(
      () => dio.post<Object?>(
        '/teacher/assessments/${Uri.encodeComponent(homeworkId)}/questions/reorder',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage:
          TeacherHomeworkMutationDto.reorderQuestionsSuccessMessage,
      operation: TeacherQuestionMutationOperation.reorder,
    );
  }

  Future<TeacherHomeworkMutationDto> _sendMutation(
    Future<Response<Object?>> Function() send, {
    required int expectedStatus,
    required String expectedMessage,
    required _TeacherHomeworkMutationOperation operation,
    TeacherHomeworkLifecycleAction? lifecycleAction,
  }) {
    return sendTeacherMutation(
      send: send,
      expectedStatus: expectedStatus,
      parse: (data) => TeacherHomeworkMutationDto.fromJson(
        data,
        expectedMessage: expectedMessage,
      ),
      conflictCodes: _homeworkConflictCodes(operation, lifecycleAction),
      failureMapper: failureMapper,
      outcomeUnknown: () =>
          const TeacherHomeworkMutationOutcomeUnknownException(),
    );
  }

  Future<TeacherHomeworkMutationDto> _sendQuestionMutation(
    Future<Response<Object?>> Function() send, {
    required int expectedStatus,
    required String expectedMessage,
    required TeacherQuestionMutationOperation operation,
  }) {
    return sendTeacherMutation(
      send: send,
      expectedStatus: expectedStatus,
      parse: (data) => TeacherHomeworkMutationDto.fromJson(
        data,
        expectedMessage: expectedMessage,
      ),
      conflictCodes: _homeworkQuestionConflictCodes,
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

enum _TeacherHomeworkMutationOperation { create, update, lifecycle }

Set<String> _homeworkConflictCodes(
  _TeacherHomeworkMutationOperation operation,
  TeacherHomeworkLifecycleAction? lifecycleAction,
) {
  return switch (operation) {
    _TeacherHomeworkMutationOperation.create => const {
      ApiErrorCodes.topicNotEditable,
    },
    _TeacherHomeworkMutationOperation.lifecycle => switch (lifecycleAction) {
      TeacherHomeworkLifecycleAction.activate => const {
        ApiErrorCodes.topicNotEditable,
        ApiErrorCodes.taskClosed,
        ApiErrorCodes.taskArchived,
        ApiErrorCodes.businessConflict,
        ApiErrorCodes.resultPairLocked,
        ApiErrorCodes.assessmentHasNoScoreablePoints,
        ApiErrorCodes.assessmentNotAssigned,
        ApiErrorCodes.deadlinePassed,
      },
      TeacherHomeworkLifecycleAction.close => const {
        ApiErrorCodes.taskNotActive,
        ApiErrorCodes.taskArchived,
        ApiErrorCodes.topicNotEditable,
        ApiErrorCodes.businessConflict,
      },
      TeacherHomeworkLifecycleAction.archive => const {
        ApiErrorCodes.businessConflict,
      },
      null => const {},
    },
    _TeacherHomeworkMutationOperation.update => const {
      ApiErrorCodes.topicNotEditable,
      ApiErrorCodes.taskClosed,
      ApiErrorCodes.taskArchived,
      ApiErrorCodes.businessConflict,
      ApiErrorCodes.officialTaskRequiresGroupAssignment,
    },
  };
}

const _homeworkQuestionConflictCodes = {
  ApiErrorCodes.topicNotEditable,
  ApiErrorCodes.taskClosed,
  ApiErrorCodes.taskArchived,
  ApiErrorCodes.businessConflict,
  ApiErrorCodes.resultPairLocked,
  ApiErrorCodes.assessmentHasNoScoreablePoints,
};
