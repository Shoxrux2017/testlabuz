import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_parent_student_relationship.dart';
import '../domain/institution_parent_student_relationship_mutation.dart';
import '../domain/institution_parent_student_relationship_query.dart';
import 'dto/institution_parent_student_relationship_list_dto.dart';
import 'dto/institution_parent_student_relationship_mutation_dto.dart';

final institutionParentStudentRelationshipRemoteDataSourceProvider =
    Provider<InstitutionParentStudentRelationshipRemoteDataSource>((ref) {
      return InstitutionParentStudentRelationshipRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionParentStudentRelationshipRemoteDataSource {
  const InstitutionParentStudentRelationshipRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionParentStudentRelationshipListDto> fetchRelationships({
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
    required InstitutionParentStudentRelationshipQuery query,
  }) async {
    if (!isCanonicalParentStudentUuid(anchorId)) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Relationship anchor is not a canonical UUID.',
        ),
      );
    }
    try {
      final response = await dio.get<Object?>(
        _listPath(perspective, anchorId),
        queryParameters: query.toQueryParameters(),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Parent-Student relationship list success status must be 200.',
        );
      }
      return InstitutionParentStudentRelationshipListDto.fromJson(
        response.data,
        perspective: perspective,
        anchorId: anchorId,
        requestedQuery: query,
      );
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 404 &&
          !_isExactRelationshipFailure(
            exception.response,
            expectedCode: ApiErrorCodes.resourceNotFound,
          )) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            statusCode: 404,
            message: 'Invalid relationship list not-found response.',
          ),
        );
      }
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

  Future<InstitutionParentStudentRelationshipMutationDto> connect(
    InstitutionParentStudentConnectRequest request,
  ) async {
    try {
      final response = await dio.post<Object?>(
        '/institution/parent-student-relationships',
        data: request.toJson(),
        options: Options(
          contentType: Headers.jsonContentType,
          followRedirects: false,
        ),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const InstitutionParentStudentMutationOutcomeUnknownException();
      }
      try {
        return InstitutionParentStudentRelationshipMutationDto.fromJson(
          response.data,
          submitted: request,
        );
      } on FormatException {
        throw const InstitutionParentStudentMutationOutcomeUnknownException();
      }
    } on InstitutionParentStudentMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteMutationFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const InstitutionParentStudentMutationOutcomeUnknownException();
    } catch (_) {
      throw const InstitutionParentStudentMutationOutcomeUnknownException();
    }
  }

  Future<void> disconnect(String relationshipId) async {
    if (!isCanonicalParentStudentUuid(relationshipId)) {
      throw ArgumentError('Relationship target must be a canonical UUID.');
    }
    try {
      final response = await dio.delete<Object?>(
        '/institution/parent-student-relationships/'
        '${Uri.encodeComponent(relationshipId)}',
        options: Options(followRedirects: false),
      );
      if (response.statusCode != 204 ||
          (response.data != null && response.data != '')) {
        throw const InstitutionParentStudentMutationOutcomeUnknownException();
      }
    } on InstitutionParentStudentMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isExactDefiniteMutationFailure(exception.response)) {
        throw ApiRequestException(failureMapper.map(exception));
      }
      throw const InstitutionParentStudentMutationOutcomeUnknownException();
    } catch (_) {
      throw const InstitutionParentStudentMutationOutcomeUnknownException();
    }
  }

  String _listPath(
    InstitutionParentStudentPerspective perspective,
    String anchorId,
  ) {
    final encoded = Uri.encodeComponent(anchorId);
    return switch (perspective) {
      InstitutionParentStudentPerspective.byParent =>
        '/institution/parents/$encoded/students',
      InstitutionParentStudentPerspective.byStudent =>
        '/institution/students/$encoded/parents',
    };
  }
}

bool _isExactDefiniteMutationFailure(Response<Object?>? response) {
  final status = response?.statusCode;
  final envelope = _readExactRelationshipErrorEnvelope(response?.data);
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

bool _isExactRelationshipFailure(
  Response<Object?>? response, {
  required String expectedCode,
}) {
  final envelope = _readExactRelationshipErrorEnvelope(response?.data);
  return envelope != null &&
      envelope.code == expectedCode &&
      envelope.errors.isEmpty;
}

_ExactRelationshipErrorEnvelope? _readExactRelationshipErrorEnvelope(
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
  return _ExactRelationshipErrorEnvelope(code: code, errors: errors);
}

class _ExactRelationshipErrorEnvelope {
  const _ExactRelationshipErrorEnvelope({
    required this.code,
    required this.errors,
  });

  final String code;
  final Map<String, List<String>> errors;
}
