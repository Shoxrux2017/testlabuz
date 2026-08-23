import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_mutation.dart';
import 'dto/teacher_topic_operation_dto.dart';

final teacherTopicRemoteDataSourceProvider =
    Provider<TeacherTopicRemoteDataSource>((ref) {
      return TeacherTopicRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class TeacherTopicRemoteDataSource {
  const TeacherTopicRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherTopicMutationDto> createTopic(
    TeacherTopicCreateRequest request,
  ) {
    return _sendMutation(
      () => dio.post<Object?>(
        '/teacher/topics',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 201,
      expectedMessage: TeacherTopicMutationDto.createSuccessMessage,
      operation: _MutationOperation.create,
    );
  }

  Future<TeacherTopicDetailDto> fetchTopic(String topicId) {
    if (!isCanonicalTeacherTopicId(topicId)) {
      throw ArgumentError.value(
        topicId,
        'topicId',
        'Must be a canonical UUID.',
      );
    }

    return _mapReadFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Topic detail success status must be 200.',
        );
      }

      return TeacherTopicDetailDto.fromJson(response.data);
    });
  }

  Future<TeacherTopicMutationDto> updateTopic(
    String topicId,
    TeacherTopicEditRequest request,
  ) {
    if (!isCanonicalTeacherTopicId(topicId) || request.isEmpty) {
      throw ArgumentError(
        'Teacher Topic PATCH requires a canonical target and changed fields.',
      );
    }

    return _sendMutation(
      () => dio.patch<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherTopicMutationDto.updateSuccessMessage,
      operation: _MutationOperation.update,
    );
  }

  Future<TeacherTopicMutationDto> performLifecycleAction(
    String topicId,
    TeacherTopicLifecycleAction action,
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
        '/teacher/topics/${Uri.encodeComponent(topicId)}/${action.segment}',
        options: Options(followRedirects: false),
      ),
      expectedStatus: 200,
      expectedMessage: TeacherTopicMutationDto.lifecycleSuccessMessage(action),
      operation: _MutationOperation.lifecycle,
    );
  }

  Future<TeacherTopicMutationDto> _sendMutation(
    Future<Response<Object?>> Function() send, {
    required int expectedStatus,
    required String expectedMessage,
    required _MutationOperation operation,
  }) async {
    try {
      final response = await send();
      if (response.statusCode != expectedStatus) {
        throw const TeacherTopicMutationOutcomeUnknownException();
      }
      try {
        return TeacherTopicMutationDto.fromJson(
          response.data,
          expectedMessage: expectedMessage,
        );
      } on FormatException {
        throw const TeacherTopicMutationOutcomeUnknownException();
      }
    } on TeacherTopicMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteMutationFailure(exception.response, operation)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const TeacherTopicMutationOutcomeUnknownException();
    } catch (_) {
      throw const TeacherTopicMutationOutcomeUnknownException();
    }
  }

  Future<T> _mapReadFailures<T>(Future<T> Function() request) async {
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

enum _MutationOperation { create, update, lifecycle }

bool _isExactDefiniteMutationFailure(
  Response<Object?>? response,
  _MutationOperation operation,
) {
  final status = response?.statusCode;
  final envelope = _readExactErrorEnvelope(response?.data);
  if (status == null || envelope == null) {
    return false;
  }
  final code = envelope.code;
  final expected = switch (status) {
    401 => code == ApiErrorCodes.authenticationRequired,
    403 =>
      code == ApiErrorCodes.forbidden ||
          code == ApiErrorCodes.passwordChangeRequired ||
          code == ApiErrorCodes.userInactive ||
          code == ApiErrorCodes.institutionInactive,
    404 => code == ApiErrorCodes.resourceNotFound,
    409 when operation != _MutationOperation.create =>
      code == ApiErrorCodes.topicNotEditable,
    422 when operation != _MutationOperation.lifecycle =>
      code == ApiErrorCodes.validationFailed,
    429 => code == ApiErrorCodes.rateLimited,
    _ => false,
  };

  return expected && (status == 422 || envelope.errors.isEmpty);
}

_ExactErrorEnvelope? _readExactErrorEnvelope(Object? value) {
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

  return _ExactErrorEnvelope(code: code, errors: errors);
}

class _ExactErrorEnvelope {
  const _ExactErrorEnvelope({required this.code, required this.errors});

  final String code;
  final Map<String, List<String>> errors;
}
