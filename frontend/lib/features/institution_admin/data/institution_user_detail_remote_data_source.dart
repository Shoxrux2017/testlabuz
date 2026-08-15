import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../data/dto/institution_user_detail_dto.dart';
import '../data/dto/institution_user_dto.dart';

final institutionUserDetailRemoteDataSourceProvider =
    Provider<InstitutionUserDetailRemoteDataSource>((ref) {
      return InstitutionUserDetailRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionUserDetailRemoteDataSource {
  const InstitutionUserDetailRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionUserDetailDto> fetchUser(String userId) async {
    if (!isCanonicalInstitutionUserId(userId)) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Institution User detail target is not canonical.',
        ),
      );
    }

    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/institution/users/${Uri.encodeComponent(userId)}',
      );

      return InstitutionUserDetailDto.fromJson(response.data);
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 404 &&
          !_isValidResourceNotFoundEnvelope(exception.response?.data)) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            statusCode: 404,
            message: 'Invalid Institution User detail error response.',
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

bool _isValidResourceNotFoundEnvelope(Object? value) {
  if (value is! Map) {
    return false;
  }

  final envelope = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      return false;
    }
    envelope[entry.key as String] = entry.value;
  }

  const requiredKeys = {'message', 'code', 'errors'};
  const allowedKeys = {...requiredKeys, 'request_id'};
  if (!envelope.keys.toSet().containsAll(requiredKeys) ||
      envelope.keys.any((key) => !allowedKeys.contains(key))) {
    return false;
  }

  final message = envelope['message'];
  final errors = envelope['errors'];
  final requestId = envelope['request_id'];

  return message is String &&
      message.trim().isNotEmpty &&
      envelope['code'] == ApiErrorCodes.resourceNotFound &&
      errors is Map &&
      errors.isEmpty &&
      (!envelope.containsKey('request_id') ||
          (requestId is String && requestId.isNotEmpty));
}
