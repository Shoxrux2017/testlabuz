import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/platform_institution_admin_create.dart';
import '../domain/platform_institution_admin_list_query.dart';
import 'dto/platform_institution_admin_dto.dart';

final platformInstitutionAdminRemoteDataSourceProvider =
    Provider<PlatformInstitutionAdminRemoteDataSource>((ref) {
      return PlatformInstitutionAdminRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class PlatformInstitutionAdminRemoteDataSource {
  const PlatformInstitutionAdminRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<PlatformInstitutionAdminListDto> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  }) {
    return _mapReadFailures(() async {
      final response = await dio.get<Object?>(
        _institutionAdminsPath(institutionId),
        queryParameters: query.toQueryParameters(),
      );

      return PlatformInstitutionAdminListDto.fromJson(response.data);
    });
  }

  Future<PlatformInstitutionAdminCreateResponseDto> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  }) {
    return _mapCreateFailures(() async {
      final response = await dio.post<Object?>(
        _institutionAdminsPath(institutionId),
        data: request.toJson(),
      );

      if (response.statusCode != 201) {
        throw const PlatformInstitutionAdminCreateOutcomeUnknownException(
          'Institution administrator creation returned an unexpected status.',
        );
      }

      try {
        final dto = PlatformInstitutionAdminCreateResponseDto.fromJson(
          response.data,
        );
        _verifyConfirmedCreate(dto, request);

        return dto;
      } on FormatException catch (exception) {
        throw PlatformInstitutionAdminCreateOutcomeUnknownException(
          exception.message,
        );
      }
    });
  }

  Future<T> _mapReadFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
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

  Future<T> _mapCreateFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on PlatformInstitutionAdminCreateOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isAmbiguousTransportException(exception)) {
        throw const PlatformInstitutionAdminCreateOutcomeUnknownException(
          'Institution administrator creation outcome is unknown.',
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

  void _verifyConfirmedCreate(
    PlatformInstitutionAdminCreateResponseDto dto,
    PlatformInstitutionAdminCreateRequest request,
  ) {
    final admin = dto.admin;
    if (!admin.isActive ||
        !admin.mustChangePassword ||
        admin.lastLoginAt != null ||
        admin.deactivatedAt != null ||
        admin.loginName != request.loginName) {
      throw const PlatformInstitutionAdminCreateOutcomeUnknownException(
        'Institution administrator creation response did not confirm success.',
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

String _institutionAdminsPath(String institutionId) {
  return '/platform/institutions/${Uri.encodeComponent(institutionId)}/admins';
}
