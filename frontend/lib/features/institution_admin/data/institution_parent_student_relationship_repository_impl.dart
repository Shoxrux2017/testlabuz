import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_parent_student_relationship.dart';
import '../domain/institution_parent_student_relationship_list.dart';
import '../domain/institution_parent_student_relationship_mutation.dart';
import '../domain/institution_parent_student_relationship_query.dart';
import '../domain/institution_parent_student_relationship_repository.dart';
import 'institution_parent_student_relationship_remote_data_source.dart';

final institutionParentStudentRelationshipRepositoryProvider =
    Provider<InstitutionParentStudentRelationshipRepository>((ref) {
      return InstitutionParentStudentRelationshipRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionParentStudentRelationshipRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionParentStudentRelationshipRepositoryImpl
    implements InstitutionParentStudentRelationshipRepository {
  const InstitutionParentStudentRelationshipRepositoryImpl({
    required this.remoteDataSource,
  });

  final InstitutionParentStudentRelationshipRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionParentStudentRelationshipListPage> fetchRelationships({
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
    required InstitutionParentStudentRelationshipQuery query,
  }) async {
    final dto = await remoteDataSource.fetchRelationships(
      perspective: perspective,
      anchorId: anchorId,
      query: query,
    );
    return dto.toDomain();
  }

  @override
  Future<InstitutionParentStudentMutationResult> connect(
    InstitutionParentStudentConnectRequest request,
  ) async {
    final dto = await remoteDataSource.connect(request);
    return dto.toDomain();
  }

  @override
  Future<void> disconnect(String relationshipId) =>
      remoteDataSource.disconnect(relationshipId);
}
