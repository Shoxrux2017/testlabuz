import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/auth_request_options.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import 'dto/auth_login_response_dto.dart';
import 'dto/auth_me_response_dto.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(
    dio: ref.watch(dioProvider),
    failureMapper: const DioFailureMapper(),
  );
});

class AuthRemoteDataSource {
  const AuthRemoteDataSource({required this.dio, required this.failureMapper});

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<AuthLoginResponseDto> login({
    required String login,
    required String password,
  }) {
    return _mapFailures(() async {
      final response = await dio.post<Object?>(
        '/auth/login',
        data: {'login': login, 'password': password},
        options: AuthRequestOptions.publicRequest(),
      );

      return AuthLoginResponseDto.fromJson(response.data);
    });
  }

  Future<AuthMeResponseDto> me() {
    return _mapFailures(() async {
      final response = await dio.get<Object?>('/auth/me');

      return AuthMeResponseDto.fromJson(response.data);
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) {
    return _mapFailures(() async {
      final response = await dio.post<Object?>(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        },
      );

      if (response.statusCode != 204) {
        throw const FormatException(
          'Change password response must be 204 No Content.',
        );
      }
    });
  }

  Future<void> logout() {
    return _mapFailures(() async {
      final response = await dio.post<Object?>('/auth/logout');

      if (response.statusCode != 204) {
        throw const FormatException('Logout response must be 204 No Content.');
      }
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw ApiRequestException(failureMapper.map(exception));
    } on ApiEnvelopeFormatException catch (exception) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: exception.message,
        ),
      );
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
