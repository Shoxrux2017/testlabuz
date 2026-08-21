import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_query.dart';

void main() {
  group('InstitutionGroupListQuery', () {
    test('defaults and serialization contain only the approved keys', () {
      const query = InstitutionGroupListQuery.initial();

      expect(query.search, isNull);
      expect(query.status, isNull);
      expect(query.page, 1);
      expect(query.perPage, 20);
      expect(query.sort, InstitutionGroupListSort.name);
      expect(query.direction, InstitutionGroupSortDirection.asc);
      expect(query.toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'name',
        'direction': 'asc',
      });
    });

    test('serializes normalized literal search and machine status exactly', () {
      final query = const InstitutionGroupListQuery.initial()
          .withSearch("  O'quvchi % _ ! Ж  ")
          .withStatus(InstitutionGroupStatusFilter.archived)
          .withPerPage(50)
          .withSort(InstitutionGroupListSort.updatedAt)
          .copyWith(direction: InstitutionGroupSortDirection.desc, page: 3);

      expect(query.toQueryParameters(), {
        'page': 3,
        'per_page': 50,
        'sort': 'updated_at',
        'direction': 'desc',
        'search': "O'quvchi % _ ! Ж",
        'status': 'archived',
      });
      expect(query.toQueryParameters().keys, {
        'page',
        'per_page',
        'sort',
        'direction',
        'search',
        'status',
      });
    });

    test('blank search normalizes to null and 254 runes is the boundary', () {
      expect(InstitutionGroupListQuery.normalizeSearch('  \n\t '), isNull);
      final valid = List.filled(254, '😀').join();
      final invalid = List.filled(255, '😀').join();
      expect(InstitutionGroupListQuery.isSearchInputValid(valid), isTrue);
      expect(InstitutionGroupListQuery.isSearchInputValid(invalid), isFalse);
      expect(
        const InstitutionGroupListQuery.initial().withSearch(valid).search,
        valid,
      );
      expect(
        () => const InstitutionGroupListQuery.initial().withSearch(invalid),
        throwsArgumentError,
      );
    });

    test('all six values participate in equality and hash identity', () {
      final base = const InstitutionGroupListQuery.initial().withSearch('A');
      final same = const InstitutionGroupListQuery.initial().withSearch(' A ');

      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(base, isNot(base.withStatus(InstitutionGroupStatusFilter.active)));
      expect(base, isNot(base.withPage(2)));
      expect(base, isNot(base.withPerPage(50)));
      expect(base, isNot(base.withSort(InstitutionGroupListSort.status)));
      expect(
        base,
        isNot(base.copyWith(direction: InstitutionGroupSortDirection.desc)),
      );
    });

    test(
      'status sort size page and clear transitions preserve exact values',
      () {
        final query = const InstitutionGroupListQuery.initial()
            .withSearch('Search')
            .withStatus(InstitutionGroupStatusFilter.active)
            .withPerPage(100)
            .withSort(InstitutionGroupListSort.createdAt)
            .withSort(InstitutionGroupListSort.createdAt)
            .withPage(4);
        final cleared = query.clearSearchAndStatus();

        expect(cleared.search, isNull);
        expect(cleared.status, isNull);
        expect(cleared.page, 1);
        expect(cleared.perPage, 100);
        expect(cleared.sort, InstitutionGroupListSort.createdAt);
        expect(cleared.direction, InstitutionGroupSortDirection.desc);
        expect(() => query.withPage(0), throwsArgumentError);
        expect(() => query.withPerPage(25), throwsArgumentError);
        expect(
          InstitutionGroupListQuery.searchDebounceDuration,
          const Duration(milliseconds: 300),
        );
      },
    );
  });
}
