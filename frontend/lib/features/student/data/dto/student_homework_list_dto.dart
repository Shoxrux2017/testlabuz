import '../../domain/student_homework_list.dart';
import '../../domain/student_homework_list_query.dart';
import 'student_dto_parse.dart';
import 'student_homework_dto.dart';

class StudentHomeworkListDto {
  StudentHomeworkListDto({
    required List<StudentHomeworkSummaryDto> items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  }) : items = List<StudentHomeworkSummaryDto>.unmodifiable(items);

  factory StudentHomeworkListDto.fromJson(
    Object? json, {
    required StudentHomeworkListQuery requestedQuery,
  }) {
    final envelope = readExactStudentMap(
      json,
      context: 'Student Homework list envelope',
      keys: const {'data', 'meta'},
    );
    final items = readStudentList(
      envelope,
      'data',
    ).map(StudentHomeworkSummaryDto.fromJson).toList();
    final meta = readExactStudentMap(
      envelope['meta'],
      context: 'Student Homework list meta',
      keys: const {'pagination'},
    );
    final pagination = readExactStudentMap(
      meta['pagination'],
      context: 'Student Homework list pagination',
      keys: const {'page', 'per_page', 'total', 'last_page'},
    );
    final page = readStudentInt(pagination, 'page');
    final perPage = readStudentInt(pagination, 'per_page');
    final total = readStudentInt(pagination, 'total');
    final lastPage = readStudentInt(pagination, 'last_page');
    if (page < 1 ||
        page != requestedQuery.page ||
        perPage < 1 ||
        perPage > 100 ||
        perPage != requestedQuery.perPage ||
        total < 0 ||
        lastPage < 1) {
      throw const FormatException(
        'Student Homework pagination contradicts request or range.',
      );
    }
    final expectedLastPage = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
    if (lastPage != expectedLastPage ||
        items.length > perPage ||
        items.length > total ||
        (page > lastPage && items.isNotEmpty)) {
      throw const FormatException(
        'Student Homework pagination is inconsistent.',
      );
    }
    final ids = <String>{};
    for (final item in items) {
      if (!ids.add(item.id.toLowerCase()) ||
          item.topic.id.toLowerCase() != requestedQuery.topicId.toLowerCase()) {
        throw const FormatException(
          'Student Homework rows have duplicate IDs or wrong Topic scope.',
        );
      }
    }
    return StudentHomeworkListDto(
      items: items,
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }

  final List<StudentHomeworkSummaryDto> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  StudentHomeworkList toDomain() => StudentHomeworkList(
    items: items.map((item) => item.toDomain()).toList(),
    page: page,
    perPage: perPage,
    total: total,
    lastPage: lastPage,
  );
}
