import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_parent_student_relationship_list_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_query.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  test('parses exact envelope pagination and direction', () {
    final page = InstitutionParentStudentRelationshipListDto.fromJson(
      relationshipListEnvelope(),
      perspective: InstitutionParentStudentPerspective.byParent,
      anchorId: testParentId,
      requestedQuery: const InstitutionParentStudentRelationshipQuery.initial(),
    ).toDomain();
    expect(page.relationships.single.id, testRelationshipId);
    expect(page.pagination.total, 1);
  });

  test('rejects duplicate relationship IDs and pagination contradictions', () {
    expect(
      () => InstitutionParentStudentRelationshipListDto.fromJson(
        relationshipListEnvelope(
          rows: [
            relationshipResource(),
            relationshipResource(id: testRelationshipId.toUpperCase()),
          ],
          total: 2,
        ),
        perspective: InstitutionParentStudentPerspective.byParent,
        anchorId: testParentId,
        requestedQuery:
            const InstitutionParentStudentRelationshipQuery.initial(),
      ),
      throwsFormatException,
    );
    for (final envelope in <Map<String, Object?>>[
      relationshipListEnvelope(page: 2),
      relationshipListEnvelope(perPage: 50),
      relationshipListEnvelope(total: 21, lastPage: 1),
      {...relationshipListEnvelope(), 'extra': true},
    ]) {
      expect(
        () => InstitutionParentStudentRelationshipListDto.fromJson(
          envelope,
          perspective: InstitutionParentStudentPerspective.byParent,
          anchorId: testParentId,
          requestedQuery:
              const InstitutionParentStudentRelationshipQuery.initial(),
        ),
        throwsFormatException,
      );
    }
  });
}
