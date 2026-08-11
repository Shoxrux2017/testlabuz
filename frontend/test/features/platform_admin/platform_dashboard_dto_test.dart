import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/data/dto/platform_dashboard_dto.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';

void main() {
  group('PlatformDashboardDto', () {
    test('decodes exact non-empty response into typed domain model', () {
      final dto = PlatformDashboardDto.fromJson(_dashboardJson());
      final dashboard = dto.toDomain();

      expect(dashboard.institutions.total, 20);
      expect(dashboard.institutions.active, 18);
      expect(dashboard.institutions.inactive, 2);
      expect(dashboard.users.total, 2800);
      expect(dashboard.users.active, 2720);
      expect(dashboard.recentInstitutions, hasLength(2));
      expect(dashboard.recentInstitutions.first.name, 'Example School');
      expect(
        dashboard.recentInstitutions.first.type,
        PlatformInstitutionType.school,
      );
      expect(
        dashboard.recentInstitutions.first.status,
        PlatformInstitutionStatus.active,
      );
      expect(
        dashboard.recentInstitutions.first.createdAt,
        DateTime.utc(2026, 8, 1, 10),
      );
      expect(dashboard.isInstitutionEmpty, isFalse);
    });

    test('decodes all-zero Institution response with non-zero User counts', () {
      final dto = PlatformDashboardDto.fromJson(
        _dashboardJson(
          institutions: {'total': 0, 'active': 0, 'inactive': 0},
          users: {'total': 1, 'active': 1},
          recentInstitutions: const [],
        ),
      );
      final dashboard = dto.toDomain();

      expect(dashboard.institutions.total, 0);
      expect(dashboard.users.total, 1);
      expect(dashboard.users.active, 1);
      expect(dashboard.isInstitutionEmpty, isTrue);
    });

    test('maps all Institution types and both statuses as machine values', () {
      const typeValues = [
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
      final recentInstitutions = [
        for (var index = 0; index < typeValues.length; index++)
          _recentInstitutionJson(
            id: '00000000-0000-0000-0000-${(index + 1).toString().padLeft(12, '0')}',
            name: 'Institution $index',
            type: typeValues[index],
            status: index.isEven ? 'active' : 'inactive',
          ),
      ];

      final dashboard = PlatformDashboardDto.fromJson(
        _dashboardJson(recentInstitutions: recentInstitutions),
      ).toDomain();

      expect(
        dashboard.recentInstitutions.map(
          (institution) => institution.type.value,
        ),
        typeValues,
      );
      expect(
        dashboard.recentInstitutions.map(
          (institution) => institution.status.value,
        ),
        [
          'active',
          'inactive',
          'active',
          'inactive',
          'active',
          'inactive',
          'active',
          'inactive',
          'active',
        ],
      );
    });

    test('normalizes offset timestamps to UTC consistently', () {
      final dashboard = PlatformDashboardDto.fromJson(
        _dashboardJson(
          recentInstitutions: [
            _recentInstitutionJson(createdAt: '2026-08-01T15:00:00+05:00'),
          ],
        ),
      ).toDomain();

      expect(
        dashboard.recentInstitutions.single.createdAt,
        DateTime.utc(2026, 8, 1, 10),
      );
    });

    test('ignores additive unknown and protected fields', () {
      final dashboard = PlatformDashboardDto.fromJson(
        _dashboardJson(
          extraData: {
            'statistics': {'trend': 99},
            'settings': {'platform_secret': 'hidden'},
          },
          recentInstitutions: [
            _recentInstitutionJson(
              extra: {
                'contact_email': 'hidden@example.test',
                'contact_phone': '+998000000000',
                'settings': {'timezone': 'Asia/Tashkent'},
                'users': [
                  {'full_name': 'Protected User'},
                ],
                'learning': {'topics': 1},
              },
            ),
          ],
        ),
      ).toDomain();

      final institution = dashboard.recentInstitutions.single;
      expect(institution.name, 'Example School');
      expect(institution.type.value, 'school');
      expect(institution.status.value, 'active');
    });

    test(
      'rejects missing wrong null string float and negative core fields',
      () {
        final invalidResponses = [
          {'unexpected': {}},
          _dashboardJson(
            institutions: {'total': '20', 'active': 18, 'inactive': 2},
          ),
          _dashboardJson(
            institutions: {'total': 20.0, 'active': 18, 'inactive': 2},
          ),
          _dashboardJson(
            institutions: {'total': -1, 'active': 18, 'inactive': 2},
          ),
          _dashboardJson(users: {'total': null, 'active': 1}),
          _dashboardJson(recentInstitutions: null),
          _dashboardJson(
            recentInstitutions: [_recentInstitutionJson(status: 'archived')],
          ),
          _dashboardJson(
            recentInstitutions: [_recentInstitutionJson(type: 'academy')],
          ),
          _dashboardJson(
            recentInstitutions: [
              _recentInstitutionJson(createdAt: 'not-a-time'),
            ],
          ),
          _dashboardJson(
            recentInstitutions: [_recentInstitutionJson(id: 'not-a-uuid')],
          ),
        ];

        for (final response in invalidResponses) {
          expect(
            () => PlatformDashboardDto.fromJson(response),
            throwsException,
          );
        }
      },
    );
  });
}

Map<String, Object?> _dashboardJson({
  Map<String, Object?>? institutions,
  Map<String, Object?>? users,
  Object? recentInstitutions = _defaultRecentMarker,
  Map<String, Object?> extraData = const {},
}) {
  return {
    'data': {
      'institutions':
          institutions ?? {'total': 20, 'active': 18, 'inactive': 2},
      'users': users ?? {'total': 2800, 'active': 2720},
      'recent_institutions': identical(recentInstitutions, _defaultRecentMarker)
          ? [
              _recentInstitutionJson(),
              _recentInstitutionJson(
                id: '00000000-0000-0000-0000-000000000002',
                name: 'Second School',
                status: 'inactive',
                createdAt: '2026-07-31T09:30:00Z',
              ),
            ]
          : recentInstitutions,
      ...extraData,
    },
  };
}

Map<String, Object?> _recentInstitutionJson({
  String id = '00000000-0000-0000-0000-000000000001',
  String name = 'Example School',
  String type = 'school',
  String status = 'active',
  String createdAt = '2026-08-01T10:00:00Z',
  Map<String, Object?> extra = const {},
}) {
  return {
    'id': id,
    'name': name,
    'type': type,
    'status': status,
    'created_at': createdAt,
    ...extra,
  };
}

const _defaultRecentMarker = Object();
