import '../../domain/teacher_blitz_list.dart';
import '../../domain/teacher_blitz_list_query.dart';
import 'teacher_blitz_dto.dart';
import 'teacher_list_envelope_dto.dart';

class TeacherBlitzListDto {
  const TeacherBlitzListDto({required this.items, required this.pagination});

  factory TeacherBlitzListDto.fromJson(
    Object? json, {
    required String expectedTopicId,
    required TeacherBlitzListQuery requestedQuery,
  }) {
    final envelope = TeacherListEnvelopeDto<TeacherBlitzSummaryDto>.fromJson(
      json,
      requestedPage: requestedQuery.page,
      requestedPerPage: requestedQuery.perPage,
      resourceName: 'Teacher Blitz',
      readRow: (row) => TeacherBlitzSummaryDto.fromJson(
        row,
        expectedTopicId: expectedTopicId,
      ),
      readId: (blitz) => blitz.id,
    );
    return TeacherBlitzListDto(
      items: envelope.rows,
      pagination: envelope.pagination,
    );
  }

  final List<TeacherBlitzSummaryDto> items;
  final TeacherListPaginationDto pagination;

  TeacherBlitzList toDomain() {
    return TeacherBlitzList(
      items: items.map((blitz) => blitz.toDomain()).toList(),
      pagination: pagination.toDomain(),
    );
  }
}
