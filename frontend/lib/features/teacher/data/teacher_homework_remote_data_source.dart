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
  }) async {
    try {
      final response = await send();
      if (response.statusCode != expectedStatus) {
        throw const TeacherHomeworkMutationOutcomeUnknownException();
      }
      try {
        return TeacherHomeworkMutationDto.fromJson(
          response.data,
          expectedMessage: expectedMessage,
        );
      } on FormatException {
        throw const TeacherHomeworkMutationOutcomeUnknownException();
      }
    } on TeacherHomeworkMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactHomeworkMutationFailure(
        exception.response,
        operation,
        lifecycleAction: lifecycleAction,
      )) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const TeacherHomeworkMutationOutcomeUnknownException();
    } catch (_) {
      throw const TeacherHomeworkMutationOutcomeUnknownException();
    }
  }

  Future<TeacherHomeworkMutationDto> _sendQuestionMutation(
    Future<Response<Object?>> Function() send, {
    required int expectedStatus,
    required String expectedMessage,
    required TeacherQuestionMutationOperation operation,
  }) async {
    try {
      final response = await send();
      if (response.statusCode != expectedStatus) {
        throw TeacherQuestionMutationOutcomeUnknownException(operation);
      }
      try {
        return TeacherHomeworkMutationDto.fromJson(
          response.data,
          expectedMessage: expectedMessage,
        );
      } on FormatException {
        throw TeacherQuestionMutationOutcomeUnknownException(operation);
      }
    } on TeacherQuestionMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactQuestionMutationFailure(exception.response, operation)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw TeacherQuestionMutationOutcomeUnknownException(operation);
    } catch (_) {
      throw TeacherQuestionMutationOutcomeUnknownException(operation);
    }
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

bool _isExactHomeworkMutationFailure(
  Response<Object?>? response,
  _TeacherHomeworkMutationOperation operation, {
  TeacherHomeworkLifecycleAction? lifecycleAction,
}) {
  final status = response?.statusCode;
  final envelope = _readExactHomeworkErrorEnvelope(response?.data);
  if (status == null || envelope == null) {
    return false;
  }

  final code = envelope.code;
  final recognized = switch (status) {
    401 => code == ApiErrorCodes.authenticationRequired,
    403 =>
      code == ApiErrorCodes.forbidden ||
          code == ApiErrorCodes.passwordChangeRequired ||
          code == ApiErrorCodes.userInactive ||
          code == ApiErrorCodes.institutionInactive,
    404 => code == ApiErrorCodes.resourceNotFound,
    409 when operation == _TeacherHomeworkMutationOperation.create =>
      code == ApiErrorCodes.topicNotEditable,
    409 when operation == _TeacherHomeworkMutationOperation.lifecycle =>
      _isDocumentedLifecycleConflict(code, lifecycleAction),
    409 =>
      code == ApiErrorCodes.topicNotEditable ||
          code == ApiErrorCodes.taskClosed ||
          code == ApiErrorCodes.taskArchived ||
          code == ApiErrorCodes.businessConflict ||
          code == ApiErrorCodes.officialTaskRequiresGroupAssignment,
    422 => code == ApiErrorCodes.validationFailed,
    429 => code == ApiErrorCodes.rateLimited,
    _ => false,
  };

  return recognized && (status == 422 || envelope.errors.isEmpty);
}

bool _isDocumentedLifecycleConflict(
  String code,
  TeacherHomeworkLifecycleAction? action,
) {
  return switch (action) {
    TeacherHomeworkLifecycleAction.activate =>
      code == ApiErrorCodes.topicNotEditable ||
          code == ApiErrorCodes.taskClosed ||
          code == ApiErrorCodes.taskArchived ||
          code == ApiErrorCodes.businessConflict ||
          code == ApiErrorCodes.resultPairLocked ||
          code == ApiErrorCodes.assessmentHasNoScoreablePoints ||
          code == ApiErrorCodes.assessmentNotAssigned ||
          code == ApiErrorCodes.deadlinePassed,
    TeacherHomeworkLifecycleAction.close =>
      code == ApiErrorCodes.taskNotActive ||
          code == ApiErrorCodes.taskArchived ||
          code == ApiErrorCodes.topicNotEditable ||
          code == ApiErrorCodes.businessConflict,
    TeacherHomeworkLifecycleAction.archive =>
      code == ApiErrorCodes.businessConflict,
    null => false,
  };
}

bool _isExactQuestionMutationFailure(
  Response<Object?>? response,
  TeacherQuestionMutationOperation operation,
) {
  final status = response?.statusCode;
  final envelope = _readExactHomeworkErrorEnvelope(response?.data);
  if (status == null || envelope == null) {
    return false;
  }

  final code = envelope.code;
  final recognized = switch (status) {
    401 => code == ApiErrorCodes.authenticationRequired,
    403 =>
      code == ApiErrorCodes.forbidden ||
          code == ApiErrorCodes.passwordChangeRequired ||
          code == ApiErrorCodes.userInactive ||
          code == ApiErrorCodes.institutionInactive,
    404 => code == ApiErrorCodes.resourceNotFound,
    409 => _isDocumentedQuestionConflict(code, operation),
    422 => code == ApiErrorCodes.validationFailed,
    429 => code == ApiErrorCodes.rateLimited,
    _ => false,
  };

  return recognized && (status == 422 || envelope.errors.isEmpty);
}

bool _isDocumentedQuestionConflict(
  String code,
  TeacherQuestionMutationOperation operation,
) {
  final allowedCodes = switch (operation) {
    TeacherQuestionMutationOperation.add ||
    TeacherQuestionMutationOperation.update ||
    TeacherQuestionMutationOperation.delete ||
    TeacherQuestionMutationOperation.reorder => const {
      ApiErrorCodes.topicNotEditable,
      ApiErrorCodes.taskClosed,
      ApiErrorCodes.taskArchived,
      ApiErrorCodes.businessConflict,
      ApiErrorCodes.resultPairLocked,
      ApiErrorCodes.assessmentHasNoScoreablePoints,
    },
  };
  return allowedCodes.contains(code);
}

_ExactHomeworkErrorEnvelope? _readExactHomeworkErrorEnvelope(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      return null;
    }
    map[entry.key as String] = entry.value;
  }

  const required = {'message', 'code', 'errors'};
  const allowed = {...required, 'request_id'};
  if (map.length < required.length ||
      !map.keys.toSet().containsAll(required) ||
      map.keys.any((key) => !allowed.contains(key))) {
    return null;
  }

  final message = map['message'];
  final code = map['code'];
  final requestId = map['request_id'];
  final rawErrors = map['errors'];
  if (message is! String ||
      message.trim().isEmpty ||
      code is! String ||
      code.isEmpty ||
      rawErrors is! Map ||
      (map.containsKey('request_id') &&
          (requestId is! String || requestId.isEmpty))) {
    return null;
  }

  final errors = <String, List<String>>{};
  for (final entry in rawErrors.entries) {
    if (entry.key is! String || entry.value is! List) {
      return null;
    }
    final messages = <String>[];
    for (final item in entry.value as List) {
      if (item is! String || item.isEmpty) {
        return null;
      }
      messages.add(item);
    }
    if (messages.isEmpty) {
      return null;
    }
    errors[entry.key as String] = messages;
  }

  return _ExactHomeworkErrorEnvelope(code: code, errors: errors);
}

class _ExactHomeworkErrorEnvelope {
  const _ExactHomeworkErrorEnvelope({required this.code, required this.errors});

  final String code;
  final Map<String, List<String>> errors;
}
