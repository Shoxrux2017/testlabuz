class InstitutionParentStudentConnectRequest {
  InstitutionParentStudentConnectRequest({
    required this.parentId,
    required this.studentId,
  }) {
    if (!isCanonicalParentStudentUuid(parentId) ||
        !isCanonicalParentStudentUuid(studentId) ||
        parentId.toLowerCase() == studentId.toLowerCase()) {
      throw ArgumentError(
        'Parent and Student IDs must be distinct canonical UUIDs.',
      );
    }
  }

  final String parentId;
  final String studentId;

  Map<String, Object> toJson() =>
      Map.unmodifiable({'parent_id': parentId, 'student_id': studentId});
}

class InstitutionParentStudentMutationResult {
  const InstitutionParentStudentMutationResult({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.startedAt,
    required this.endedAt,
  });

  final String id;
  final String parentId;
  final String studentId;
  final DateTime startedAt;
  final DateTime? endedAt;
}

class InstitutionParentStudentMutationOutcomeUnknownException
    implements Exception {
  const InstitutionParentStudentMutationOutcomeUnknownException();
}

bool isCanonicalParentStudentUuid(String value) =>
    _canonicalUuidPattern.hasMatch(value);

final _canonicalUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
