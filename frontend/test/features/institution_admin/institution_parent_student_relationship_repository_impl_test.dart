import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_parent_student_relationship_list_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_parent_student_relationship_mutation_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_parent_student_relationship_remote_data_source.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_parent_student_relationship_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_query.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  test('repository converts strict list and mutation DTOs to domain', () async {
    final remote = _FakeRemote();
    final repository = InstitutionParentStudentRelationshipRepositoryImpl(
      remoteDataSource: remote,
    );
    final page = await repository.fetchRelationships(
      perspective: InstitutionParentStudentPerspective.byParent,
      anchorId: testParentId,
      query: const InstitutionParentStudentRelationshipQuery.initial(),
    );
    expect(page.relationships.single.id, testRelationshipId);

    final connected = await repository.connect(
      InstitutionParentStudentConnectRequest(
        parentId: testParentId,
        studentId: testStudentId,
      ),
    );
    expect(connected.startedAt, DateTime.utc(2026, 8, 21, 10, 15));

    await repository.disconnect(testRelationshipId);
    expect(remote.disconnected, [testRelationshipId]);
  });
}

class _FakeRemote extends InstitutionParentStudentRelationshipRemoteDataSource {
  _FakeRemote()
    : super(
        dio: testDio(RecordingAdapter((_) => throw StateError('unused'))),
        failureMapper: const DioFailureMapper(),
      );

  final disconnected = <String>[];

  @override
  Future<InstitutionParentStudentRelationshipListDto> fetchRelationships({
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
    required InstitutionParentStudentRelationshipQuery query,
  }) async => InstitutionParentStudentRelationshipListDto.fromJson(
    relationshipListEnvelope(),
    perspective: perspective,
    anchorId: anchorId,
    requestedQuery: query,
  );

  @override
  Future<InstitutionParentStudentRelationshipMutationDto> connect(
    InstitutionParentStudentConnectRequest request,
  ) async => InstitutionParentStudentRelationshipMutationDto.fromJson({
    'data': {
      'id': testRelationshipId,
      'parent_id': testParentId,
      'student_id': testStudentId,
      'started_at': '2026-08-21T10:15:00Z',
      'ended_at': null,
    },
    'message': 'Parent and student connected successfully.',
  }, submitted: request);

  @override
  Future<void> disconnect(String relationshipId) async {
    disconnected.add(relationshipId);
  }
}
