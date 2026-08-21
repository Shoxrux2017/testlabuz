import 'institution_parent_student_relationship.dart';
import 'institution_parent_student_relationship_list.dart';
import 'institution_parent_student_relationship_mutation.dart';
import 'institution_parent_student_relationship_query.dart';

abstract interface class InstitutionParentStudentRelationshipRepository {
  Future<InstitutionParentStudentRelationshipListPage> fetchRelationships({
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
    required InstitutionParentStudentRelationshipQuery query,
  });

  Future<InstitutionParentStudentMutationResult> connect(
    InstitutionParentStudentConnectRequest request,
  );

  Future<void> disconnect(String relationshipId);
}
