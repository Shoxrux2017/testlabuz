import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group.dart';

void main() {
  group('InstitutionGroupDto', () {
    test('parses the exact active and archived resource contracts', () {
      final active = InstitutionGroupDto.fromJson(_groupJson()).toDomain();
      final archived = InstitutionGroupDto.fromJson(
        _groupJson(status: 'archived', archivedAt: '2026-08-08T10:00:00Z'),
      ).toDomain();

      expect(active.id, '00000000-0000-0000-0000-000000000001');
      expect(active.name, 'Group A');
      expect(active.level, isNull);
      expect(active.subjectDirection, 'Mathematics');
      expect(active.description, 'Exact description');
      expect(active.status, InstitutionGroupStatus.active);
      expect(active.teachersCount, 2);
      expect(active.studentsCount, 15);
      expect(active.archivedAt, isNull);
      expect(active.createdAt, DateTime.utc(2026, 8, 7, 15));
      expect(archived.status, InstitutionGroupStatus.archived);
      expect(archived.archivedAt, DateTime.utc(2026, 8, 8, 10));
    });

    test('rejects missing unknown malformed and coerced values', () {
      final invalidResources = <Map<String, Object?>>[
        {..._groupJson()}..remove('name'),
        {..._groupJson(), 'unknown': true},
        {..._groupJson(), 'id': 'not-a-uuid'},
        {..._groupJson(), 'name': '   '},
        {..._groupJson(), 'level': 4},
        {..._groupJson(), 'status': 'disabled'},
        {..._groupJson(), 'teachers_count': -1},
        {..._groupJson(), 'teachers_count': 1.0},
        {..._groupJson(), 'students_count': '15'},
        {..._groupJson(), 'created_at': '2026-08-07T15:00:00+00:00'},
        {..._groupJson(), 'updated_at': 'not-a-dateZ'},
        {..._groupJson(), 'updated_at': '2026-02-30T16:00:00Z'},
      ];

      for (final resource in invalidResources) {
        expect(
          () => InstitutionGroupDto.fromJson(resource),
          throwsFormatException,
          reason: resource.toString(),
        );
      }
    });

    test('enforces the archived_at lifecycle invariant', () {
      expect(
        () => InstitutionGroupDto.fromJson(
          _groupJson(archivedAt: '2026-08-08T10:00:00Z'),
        ),
        throwsFormatException,
      );
      expect(
        () => InstitutionGroupDto.fromJson(_groupJson(status: 'archived')),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _groupJson({
  String status = 'active',
  String? archivedAt,
}) {
  return {
    'id': '00000000-0000-0000-0000-000000000001',
    'name': 'Group A',
    'level': null,
    'subject_direction': 'Mathematics',
    'description': 'Exact description',
    'status': status,
    'teachers_count': 2,
    'students_count': 15,
    'archived_at': archivedAt,
    'created_at': '2026-08-07T15:00:00Z',
    'updated_at': '2026-08-07T16:00:00Z',
  };
}
