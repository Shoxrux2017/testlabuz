class TeacherGroupStudentListQuery {
  const TeacherGroupStudentListQuery._({
    required this.search,
    required this.page,
    required this.perPage,
  });

  const TeacherGroupStudentListQuery.initial()
    : this._(search: null, page: initialPage, perPage: defaultPerPage);

  static const initialPage = 1;
  static const defaultPerPage = 50;
  static const maxPerPage = 100;
  static const maxSearchLength = 100;

  final String? search;
  final int page;
  final int perPage;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{'page': page, 'per_page': perPage};
    if (search case final committedSearch?) {
      parameters['search'] = committedSearch;
    }
    return Map<String, Object>.unmodifiable(parameters);
  }

  TeacherGroupStudentListQuery withSearch(String? value) {
    final normalized = normalizeSearch(value ?? '');
    if (normalized != null && normalized.runes.length > maxSearchLength) {
      throw ArgumentError.value(value, 'value', 'Search is too long.');
    }
    return TeacherGroupStudentListQuery._(
      search: normalized,
      page: initialPage,
      perPage: perPage,
    );
  }

  TeacherGroupStudentListQuery withPage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'value', 'Page must be at least 1.');
    }
    return TeacherGroupStudentListQuery._(
      search: search,
      page: value,
      perPage: perPage,
    );
  }

  TeacherGroupStudentListQuery withPerPage(int value) {
    if (value < 1 || value > maxPerPage) {
      throw ArgumentError.value(value, 'value', 'Per-page must be 1 to 100.');
    }
    return TeacherGroupStudentListQuery._(
      search: search,
      page: initialPage,
      perPage: value,
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
        other is TeacherGroupStudentListQuery &&
            other.search == search &&
            other.page == page &&
            other.perPage == perPage;
  }

  @override
  int get hashCode => Object.hash(search, page, perPage);
}
