import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_dashboard_dto.dart';

void main() {
  group('InstitutionDashboardDto', () {
    test('decodes exact totals into the correctly ordered domain fields', () {
      final dashboard = InstitutionDashboardDto.fromJson(
        _dashboardJson(teachers: 30, students: 600, parents: 450),
      ).toDomain();

      expect(dashboard.teachers, 30);
      expect(dashboard.students, 600);
      expect(dashboard.parents, 450);
      expect(dashboard.hasNoUsers, isFalse);
    });

    test('all-zero is valid data and is the only no-users state', () {
      final empty = InstitutionDashboardDto.fromJson(
        _dashboardJson(teachers: 0, students: 0, parents: 0),
      ).toDomain();
      final partial = InstitutionDashboardDto.fromJson(
        _dashboardJson(teachers: 0, students: 1, parents: 0),
      ).toDomain();

      expect(empty.hasNoUsers, isTrue);
      expect(partial.hasNoUsers, isFalse);
    });

    test('ignores additive transport keys without exposing them', () {
      final dashboard = InstitutionDashboardDto.fromJson({
        'data': {
          'users': {
            'teachers': 3,
            'students': 6,
            'parents': 4,
            'active': 99,
            'inactive': 1,
            'protected_identity': 'hidden',
          },
          'groups': 12,
          'learning': {'topics': 20},
        },
        'meta': {'future': true},
      }).toDomain();

      expect(dashboard.teachers, 3);
      expect(dashboard.students, 6);
      expect(dashboard.parents, 4);
    });

    test('rejects missing or malformed envelope data and users objects', () {
      final invalidResponses = <Object?>[
        null,
        const {},
        {'data': null},
        {'data': true},
        {
          'data': {'users': null},
        },
        {
          'data': {'users': []},
        },
        {
          'data': {'users': 'counts'},
        },
      ];

      for (final response in invalidResponses) {
        expect(
          () => InstitutionDashboardDto.fromJson(response),
          throwsException,
          reason: '$response',
        );
      }
    });

    test('rejects every missing or invalid required count independently', () {
      const fields = ['teachers', 'students', 'parents'];
      final invalidValues = <Object?>[
        null,
        true,
        false,
        '1',
        1.0,
        -1,
        const [],
        const <String, Object?>{},
      ];

      for (final field in fields) {
        final missing = _usersJson();
        missing.remove(field);
        expect(
          () => InstitutionDashboardDto.fromJson({
            'data': {'users': missing},
          }),
          throwsException,
          reason: 'missing $field',
        );

        for (final invalidValue in invalidValues) {
          final users = _usersJson()..[field] = invalidValue;
          expect(
            () => InstitutionDashboardDto.fromJson({
              'data': {'users': users},
            }),
            throwsException,
            reason: '$field = $invalidValue',
          );
        }
      }
    });
  });
}

Map<String, Object?> _dashboardJson({
  required int teachers,
  required int students,
  required int parents,
}) {
  return {
    'data': {
      'users': {'teachers': teachers, 'students': students, 'parents': parents},
    },
  };
}

Map<String, Object?> _usersJson() {
  return {'teachers': 1, 'students': 2, 'parents': 3};
}
