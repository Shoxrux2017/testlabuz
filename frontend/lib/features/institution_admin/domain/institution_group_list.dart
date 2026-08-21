import 'institution_group.dart';

class InstitutionGroupListPage {
  const InstitutionGroupListPage({
    required this.groups,
    required this.pagination,
  });

  final List<InstitutionGroup> groups;
  final InstitutionGroupListPagination pagination;

  int get rangeStart {
    if (groups.isEmpty) {
      return 0;
    }

    return (pagination.page - 1) * pagination.perPage + 1;
  }

  int get rangeEnd {
    if (groups.isEmpty) {
      return 0;
    }

    return rangeStart + groups.length - 1;
  }
}

class InstitutionGroupListPagination {
  const InstitutionGroupListPagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final int page;
  final int perPage;
  final int total;
  final int lastPage;
}
