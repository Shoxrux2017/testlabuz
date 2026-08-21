import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/network/dio_failure_mapper.dart';
import '../domain/institution_group_list_query.dart';
import 'dto/institution_group_list_dto.dart';

final institutionGroupListRemoteDataSourceProvider =
    Provider<InstitutionGroupListRemoteDataSource>((ref) {
      return InstitutionGroupListRemoteDataSource(
        dio: ref.watch(dioProvider),
        failureMapper: const DioFailureMapper(),
      );
    });

class InstitutionGroupListRemoteDataSource {
  const InstitutionGroupListRemoteDataSource({
    required this.dio,
    required this.failureMapper,
  });

  final Dio dio;
  final DioFailureMapper failureMapper;

  Future<InstitutionGroupListDto> fetchGroups(InstitutionGroupListQuery query) {
    return _mapFailures(() async {
      final response = await dio.get<Object?>(
        '/institution/groups',
        queryParameters: query.toQueryParameters(),
      );
      if (response.statusCode != 200) {
        throw const FormatException(
          'Institution Group list success status must be 200.',
        );
      }

      return InstitutionGroupListDto.fromJson(
        response.data,
        requestedQuery: query,
      );
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
