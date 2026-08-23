import 'teacher_topic.dart';

class TeacherTopicListQuery {
  const TeacherTopicListQuery._({
    required this.groupId,
    required this.status,
    required this.search,
    required this.page,
  });

  const TeacherTopicListQuery.initial()
    : this._(groupId: null, status: null, search: null, page: 1);

  static const initialPage = 1;
  static const perPage = 20;
  static const maxSearchLength = 254;
  static const searchDebounceDuration = Duration(milliseconds: 300);

  final String? groupId;
  final TeacherTopicStatus? status;
  final String? search;
  final int page;

  bool get hasFilters => groupId != null || status != null || search != null;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{
      'page': page,
      'per_page': perPage,
      'sort': 'created_at',
      'direction': 'desc',
    };
    if (groupId case final selectedGroupId?) {
      parameters['group_id'] = selectedGroupId;
    }
    if (status case final selectedStatus?) {
      parameters['status'] = selectedStatus.value;
    }
    if (search case final committedSearch?) {
      parameters['search'] = committedSearch;
    }

    return Map<String, Object>.unmodifiable(parameters);
  }

  TeacherTopicListQuery withSearch(String? value) {
    final normalized = normalizeSearch(value ?? '');
    if (normalized != null && normalized.runes.length > maxSearchLength) {
      throw ArgumentError.value(value, 'value', 'Search is too long.');
    }

    return _copy(search: normalized, page: initialPage);
  }

  TeacherTopicListQuery withGroupId(String? value) {
    return _copy(groupId: value, page: initialPage);
  }

  TeacherTopicListQuery withStatus(TeacherTopicStatus? value) {
    return _copy(status: value, page: initialPage);
  }

  TeacherTopicListQuery withPage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'value', 'Page must be at least 1.');
    }

    return _copy(page: value);
  }

  TeacherTopicListQuery clearFilters() {
    return const TeacherTopicListQuery.initial();
  }

  TeacherTopicListQuery _copy({
    Object? groupId = _sentinel,
    Object? status = _sentinel,
    Object? search = _sentinel,
    int? page,
  }) {
    return TeacherTopicListQuery._(
      groupId: identical(groupId, _sentinel)
          ? this.groupId
          : groupId as String?,
      status: identical(status, _sentinel)
          ? this.status
          : status as TeacherTopicStatus?,
      search: identical(search, _sentinel) ? this.search : search as String?,
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
        other is TeacherTopicListQuery &&
            other.groupId == groupId &&
            other.status == status &&
            other.search == search &&
            other.page == page;
  }

  @override
  int get hashCode => Object.hash(groupId, status, search, page);
}

const _sentinel = Object();
