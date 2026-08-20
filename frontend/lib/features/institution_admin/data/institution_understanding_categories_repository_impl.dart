import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_understanding_categories.dart';
import '../domain/institution_understanding_categories_repository.dart';
import 'institution_understanding_categories_remote_data_source.dart';

final institutionUnderstandingCategoriesRepositoryProvider =
    Provider<InstitutionUnderstandingCategoriesRepository>((ref) {
      return InstitutionUnderstandingCategoriesRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionUnderstandingCategoriesRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionUnderstandingCategoriesRepositoryImpl
    implements InstitutionUnderstandingCategoriesRepository {
  const InstitutionUnderstandingCategoriesRepositoryImpl({
    required this.remoteDataSource,
  });

  final InstitutionUnderstandingCategoriesRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionUnderstandingCategoryConfiguration>
  fetchCategories() async {
    final dto = await remoteDataSource.fetchCategories();
    return dto.configuration;
  }

  @override
  Future<InstitutionUnderstandingCategoryConfiguration> replaceCategories(
    InstitutionUnderstandingCategoryUpdateRequest request,
  ) async {
    final dto = await remoteDataSource.replaceCategories(request);
    return dto.configuration;
  }
}
