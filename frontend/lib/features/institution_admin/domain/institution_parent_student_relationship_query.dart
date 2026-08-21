class InstitutionParentStudentRelationshipQuery {
  const InstitutionParentStudentRelationshipQuery._({
    required this.search,
    required this.status,
    required this.page,
    required this.perPage,
    required this.sort,
    required this.direction,
  });

  const InstitutionParentStudentRelationshipQuery.initial()
    : this._(
        search: null,
        status: null,
        page: initialPage,
        perPage: initialPerPage,
        sort: InstitutionParentStudentRelationshipSort.fullName,
        direction: InstitutionParentStudentRelationshipSortDirection.asc,
      );

  static const initialPage = 1;
  static const initialPerPage = 20;
  static const maxSearchLength = 254;
  static const searchDebounceDuration = Duration(milliseconds: 300);
  static const pageSizeOptions = <int>[20, 50, 100];

  final String? search;
  final InstitutionParentStudentRelationshipStatusFilter? status;
  final int page;
  final int perPage;
  final InstitutionParentStudentRelationshipSort sort;
  final InstitutionParentStudentRelationshipSortDirection direction;

  bool get hasSearchOrFilter => search != null || status != null;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{
      'page': page,
      'per_page': perPage,
      'sort': sort.value,
      'direction': direction.value,
    };
    if (search case final value?) {
      parameters['search'] = value;
    }
    if (status case final value?) {
      parameters['status'] = value.value;
    }
    return Map.unmodifiable(parameters);
  }

  InstitutionParentStudentRelationshipQuery copyWith({
    Object? search = _sentinel,
    Object? status = _sentinel,
    int? page,
    int? perPage,
    InstitutionParentStudentRelationshipSort? sort,
    InstitutionParentStudentRelationshipSortDirection? direction,
  }) {
    final nextPage = page ?? this.page;
    final nextPerPage = perPage ?? this.perPage;
    if (nextPage < 1) {
      throw ArgumentError.value(nextPage, 'page', 'Page must be at least 1.');
    }
    if (!pageSizeOptions.contains(nextPerPage)) {
      throw ArgumentError.value(
        nextPerPage,
        'perPage',
        'Unsupported page size.',
      );
    }
    final normalizedSearch = identical(search, _sentinel)
        ? this.search
        : normalizeSearch(search as String? ?? '');
    if (normalizedSearch != null &&
        normalizedSearch.runes.length > maxSearchLength) {
      throw ArgumentError.value(search, 'search', 'Search is too long.');
    }
    return InstitutionParentStudentRelationshipQuery._(
      search: normalizedSearch,
      status: identical(status, _sentinel)
          ? this.status
          : status as InstitutionParentStudentRelationshipStatusFilter?,
      page: nextPage,
      perPage: nextPerPage,
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
    );
  }

  InstitutionParentStudentRelationshipQuery withSearch(String? value) =>
      copyWith(search: value, page: initialPage);

  InstitutionParentStudentRelationshipQuery withStatus(
    InstitutionParentStudentRelationshipStatusFilter? value,
  ) => copyWith(status: value, page: initialPage);

  InstitutionParentStudentRelationshipQuery withSort(
    InstitutionParentStudentRelationshipSort value,
  ) => copyWith(
    sort: value,
    direction: sort == value
        ? direction.toggled()
        : InstitutionParentStudentRelationshipSortDirection.asc,
    page: initialPage,
  );

  InstitutionParentStudentRelationshipQuery withPerPage(int value) =>
      copyWith(perPage: value, page: initialPage);

  InstitutionParentStudentRelationshipQuery withPage(int value) =>
      copyWith(page: value);

  InstitutionParentStudentRelationshipQuery clearSearchAndStatus() =>
      copyWith(search: null, status: null, page: initialPage);

  static String? normalizeSearch(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static bool isSearchInputValid(String value) =>
      (normalizeSearch(value)?.runes.length ?? 0) <= maxSearchLength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionParentStudentRelationshipQuery &&
          other.search == search &&
          other.status == status &&
          other.page == page &&
          other.perPage == perPage &&
          other.sort == sort &&
          other.direction == direction;

  @override
  int get hashCode =>
      Object.hash(search, status, page, perPage, sort, direction);
}

enum InstitutionParentStudentRelationshipStatusFilter {
  active('active'),
  inactive('inactive');

  const InstitutionParentStudentRelationshipStatusFilter(this.value);
  final String value;
}

enum InstitutionParentStudentRelationshipSort {
  fullName('full_name'),
  startedAt('started_at');

  const InstitutionParentStudentRelationshipSort(this.value);
  final String value;
}

enum InstitutionParentStudentRelationshipSortDirection {
  asc('asc'),
  desc('desc');

  const InstitutionParentStudentRelationshipSortDirection(this.value);
  final String value;

  InstitutionParentStudentRelationshipSortDirection toggled() =>
      this == asc ? desc : asc;
}

const _sentinel = Object();
