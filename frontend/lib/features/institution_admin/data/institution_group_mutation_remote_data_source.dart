import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_group_mutation.dart';
import 'dto/institution_group_dto.dart';
import 'dto/institution_group_mutation_dto.dart';

final institutionGroupMutationRemoteDataSourceProvider =
    Provider<InstitutionGroupMutationRemoteDataSource>((ref) {
      return InstitutionGroupMutationRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionGroupMutationRemoteDataSource {
  const InstitutionGroupMutationRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionGroupMutationDto> updateGroup(
    String groupId,
    InstitutionGroupEditRequest request,
  ) {
    if (!isCanonicalInstitutionGroupId(groupId) || request.isEmpty) {
      throw ArgumentError(
        'Institution Group PATCH requires a valid target and changes.',
      );
    }
    return _sendMutation(
      () => dio.patch<Object?>(
        '/institution/groups/${Uri.encodeComponent(groupId)}',
        data: request.toJson(),
        options: Options(followRedirects: false),
      ),
      expectedMessage: 'Group updated successfully.',
    );
  }

  Future<InstitutionGroupMutationDto> archiveGroup(String groupId) {
    if (!isCanonicalInstitutionGroupId(groupId)) {
      throw ArgumentError('Institution Group archive target must be valid.');
    }
    return _sendMutation(
      () => dio.post<Object?>(
        '/institution/groups/${Uri.encodeComponent(groupId)}/archive',
        options: Options(followRedirects: false),
      ),
      expectedMessage: 'Group archived successfully.',
    );
  }

  Future<InstitutionGroupMutationDto> _sendMutation(
    Future<Response<Object?>> Function() send, {
    required String expectedMessage,
  }) async {
    try {
      final response = await send();
      if (response.statusCode != 200) {
        throw const InstitutionGroupMutationOutcomeUnknownException();
      }
      try {
        return InstitutionGroupMutationDto.fromJson(
          response.data,
          expectedMessage: expectedMessage,
        );
      } on FormatException {
        throw const InstitutionGroupMutationOutcomeUnknownException();
      }
    } on InstitutionGroupMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteMutationFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const InstitutionGroupMutationOutcomeUnknownException();
    } catch (_) {
      throw const InstitutionGroupMutationOutcomeUnknownException();
    }
  }
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
    409 => code == ApiErrorCodes.businessConflict,
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
