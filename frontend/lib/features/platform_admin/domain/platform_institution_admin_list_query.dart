import 'platform_institution_list_query.dart';

const int platformInstitutionAdminSearchDebounceMs = 350;
const int platformInstitutionAdminMaxSearchLength = 254;
const List<int> platformInstitutionAdminPageSizeOptions = [20, 50, 100];

enum PlatformInstitutionAdminStatus {
  active('active'),
  inactive('inactive');

  const PlatformInstitutionAdminStatus(this.apiValue);

  final String apiValue;
}

enum PlatformInstitutionAdminListSort {
  fullName('full_name'),
  loginName('login_name'),
  createdAt('created_at'),
  updatedAt('updated_at');

  const PlatformInstitutionAdminListSort(this.apiValue);

  final String apiValue;
}

class PlatformInstitutionAdminListQuery {
  static const int initialPage = 1;
  static const Duration searchDebounceDuration = Duration(
    milliseconds: platformInstitutionAdminSearchDebounceMs,
  );

  const PlatformInstitutionAdminListQuery({
    this.search,
    this.status,
    this.page = 1,
    this.perPage = 20,
    this.sort = PlatformInstitutionAdminListSort.fullName,
    this.direction = PlatformSortDirection.asc,
  }) : assert(page >= 1),
       assert(
         perPage == 20 || perPage == 50 || perPage == 100,
         'perPage must be one of the approved page sizes.',
       ),
       assert(
         search == null ||
             search.length <= platformInstitutionAdminMaxSearchLength,
       );

  final String? search;
  final PlatformInstitutionAdminStatus? status;
  final int page;
  final int perPage;
  final PlatformInstitutionAdminListSort sort;
  final PlatformSortDirection direction;

  bool get hasSearchOrFilter => search != null || status != null;

  const PlatformInstitutionAdminListQuery.initial() : this();

  PlatformInstitutionAdminListQuery copyWith({
    String? search,
    bool clearSearch = false,
    PlatformInstitutionAdminStatus? status,
    bool clearStatus = false,
    int? page,
    int? perPage,
    PlatformInstitutionAdminListSort? sort,
    PlatformSortDirection? direction,
  }) {
    return PlatformInstitutionAdminListQuery(
      search: clearSearch ? null : (search ?? this.search),
      status: clearStatus ? null : (status ?? this.status),
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      sort: sort ?? this.sort,
      direction: direction ?? this.direction,
    );
  }

  PlatformInstitutionAdminListQuery withSearchInput(String value) {
    final trimmed = normalizeSearch(value);
    return copyWith(
      search: trimmed.isEmpty ? null : trimmed,
      clearSearch: trimmed.isEmpty,
      page: 1,
    );
  }

  PlatformInstitutionAdminListQuery withStatus(
    PlatformInstitutionAdminStatus? nextStatus,
  ) {
    return copyWith(
      status: nextStatus,
      clearStatus: nextStatus == null,
      page: 1,
    );
  }

  PlatformInstitutionAdminListQuery withPageSize(int nextPerPage) {
    if (!platformInstitutionAdminPageSizeOptions.contains(nextPerPage)) {
      return this;
    }

    return copyWith(perPage: nextPerPage, page: 1);
  }

  PlatformInstitutionAdminListQuery withPage(int nextPage) {
    return copyWith(page: nextPage < 1 ? 1 : nextPage);
  }

  PlatformInstitutionAdminListQuery withSort(
    PlatformInstitutionAdminListSort nextSort,
  ) {
    if (nextSort == sort) {
      return copyWith(
        direction: direction == PlatformSortDirection.asc
            ? PlatformSortDirection.desc
            : PlatformSortDirection.asc,
        page: 1,
      );
    }

    return copyWith(
      sort: nextSort,
      direction: PlatformSortDirection.asc,
      page: 1,
    );
  }

  Map<String, Object> toQueryParameters() {
    final params = <String, Object>{
      'page': page,
      'per_page': perPage,
      'sort': sort.apiValue,
      'direction': direction.value,
    };

    final currentSearch = search;
    if (currentSearch != null && currentSearch.isNotEmpty) {
      params['search'] = currentSearch;
    }

    final currentStatus = status;
    if (currentStatus != null) {
      params['status'] = currentStatus.apiValue;
    }

    return Map.unmodifiable(params);
  }

  static bool isSearchInputValid(String value) {
    return value.length <= platformInstitutionAdminMaxSearchLength;
  }

  static String normalizeSearch(String value) {
    return value.trim();
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionAdminListQuery &&
            other.search == search &&
            other.status == status &&
            other.page == page &&
            other.perPage == perPage &&
            other.sort == sort &&
            other.direction == direction;
  }

  @override
  int get hashCode {
    return Object.hash(search, status, page, perPage, sort, direction);
  }
}
