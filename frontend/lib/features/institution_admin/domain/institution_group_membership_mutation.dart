import 'institution_group_membership.dart';

class InstitutionGroupMembershipAssignmentRequest {
  InstitutionGroupMembershipAssignmentRequest(Iterable<String> memberIds)
    : memberIds = _validate(memberIds);

  final List<String> memberIds;

  Map<String, Object> toJson(InstitutionGroupMemberKind kind) =>
      Map.unmodifiable({kind.assignmentBodyKey: memberIds});

  static List<String> _validate(Iterable<String> values) {
    final ids = List<String>.from(values);
    if (ids.isEmpty || ids.length > 100) {
      throw ArgumentError('Assignment requires between 1 and 100 users.');
    }
    final normalized = <String>{};
    for (final id in ids) {
      if (!_canonicalUuidPattern.hasMatch(id) ||
          !normalized.add(id.toLowerCase())) {
        throw ArgumentError(
          'Assignment IDs must be canonical and case-insensitively distinct.',
        );
      }
    }
    return List.unmodifiable(ids);
  }
}

class InstitutionGroupMembershipMutationOutcomeUnknownException
    implements Exception {
  const InstitutionGroupMembershipMutationOutcomeUnknownException();
}

final _canonicalUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
