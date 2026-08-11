import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';

void main() {
  group('PlatformInstitutionListQuery', () {
    test('initial query serializes canonical defaults and omits optionals', () {
      const query = PlatformInstitutionListQuery.initial();

      expect(query.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'name',
        'direction': 'asc',
      });
      expect(query.toQueryParameters().keys, isNot(contains('search')));
      expect(query.toQueryParameters().keys, isNot(contains('status')));
      expect(query.toQueryParameters().keys, isNot(contains('type')));
    });

    test('serializes only accepted optional values and backend allowlists', () {
      final query = const PlatformInstitutionListQuery.initial()
          .withSearch('Oliy maktab')
          .withStatus(PlatformInstitutionStatus.active)
          .withType(PlatformInstitutionType.privateEducation)
          .withSort(PlatformInstitutionListSort.createdAt)
          .copyWith(direction: PlatformSortDirection.desc, page: 2);

      expect(query.toQueryParameters(), {
        'page': 2,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
        'search': 'Oliy maktab',
        'status': 'active',
        'type': 'private_education',
      });
      expect(
        query.toQueryParameters().keys,
        isNot(
          containsAll([
            'institution_id',
            'created_by_user_id',
            'role',
            'user_id',
            'include_users',
            'include_learning_data',
            'address',
            'description',
            'activity',
            'teacher_count',
            'student_count',
          ]),
        ),
      );
    });

    test('normalizes search and blocks values over 200 characters', () {
      expect(
        PlatformInstitutionListQuery.normalizeSearch('  School  '),
        'School',
      );
      expect(PlatformInstitutionListQuery.normalizeSearch('   '), isNull);
      final maxLengthSearch = List.filled(
        PlatformInstitutionListQuery.maxSearchLength,
        'x',
      ).join();
      final tooLongSearch = '$maxLengthSearch!';
      expect(
        PlatformInstitutionListQuery.isSearchInputValid(maxLengthSearch),
        isTrue,
      );
      expect(
        PlatformInstitutionListQuery.isSearchInputValid(tooLongSearch),
        isFalse,
      );
    });

    test('maps every status type sort direction and page size explicitly', () {
      expect(PlatformInstitutionStatus.values.map((status) => status.value), [
        'active',
        'inactive',
      ]);
      expect(PlatformInstitutionType.values.map((type) => type.value), [
        'school',
        'college',
        'lyceum',
        'university',
        'institute',
        'learning_center',
        'training_center',
        'private_education',
        'other',
      ]);
      expect(PlatformInstitutionListSort.values.map((sort) => sort.value), [
        'name',
        'created_at',
        'updated_at',
        'status',
      ]);
      expect(PlatformSortDirection.values.map((direction) => direction.value), [
        'asc',
        'desc',
      ]);
      expect(PlatformInstitutionListQuery.pageSizeOptions, [20, 50, 100]);

      for (final pageSize in PlatformInstitutionListQuery.pageSizeOptions) {
        expect(
          const PlatformInstitutionListQuery.initial()
              .withPerPage(pageSize)
              .perPage,
          pageSize,
        );
      }
      expect(
        () => const PlatformInstitutionListQuery.initial().withPerPage(25),
        throwsArgumentError,
      );
    });

    test('query equality prevents duplicate identical loads', () {
      const first = PlatformInstitutionListQuery.initial();
      const second = PlatformInstitutionListQuery.initial();
      final changed = first.withStatus(PlatformInstitutionStatus.inactive);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(changed));
    });
  });
}
