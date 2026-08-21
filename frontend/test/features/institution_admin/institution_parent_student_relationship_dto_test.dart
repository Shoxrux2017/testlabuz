import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_parent_student_relationship_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  test('parses exact current resource for both directions and inactivity', () {
    final byParent = InstitutionParentStudentRelationshipDto.fromJson(
      relationshipResource(isActive: false),
      perspective: InstitutionParentStudentPerspective.byParent,
      anchorId: testParentId,
    ).toDomain();
    expect(byParent.relatedUser.id, testStudentId);
    expect(byParent.relatedUser.isActive, isFalse);
    expect(byParent.endedAt, isNull);

    final byStudent = InstitutionParentStudentRelationshipDto.fromJson(
      relationshipResource(
        perspective: InstitutionParentStudentPerspective.byStudent,
      ),
      perspective: InstitutionParentStudentPerspective.byStudent,
      anchorId: testStudentId,
    ).toDomain();
    expect(byStudent.relatedUser.id, testParentId);
  });

  test(
    'rejects unknown keys current/direction/related identity violations',
    () {
      final invalid = <Map<String, Object?>>[
        {...relationshipResource(), 'extra': true},
        relationshipResource(endedAt: '2026-08-22T00:00:00Z'),
        relationshipResource(parentId: testStudentId),
        relationshipResource(relatedId: testParentId),
        relationshipResource(startedAt: '2026-08-21T15:15:00+05:00'),
      ];
      for (final resource in invalid) {
        expect(
          () => InstitutionParentStudentRelationshipDto.fromJson(
            resource,
            perspective: InstitutionParentStudentPerspective.byParent,
            anchorId: testParentId,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
