import 'platform_institution_detail.dart';

abstract interface class PlatformInstitutionDetailRepository {
  Future<PlatformInstitutionDetail> fetchInstitutionDetail(
    String institutionId,
  );
}
