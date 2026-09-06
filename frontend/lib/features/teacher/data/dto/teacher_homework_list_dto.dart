import '../../domain/teacher_homework_list.dart';
import '../../domain/teacher_homework_list_query.dart';
import 'teacher_homework_dto.dart';
import 'teacher_list_envelope_dto.dart';

class TeacherHomeworkListDto {
  const TeacherHomeworkListDto({required this.items, required this.pagination});

  factory TeacherHomeworkListDto.fromJson(
    Object? json, {
    required String expectedTopicId,
    required TeacherHomeworkListQuery requestedQuery,
  }) {
    final envelope = TeacherListEnvelopeDto<TeacherHomeworkSummaryDto>.fromJson(
      json,
      requestedPage: requestedQuery.page,
      requestedPerPage: requestedQuery.perPage,
      resourceName: 'Teacher Homework',
      readRow: (row) => TeacherHomeworkSummaryDto.fromJson(
        row,
        expectedTopicId: expectedTopicId,
      ),
      readId: (homework) => homework.id,
    );
    return TeacherHomeworkListDto(
      items: envelope.rows,
      pagination: envelope.pagination,
    );
  }

  final List<TeacherHomeworkSummaryDto> items;
  final TeacherListPaginationDto pagination;

  TeacherHomeworkList toDomain() {
    return TeacherHomeworkList(
      items: items.map((homework) => homework.toDomain()).toList(),
      pagination: pagination.toDomain(),
    );
  }
}
