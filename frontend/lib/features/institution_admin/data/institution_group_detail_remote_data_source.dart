import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import 'dto/institution_group_detail_dto.dart';
import 'dto/institution_group_dto.dart';

final institutionGroupDetailRemoteDataSourceProvider =
    Provider<InstitutionGroupDetailRemoteDataSource>((ref) {
      return InstitutionGroupDetailRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionGroupDetailRemoteDataSource {
  const InstitutionGroupDetailRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionGroupDetailDto> fetchGroup(String groupId) async {
    if (!isCanonicalInstitutionGroupId(groupId)) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Institution Group detail target is not canonical.',
        ),
      );
    }

    try {
      final response = await dio.get<Object?>(
        '/institution/groups/${Uri.encodeComponent(groupId)}',
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Institution Group detail success status must be 200.',
        );
      }

      return InstitutionGroupDetailDto.fromJson(response.data);
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 404 &&
          !_isExactResourceNotFoundEnvelope(exception.response?.data)) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            statusCode: 404,
            message: 'Invalid Institution Group detail error response.',
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
}

bool _isExactResourceNotFoundEnvelope(Object? value) {
  if (value is! Map) {
    return false;
  }

  final map = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      return false;
    }
    map[entry.key as String] = entry.value;
  }

  const requiredKeys = {'message', 'code', 'errors'};
  const allowedKeys = {...requiredKeys, 'request_id'};
  if (map.length < requiredKeys.length ||
      !map.keys.toSet().containsAll(requiredKeys) ||
      map.keys.any((key) => !allowedKeys.contains(key))) {
    return false;
  }

  final message = map['message'];
  final code = map['code'];
  final errors = map['errors'];
  final requestId = map['request_id'];

  return message is String &&
      message.trim().isNotEmpty &&
      code == ApiErrorCodes.resourceNotFound &&
      errors is Map &&
      errors.isEmpty &&
      (!map.containsKey('request_id') ||
          (requestId is String && requestId.isNotEmpty));
}
