import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_list_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_list_query.dart';

void main() {
  group('InstitutionGroupListDto', () {
    test('parses exact envelope pagination and preserves row order', () {
      final query = const InstitutionGroupListQuery.initial().copyWith(
        page: 2,
        perPage: 50,
      );
      final page = InstitutionGroupListDto.fromJson(
        _listJson(
          rows: [
            _groupJson(name: 'B'),
            _groupJson(id: '00000000-0000-0000-0000-000000000002', name: 'A'),
          ],
          page: 2,
          perPage: 50,
          total: 52,
          lastPage: 2,
        ),
        requestedQuery: query,
      ).toDomain();

      expect(page.groups.map((group) => group.name), ['B', 'A']);
      expect(page.pagination.page, 2);
      expect(page.pagination.perPage, 50);
      expect(page.pagination.total, 52);
      expect(page.pagination.lastPage, 2);
    });

    test('accepts only empty rows beyond authoritative last_page', () {
      final query = const InstitutionGroupListQuery.initial().copyWith(page: 4);
      final page = InstitutionGroupListDto.fromJson(
        _listJson(rows: [], page: 4, total: 41, lastPage: 3),
        requestedQuery: query,
      ).toDomain();

      expect(page.groups, isEmpty);
      expect(page.pagination.lastPage, 3);
      expect(
        () => InstitutionGroupListDto.fromJson(
          _listJson(page: 4, total: 41, lastPage: 3),
          requestedQuery: query,
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate IDs and contradictory envelope metadata', () {
      const query = InstitutionGroupListQuery.initial();
      final invalid = <Object?>[
        {'data': <Object?>[]},
        {..._listJson(), 'unknown': true},
        {
          'data': [_groupJson(), _groupJson()],
          'meta': {
            'pagination': {
              'page': 1,
              'per_page': 20,
              'total': 2,
              'last_page': 1,
            },
          },
        },
        _listJson(page: 2),
        _listJson(perPage: 50),
        _listJson(total: -1),
        _listJson(total: 21, lastPage: 1),
        _listJson(page: 1.0),
        _listJson(total: 0, lastPage: 1),
      ];

      for (final json in invalid) {
        expect(
          () => InstitutionGroupListDto.fromJson(json, requestedQuery: query),
          throwsFormatException,
          reason: json.toString(),
        );
      }
    });

    test('requires exact top-level meta and pagination keys', () {
      const query = InstitutionGroupListQuery.initial();
      final base = _listJson(rows: [], total: 0, lastPage: 1);
      final meta = Map<String, Object?>.from(base['meta']! as Map);
      final pagination = Map<String, Object?>.from(meta['pagination']! as Map);
      pagination['current_page'] = pagination.remove('page');
      meta['pagination'] = pagination;

      expect(
        () => InstitutionGroupListDto.fromJson({
          ...base,
          'meta': meta,
        }, requestedQuery: query),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _listJson({
  List<Map<String, Object?>>? rows,
  Object page = 1,
  Object perPage = 20,
  Object total = 1,
  Object lastPage = 1,
}) {
  return {
    'data': rows ?? [_groupJson()],
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

Map<String, Object?> _groupJson({
  String id = '00000000-0000-0000-0000-000000000001',
  String name = 'Group A',
}) {
  return {
    'id': id,
    'name': name,
    'level': null,
    'subject_direction': null,
    'description': null,
    'status': 'active',
    'teachers_count': 0,
    'students_count': 0,
    'archived_at': null,
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T16:00:00Z',
  };
}
