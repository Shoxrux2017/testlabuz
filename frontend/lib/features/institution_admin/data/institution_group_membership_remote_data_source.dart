import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_group_membership.dart';
import '../domain/institution_group_membership_mutation.dart';
import '../domain/institution_group_membership_query.dart';
import 'dto/institution_group_dto.dart';
import 'dto/institution_group_membership_dto.dart';
import 'dto/institution_group_membership_list_dto.dart';
import 'dto/institution_group_membership_mutation_dto.dart';

final institutionGroupMembershipRemoteDataSourceProvider =
    Provider<InstitutionGroupMembershipRemoteDataSource>((ref) {
      return InstitutionGroupMembershipRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionGroupMembershipRemoteDataSource {
  const InstitutionGroupMembershipRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionGroupMembershipListDto> fetchMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipQuery query,
  }) async {
    if (!isCanonicalInstitutionGroupId(groupId)) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Institution Group membership target is not canonical.',
        ),
      );
    }
    try {
      final response = await dio.get<Object?>(
        _collectionPath(groupId, kind),
        queryParameters: query.toQueryParameters(),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Institution Group membership list success status must be 200.',
        );
      }
      return InstitutionGroupMembershipListDto.fromJson(
        response.data,
        requestedQuery: query,
      );
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

  Future<InstitutionGroupMembershipMutationDto> assignMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipAssignmentRequest request,
  }) async {
    if (!isCanonicalInstitutionGroupId(groupId)) {
      throw ArgumentError('Institution Group assignment target must be valid.');
    }
    try {
      final response = await dio.post<Object?>(
        _collectionPath(groupId, kind),
        data: request.toJson(kind),
        options: Options(
          contentType: Headers.jsonContentType,
          followRedirects: false,
        ),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const InstitutionGroupMembershipMutationOutcomeUnknownException();
      }
      try {
        return InstitutionGroupMembershipMutationDto.fromJson(
          response.data,
          kind: kind,
          submittedIds: request.memberIds,
        );
      } on FormatException {
        throw const InstitutionGroupMembershipMutationOutcomeUnknownException();
      }
    } on InstitutionGroupMembershipMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteMembershipFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const InstitutionGroupMembershipMutationOutcomeUnknownException();
    } catch (_) {
      throw const InstitutionGroupMembershipMutationOutcomeUnknownException();
    }
  }

  Future<void> removeMembership({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required String memberId,
  }) async {
    if (!isCanonicalInstitutionGroupId(groupId) ||
        !isCanonicalInstitutionGroupMembershipId(memberId)) {
      throw ArgumentError('Institution Group removal targets must be valid.');
    }
    try {
      final response = await dio.delete<Object?>(
        '${_collectionPath(groupId, kind)}/${Uri.encodeComponent(memberId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 204 ||
          (response.data != null && response.data != '')) {
        throw const InstitutionGroupMembershipMutationOutcomeUnknownException();
      }
    } on InstitutionGroupMembershipMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteMembershipFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const InstitutionGroupMembershipMutationOutcomeUnknownException();
    } catch (_) {
      throw const InstitutionGroupMembershipMutationOutcomeUnknownException();
    }
  }

  String _collectionPath(String groupId, InstitutionGroupMemberKind kind) =>
      '/institution/groups/${Uri.encodeComponent(groupId)}/${kind.endpointSegment}';
}

bool _isExactDefiniteMembershipFailure(Response<Object?>? response) {
  final status = response?.statusCode;
  final envelope = _readExactMembershipErrorEnvelope(response?.data);
  if (status == null || envelope == null) {
    return false;
  }
  final matchesPair = switch (status) {
    401 => envelope.code == ApiErrorCodes.authenticationRequired,
    403 =>
      envelope.code == ApiErrorCodes.forbidden ||
          envelope.code == ApiErrorCodes.passwordChangeRequired ||
          envelope.code == ApiErrorCodes.userInactive ||
          envelope.code == ApiErrorCodes.institutionInactive,
    404 => envelope.code == ApiErrorCodes.resourceNotFound,
    409 => envelope.code == ApiErrorCodes.businessConflict,
    422 => envelope.code == ApiErrorCodes.validationFailed,
    429 => envelope.code == ApiErrorCodes.rateLimited,
    _ => false,
  };
  return matchesPair && (status == 422 || envelope.errors.isEmpty);
}

_ExactMembershipErrorEnvelope? _readExactMembershipErrorEnvelope(
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
  return _ExactMembershipErrorEnvelope(code: code, errors: errors);
}

class _ExactMembershipErrorEnvelope {
  const _ExactMembershipErrorEnvelope({
    required this.code,
    required this.errors,
  });

  final String code;
  final Map<String, List<String>> errors;
}
