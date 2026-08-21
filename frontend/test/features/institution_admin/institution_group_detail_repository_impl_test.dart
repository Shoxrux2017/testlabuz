import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_detail_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_group_detail_repository_impl.dart';

import 'institution_group_test_support.dart';

void main() {
  test('maps exact detail DTO and accepts case-equivalent target', () async {
    final repository = InstitutionGroupDetailRepositoryImpl(
      remoteDataSource: _FakeDetailSource(
        InstitutionGroupDetailDto.fromJson({
          'data': groupResource(id: testGroupIdUpper.toLowerCase()),
        }),
      ),
    );
    final group = await repository.fetchGroup(testGroupIdUpper);
    expect(group.id, testGroupIdUpper.toLowerCase());
  });

  test('rejects response UUID that differs from requested target', () async {
    final repository = InstitutionGroupDetailRepositoryImpl(
      remoteDataSource: _FakeDetailSource(
        InstitutionGroupDetailDto.fromJson({'data': groupResource()}),
      ),
    );
    await expectLater(
      repository.fetchGroup(testGroupIdUpper),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.failure.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });
}

class _FakeDetailSource implements InstitutionGroupDetailRemoteDataSource {
  const _FakeDetailSource(this.dto);

  final InstitutionGroupDetailDto dto;

  @override
  Future<InstitutionGroupDetailDto> fetchGroup(String groupId) async => dto;

  @override
  Dio get dio => throw UnimplementedError();

  @override
  DioFailureMapper get failureMapper => throw UnimplementedError();
}
