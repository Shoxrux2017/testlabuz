class TeacherGroupListQuery {
  const TeacherGroupListQuery._({required this.search, required this.page});

  const TeacherGroupListQuery.initial() : this._(search: null, page: 1);

  static const initialPage = 1;
  static const perPage = 20;
  static const maxSearchLength = 254;
  static const searchDebounceDuration = Duration(milliseconds: 300);

  final String? search;
  final int page;

  bool get hasSearch => search != null;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{
      'page': page,
      'per_page': perPage,
      'sort': 'name',
      'direction': 'asc',
    };
    if (search case final committedSearch?) {
      parameters['search'] = committedSearch;
    }

    return Map<String, Object>.unmodifiable(parameters);
  }

  TeacherGroupListQuery withSearch(String? value) {
    final normalized = normalizeSearch(value ?? '');
    if (normalized != null && normalized.runes.length > maxSearchLength) {
      throw ArgumentError.value(value, 'value', 'Search is too long.');
    }

    return TeacherGroupListQuery._(search: normalized, page: initialPage);
  }

  TeacherGroupListQuery withPage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'value', 'Page must be at least 1.');
    }

    return TeacherGroupListQuery._(search: search, page: value);
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
        other is TeacherGroupListQuery &&
            other.search == search &&
            other.page == page;
  }

  @override
  int get hashCode => Object.hash(search, page);
}
