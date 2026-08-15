import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_user_create.dart';
import 'dto/institution_user_create_dto.dart';

final institutionUserCreateRemoteDataSourceProvider =
    Provider<InstitutionUserCreateRemoteDataSource>((ref) {
      return InstitutionUserCreateRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionUserCreateRemoteDataSource {
  const InstitutionUserCreateRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionUserCreateDto> createUser(
    InstitutionUserCreateRequest request,
  ) async {
    try {
      final response = await dio.post<Object?>(
        '/institution/users',
        data: request.toJson(),
      );
      if (response.statusCode != 201) {
        throw const InstitutionUserCreateOutcomeUnknownException();
      }

      try {
        return InstitutionUserCreateDto.fromJson(response.data);
      } on FormatException {
        throw const InstitutionUserCreateOutcomeUnknownException();
      }
    } on DioException catch (exception) {
      if (_isExactDefiniteFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }

      throw const InstitutionUserCreateOutcomeUnknownException();
    }
  }
}

bool _isExactDefiniteFailure(Response<Object?>? response) {
  final statusCode = response?.statusCode;
  final envelope = _readExactErrorEnvelope(response?.data);
  if (statusCode == null || envelope == null) {
    return false;
  }

  final code = envelope.code;
  final expectedCode = switch (statusCode) {
    401 => code == ApiErrorCodes.authenticationRequired,
    403 =>
      code == ApiErrorCodes.forbidden ||
          code == ApiErrorCodes.passwordChangeRequired ||
          code == ApiErrorCodes.userInactive ||
          code == ApiErrorCodes.institutionInactive,
    422 => code == ApiErrorCodes.validationFailed,
    429 => code == ApiErrorCodes.rateLimited,
    _ => false,
  };
  if (!expectedCode) {
    return false;
  }

  return statusCode == 422 || envelope.errors.isEmpty;
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

  const requiredKeys = {'message', 'code', 'errors'};
  const allowedKeys = {...requiredKeys, 'request_id'};
  if (!map.keys.toSet().containsAll(requiredKeys) ||
      map.keys.any((key) => !allowedKeys.contains(key))) {
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
    final key = entry.key;
    final messages = entry.value;
    if (key is! String || messages is! List || messages.isEmpty) {
      return null;
    }
    final parsedMessages = <String>[];
    for (final message in messages) {
      if (message is! String || message.isEmpty) {
        return null;
      }
      parsedMessages.add(message);
    }
    errors[key] = parsedMessages;
  }

  return _ExactErrorEnvelope(code: code, errors: errors);
}

class _ExactErrorEnvelope {
  const _ExactErrorEnvelope({required this.code, required this.errors});

  final String code;
  final Map<String, List<String>> errors;
}
