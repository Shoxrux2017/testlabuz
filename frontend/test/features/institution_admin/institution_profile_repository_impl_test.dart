import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_profile_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_profile_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_profile_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_repository.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_update.dart';

void main() {
  group('InstitutionProfileRepositoryImpl', () {
    test('maps exact GET and PATCH DTOs into domain results', () async {
      final remote = FakeInstitutionProfileRemoteDataSource();
      final repository = InstitutionProfileRepositoryImpl(
        remoteDataSource: remote,
      );

      final fetched = await repository.fetchProfile();
      final request = InstitutionProfileUpdateRequest.fromChanges({
        'name': 'Renamed School',
      });
      final updated = await repository.updateProfile(request);

      expect(fetched.name, 'Example School');
      expect(updated.profile.name, 'Renamed School');
      expect(remote.updateRequests.single, same(request));
    });

    test('preserves typed definite and uncertain failures', () async {
      final definite = ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Invalid.',
        ),
      );
      final definiteRepository = InstitutionProfileRepositoryImpl(
        remoteDataSource: FakeInstitutionProfileRemoteDataSource(
          onFetch: () async => throw definite,
        ),
      );
      await expectLater(
        definiteRepository.fetchProfile(),
        throwsA(same(definite)),
      );

      final uncertainRepository = InstitutionProfileRepositoryImpl(
        remoteDataSource: FakeInstitutionProfileRemoteDataSource(
          onUpdate: (_) async =>
              throw const InstitutionProfileUpdateOutcomeUnknownException(),
        ),
      );
      await expectLater(
        uncertainRepository.updateProfile(
          InstitutionProfileUpdateRequest.fromChanges({'name': 'New'}),
        ),
        throwsA(isA<InstitutionProfileUpdateOutcomeUnknownException>()),
      );
    });
  });
}

class FakeInstitutionProfileRemoteDataSource
    extends InstitutionProfileRemoteDataSource {
  FakeInstitutionProfileRemoteDataSource({this.onFetch, this.onUpdate})
    : super(dio: Dio(), failureMapper: const DioFailureMapper());

  final Future<InstitutionProfileGetResponseDto> Function()? onFetch;
  final Future<InstitutionProfileUpdateResponseDto> Function(
    InstitutionProfileUpdateRequest request,
  )?
  onUpdate;
  final updateRequests = <InstitutionProfileUpdateRequest>[];

  @override
  Future<InstitutionProfileGetResponseDto> fetchProfile() {
    return onFetch?.call() ??
        Future.value(
          InstitutionProfileGetResponseDto.fromJson({'data': _resource()}),
        );
  }

  @override
  Future<InstitutionProfileUpdateResponseDto> updateProfile(
    InstitutionProfileUpdateRequest request,
  ) {
    updateRequests.add(request);

    return onUpdate?.call(request) ??
        Future.value(
          InstitutionProfileUpdateResponseDto.fromJson({
            'data': _resource()..['name'] = 'Renamed School',
            'message': institutionProfileUpdateSuccessMessage,
          }),
        );
  }
}

Map<String, Object?> _resource() {
  return {
    'id': '550e8400-e29b-41d4-a716-446655440000',
    'name': 'Example School',
    'type': 'school',
    'status': 'active',
    'contact_email': null,
    'contact_phone': null,
    'address': null,
    'description': null,
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T15:00:00Z',
  };
}
