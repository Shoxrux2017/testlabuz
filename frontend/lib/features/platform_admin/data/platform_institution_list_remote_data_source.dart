import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/platform_institution_list_query.dart';
import 'dto/platform_institution_list_dto.dart';

final platformInstitutionListRemoteDataSourceProvider =
    Provider<PlatformInstitutionListRemoteDataSource>((ref) {
      return PlatformInstitutionListRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class PlatformInstitutionListRemoteDataSource {
  const PlatformInstitutionListRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<PlatformInstitutionListDto> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) {
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/platform/institutions',
        queryParameters: query.toQueryParameters(),
      );

      return PlatformInstitutionListDto.fromJson(response.data);
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
