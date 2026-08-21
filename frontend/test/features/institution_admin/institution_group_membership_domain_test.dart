import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_mutation.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_query.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';

import 'institution_group_test_support.dart';

void main() {
  test('member kinds own exact machine paths keys roles and labels', () {
    expect(InstitutionGroupMemberKind.teacher.endpointSegment, 'teachers');
    expect(InstitutionGroupMemberKind.teacher.assignmentBodyKey, 'teacher_ids');
    expect(
      InstitutionGroupMemberKind.teacher.candidateRole,
      InstitutionUserRole.teacher,
    );
    expect(InstitutionGroupMemberKind.student.endpointSegment, 'students');
    expect(InstitutionGroupMemberKind.student.assignmentBodyKey, 'student_ids');
    expect(
      InstitutionGroupMemberKind.student.candidateRole,
      InstitutionUserRole.student,
    );
  });

  test('query serializes exact defaults optionals and rune validation', () {
    const initial = InstitutionGroupMembershipQuery.initial();
    expect(initial.toQueryParameters(), {
      'page': 1,
      'per_page': 20,
      'sort': 'full_name',
      'direction': 'asc',
    });
    final filtered = initial
        .withSearch('  Ali % _  ')
        .withStatus(InstitutionGroupMembershipStatusFilter.inactive)
        .withPerPage(50)
        .withSort(InstitutionGroupMembershipSort.startedAt)
        .withSort(InstitutionGroupMembershipSort.startedAt);
    expect(filtered.toQueryParameters(), {
      'search': 'Ali % _',
      'status': 'inactive',
      'page': 1,
      'per_page': 50,
      'sort': 'started_at',
      'direction': 'desc',
    });
    expect(
      InstitutionGroupMembershipQuery.isSearchInputValid(
        List.filled(254, '😀').join(),
      ),
      isTrue,
    );
    expect(
      InstitutionGroupMembershipQuery.isSearchInputValid(
        List.filled(255, '😀').join(),
      ),
      isFalse,
    );
  });

  test(
    'assignment IDs preserve order and reject invalid bounds or duplicates',
    () {
      final request = InstitutionGroupMembershipAssignmentRequest([
        testTeacherId,
        testStudentId,
      ]);
      expect(request.memberIds, [testTeacherId, testStudentId]);
      expect(request.toJson(InstitutionGroupMemberKind.teacher), {
        'teacher_ids': [testTeacherId, testStudentId],
      });
      expect(
        () => InstitutionGroupMembershipAssignmentRequest(const []),
        throwsArgumentError,
      );
      expect(
        () => InstitutionGroupMembershipAssignmentRequest([
          testGroupIdUpper,
          testGroupIdUpper.toLowerCase(),
        ]),
        throwsArgumentError,
      );
      expect(
        () => InstitutionGroupMembershipAssignmentRequest(
          List.generate(
            101,
            (index) =>
                '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test('current membership identity includes startedAt and exact object', () {
    final membership = testMembership();
    final identity = InstitutionGroupMembershipIdentity(
      groupId: testGroupId,
      kind: InstitutionGroupMemberKind.teacher,
      membership: membership,
    );
    expect(
      identity.matches(
        currentGroupId: testGroupId.toUpperCase(),
        currentKind: InstitutionGroupMemberKind.teacher,
        currentMembership: membership,
      ),
      isTrue,
    );
    expect(
      identity.matches(
        currentGroupId: testGroupId,
        currentKind: InstitutionGroupMemberKind.teacher,
        currentMembership: testMembership(),
      ),
      isFalse,
    );
    expect(
      identity.matches(
        currentGroupId: testGroupId,
        currentKind: InstitutionGroupMemberKind.teacher,
        currentMembership: testMembership(startedAt: DateTime.utc(2026, 8, 22)),
      ),
      isFalse,
    );
  });
}
