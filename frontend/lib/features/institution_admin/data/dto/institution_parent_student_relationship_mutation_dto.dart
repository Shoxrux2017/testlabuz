import '../../domain/institution_parent_student_relationship_mutation.dart';
import 'institution_parent_student_relationship_dto.dart';

class InstitutionParentStudentRelationshipMutationDto {
  const InstitutionParentStudentRelationshipMutationDto({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.startedAt,
    required this.endedAt,
  });

  factory InstitutionParentStudentRelationshipMutationDto.fromJson(
    Object? json, {
    required InstitutionParentStudentConnectRequest submitted,
  }) {
    final envelope = readExactParentStudentMap(
      json,
      context: 'Parent-Student connection response envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != 'Parent and student connected successfully.') {
      throw const FormatException(
        'Parent-Student connection message did not match the endpoint.',
      );
    }
    final data = readExactParentStudentMap(
      envelope['data'],
      context: 'Parent-Student connection response data',
      keys: const {'id', 'parent_id', 'student_id', 'started_at', 'ended_at'},
    );
    final id = readCanonicalParentStudentUuid(data, 'id');
    final parentId = readCanonicalParentStudentUuid(data, 'parent_id');
    final studentId = readCanonicalParentStudentUuid(data, 'student_id');
    if (parentId.toLowerCase() != submitted.parentId.toLowerCase() ||
        studentId.toLowerCase() != submitted.studentId.toLowerCase() ||
        parentId.toLowerCase() == studentId.toLowerCase() ||
        data['ended_at'] != null) {
      throw const FormatException(
        'Parent-Student connection result contradicts the request.',
      );
    }
    return InstitutionParentStudentRelationshipMutationDto(
      id: id,
      parentId: parentId,
      studentId: studentId,
      startedAt: readParentStudentUtcTimestamp(data, 'started_at'),
      endedAt: null,
    );
  }

  final String id;
  final String parentId;
  final String studentId;
  final DateTime startedAt;
  final DateTime? endedAt;

  InstitutionParentStudentMutationResult toDomain() =>
      InstitutionParentStudentMutationResult(
        id: id,
        parentId: parentId,
        studentId: studentId,
        startedAt: startedAt,
        endedAt: endedAt,
      );
}
