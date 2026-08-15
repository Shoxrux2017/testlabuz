import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
