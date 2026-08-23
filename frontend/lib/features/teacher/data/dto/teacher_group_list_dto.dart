import '../../domain/teacher_group.dart';
import '../../domain/teacher_group_list.dart';
import '../../domain/teacher_group_list_query.dart';
import 'teacher_group_dto.dart';
import 'teacher_list_envelope_dto.dart';

class TeacherGroupListDto {
  const TeacherGroupListDto({required this.groups, required this.pagination});

  factory TeacherGroupListDto.fromJson(
    Object? json, {
    required TeacherGroupListQuery requestedQuery,
  }) {
    final envelope = TeacherListEnvelopeDto<TeacherGroupDto>.fromJson(
      json,
      requestedPage: requestedQuery.page,
      requestedPerPage: TeacherGroupListQuery.perPage,
      resourceName: 'Teacher Group',
      readRow: TeacherGroupDto.fromAssignedGroupJson,
      readId: (group) => group.id,
    );

    return TeacherGroupListDto(
      groups: envelope.rows,
      pagination: envelope.pagination,
    );
  }

  final List<TeacherGroupDto> groups;
  final TeacherListPaginationDto pagination;

  TeacherGroupListPage toDomain() {
    return TeacherGroupListPage(
      groups: List<TeacherGroupSummary>.unmodifiable(
        groups.map((group) => group.toDomain()),
      ),
      pagination: pagination.toDomain(),
    );
  }
}
