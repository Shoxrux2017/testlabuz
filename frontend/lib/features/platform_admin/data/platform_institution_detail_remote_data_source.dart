import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import 'dto/platform_institution_detail_dto.dart';

final platformInstitutionDetailRemoteDataSourceProvider =
    Provider<PlatformInstitutionDetailRemoteDataSource>((ref) {
      return PlatformInstitutionDetailRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class PlatformInstitutionDetailRemoteDataSource {
  const PlatformInstitutionDetailRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<PlatformInstitutionDetailDto> fetchInstitutionDetail(
    String institutionId,
  ) {
    return _mapFailures(() async {
      final encodedInstitutionId = Uri.encodeComponent(institutionId);
      final response = await dio.get<Object?>(
        '/platform/institutions/$encodedInstitutionId',
      );

      return PlatformInstitutionDetailDto.fromJson(response.data);
    });
  }

  Future<T> _mapFailures<T>(Future<T> Function() request) async {
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
}
