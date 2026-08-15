import 'institution_user.dart';

class InstitutionUserListPage {
  const InstitutionUserListPage({
    required this.users,
    required this.pagination,
  });

  final List<InstitutionUser> users;
  final InstitutionUserListPagination pagination;

  int get rangeStart {
    if (users.isEmpty) {
      return 0;
    }

    return (pagination.page - 1) * pagination.perPage + 1;
  }

  int get rangeEnd {
    if (users.isEmpty) {
      return 0;
    }

    return rangeStart + users.length - 1;
  }
}

class InstitutionUserListPagination {
  const InstitutionUserListPagination({
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
