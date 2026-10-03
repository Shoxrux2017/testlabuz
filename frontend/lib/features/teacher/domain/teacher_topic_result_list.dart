import 'teacher_list_pagination.dart';
import 'teacher_topic_result.dart';

/// The number of cohort results per status, before any filter.
class TeacherTopicResultCounts {
  TeacherTopicResultCounts(Map<TeacherTopicResultStatus, int> counts)
    : _counts = Map.unmodifiable(counts);

  final Map<TeacherTopicResultStatus, int> _counts;

  int of(TeacherTopicResultStatus status) => _counts[status] ?? 0;

  int get total => _counts.values.fold(0, (sum, count) => sum + count);
}

class TeacherTopicResultList {
  const TeacherTopicResultList({
    required this.items,
    required this.pagination,
    required this.counts,
  });

  final List<TeacherTopicResult> items;
  final TeacherListPagination pagination;
  final TeacherTopicResultCounts counts;
}

/// `GET /teacher/topics/{topic}/results` filters and page; 25 rows a page.
class TeacherTopicResultListQuery {
  const TeacherTopicResultListQuery({
    this.status,
    this.category,
    this.page = initialPage,
  });

  static const initialPage = 1;
  static const perPage = 25;

  final TeacherTopicResultStatus? status;
  final TeacherTopicResultCategoryCode? category;
  final int page;

  bool get isFiltered => status != null || category != null;

  Map<String, Object> toQueryParameters() {
    return Map<String, Object>.unmodifiable(<String, Object>{
      if (status case final selected?) 'result_status': selected.value,
      if (category case final selected?) 'category': selected.value,
      'page': page,
      'per_page': perPage,
    });
  }

  /// A new filter starts at the first page.
  TeacherTopicResultListQuery withStatus(TeacherTopicResultStatus? value) =>
      TeacherTopicResultListQuery(status: value, category: category);

  TeacherTopicResultListQuery withCategory(
    TeacherTopicResultCategoryCode? value,
  ) => TeacherTopicResultListQuery(status: status, category: value);

  TeacherTopicResultListQuery withPage(int value) =>
      TeacherTopicResultListQuery(
        status: status,
        category: category,
        page: value,
      );

  @override
  bool operator ==(Object other) {
    return other is TeacherTopicResultListQuery &&
        other.status == status &&
        other.category == category &&
        other.page == page;
  }

  @override
  int get hashCode => Object.hash(status, category, page);
}
