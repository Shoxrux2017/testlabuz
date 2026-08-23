import '../../domain/teacher_topic.dart';
import '../../domain/teacher_topic_list.dart';
import '../../domain/teacher_topic_list_query.dart';
import 'teacher_list_envelope_dto.dart';
import 'teacher_topic_dto.dart';

class TeacherTopicListDto {
  const TeacherTopicListDto({required this.topics, required this.pagination});

  factory TeacherTopicListDto.fromJson(
    Object? json, {
    required TeacherTopicListQuery requestedQuery,
  }) {
    final envelope = TeacherListEnvelopeDto<TeacherTopicDto>.fromJson(
      json,
      requestedPage: requestedQuery.page,
      requestedPerPage: TeacherTopicListQuery.perPage,
      resourceName: 'Teacher Topic',
      readRow: TeacherTopicDto.fromJson,
      readId: (topic) => topic.id,
    );

    return TeacherTopicListDto(
      topics: envelope.rows,
      pagination: envelope.pagination,
    );
  }

  final List<TeacherTopicDto> topics;
  final TeacherListPaginationDto pagination;

  TeacherTopicListPage toDomain() {
    return TeacherTopicListPage(
      topics: List<TeacherTopic>.unmodifiable(
        topics.map((topic) => topic.toDomain()),
      ),
      pagination: pagination.toDomain(),
    );
  }
}
