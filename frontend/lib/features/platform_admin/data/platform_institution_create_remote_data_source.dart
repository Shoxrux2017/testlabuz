import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/platform_institution_create.dart';
import '../domain/platform_institution_create_repository.dart';
import 'dto/platform_institution_create_dto.dart';

final platformInstitutionCreateRemoteDataSourceProvider =
    Provider<PlatformInstitutionCreateRemoteDataSource>((ref) {
      return PlatformInstitutionCreateRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class PlatformInstitutionCreateRemoteDataSource {
  const PlatformInstitutionCreateRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<PlatformInstitutionCreateResponseDto> createInstitution(
    PlatformInstitutionCreateRequest request,
  ) {
    return _mapFailures(() async {
      final response = await dio.post<Object?>(
        '/platform/institutions',
        data: request.toJson(),
      );

      if (response.statusCode != 201) {
        throw const PlatformInstitutionCreateOutcomeUnknownException(
          'Institution creation returned an unexpected success status.',
        );
      }

      try {
        return PlatformInstitutionCreateResponseDto.fromJson(response.data);
      } on FormatException catch (exception) {
        throw PlatformInstitutionCreateOutcomeUnknownException(
          exception.message,
        );
      }
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on PlatformInstitutionCreateOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isAmbiguousTransportException(exception)) {
        throw const PlatformInstitutionCreateOutcomeUnknownException(
          'Institution creation outcome is unknown.',
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
