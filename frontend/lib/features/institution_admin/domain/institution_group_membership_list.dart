import 'institution_group_membership.dart';

class InstitutionGroupMembershipListPage {
  const InstitutionGroupMembershipListPage({
    required this.memberships,
    required this.pagination,
  });

  final List<InstitutionGroupMembership> memberships;
  final InstitutionGroupMembershipListPagination pagination;

  int get rangeStart =>
      memberships.isEmpty ? 0 : (pagination.page - 1) * pagination.perPage + 1;

  int get rangeEnd =>
      memberships.isEmpty ? 0 : rangeStart + memberships.length - 1;
}

class InstitutionGroupMembershipListPagination {
  const InstitutionGroupMembershipListPagination({
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
