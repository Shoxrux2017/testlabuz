import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';

void main() {
  group('PlatformInstitutionAdminListQuery', () {
    test('initial query serializes canonical defaults and omits optionals', () {
      const query = PlatformInstitutionAdminListQuery.initial();

      expect(query.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'full_name',
        'direction': 'asc',
      });
      expect(query.toQueryParameters().keys, isNot(contains('search')));
      expect(query.toQueryParameters().keys, isNot(contains('status')));
    });

    test('serializes only accepted admin list query parameters', () {
      final query = const PlatformInstitutionAdminListQuery.initial()
          .withSearchInput('  Ali Valiyev  ')
          .withStatus(PlatformInstitutionAdminStatus.inactive)
          .withSort(PlatformInstitutionAdminListSort.createdAt)
          .copyWith(direction: PlatformSortDirection.desc, page: 2);

      expect(query.toQueryParameters(), {
        'page': 2,
        'per_page': 20,
        'sort': 'created_at',
        'direction': 'desc',
        'search': 'Ali Valiyev',
        'status': 'inactive',
      });
      expect(
        query.toQueryParameters().keys,
        isNot(
          containsAll([
            'institution_id',
            'role',
            'user_id',
            'password',
            'password_hash',
            'must_change_password',
            'created_by_user_id',
          ]),
        ),
      );
    });

    test('normalizes search and enforces 254 character client cap', () {
      expect(
        PlatformInstitutionAdminListQuery.normalizeSearch('  admin  '),
        'admin',
      );
      expect(PlatformInstitutionAdminListQuery.normalizeSearch('   '), '');

      final maxLengthSearch = List.filled(
        platformInstitutionAdminMaxSearchLength,
        'x',
      ).join();
      final tooLongSearch = '$maxLengthSearch!';

      expect(
        PlatformInstitutionAdminListQuery.isSearchInputValid(maxLengthSearch),
        isTrue,
      );
      expect(
        PlatformInstitutionAdminListQuery.isSearchInputValid(tooLongSearch),
        isFalse,
      );
    });

    test('maps every status sort direction and page size explicitly', () {
      expect(
        PlatformInstitutionAdminStatus.values.map((status) => status.apiValue),
        ['active', 'inactive'],
      );
      expect(
        PlatformInstitutionAdminListSort.values.map((sort) => sort.apiValue),
        ['full_name', 'login_name', 'created_at', 'updated_at'],
      );
      expect(PlatformSortDirection.values.map((direction) => direction.value), [
        'asc',
        'desc',
      ]);
      expect(platformInstitutionAdminPageSizeOptions, [20, 50, 100]);

      for (final pageSize in platformInstitutionAdminPageSizeOptions) {
        expect(
          const PlatformInstitutionAdminListQuery.initial()
              .withPageSize(pageSize)
              .perPage,
          pageSize,
        );
      }
      expect(
        const PlatformInstitutionAdminListQuery.initial()
            .withPageSize(25)
            .perPage,
        20,
      );
    });

    test('sort selection toggles current direction and resets page', () {
      final query = const PlatformInstitutionAdminListQuery.initial().copyWith(
        page: 4,
      );

      final toggled = query.withSort(PlatformInstitutionAdminListSort.fullName);
      final changed = query.withSort(
        PlatformInstitutionAdminListSort.loginName,
      );

      expect(toggled.direction, PlatformSortDirection.desc);
      expect(toggled.page, 1);
      expect(changed.sort, PlatformInstitutionAdminListSort.loginName);
      expect(changed.direction, PlatformSortDirection.asc);
      expect(changed.page, 1);
    });
  });
}
