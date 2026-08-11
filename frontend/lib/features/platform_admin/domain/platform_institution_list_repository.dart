import 'platform_institution_list.dart';
import 'platform_institution_list_query.dart';

abstract interface class PlatformInstitutionListRepository {
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  );
}
