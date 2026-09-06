import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_result_pair.dart';
import 'dto/teacher_topic_result_pair_operation_dto.dart';

final teacherTopicResultPairRemoteDataSourceProvider =
    Provider<TeacherTopicResultPairRemoteDataSource>((ref) {
      return TeacherTopicResultPairRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class TeacherTopicResultPairRemoteDataSource {
  const TeacherTopicResultPairRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<TeacherTopicResultPairReadDto> fetchResultPair(String topicId) {
    _requireTopicId(topicId);
    return _mapReadFailures(() async {
      final response = await dio.get<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}/result-pair',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Teacher Topic result pair read success status must be 200.',
        );
      }
      return TeacherTopicResultPairReadDto.fromJson(response.data);
    });
  }

  Future<TeacherTopicResultPairMutationDto> setOfficialHomework(
    String topicId,
    String homeworkId,
  ) {
    _requireTopicId(topicId);
    if (!isCanonicalTeacherHomeworkId(homeworkId)) {
      throw ArgumentError.value(
        homeworkId,
        'homeworkId',
        'Must be a canonical UUID.',
      );
    }

    return _sendMutation(
      () => dio.put<Object?>(
        '/teacher/topics/${Uri.encodeComponent(topicId)}/result-pair',
        data: <String, Object?>{'homework_assessment_id': homeworkId},
        options: Options(followRedirects: false),
      ),
    );
  }

  Future<TeacherTopicResultPairMutationDto> _sendMutation(
    Future<Response<Object?>> Function() send,
  ) async {
    try {
      final response = await send();
      if (response.statusCode != 200) {
        throw const TeacherTopicResultPairMutationOutcomeUnknownException();
      }
      try {
        return TeacherTopicResultPairMutationDto.fromJson(response.data);
      } on FormatException {
        throw const TeacherTopicResultPairMutationOutcomeUnknownException();
      }
    } on TeacherTopicResultPairMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteResultPairMutationFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const TeacherTopicResultPairMutationOutcomeUnknownException();
    } catch (_) {
      throw const TeacherTopicResultPairMutationOutcomeUnknownException();
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

void _requireTopicId(String topicId) {
  if (!isCanonicalTeacherTopicId(topicId)) {
    throw ArgumentError.value(topicId, 'topicId', 'Must be a canonical UUID.');
  }
}

bool _isExactDefiniteResultPairMutationFailure(Response<Object?>? response) {
  final status = response?.statusCode;
  final envelope = _readExactResultPairErrorEnvelope(response?.data);
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
    409 =>
      code == ApiErrorCodes.topicNotEditable ||
          code == ApiErrorCodes.officialTaskRequiresGroupAssignment ||
          code == ApiErrorCodes.businessConflict ||
          code == ApiErrorCodes.resultPairLocked,
    422 => code == ApiErrorCodes.validationFailed,
    429 => code == ApiErrorCodes.rateLimited,
    _ => false,
  };

  return recognized && (status == 422 || envelope.errors.isEmpty);
}

_ExactResultPairErrorEnvelope? _readExactResultPairErrorEnvelope(
  Object? value,
) {
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

  return _ExactResultPairErrorEnvelope(code: code, errors: errors);
}

class _ExactResultPairErrorEnvelope {
  const _ExactResultPairErrorEnvelope({
    required this.code,
    required this.errors,
  });

  final String code;
  final Map<String, List<String>> errors;
}
