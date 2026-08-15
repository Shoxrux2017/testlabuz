import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_user_mutation.dart';
import 'dto/institution_user_dto.dart';
import 'dto/institution_user_mutation_dto.dart';

final institutionUserMutationRemoteDataSourceProvider =
    Provider<InstitutionUserMutationRemoteDataSource>((ref) {
      return InstitutionUserMutationRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionUserMutationRemoteDataSource {
  const InstitutionUserMutationRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionUserMutationDto> updateUser(
    String userId,
    InstitutionUserEditRequest request,
  ) {
    if (!isCanonicalInstitutionUserId(userId) || request.isEmpty) {
      throw ArgumentError(
        'Institution User PATCH requires a valid target and changes.',
      );
    }
    return _sendMutation(
      () => dio.patch<Object?>(
        '/institution/users/${Uri.encodeComponent(userId)}',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedMessage: 'Institution user updated successfully.',
    );
  }

  Future<InstitutionUserMutationDto> changeLifecycle(
    String userId,
    InstitutionUserLifecycleAction action,
  ) {
    if (!isCanonicalInstitutionUserId(userId)) {
      throw ArgumentError('Institution User lifecycle target must be valid.');
    }
    return _sendMutation(
      () => dio.post<Object?>(
        '/institution/users/${Uri.encodeComponent(userId)}/${action.endpointSegment}',
        options: Options(followRedirects: false),
      ),
      expectedMessage: action == InstitutionUserLifecycleAction.activate
          ? 'Institution user activated successfully.'
          : 'Institution user deactivated successfully.',
    );
  }

  Future<InstitutionUserMutationDto> _sendMutation(
    Future<Response<Object?>> Function() send, {
    required String expectedMessage,
  }) async {
    try {
      final response = await send();
      if (response.statusCode != 200) {
        throw const InstitutionUserMutationOutcomeUnknownException();
      }
      try {
        return InstitutionUserMutationDto.fromJson(
          response.data,
          expectedMessage: expectedMessage,
        );
      } on FormatException {
        throw const InstitutionUserMutationOutcomeUnknownException();
      }
    } on InstitutionUserMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteMutationFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const InstitutionUserMutationOutcomeUnknownException();
    } catch (exception) {
      if (exception is ArgumentError) {
        rethrow;
      }
      throw const InstitutionUserMutationOutcomeUnknownException();
    }
  }
}

bool _isExactDefiniteMutationFailure(Response<Object?>? response) {
  final status = response?.statusCode;
  final envelope = _readExactErrorEnvelope(response?.data);
  if (status == null || envelope == null || status < 400 || status >= 500) {
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
    422 => code == ApiErrorCodes.validationFailed,
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
  if (!map.keys.toSet().containsAll(required) ||
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
    for (final value in entry.value as List) {
      if (value is! String || value.isEmpty) {
        return null;
      }
      messages.add(value);
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
