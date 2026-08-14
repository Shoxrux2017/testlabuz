import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_dashboard_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_dashboard_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_dashboard_repository_impl.dart';

void main() {
  group('InstitutionDashboardRepositoryImpl', () {
    test('maps the transport DTO to the exact domain model', () async {
      final repository = InstitutionDashboardRepositoryImpl(
        remoteDataSource: FakeInstitutionDashboardRemoteDataSource(
          onFetch: () async => const InstitutionDashboardDto(
            teachers: 7,
            students: 80,
            parents: 65,
          ),
        ),
      );

      final dashboard = await repository.fetchDashboard();

      expect(dashboard.teachers, 7);
      expect(dashboard.students, 80);
      expect(dashboard.parents, 65);
      expect(dashboard.hasNoUsers, isFalse);
    });

    test('propagates typed failures without fallback or stale data', () async {
      final failure = ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.connection,
          message: 'Repository transport failed.',
        ),
      );
      final repository = InstitutionDashboardRepositoryImpl(
        remoteDataSource: FakeInstitutionDashboardRemoteDataSource(
          onFetch: () async => throw failure,
        ),
      );

      await expectLater(repository.fetchDashboard(), throwsA(same(failure)));
    });
  });
}

class FakeInstitutionDashboardRemoteDataSource
    extends InstitutionDashboardRemoteDataSource {
  FakeInstitutionDashboardRemoteDataSource({required this.onFetch})
    : super(dio: Dio(), failureMapper: const DioFailureMapper());

  final Future<InstitutionDashboardDto> Function() onFetch;

  @override
  Future<InstitutionDashboardDto> fetchDashboard() => onFetch();
}
