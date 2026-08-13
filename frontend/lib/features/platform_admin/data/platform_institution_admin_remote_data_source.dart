import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/platform_institution_admin_create.dart';
import '../domain/platform_institution_admin_lifecycle.dart';
import '../domain/platform_institution_admin_list_query.dart';
import '../domain/platform_institution_admin_update.dart';
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

  Future<PlatformInstitutionAdminUpdateResponseDto> updateAdmin({
    required String adminId,
    required PlatformInstitutionAdminUpdateRequest request,
  }) {
    if (request.isEmpty) {
      throw ArgumentError('Admin update request must contain changes.');
    }

    return _mapMutationFailures(() async {
      final response = await dio.patch<Object?>(
        _institutionAdminPath(adminId),
        data: request.toJson(),
      );

      if (response.statusCode != 200) {
        throw const PlatformInstitutionAdminMutationOutcomeUnknownException(
          'Institution administrator update returned an unexpected status.',
        );
      }

      try {
        final dto = PlatformInstitutionAdminUpdateResponseDto.fromJson(
          response.data,
        );
        _verifyConfirmedUpdate(dto, adminId);

        return dto;
      } on FormatException catch (exception) {
        throw PlatformInstitutionAdminMutationOutcomeUnknownException(
          exception.message,
        );
      }
    });
  }

  Future<PlatformInstitutionAdminLifecycleResponseDto> activateAdmin({
    required String adminId,
  }) {
    return _postLifecycleAdmin(
      adminId: adminId,
      action: PlatformInstitutionAdminLifecycleAction.activate,
    );
  }

  Future<PlatformInstitutionAdminLifecycleResponseDto> deactivateAdmin({
    required String adminId,
  }) {
    return _postLifecycleAdmin(
      adminId: adminId,
      action: PlatformInstitutionAdminLifecycleAction.deactivate,
    );
  }

  Future<PlatformInstitutionAdminLifecycleResponseDto> _postLifecycleAdmin({
    required String adminId,
    required PlatformInstitutionAdminLifecycleAction action,
  }) {
    return _mapMutationFailures(() async {
      final response = await dio.post<Object?>(
        '${_institutionAdminPath(adminId)}/${action.endpointSegment}',
        data: const <String, Object?>{},
      );

      if (response.statusCode != 200) {
        throw const PlatformInstitutionAdminMutationOutcomeUnknownException(
          'Institution administrator lifecycle returned an unexpected status.',
        );
      }

      try {
        final dto = PlatformInstitutionAdminLifecycleResponseDto.fromJson(
          response.data,
          action: action,
        );
        _verifyConfirmedLifecycle(dto, adminId, action);

        return dto;
      } on FormatException catch (exception) {
        throw PlatformInstitutionAdminMutationOutcomeUnknownException(
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

  Future<T> _mapMutationFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on PlatformInstitutionAdminMutationOutcomeUnknownException {
      rethrow;
    } on DioException catch (exception) {
      if (_isAmbiguousTransportException(exception)) {
        throw const PlatformInstitutionAdminMutationOutcomeUnknownException(
          'Institution administrator mutation outcome is unknown.',
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

  void _verifyConfirmedUpdate(
    PlatformInstitutionAdminUpdateResponseDto dto,
    String adminId,
  ) {
    if (dto.admin.id != adminId ||
        dto.message != 'Institution admin updated successfully.') {
      throw const PlatformInstitutionAdminMutationOutcomeUnknownException(
        'Institution administrator update response did not confirm success.',
      );
    }
  }

  void _verifyConfirmedLifecycle(
    PlatformInstitutionAdminLifecycleResponseDto dto,
    String adminId,
    PlatformInstitutionAdminLifecycleAction action,
  ) {
    final admin = dto.admin;
    if (admin.id != adminId ||
        dto.message != action.successMessage ||
        admin.isActive != action.targetIsActive ||
        (action.targetIsActive
            ? admin.deactivatedAt != null
            : admin.deactivatedAt == null)) {
      throw const PlatformInstitutionAdminMutationOutcomeUnknownException(
        'Institution administrator lifecycle response did not confirm success.',
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
      DioExceptionType.unknown ||
      DioExceptionType.cancel => true,
      DioExceptionType.badCertificate || DioExceptionType.badResponse => false,
    };
  }
}

String _institutionAdminsPath(String institutionId) {
  return '/platform/institutions/${Uri.encodeComponent(institutionId)}/admins';
}

String _institutionAdminPath(String adminId) {
  return '/platform/institution-admins/${Uri.encodeComponent(adminId)}';
}
