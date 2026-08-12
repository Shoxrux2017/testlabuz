import 'platform_institution_admin.dart';

class PlatformInstitutionAdminList {
  const PlatformInstitutionAdminList({
    required this.admins,
    required this.pagination,
  });

  final List<PlatformInstitutionAdmin> admins;
  final PlatformInstitutionAdminPagination pagination;

  bool get isEmpty => admins.isEmpty;
}

class PlatformInstitutionAdminPagination {
  const PlatformInstitutionAdminPagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasPreviousPage => page > 1;

  bool get hasNextPage => page < lastPage;
}
