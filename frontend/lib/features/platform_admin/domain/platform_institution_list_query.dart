import 'platform_institution.dart';

class PlatformInstitutionListQuery {
  const PlatformInstitutionListQuery._({
    required this.search,
    required this.status,
    required this.type,
    required this.page,
    required this.perPage,
    required this.sort,
    required this.direction,
  });

  const PlatformInstitutionListQuery.initial()
    : this._(
        search: null,
        status: null,
        type: null,
        page: initialPage,
        perPage: initialPerPage,
        sort: PlatformInstitutionListSort.name,
        direction: PlatformSortDirection.asc,
      );

  static const initialPage = 1;
  static const initialPerPage = 20;
  static const maxSearchLength = 200;
  static const searchDebounceDuration = Duration(milliseconds: 350);
  static const pageSizeOptions = <int>[20, 50, 100];

  final String? search;
  final PlatformInstitutionStatus? status;
  final PlatformInstitutionType? type;
  final int page;
  final int perPage;
  final PlatformInstitutionListSort sort;
  final PlatformSortDirection direction;

  bool get hasSearchOrFilter =>
      search != null || status != null || type != null;

  Map<String, Object> toQueryParameters() {
    final query = <String, Object>{
      'page': page,
      'per_page': perPage,
      'sort': sort.value,
      'direction': direction.value,
    };

    final committedSearch = search;
    if (committedSearch != null) {
      query['search'] = committedSearch;
    }

    final committedStatus = status;
    if (committedStatus != null) {
      query['status'] = committedStatus.value;
    }

    final committedType = type;
    if (committedType != null) {
      query['type'] = committedType.value;
    }

    return Map<String, Object>.unmodifiable(query);
  }

  PlatformInstitutionListQuery copyWith({
    Object? search = _sentinel,
    Object? status = _sentinel,
    Object? type = _sentinel,
    int? page,
    int? perPage,
    PlatformInstitutionListSort? sort,
    PlatformSortDirection? direction,
  }) {
    final nextSearch = identical(search, _sentinel)
        ? this.search
        : _normalizeProvidedSearch(search as String?);
    final nextPage = page ?? this.page;
    final nextPerPage = perPage ?? this.perPage;
    _validatePage(nextPage);
    _validatePerPage(nextPerPage);

    return PlatformInstitutionListQuery._(
      search: nextSearch,
      status: identical(status, _sentinel)
          ? this.status
          : status as PlatformInstitutionStatus?,
      type: identical(type, _sentinel)
          ? this.type
          : type as PlatformInstitutionType?,
      page: nextPage,
      perPage: nextPerPage,
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
    );
  }

  PlatformInstitutionListQuery withSearch(String? value) {
    return copyWith(search: value, page: initialPage);
  }

  PlatformInstitutionListQuery withStatus(PlatformInstitutionStatus? value) {
    return copyWith(status: value, page: initialPage);
  }

  PlatformInstitutionListQuery withType(PlatformInstitutionType? value) {
    return copyWith(type: value, page: initialPage);
  }

  PlatformInstitutionListQuery withSort(PlatformInstitutionListSort value) {
    final nextDirection = sort == value
        ? direction.toggled()
        : PlatformSortDirection.asc;

    return copyWith(sort: value, direction: nextDirection, page: initialPage);
  }

  PlatformInstitutionListQuery withPerPage(int value) {
    return copyWith(perPage: value, page: initialPage);
  }

  PlatformInstitutionListQuery withPage(int value) {
    return copyWith(page: value);
  }

  static String? normalizeSearch(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  static bool isSearchInputValid(String value) {
    return value.length <= maxSearchLength;
  }

  static String? _normalizeProvidedSearch(String? value) {
    if (value == null) {
      return null;
    }

    if (!isSearchInputValid(value)) {
      throw ArgumentError.value(value, 'value', 'Search is too long.');
    }

    return normalizeSearch(value);
  }

  static void _validatePage(int value) {
    if (value < initialPage) {
      throw ArgumentError.value(value, 'value', 'Page must be at least 1.');
    }
  }

  static void _validatePerPage(int value) {
    if (!pageSizeOptions.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported page size.');
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionListQuery &&
            other.search == search &&
            other.status == status &&
            other.type == type &&
            other.page == page &&
            other.perPage == perPage &&
            other.sort == sort &&
            other.direction == direction;
  }

  @override
  int get hashCode {
    return Object.hash(search, status, type, page, perPage, sort, direction);
  }
}

enum PlatformInstitutionListSort {
  name('name'),
  createdAt('created_at'),
  updatedAt('updated_at'),
  status('status');

  const PlatformInstitutionListSort(this.value);

  final String value;
}

enum PlatformSortDirection {
  asc('asc'),
  desc('desc');

  const PlatformSortDirection(this.value);

  final String value;

  PlatformSortDirection toggled() {
    return switch (this) {
      PlatformSortDirection.asc => PlatformSortDirection.desc,
      PlatformSortDirection.desc => PlatformSortDirection.asc,
    };
  }
}

const _sentinel = Object();
