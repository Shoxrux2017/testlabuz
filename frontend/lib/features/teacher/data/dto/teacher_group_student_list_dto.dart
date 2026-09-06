import '../../domain/teacher_group_student_list.dart';
import '../../domain/teacher_group_student_list_query.dart';
import 'teacher_group_student_dto.dart';
import 'teacher_list_envelope_dto.dart';

class TeacherGroupStudentListDto {
  const TeacherGroupStudentListDto({
    required this.items,
    required this.pagination,
  });

  factory TeacherGroupStudentListDto.fromJson(
    Object? json, {
    required TeacherGroupStudentListQuery requestedQuery,
  }) {
    final envelope = TeacherListEnvelopeDto<TeacherGroupStudentDto>.fromJson(
      json,
      requestedPage: requestedQuery.page,
      requestedPerPage: requestedQuery.perPage,
      resourceName: 'Teacher Group Student',
      readRow: TeacherGroupStudentDto.fromJson,
      readId: (student) => student.id,
    );
    return TeacherGroupStudentListDto(
      items: envelope.rows,
      pagination: envelope.pagination,
    );
  }

  final List<TeacherGroupStudentDto> items;
  final TeacherListPaginationDto pagination;

  TeacherGroupStudentList toDomain() {
    return TeacherGroupStudentList(
      items: items.map((student) => student.toDomain()).toList(),
      pagination: pagination.toDomain(),
    );
  }
}
