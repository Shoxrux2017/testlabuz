class InstitutionGroupListQuery {
  const InstitutionGroupListQuery._({
    required this.search,
    required this.status,
    required this.page,
    required this.perPage,
    required this.sort,
    required this.direction,
  });

  const InstitutionGroupListQuery.initial()
    : this._(
        search: null,
        status: null,
        page: initialPage,
        perPage: initialPerPage,
        sort: InstitutionGroupListSort.name,
        direction: InstitutionGroupSortDirection.asc,
      );

  static const initialPage = 1;
  static const initialPerPage = 20;
  static const maxSearchLength = 254;
  static const searchDebounceDuration = Duration(milliseconds: 300);
  static const pageSizeOptions = <int>[20, 50, 100];

  final String? search;
  final InstitutionGroupStatusFilter? status;
  final int page;
  final int perPage;
  final InstitutionGroupListSort sort;
  final InstitutionGroupSortDirection direction;

  bool get hasSearchOrFilter => search != null || status != null;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{
      'page': page,
      'per_page': perPage,
      'sort': sort.value,
      'direction': direction.value,
    };

    if (search case final committedSearch?) {
      parameters['search'] = committedSearch;
    }
    if (status case final selectedStatus?) {
      parameters['status'] = selectedStatus.value;
    }

    return Map<String, Object>.unmodifiable(parameters);
  }

  InstitutionGroupListQuery copyWith({
    Object? search = _sentinel,
    Object? status = _sentinel,
    int? page,
    int? perPage,
    InstitutionGroupListSort? sort,
    InstitutionGroupSortDirection? direction,
  }) {
    final nextPage = page ?? this.page;
    final nextPerPage = perPage ?? this.perPage;
    _validatePage(nextPage);
    _validatePerPage(nextPerPage);

    final normalizedSearch = identical(search, _sentinel)
        ? this.search
        : normalizeSearch(search as String? ?? '');
    if (normalizedSearch != null &&
        normalizedSearch.runes.length > maxSearchLength) {
      throw ArgumentError.value(search, 'search', 'Search is too long.');
    }

    return InstitutionGroupListQuery._(
      search: normalizedSearch,
      status: identical(status, _sentinel)
          ? this.status
          : status as InstitutionGroupStatusFilter?,
      page: nextPage,
      perPage: nextPerPage,
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
    );
  }

  InstitutionGroupListQuery withSearch(String? value) {
    return copyWith(search: value, page: initialPage);
  }

  InstitutionGroupListQuery withStatus(InstitutionGroupStatusFilter? value) {
    return copyWith(status: value, page: initialPage);
  }

  InstitutionGroupListQuery withSort(InstitutionGroupListSort value) {
    return copyWith(
      sort: value,
      direction: sort == value
          ? direction.toggled()
          : InstitutionGroupSortDirection.asc,
      page: initialPage,
    );
  }

  InstitutionGroupListQuery withPerPage(int value) {
    return copyWith(perPage: value, page: initialPage);
  }

  InstitutionGroupListQuery withPage(int value) {
    return copyWith(page: value);
  }

  InstitutionGroupListQuery clearSearchAndStatus() {
    return copyWith(search: null, status: null, page: initialPage);
  }

  static String? normalizeSearch(String value) {
    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  static bool isSearchInputValid(String value) {
    return (normalizeSearch(value)?.runes.length ?? 0) <= maxSearchLength;
  }

  static void _validatePage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'page', 'Page must be at least 1.');
    }
  }

  static void _validatePerPage(int value) {
    if (!pageSizeOptions.contains(value)) {
      throw ArgumentError.value(value, 'perPage', 'Unsupported page size.');
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionGroupListQuery &&
            other.search == search &&
            other.status == status &&
            other.page == page &&
            other.perPage == perPage &&
            other.sort == sort &&
            other.direction == direction;
  }

  @override
  int get hashCode =>
      Object.hash(search, status, page, perPage, sort, direction);
}

enum InstitutionGroupStatusFilter {
  active('active'),
  archived('archived');

  const InstitutionGroupStatusFilter(this.value);

  final String value;
}

enum InstitutionGroupListSort {
  name('name'),
  status('status'),
  createdAt('created_at'),
  updatedAt('updated_at');

  const InstitutionGroupListSort(this.value);

  final String value;
}

enum InstitutionGroupSortDirection {
  asc('asc'),
  desc('desc');

  const InstitutionGroupSortDirection(this.value);

  final String value;

  InstitutionGroupSortDirection toggled() {
    return switch (this) {
      InstitutionGroupSortDirection.asc => InstitutionGroupSortDirection.desc,
      InstitutionGroupSortDirection.desc => InstitutionGroupSortDirection.asc,
    };
  }
}

const _sentinel = Object();
