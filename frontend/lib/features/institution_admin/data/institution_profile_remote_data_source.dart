import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_profile_repository.dart';
import '../domain/institution_profile_update.dart';
import 'dto/institution_profile_dto.dart';

final institutionProfileRemoteDataSourceProvider =
    Provider<InstitutionProfileRemoteDataSource>((ref) {
      return InstitutionProfileRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionProfileRemoteDataSource {
  const InstitutionProfileRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionProfileGetResponseDto> fetchProfile() async {
    try {
      final response = await dio.get<Object?>('/institution/profile');
      if (response.statusCode != 200) {
        throw const FormatException(
          'Unexpected institution profile response status.',
        );
      }

      return InstitutionProfileGetResponseDto.fromJson(response.data);
    } on DioException catch (exception) {
      throw ApiRequestException(failureMapper.map(exception));
    } on ApiEnvelopeFormatException catch (exception) {
      throw ApiRequestException(_invalidResponse(exception.message));
    } on FormatException catch (exception) {
      throw ApiRequestException(_invalidResponse(exception.message));
    }
  }

  Future<InstitutionProfileUpdateResponseDto> updateProfile(
    InstitutionProfileUpdateRequest request,
  ) async {
    if (request.isEmpty) {
      throw ArgumentError.value(request, 'request', 'Must not be empty.');
    }

    try {
      final response = await dio.patch<Object?>(
        '/institution/profile',
        data: request.toJson(),
      );
      if (response.statusCode != 200) {
        throw const InstitutionProfileUpdateOutcomeUnknownException();
      }

      try {
        if (!_isExactUpdateSuccessResponse(response.data)) {
          throw const InstitutionProfileUpdateOutcomeUnknownException();
        }
        final parsed = InstitutionProfileUpdateResponseDto.fromJson(
          response.data,
        );
        if (!request.matchesProfile(parsed.profile.toDomain())) {
          throw const InstitutionProfileUpdateOutcomeUnknownException();
        }
        return parsed;
      } on ApiEnvelopeFormatException {
        throw const InstitutionProfileUpdateOutcomeUnknownException();
      } on FormatException {
        throw const InstitutionProfileUpdateOutcomeUnknownException();
      }
    } on InstitutionProfileUpdateOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteMutationFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }

      throw const InstitutionProfileUpdateOutcomeUnknownException();
    } catch (exception) {
      if (exception is ArgumentError) {
        rethrow;
      }
      throw const InstitutionProfileUpdateOutcomeUnknownException();
    }
  }
}

bool _isExactUpdateSuccessResponse(Object? value) {
  final envelope = _readExactStringMap(
    value,
    expectedKeys: const {'data', 'message'},
  );
  if (envelope == null ||
      envelope['message'] != institutionProfileUpdateSuccessMessage) {
    return false;
  }

  return _readExactStringMap(
        envelope['data'],
        expectedKeys: const {
          'id',
          'name',
          'type',
          'status',
          'contact_email',
          'contact_phone',
          'address',
          'description',
          'created_at',
          'updated_at',
        },
      ) !=
      null;
}

Map<String, Object?>? _readExactStringMap(
  Object? value, {
  required Set<String> expectedKeys,
}) {
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

  return map.keys.length == expectedKeys.length &&
          map.keys.toSet().containsAll(expectedKeys)
      ? map
      : null;
}

bool _isExactDefiniteMutationFailure(Response<Object?>? response) {
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

ApiFailure _invalidResponse(String message) {
  return ApiFailure.local(
    kind: ApiFailureKind.invalidResponse,
    message: message,
  );
}
