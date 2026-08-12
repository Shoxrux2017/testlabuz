import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/platform_institution_lifecycle.dart';
import '../domain/platform_institution_lifecycle_repository.dart';
import 'dto/platform_institution_lifecycle_dto.dart';

final platformInstitutionLifecycleRemoteDataSourceProvider =
    Provider<PlatformInstitutionLifecycleRemoteDataSource>((ref) {
      return PlatformInstitutionLifecycleRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class PlatformInstitutionLifecycleRemoteDataSource {
  const PlatformInstitutionLifecycleRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<PlatformInstitutionLifecycleResponseDto> activateInstitution(
    String institutionId,
  ) {
    return _postLifecycle(
      institutionId,
      PlatformInstitutionLifecycleAction.activate,
    );
  }

  Future<PlatformInstitutionLifecycleResponseDto> deactivateInstitution(
    String institutionId,
  ) {
    return _postLifecycle(
      institutionId,
      PlatformInstitutionLifecycleAction.deactivate,
    );
  }

  Future<PlatformInstitutionLifecycleResponseDto> _postLifecycle(
    String institutionId,
    PlatformInstitutionLifecycleAction action,
  ) {
    return _mapFailures(() async {
      final encodedInstitutionId = Uri.encodeComponent(institutionId);
      final response = await dio.post<Object?>(
        '/platform/institutions/'
        '$encodedInstitutionId/'
        '${action.endpointSegment}',
        data: const <String, Object?>{},
      );

      if (response.statusCode != 200) {
        throw const PlatformInstitutionLifecycleOutcomeUnknownException(
          'Institution lifecycle command returned an unexpected success status.',
        );
      }

      try {
        return PlatformInstitutionLifecycleResponseDto.fromJson(
          response.data,
          requestedInstitutionId: institutionId,
          targetStatus: action.targetStatus,
        );
      } on FormatException catch (exception) {
        throw PlatformInstitutionLifecycleOutcomeUnknownException(
          exception.message,
        );
      }
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on PlatformInstitutionLifecycleOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isAmbiguousTransportException(exception)) {
        throw const PlatformInstitutionLifecycleOutcomeUnknownException(
          'Institution lifecycle command outcome is unknown.',
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

  bool _isAmbiguousTransportException(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => true,
      DioExceptionType.badCertificate ||
      DioExceptionType.badResponse ||
      DioExceptionType.cancel => false,
    };
  }
}
