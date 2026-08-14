import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_profile_repository.dart';
import '../domain/institution_profile_update.dart';
import 'dto/institution_profile_dto.dart';

final institutionProfileRemoteDataSourceProvider =
    Provider<InstitutionProfileRemoteDataSource>((ref) {
      return InstitutionProfileRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionProfileRemoteDataSource {
  const InstitutionProfileRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionProfileGetResponseDto> fetchProfile() async {
    try {
      final response = await dio.get<Object?>('/institution/profile');
      if (response.statusCode != 200) {
        throw const FormatException(
          'Unexpected institution profile response status.',
        );
      }

      return InstitutionProfileGetResponseDto.fromJson(response.data);
    } on DioException catch (exception) {
      throw ApiRequestException(failureMapper.map(exception));
    } on ApiEnvelopeFormatException catch (exception) {
      throw ApiRequestException(_invalidResponse(exception.message));
    } on FormatException catch (exception) {
      throw ApiRequestException(_invalidResponse(exception.message));
    }
  }

  Future<InstitutionProfileUpdateResponseDto> updateProfile(
    InstitutionProfileUpdateRequest request,
  ) async {
    if (request.isEmpty) {
      throw ArgumentError.value(request, 'request', 'Must not be empty.');
    }

    try {
      final response = await dio.patch<Object?>(
        '/institution/profile',
        data: request.toJson(),
      );
      if (response.statusCode != 200) {
        throw const InstitutionProfileUpdateOutcomeUnknownException();
      }

      try {
        return InstitutionProfileUpdateResponseDto.fromJson(response.data);
      } on ApiEnvelopeFormatException {
        throw const InstitutionProfileUpdateOutcomeUnknownException();
      } on FormatException {
        throw const InstitutionProfileUpdateOutcomeUnknownException();
      }
    } on DioException catch (exception) {
      if (exception.type == DioExceptionType.badResponse ||
          exception.type == DioExceptionType.badCertificate) {
        throw ApiRequestException(failureMapper.map(exception));
      }

      throw const InstitutionProfileUpdateOutcomeUnknownException();
    }
  }
}

ApiFailure _invalidResponse(String message) {
  return ApiFailure.local(
    kind: ApiFailureKind.invalidResponse,
    message: message,
  );
}
