import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/data/dto/platform_institution_detail_dto.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';

void main() {
  group('PlatformInstitutionDetailDto', () {
    test('decodes exact detail response to focused domain fields', () {
      final detail = PlatformInstitutionDetailDto.fromJson(
        _detailEnvelope(),
      ).toDomain();

      expect(detail.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(detail.name, 'Example School');
      expect(detail.type, PlatformInstitutionType.school);
      expect(detail.status, PlatformInstitutionStatus.active);
      expect(detail.contactEmail, 'info@example.uz');
      expect(detail.contactPhone, '+998901234567');
      expect(detail.address, 'Samarkand');
      expect(detail.description, 'Optional notes');
      expect(detail.createdAt, DateTime.utc(2026, 8, 7, 15));
      expect(detail.updatedAt, DateTime.utc(2026, 8, 7, 16, 30));
      expect(detail.userCounts.total, 42);
      expect(detail.userCounts.active, 40);
    });

    test(
      'decodes all nine accepted types both statuses nullable fields and times',
      () {
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

        for (var index = 0; index < types.length; index++) {
          final detail = PlatformInstitutionDetailDto.fromJson(
            _detailEnvelope(
              id: '00000000-0000-0000-0000-${(index + 1).toString().padLeft(12, '0')}',
              type: types[index],
              status: index.isEven ? 'active' : 'inactive',
              contactEmail: index.isEven ? null : 'contact$index@example.uz',
              contactPhone: index.isEven ? '+998$index' : null,
              address: index.isEven ? null : 'Address $index',
              description: index.isEven ? 'Notes $index' : null,
              createdAt: '2026-08-07T20:00:00+05:00',
              updatedAt: '2026-08-07T16:30:00Z',
            ),
          ).toDomain();

          expect(detail.type.value, types[index]);
          expect(detail.status.value, index.isEven ? 'active' : 'inactive');
          expect(detail.createdAt, DateTime.utc(2026, 8, 7, 15));
          expect(detail.updatedAt, DateTime.utc(2026, 8, 7, 16, 30));
        }
      },
    );

    test(
      'rejects missing null wrong-type unknown enum time and count shapes',
      () {
        final missingId = _detailEnvelope();
        (missingId['data']! as Map<String, Object?>).remove('id');

        final invalidResponses = [
          null,
          {'data': null},
          {'data': []},
          missingId,
          _detailEnvelope(extra: {'id': ''}),
          _detailEnvelope(extra: {'name': null}),
          _detailEnvelope(extra: {'type': 'academy'}),
          _detailEnvelope(extra: {'status': 'archived'}),
          _detailEnvelope(extra: {'contact_email': false}),
          _detailEnvelope(extra: {'contact_phone': 123}),
          _detailEnvelope(extra: {'address': []}),
          _detailEnvelope(extra: {'description': {}}),
          _detailEnvelope(extra: {'created_at': '2026-08-07 15:00:00Z'}),
          _detailEnvelope(extra: {'updated_at': null}),
          _detailEnvelope(extra: {'user_counts': null}),
          _detailEnvelope(userCounts: {'total': -1, 'active': 0}),
          _detailEnvelope(userCounts: {'total': '42', 'active': 40}),
          _detailEnvelope(userCounts: {'total': 42, 'active': 42.0}),
          _detailEnvelope(userCounts: {'total': 1, 'active': 2}),
        ];

        for (final response in invalidResponses) {
          expect(
            () => PlatformInstitutionDetailDto.fromJson(response),
            throwsA(isA<FormatException>()),
          );
        }
      },
    );

    test('ignores additive unknown and protected fields', () {
      final detail = PlatformInstitutionDetailDto.fromJson(
        _detailEnvelope(
          extra: {
            'creator': {'full_name': 'Protected Creator'},
            'created_by_user_id': 'hidden',
            'deactivated_at': '2026-08-08T00:00:00Z',
            'settings': {'timezone': 'Asia/Tashkent'},
            'users': [
              {'full_name': 'Protected User'},
            ],
            'role_counts': {'teacher': 2},
            'inactive_user_count': 2,
            'activity': {'online': 1},
            'admin_url': 'https://secret.example',
          },
        ),
      ).toDomain();

      expect(detail.name, 'Example School');
      expect(detail.description, 'Optional notes');
      expect(detail.userCounts.total, 42);
      expect(detail.userCounts.active, 40);
    });
  });
}

Map<String, Object?> _detailEnvelope({
  String id = '550e8400-e29b-41d4-a716-446655440000',
  String name = 'Example School',
  String type = 'school',
  String status = 'active',
  Object? contactEmail = 'info@example.uz',
  Object? contactPhone = '+998901234567',
  Object? address = 'Samarkand',
  Object? description = 'Optional notes',
  String createdAt = '2026-08-07T15:00:00Z',
  String updatedAt = '2026-08-07T16:30:00Z',
  Map<String, Object?> userCounts = const {'total': 42, 'active': 40},
  Map<String, Object?> extra = const {},
}) {
  return {
    'data': {
      'id': id,
      'name': name,
      'type': type,
      'status': status,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'address': address,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'user_counts': userCounts,
      ...extra,
    },
  };
}
