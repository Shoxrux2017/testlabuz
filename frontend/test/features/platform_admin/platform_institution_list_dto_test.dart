import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/data/dto/platform_institution_list_dto.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';

void main() {
  group('PlatformInstitutionListDto', () {
    test('decodes exact normal and empty collection responses', () {
      final page = PlatformInstitutionListDto.fromJson(_listJson()).toDomain();

      expect(page.institutions, hasLength(2));
      expect(page.institutions.first.name, 'Example School');
      expect(page.institutions.first.type, PlatformInstitutionType.school);
      expect(page.institutions.first.status, PlatformInstitutionStatus.active);
      expect(page.institutions.first.userCounts.total, 42);
      expect(page.institutions.first.userCounts.active, 40);
      expect(page.pagination.page, 1);
      expect(page.pagination.perPage, 20);
      expect(page.pagination.total, 2);
      expect(page.pagination.lastPage, 1);

      final empty = PlatformInstitutionListDto.fromJson(
        _listJson(data: const [], total: 0),
      ).toDomain();
      expect(empty.institutions, isEmpty);
      expect(empty.pagination.total, 0);
      expect(empty.pagination.lastPage, 1);
    });

    test('decodes all nine types both statuses nullable contacts and times', () {
      const types = [
        'school',
        'college',
        'lyceum',
        'university',
        'institute',
        'learning_center',
        'training_center',
        'private_education',
        'other',
      ];
      final rows = [
        for (var index = 0; index < types.length; index++)
          _institutionJson(
            id: '00000000-0000-0000-0000-${(index + 1).toString().padLeft(12, '0')}',
            name: 'Institution $index',
            type: types[index],
            status: index.isEven ? 'active' : 'inactive',
            contactEmail: index.isEven ? null : 'contact$index@example.uz',
            contactPhone: index.isEven ? '+998$index' : null,
            createdAt: '2026-08-07T20:00:00+05:00',
            updatedAt: '2026-08-07T16:30:00Z',
          ),
      ];

      final page = PlatformInstitutionListDto.fromJson(
        _listJson(data: rows, total: rows.length),
      ).toDomain();

      expect(
        page.institutions.map((institution) => institution.type.value),
        types,
      );
      expect(page.institutions.map((institution) => institution.status.value), [
        'active',
        'inactive',
        'active',
        'inactive',
        'active',
        'inactive',
        'active',
        'inactive',
        'active',
      ]);
      expect(page.institutions.first.contactEmail, isNull);
      expect(page.institutions.first.contactPhone, '+9980');
      expect(page.institutions.first.createdAt, DateTime.utc(2026, 8, 7, 15));
      expect(
        page.institutions.first.updatedAt,
        DateTime.utc(2026, 8, 7, 16, 30),
      );
    });

    test('rejects strict invalid core counts pagination and enum shapes', () {
      final invalidResponses = [
        {'meta': {}},
        _listJson(data: {}),
        _listJson(
          data: [
            _institutionJson(extra: {'name': ''}),
          ],
        ),
        _listJson(
          data: [
            _institutionJson(extra: {'type': 'academy'}),
          ],
        ),
        _listJson(
          data: [
            _institutionJson(extra: {'status': 'archived'}),
          ],
        ),
        _listJson(
          data: [
            _institutionJson(extra: {'contact_email': false}),
          ],
        ),
        _listJson(
          data: [
            _institutionJson(extra: {'created_at': 'not-a-date'}),
          ],
        ),
        _listJson(
          data: [
            _institutionJson(userCounts: {'total': '42', 'active': 40}),
          ],
        ),
        _listJson(
          data: [
            _institutionJson(userCounts: {'total': 42.0, 'active': 40}),
          ],
        ),
        _listJson(
          data: [
            _institutionJson(userCounts: {'total': 1, 'active': 2}),
          ],
        ),
        _listJson(page: 0),
        _listJson(perPage: 101),
        _listJson(total: -1),
        _listJson(lastPage: 0),
        _listJson(paginationExtra: {'page': true}),
      ];

      for (final response in invalidResponses) {
        expect(
          () => PlatformInstitutionListDto.fromJson(response),
          throwsException,
        );
      }
    });

    test('ignores additive unknown and protected fields', () {
      final page = PlatformInstitutionListDto.fromJson(
        _listJson(
          data: [
            _institutionJson(
              extra: {
                'creator': {'full_name': 'Protected Creator'},
                'created_by_user_id': 'hidden',
                'deactivated_at': '2026-08-08T00:00:00Z',
                'address': 'Hidden address',
                'description': 'Hidden description',
                'settings': {'timezone': 'Asia/Tashkent'},
                'users': [
                  {'full_name': 'Protected User'},
                ],
                'role_counts': {'teacher': 2},
                'learning': {'topics': 1},
              },
            ),
          ],
        ),
      ).toDomain();

      final institution = page.institutions.single;
      expect(institution.name, 'Example School');
      expect(institution.contactEmail, 'info@example.uz');
      expect(institution.userCounts.active, 40);
    });
  });
}

Map<String, Object?> _listJson({
  Object? data = _defaultDataMarker,
  int page = 1,
  int perPage = 20,
  int total = 2,
  int lastPage = 1,
  Map<String, Object?> paginationExtra = const {},
}) {
  return {
    'data': identical(data, _defaultDataMarker)
        ? [
            _institutionJson(),
            _institutionJson(
              id: '00000000-0000-0000-0000-000000000002',
              name: 'Second College',
              type: 'college',
              status: 'inactive',
              contactEmail: null,
              contactPhone: null,
              userCounts: {'total': 3, 'active': 1},
            ),
          ]
        : data,
    'meta': {
      'pagination': {
        'page': page,
        'per_page': perPage,
        'total': total,
        'last_page': lastPage,
        ...paginationExtra,
      },
    },
  };
}

Map<String, Object?> _institutionJson({
  String id = '00000000-0000-0000-0000-000000000001',
  String name = 'Example School',
  String type = 'school',
  String status = 'active',
  Object? contactEmail = 'info@example.uz',
  Object? contactPhone = '+998901234567',
  String createdAt = '2026-08-07T15:00:00Z',
  String updatedAt = '2026-08-07T16:00:00Z',
  Map<String, Object?> userCounts = const {'total': 42, 'active': 40},
  Map<String, Object?> extra = const {},
}) {
  return {
    'id': id,
    'name': name,
    'type': type,
    'status': status,
    'contact_email': contactEmail,
    'contact_phone': contactPhone,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'user_counts': userCounts,
    ...extra,
  };
}

const _defaultDataMarker = Object();
