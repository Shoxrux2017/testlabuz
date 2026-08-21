import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_group_create.dart';
import 'dto/institution_group_create_dto.dart';

final institutionGroupCreateRemoteDataSourceProvider =
    Provider<InstitutionGroupCreateRemoteDataSource>((ref) {
      return InstitutionGroupCreateRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionGroupCreateRemoteDataSource {
  const InstitutionGroupCreateRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionGroupCreateDto> createGroup(
    InstitutionGroupCreateRequest request,
  ) async {
    try {
      final response = await dio.post<Object?>(
        '/institution/groups',
        data: request.toJson(),
      );
      if (response.statusCode != 201) {
        throw const InstitutionGroupCreateOutcomeUnknownException();
      }

      try {
        return InstitutionGroupCreateDto.fromJson(response.data);
      } on FormatException {
        throw const InstitutionGroupCreateOutcomeUnknownException();
      }
    } on DioException catch (exception) {
      if (_isExactDefiniteFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }

      throw const InstitutionGroupCreateOutcomeUnknownException();
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
  final allowedPair = switch (statusCode) {
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

  return allowedPair && (statusCode == 422 || envelope.errors.isEmpty);
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
  if (map.length < requiredKeys.length ||
      !map.keys.toSet().containsAll(requiredKeys) ||
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
    if (entry.key is! String ||
        entry.value is! List ||
        (entry.value as List).isEmpty) {
      return null;
    }

    final messages = <String>[];
    for (final item in entry.value as List) {
      if (item is! String || item.isEmpty) {
        return null;
      }
      messages.add(item);
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
