import 'platform_institution.dart';

class PlatformInstitutionListPage {
  const PlatformInstitutionListPage({
    required this.institutions,
    required this.pagination,
  });

  final List<PlatformInstitutionSummary> institutions;
  final PlatformInstitutionPagination pagination;
}

class PlatformInstitutionPagination {
  const PlatformInstitutionPagination({
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
