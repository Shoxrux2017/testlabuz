import 'student_topic.dart';

class StudentTopicListQuery {
  const StudentTopicListQuery._({
    required this.status,
    required this.search,
    required this.page,
  });

  const StudentTopicListQuery.initial()
    : this._(status: null, search: null, page: initialPage);

  static const initialPage = 1;
  static const perPage = 20;
  static const maxSearchLength = 254;
  static const searchDebounceDuration = Duration(milliseconds: 300);

  final StudentTopicStatus? status;
  final String? search;
  final int page;

  bool get hasFilters => status != null || search != null;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{'page': page, 'per_page': perPage};
    if (status case final selectedStatus?) {
      parameters['status'] = selectedStatus.value;
    }
    if (search case final committedSearch?) {
      parameters['search'] = committedSearch;
    }

    return Map<String, Object>.unmodifiable(parameters);
  }

  StudentTopicListQuery withSearch(String? value) {
    final normalized = normalizeSearch(value ?? '');
    if (normalized != null && normalized.runes.length > maxSearchLength) {
      throw ArgumentError.value(value, 'value', 'Search is too long.');
    }

    return _copy(search: normalized, page: initialPage);
  }

  StudentTopicListQuery withStatus(StudentTopicStatus? value) {
    return _copy(status: value, page: initialPage);
  }

  StudentTopicListQuery withPage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'value', 'Page must be at least 1.');
    }

    return _copy(page: value);
  }

  StudentTopicListQuery clearFilters() {
    return const StudentTopicListQuery.initial();
  }

  StudentTopicListQuery _copy({
    Object? status = _unchanged,
    Object? search = _unchanged,
    int? page,
  }) {
    return StudentTopicListQuery._(
      status: identical(status, _unchanged)
          ? this.status
          : status as StudentTopicStatus?,
      search: identical(search, _unchanged) ? this.search : search as String?,
      page: page ?? this.page,
    );
  }

  static String? normalizeSearch(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static bool isSearchInputValid(String value) {
    return (normalizeSearch(value)?.runes.length ?? 0) <= maxSearchLength;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StudentTopicListQuery &&
            other.status == status &&
            other.search == search &&
            other.page == page;
  }

  @override
  int get hashCode => Object.hash(status, search, page);
}

const _unchanged = Object();
