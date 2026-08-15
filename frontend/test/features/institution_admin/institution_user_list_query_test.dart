import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_list_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';

void main() {
  group('InstitutionUserListQuery', () {
    test('serializes exact defaults and only approved optional filters', () {
      expect(const InstitutionUserListQuery.initial().toQueryParameters(), {
        'page': 1,
        'per_page': 20,
        'sort': 'full_name',
        'direction': 'asc',
      });

      final query = const InstitutionUserListQuery.initial()
          .withSearch("  O'quvchi % _  ")
          .withRole(InstitutionUserRole.student)
          .withStatus(InstitutionUserStatusFilter.inactive)
          .withPerPage(50)
          .withSort(InstitutionUserListSort.updatedAt)
          .copyWith(page: 3);

      expect(query.toQueryParameters(), {
        'page': 3,
        'per_page': 50,
        'sort': 'updated_at',
        'direction': 'asc',
        'role': 'student',
        'status': 'inactive',
        'search': "O'quvchi % _",
      });
      expect(
        query.toQueryParameters().keys,
        isNot(
          containsAll(['institution_id', 'user_id', 'include', 'permissions']),
        ),
      );
    });

    test('uses Dart runes for the trimmed 254-character limit', () {
      final valid = ' ${List.filled(254, '😀').join()} ';
      final invalid = '${List.filled(255, '😀').join()} ';

      expect(InstitutionUserListQuery.isSearchInputValid(valid), isTrue);
      expect(InstitutionUserListQuery.isSearchInputValid(invalid), isFalse);
      expect(InstitutionUserListQuery.normalizeSearch('   '), isNull);
      expect(
        InstitutionUserListQuery.searchDebounceDuration,
        const Duration(milliseconds: 300),
      );
      expect(InstitutionUserListQuery.pageSizeOptions, [20, 50, 100]);
    });

    test('query transitions preserve the approved reset semantics', () {
      var query = const InstitutionUserListQuery.initial().copyWith(page: 4);
      query = query.withRole(InstitutionUserRole.teacher);
      expect(query.page, 1);
      query = query
          .copyWith(page: 3)
          .withStatus(InstitutionUserStatusFilter.active);
      expect(query.page, 1);
      query = query
          .copyWith(page: 2)
          .withSort(InstitutionUserListSort.createdAt);
      expect(query.page, 1);
      expect(query.direction, InstitutionUserSortDirection.asc);
      query = query.withSort(InstitutionUserListSort.createdAt);
      expect(query.direction, InstitutionUserSortDirection.desc);
      query = query.copyWith(page: 2).withPerPage(100);
      expect(query.page, 1);
      query = query.copyWith(page: 2).clearSearchRoleAndStatus();
      expect(query.page, 1);
      expect(query.perPage, 100);
      expect(query.sort, InstitutionUserListSort.createdAt);
      expect(query.direction, InstitutionUserSortDirection.desc);
    });

    test(
      'equality, hash, enums, navigation, and page-size guards are exact',
      () {
        const initialA = InstitutionUserListQuery.initial();
        const initialB = InstitutionUserListQuery.initial();
        expect(initialA, initialB);
        expect(initialA.hashCode, initialB.hashCode);
        expect(initialA.withPage(2).page, 2);
        expect(InstitutionUserRole.values.map((value) => value.value), [
          'teacher',
          'student',
          'parent',
        ]);
        expect(InstitutionUserStatusFilter.values.map((value) => value.value), [
          'active',
          'inactive',
        ]);
        expect(InstitutionUserListSort.values.map((value) => value.value), [
          'full_name',
          'login_name',
          'created_at',
          'updated_at',
        ]);
        expect(
          InstitutionUserSortDirection.values.map((value) => value.value),
          ['asc', 'desc'],
        );
        expect(() => initialA.copyWith(page: 0), throwsArgumentError);
        for (final invalid in [0, 19, 21, 101]) {
          expect(() => initialA.withPerPage(invalid), throwsArgumentError);
        }
      },
    );
  });

  group('InstitutionUserListDto', () {
    test(
      'parses exact resources, preserves values, order, and page metadata',
      () {
        final query = const InstitutionUserListQuery.initial().copyWith(
          page: 2,
          perPage: 50,
        );
        final dto = InstitutionUserListDto.fromJson(
          _listJson(
            rows: [
              _userJson(fullName: '  Teacher Name  ', email: '', phone: null),
              _userJson(
                id: '00000000-0000-0000-0000-000000000002',
                role: 'parent',
                fullName: 'Parent Name',
                isActive: false,
                deactivatedAt: '2026-08-08T10:30:00Z',
              ),
            ],
            page: 2,
            perPage: 50,
            total: 52,
            lastPage: 2,
          ),
          requestedQuery: query,
        ).toDomain();

        expect(dto.users.map((user) => user.fullName), [
          '  Teacher Name  ',
          'Parent Name',
        ]);
        expect(dto.users.first.email, '');
        expect(dto.users.last.role, InstitutionUserRole.parent);
        expect(dto.users.last.isActive, isFalse);
        expect(dto.pagination.page, 2);
        expect(dto.pagination.perPage, 50);
        expect(dto.pagination.total, 52);
        expect(dto.pagination.lastPage, 2);
        expect(dto.rangeStart, 51);
        expect(dto.rangeEnd, 52);
      },
    );

    test('rejects envelope/meta/pagination drift including current_page', () {
      final invalidResponses = <Object?>[
        {'data': <Object?>[]},
        {
          'data': <Object?>[],
          'meta': {
            'pagination': {
              'current_page': 1,
              'per_page': 20,
              'total': 0,
              'last_page': 1,
            },
          },
        },
        {..._listJson(rows: const [], total: 0), 'links': <Object?>[]},
        _listJson(rows: const [], total: 0, lastPage: 2),
        _listJson(rows: const [], page: 2, total: 0),
        _listJson(rows: const [], total: -1),
      ];

      for (final response in invalidResponses) {
        expect(
          () => InstitutionUserListDto.fromJson(
            response,
            requestedQuery: const InstitutionUserListQuery.initial(),
          ),
          throwsFormatException,
        );
      }
    });

    test('accepts only empty data for an out-of-range requested page', () {
      final query = const InstitutionUserListQuery.initial().copyWith(page: 3);
      final page = InstitutionUserListDto.fromJson(
        _listJson(rows: const [], page: 3, total: 1, lastPage: 1),
        requestedQuery: query,
      ).toDomain();
      expect(page.users, isEmpty);

      expect(
        () => InstitutionUserListDto.fromJson(
          _listJson(page: 3, total: 1, lastPage: 1),
          requestedQuery: query,
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed, contradictory, duplicate, or protected rows', () {
      final activeWithTimestamp = _userJson()
        ..['deactivated_at'] = '2026-08-08T10:30:00Z';
      final inactiveWithoutTimestamp = _userJson(isActive: false);
      final protected = _userJson()..['institution_id'] = 'institution-1';
      final wrongRole = _userJson()..['role'] = 'institution_admin';
      final blankName = _userJson()..['full_name'] = '   ';
      final offsetTimestamp = _userJson()
        ..['created_at'] = '2026-08-07T20:00:00+05:00';
      final nonUuid = _userJson()..['id'] = 'user-1';
      final duplicate = [_userJson(), _userJson()];

      for (final rows in <List<Map<String, Object?>>>[
        [activeWithTimestamp],
        [inactiveWithoutTimestamp],
        [protected],
        [wrongRole],
        [blankName],
        [offsetTimestamp],
        [nonUuid],
        duplicate,
      ]) {
        expect(
          () => InstitutionUserListDto.fromJson(
            _listJson(rows: rows, total: rows.length),
            requestedQuery: const InstitutionUserListQuery.initial(),
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects every wrong row scalar/null/key/timestamp shape', () {
      final cases = <Map<String, Object?>>[];

      Map<String, Object?> changed(String key, Object? value) {
        return _userJson()..[key] = value;
      }

      cases.addAll([
        changed('id', null),
        changed('role', null),
        changed('full_name', 1),
        changed('login_name', ''),
        changed('email', 1),
        changed('phone', false),
        changed('is_active', 'true'),
        changed('must_change_password', null),
        changed('last_login_at', 1),
        changed('last_login_at', '2026-08-07T20:00:00+05:00'),
        changed('deactivated_at', false),
        changed('created_at', null),
        changed('created_at', 'not-a-dateZ'),
        changed('updated_at', '2026-08-07T16:00:00'),
      ]);
      final missing = _userJson()..remove('phone');
      cases.add(missing);

      for (final row in cases) {
        expect(
          () => InstitutionUserListDto.fromJson(
            _listJson(rows: [row]),
            requestedQuery: const InstitutionUserListQuery.initial(),
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects wrong page scalar, echo, size, and row-count shapes', () {
      final responses = <Object?>[];

      Map<String, Object?> withPaginationValue(String key, Object? value) {
        final pagination = <String, Object?>{
          'page': 1,
          'per_page': 20,
          'total': 1,
          'last_page': 1,
        };
        pagination[key] = value;

        return <String, Object?>{
          'data': [_userJson()],
          'meta': <String, Object?>{'pagination': pagination},
        };
      }

      responses.addAll([
        {'data': <Object?>{}, 'meta': _listJson()['meta']},
        {'data': <Object?>[], 'meta': <String, Object?>{}},
        {
          'data': <Object?>[],
          'meta': {
            'pagination': {
              'page': 1,
              'per_page': 20,
              'total': 0,
              'last_page': 1,
              'extra': true,
            },
          },
        },
        withPaginationValue('page', '1'),
        withPaginationValue('page', 1.0),
        withPaginationValue('per_page', true),
        withPaginationValue('per_page', 50),
        withPaginationValue('total', null),
        withPaginationValue('last_page', 0),
        _listJson(
          rows: List.generate(
            21,
            (index) => _userJson(
              id: '00000000-0000-0000-0000-${index.toString().padLeft(12, '0')}',
            ),
          ),
          total: 21,
          lastPage: 2,
        ),
        _listJson(
          rows: [
            _userJson(),
            _userJson(id: '00000000-0000-0000-0000-000000000002'),
          ],
          total: 1,
        ),
      ]);

      for (final response in responses) {
        expect(
          () => InstitutionUserListDto.fromJson(
            response,
            requestedQuery: const InstitutionUserListQuery.initial(),
          ),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, Object?> _listJson({
  List<Map<String, Object?>>? rows,
  int page = 1,
  int perPage = 20,
  int total = 1,
  int lastPage = 1,
}) {
  return {
    'data': rows ?? [_userJson()],
    'meta': {
      'pagination': {
        'page': page,
        'per_page': perPage,
        'total': total,
        'last_page': lastPage,
      },
    },
  };
}

Map<String, Object?> _userJson({
  String id = '00000000-0000-0000-0000-000000000001',
  String role = 'teacher',
  String fullName = 'Teacher Name',
  String? email = 'teacher@example.uz',
  String? phone = '+998901234567',
  bool isActive = true,
  String? deactivatedAt,
}) {
  return {
    'id': id,
    'role': role,
    'full_name': fullName,
    'login_name': 'teacher01',
    'email': email,
    'phone': phone,
    'is_active': isActive,
    'must_change_password': true,
    'last_login_at': null,
    'deactivated_at': deactivatedAt,
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T16:00:00Z',
  };
}
