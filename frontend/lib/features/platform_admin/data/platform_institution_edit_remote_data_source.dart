import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/platform_institution_edit.dart';
import '../domain/platform_institution_edit_repository.dart';
import 'dto/platform_institution_edit_dto.dart';

final platformInstitutionEditRemoteDataSourceProvider =
    Provider<PlatformInstitutionEditRemoteDataSource>((ref) {
      return PlatformInstitutionEditRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class PlatformInstitutionEditRemoteDataSource {
  const PlatformInstitutionEditRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<PlatformInstitutionEditResponseDto> updateInstitution(
    String institutionId,
    PlatformInstitutionEditRequest request,
  ) {
    if (request.isEmpty) {
      throw ArgumentError.value(
        request,
        'request',
        'Institution edit PATCH requires changed fields.',
      );
    }

    return _mapFailures(() async {
      final encodedInstitutionId = Uri.encodeComponent(institutionId);
      final response = await dio.patch<Object?>(
        '/platform/institutions/$encodedInstitutionId',
        data: request.toJson(),
      );

      if (response.statusCode != 200) {
        throw const PlatformInstitutionEditOutcomeUnknownException(
          'Institution update returned an unexpected success status.',
        );
      }

      try {
        return PlatformInstitutionEditResponseDto.fromJson(
          response.data,
          requestedInstitutionId: institutionId,
        );
      } on FormatException catch (exception) {
        throw PlatformInstitutionEditOutcomeUnknownException(exception.message);
      }
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on PlatformInstitutionEditOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isAmbiguousTransportException(exception)) {
        throw const PlatformInstitutionEditOutcomeUnknownException(
          'Institution update outcome is unknown.',
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
