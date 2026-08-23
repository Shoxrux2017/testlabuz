import '../../domain/teacher_list_pagination.dart';
import 'teacher_dto_parse.dart';

class TeacherListEnvelopeDto<T> {
  const TeacherListEnvelopeDto({required this.rows, required this.pagination});

  factory TeacherListEnvelopeDto.fromJson(
    Object? json, {
    required int requestedPage,
    required int requestedPerPage,
    required String resourceName,
    required T Function(Object? json) readRow,
    required String Function(T row) readId,
  }) {
    final envelope = readExactTeacherMap(
      json,
      context: '$resourceName list envelope',
      keys: const {'data', 'meta'},
    );
    final rawRows = envelope['data'];
    if (rawRows is! List<Object?>) {
      throw FormatException('$resourceName list data must be an array.');
    }
    final meta = readExactTeacherMap(
      envelope['meta'],
      context: '$resourceName list meta',
      keys: const {'pagination'},
    );
    final pagination = TeacherListPaginationDto.fromJson(
      meta['pagination'],
      requestedPage: requestedPage,
      requestedPerPage: requestedPerPage,
      rowCount: rawRows.length,
      resourceName: resourceName,
    );
    final rows = List<T>.unmodifiable(rawRows.map(readRow));
    final ids = rows.map(readId).map((id) => id.toLowerCase()).toSet();
    if (ids.length != rows.length) {
      throw FormatException('$resourceName list contains duplicate IDs.');
    }

    return TeacherListEnvelopeDto(rows: rows, pagination: pagination);
  }

  final List<T> rows;
  final TeacherListPaginationDto pagination;
}

class TeacherListPaginationDto {
  const TeacherListPaginationDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory TeacherListPaginationDto.fromJson(
    Object? json, {
    required int requestedPage,
    required int requestedPerPage,
    required int rowCount,
    required String resourceName,
  }) {
    final map = readExactTeacherMap(
      json,
      context: '$resourceName list pagination',
      keys: const {'page', 'per_page', 'total', 'last_page'},
    );
    final page = readTeacherInt(map, 'page');
    final perPage = readTeacherInt(map, 'per_page');
    final total = readTeacherInt(map, 'total');
    final lastPage = readTeacherInt(map, 'last_page');

    if (page < 1 || page != requestedPage) {
      throw const FormatException(
        'Pagination page does not match the request.',
      );
    }
    if (perPage != requestedPerPage) {
      throw const FormatException(
        'Pagination per_page does not match the request.',
      );
    }
    if (total < 0) {
      throw const FormatException('Pagination total cannot be negative.');
    }
    final expectedLastPage = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
    if (lastPage != expectedLastPage) {
      throw const FormatException('Pagination last_page is contradictory.');
    }
    if (rowCount > perPage || (total > 0 && rowCount > total)) {
      throw FormatException('$resourceName row count exceeds pagination.');
    }
    if (total == 0 && rowCount != 0) {
      throw FormatException(
        'A zero-total $resourceName page cannot have rows.',
      );
    }
    if (page > lastPage && rowCount != 0) {
      throw const FormatException('An out-of-range page must be empty.');
    }

    return TeacherListPaginationDto(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }

  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  TeacherListPagination toDomain() {
    return TeacherListPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }
}
