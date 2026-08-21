import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_parent_student_relationship_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';

import 'institution_parent_student_relationship_test_support.dart';

void main() {
  test('perspectives own exact anchor and related roles', () {
    expect(
      InstitutionParentStudentPerspective.byParent.anchorRole,
      InstitutionUserRole.parent,
    );
    expect(
      InstitutionParentStudentPerspective.byStudent.anchorRole,
      InstitutionUserRole.student,
    );
  });

  test('query sends exact defaults optionals and validates Unicode runes', () {
    const initial = InstitutionParentStudentRelationshipQuery.initial();
    expect(initial.toQueryParameters(), {
      'page': 1,
      'per_page': 20,
      'sort': 'full_name',
      'direction': 'asc',
    });
    final filtered = initial
        .withSearch('  Ali % _ !  ')
        .withStatus(InstitutionParentStudentRelationshipStatusFilter.inactive)
        .withPerPage(50)
        .withSort(InstitutionParentStudentRelationshipSort.startedAt)
        .withSort(InstitutionParentStudentRelationshipSort.startedAt);
    expect(filtered.toQueryParameters(), {
      'search': 'Ali % _ !',
      'status': 'inactive',
      'page': 1,
      'per_page': 50,
      'sort': 'started_at',
      'direction': 'desc',
    });
    expect(
      InstitutionParentStudentRelationshipQuery.isSearchInputValid(
        List.filled(254, '😀').join(),
      ),
      isTrue,
    );
    expect(
      InstitutionParentStudentRelationshipQuery.isSearchInputValid(
        List.filled(255, '😀').join(),
      ),
      isFalse,
    );
  });

  test('connect request has exact keys and rejects invalid pair', () {
    final request = InstitutionParentStudentConnectRequest(
      parentId: testParentId,
      studentId: testStudentId,
    );
    expect(request.toJson(), {
      'parent_id': testParentId,
      'student_id': testStudentId,
    });
    expect(
      () => InstitutionParentStudentConnectRequest(
        parentId: testParentId,
        studentId: testParentId.toUpperCase(),
      ),
      throwsArgumentError,
    );
  });

  test('disconnect identity rejects replacement and reconnect identity', () {
    final anchor = testInstitutionUser();
    final relationship = testRelationship();
    final identity = InstitutionParentStudentRelationshipIdentity(
      perspective: InstitutionParentStudentPerspective.byParent,
      anchor: anchor,
      relationship: relationship,
    );
    expect(
      identity.matches(
        currentPerspective: InstitutionParentStudentPerspective.byParent,
        currentAnchor: anchor,
        currentRelationship: relationship,
      ),
      isTrue,
    );
    expect(
      identity.matches(
        currentPerspective: InstitutionParentStudentPerspective.byParent,
        currentAnchor: anchor,
        currentRelationship: testRelationship(),
      ),
      isFalse,
    );
    expect(
      identity.matches(
        currentPerspective: InstitutionParentStudentPerspective.byParent,
        currentAnchor: anchor,
        currentRelationship: testRelationship(
          id: testOtherRelationshipId,
          startedAt: DateTime.utc(2026, 8, 22),
        ),
      ),
      isFalse,
    );
  });
}
