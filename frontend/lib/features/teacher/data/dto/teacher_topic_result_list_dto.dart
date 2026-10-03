import '../../domain/teacher_topic_result.dart';
import '../../domain/teacher_topic_result_list.dart';
import 'teacher_dto_parse.dart';
import 'teacher_list_envelope_dto.dart';
import 'teacher_topic_result_dto.dart';

/// A page of Topic results with the cohort status counts (docs/09 §25.5).
/// The counts are taken before filtering, so the page total must agree with
/// them and every row must match the requested filters.
class TeacherTopicResultListDto {
  const TeacherTopicResultListDto._(this._list);

  factory TeacherTopicResultListDto.fromJson(
    Object? json, {
    required TeacherTopicResultListQuery query,
  }) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Topic result list envelope',
      keys: const {'data', 'meta'},
    );
    final rawRows = envelope['data'];
    if (rawRows is! List<Object?>) {
      throw const FormatException('Topic result list data must be an array.');
    }
    final meta = readExactTeacherMap(
      envelope['meta'],
      context: 'Topic result list meta',
      keys: const {'pagination', 'counts'},
    );
    final pagination = TeacherListPaginationDto.fromJson(
      meta['pagination'],
      requestedPage: query.page,
      requestedPerPage: TeacherTopicResultListQuery.perPage,
      rowCount: rawRows.length,
      resourceName: 'Topic result',
    ).toDomain();
    final counts = _readCounts(meta['counts']);
    final items = List<TeacherTopicResult>.unmodifiable(
      rawRows.map((row) => TeacherTopicResultDto.fromJson(row).toDomain()),
    );

    final studentIds = items.map((item) => item.studentId.toLowerCase());
    if (studentIds.toSet().length != items.length) {
      throw const FormatException('Topic result list repeats a Student.');
    }
    _requireTotalMatchesCounts(pagination.total, counts, query);
    for (final item in items) {
      if ((query.status != null && item.status != query.status) ||
          (query.category != null && item.category?.code != query.category)) {
        throw const FormatException(
          'Topic result list contains a row outside its filters.',
        );
      }
    }

    return TeacherTopicResultListDto._(
      TeacherTopicResultList(
        items: items,
        pagination: pagination,
        counts: counts,
      ),
    );
  }

  final TeacherTopicResultList _list;

  TeacherTopicResultList toDomain() => _list;
}

TeacherTopicResultCounts _readCounts(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Topic result counts',
    keys: {for (final status in TeacherTopicResultStatus.values) status.value},
  );
  final counts = <TeacherTopicResultStatus, int>{};
  for (final status in TeacherTopicResultStatus.values) {
    final count = readTeacherInt(map, status.value);
    if (count < 0) {
      throw const FormatException('Topic result counts cannot be negative.');
    }
    counts[status] = count;
  }
  return TeacherTopicResultCounts(counts);
}

void _requireTotalMatchesCounts(
  int total,
  TeacherTopicResultCounts counts,
  TeacherTopicResultListQuery query,
) {
  final status = query.status;
  final limit = status == null ? counts.total : counts.of(status);
  final consistent = query.category == null ? total == limit : total <= limit;
  if (!consistent) {
    throw const FormatException(
      'Topic result list total contradicts the status counts.',
    );
  }
}
