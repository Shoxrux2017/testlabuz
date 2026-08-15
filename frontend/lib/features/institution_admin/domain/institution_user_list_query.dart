import 'institution_user.dart';

class InstitutionUserListQuery {
  const InstitutionUserListQuery._({
    required this.role,
    required this.status,
    required this.search,
    required this.page,
    required this.perPage,
    required this.sort,
    required this.direction,
  });

  const InstitutionUserListQuery.initial()
    : this._(
        role: null,
        status: null,
        search: null,
        page: initialPage,
        perPage: initialPerPage,
        sort: InstitutionUserListSort.fullName,
        direction: InstitutionUserSortDirection.asc,
      );

  static const initialPage = 1;
  static const initialPerPage = 20;
  static const maxSearchLength = 254;
  static const searchDebounceDuration = Duration(milliseconds: 300);
  static const pageSizeOptions = <int>[20, 50, 100];

  final InstitutionUserRole? role;
  final InstitutionUserStatusFilter? status;
  final String? search;
  final int page;
  final int perPage;
  final InstitutionUserListSort sort;
  final InstitutionUserSortDirection direction;

  bool get hasSearchOrFilter =>
      search != null || role != null || status != null;

  Map<String, Object> toQueryParameters() {
    final parameters = <String, Object>{
      'page': page,
      'per_page': perPage,
      'sort': sort.value,
      'direction': direction.value,
    };

    if (role case final selectedRole?) {
      parameters['role'] = selectedRole.value;
    }
    if (status case final selectedStatus?) {
      parameters['status'] = selectedStatus.value;
    }
    if (search case final committedSearch?) {
      parameters['search'] = committedSearch;
    }

    return Map<String, Object>.unmodifiable(parameters);
  }

  InstitutionUserListQuery copyWith({
    Object? role = _sentinel,
    Object? status = _sentinel,
    Object? search = _sentinel,
    int? page,
    int? perPage,
    InstitutionUserListSort? sort,
    InstitutionUserSortDirection? direction,
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

    return InstitutionUserListQuery._(
      role: identical(role, _sentinel)
          ? this.role
          : role as InstitutionUserRole?,
      status: identical(status, _sentinel)
          ? this.status
          : status as InstitutionUserStatusFilter?,
      search: normalizedSearch,
      page: nextPage,
      perPage: nextPerPage,
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
    );
  }

  InstitutionUserListQuery withSearch(String? value) {
    return copyWith(search: value, page: initialPage);
  }

  InstitutionUserListQuery withRole(InstitutionUserRole? value) {
    return copyWith(role: value, page: initialPage);
  }

  InstitutionUserListQuery withStatus(InstitutionUserStatusFilter? value) {
    return copyWith(status: value, page: initialPage);
  }

  InstitutionUserListQuery withSort(InstitutionUserListSort value) {
    return copyWith(
      sort: value,
      direction: sort == value
          ? direction.toggled()
          : InstitutionUserSortDirection.asc,
      page: initialPage,
    );
  }

  InstitutionUserListQuery withPerPage(int value) {
    return copyWith(perPage: value, page: initialPage);
  }

  InstitutionUserListQuery withPage(int value) {
    return copyWith(page: value);
  }

  InstitutionUserListQuery clearSearchRoleAndStatus() {
    return copyWith(role: null, status: null, search: null, page: initialPage);
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
        other is InstitutionUserListQuery &&
            other.role == role &&
            other.status == status &&
            other.search == search &&
            other.page == page &&
            other.perPage == perPage &&
            other.sort == sort &&
            other.direction == direction;
  }

  @override
  int get hashCode {
    return Object.hash(role, status, search, page, perPage, sort, direction);
  }
}

enum InstitutionUserStatusFilter {
  active('active'),
  inactive('inactive');

  const InstitutionUserStatusFilter(this.value);

  final String value;
}

enum InstitutionUserListSort {
  fullName('full_name'),
  loginName('login_name'),
  createdAt('created_at'),
  updatedAt('updated_at');

  const InstitutionUserListSort(this.value);

  final String value;
}

enum InstitutionUserSortDirection {
  asc('asc'),
  desc('desc');

  const InstitutionUserSortDirection(this.value);

  final String value;

  InstitutionUserSortDirection toggled() {
    return switch (this) {
      InstitutionUserSortDirection.asc => InstitutionUserSortDirection.desc,
      InstitutionUserSortDirection.desc => InstitutionUserSortDirection.asc,
    };
  }
}

const _sentinel = Object();
