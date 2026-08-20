import 'institution_understanding_categories.dart';

abstract interface class InstitutionUnderstandingCategoriesRepository {
  Future<InstitutionUnderstandingCategoryConfiguration> fetchCategories();

  Future<InstitutionUnderstandingCategoryConfiguration> replaceCategories(
    InstitutionUnderstandingCategoryUpdateRequest request,
  );
}

class InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException
    implements Exception {
  const InstitutionUnderstandingCategoriesUpdateOutcomeUnknownException();
}
