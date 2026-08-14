import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_profile_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile.dart';

void main() {
  group('InstitutionProfileDto', () {
    test(
      'parses the exact complete GET resource and ignores additive keys',
      () {
        final profile = InstitutionProfileGetResponseDto.fromJson({
          'data': _resource()
            ..addAll({
              'created_by_user_id': 'creator-private',
              'institution_id': 'foreign-private',
              'settings': {'timezone': 'private'},
              'users': ['private-user'],
              'token': 'private-token',
            }),
          'meta': {'future': true, 'request_id': 'private-request'},
          'links': {'future': '/private'},
        }).profile.toDomain();

        expect(profile.id, _institutionId);
        expect(profile.name, 'Example School');
        expect(profile.type, InstitutionProfileType.school);
        expect(profile.status, InstitutionProfileStatus.active);
        expect(profile.contactEmail, 'office@example.uz');
        expect(profile.contactPhone, isNull);
        expect(profile.address, 'Tashkent');
        expect(profile.description, isNull);
        expect(profile.createdAt.isUtc, isTrue);
        expect(profile.createdAt.millisecond, 123);
        expect(profile.createdAt.microsecond, 456);
        expect(profile.updatedAt, DateTime.utc(2026, 8, 7, 15, 0));
        expect(
          profile.toString(),
          isNot(
            anyOf(
              contains('creator-private'),
              contains('foreign-private'),
              contains('private-user'),
              contains('private-token'),
              contains('private-request'),
            ),
          ),
        );
      },
    );

    test('maps every field exactly without positional or key swaps', () {
      final profile = InstitutionProfileDto.fromJson({
        'updated_at': '2026-09-10T11:12:13.654321Z',
        'description': 'description-value',
        'id': _institutionId,
        'contact_phone': 'phone-value',
        'status': 'inactive',
        'address': 'address-value',
        'created_at': '2025-01-02T03:04:05.123456Z',
        'type': 'university',
        'contact_email': 'email-value@example.uz',
        'name': 'name-value',
      }).toDomain();

      expect(profile.id, _institutionId);
      expect(profile.name, 'name-value');
      expect(profile.type, InstitutionProfileType.university);
      expect(profile.status, InstitutionProfileStatus.inactive);
      expect(profile.contactEmail, 'email-value@example.uz');
      expect(profile.contactPhone, 'phone-value');
      expect(profile.address, 'address-value');
      expect(profile.description, 'description-value');
      expect(profile.createdAt, DateTime.utc(2025, 1, 2, 3, 4, 5, 123, 456));
      expect(
        profile.updatedAt,
        DateTime.utc(2026, 9, 10, 11, 12, 13, 654, 321),
      );

      final highPrecision = InstitutionProfileDto.fromJson(
        _resource()..['created_at'] = '2026-08-07T15:00:00.123456789Z',
      );
      expect(
        highPrecision.createdAt,
        DateTime.utc(2026, 8, 7, 15, 0, 0, 123, 456),
      );
    });

    test('accepts all exact types and both statuses', () {
      const types = {
        'school': InstitutionProfileType.school,
        'college': InstitutionProfileType.college,
        'lyceum': InstitutionProfileType.lyceum,
        'university': InstitutionProfileType.university,
        'institute': InstitutionProfileType.institute,
        'learning_center': InstitutionProfileType.learningCenter,
        'training_center': InstitutionProfileType.trainingCenter,
        'private_education': InstitutionProfileType.privateEducation,
        'other': InstitutionProfileType.other,
      };

      for (final entry in types.entries) {
        final resource = _resource()
          ..['type'] = entry.key
          ..['status'] = entry.key == 'other' ? 'inactive' : 'active';
        final profile = InstitutionProfileDto.fromJson(resource).toDomain();
        expect(profile.type, entry.value);
        expect(
          profile.status,
          entry.key == 'other'
              ? InstitutionProfileStatus.inactive
              : InstitutionProfileStatus.active,
        );
      }
    });

    test('requires nullable fields to remain present while accepting null', () {
      for (final key in const [
        'contact_email',
        'contact_phone',
        'address',
        'description',
      ]) {
        final nullable = _resource()..[key] = null;
        expect(() => InstitutionProfileDto.fromJson(nullable), returnsNormally);

        final missing = _resource()..remove(key);
        expect(
          () => InstitutionProfileDto.fromJson(missing),
          throwsFormatException,
          reason: key,
        );
      }
    });

    test('rejects every missing required resource key independently', () {
      for (final key in const [
        'id',
        'name',
        'type',
        'status',
        'contact_email',
        'contact_phone',
        'address',
        'description',
        'created_at',
        'updated_at',
      ]) {
        final resource = _resource()..remove(key);
        expect(
          () => InstitutionProfileDto.fromJson(resource),
          throwsException,
          reason: 'missing $key',
        );
      }
    });

    test('accepts a non-empty name and rejects exactly an empty name', () {
      expect(
        InstitutionProfileDto.fromJson(_resource()..['name'] = 'School').name,
        'School',
      );
      expect(
        () => InstitutionProfileDto.fromJson(_resource()..['name'] = ''),
        throwsFormatException,
      );
    });

    test('rejects null or invalid type for every required field', () {
      final invalidValues = <String, List<Object?>>{
        'id': [null, 1, true, const <Object?>[]],
        'name': [null, 1, true, const <Object?>[]],
        'type': [null, 1, true, const <Object?>[]],
        'status': [null, 1, true, const <Object?>[]],
        'contact_email': [
          1,
          true,
          const <Object?>[],
          const <String, Object?>{},
        ],
        'contact_phone': [
          1,
          true,
          const <Object?>[],
          const <String, Object?>{},
        ],
        'address': [1, true, const <Object?>[], const <String, Object?>{}],
        'description': [1, true, const <Object?>[], const <String, Object?>{}],
        'created_at': [null, 1, true, const <Object?>[]],
        'updated_at': [null, 1, true, const <Object?>[]],
      };

      for (final entry in invalidValues.entries) {
        for (final invalidValue in entry.value) {
          expect(
            () => InstitutionProfileDto.fromJson(
              _resource()..[entry.key] = invalidValue,
            ),
            throwsException,
            reason: '${entry.key}: $invalidValue',
          );
        }
      }
    });

    test('rejects malformed IDs enums timestamps fields and envelopes', () {
      final invalidResources = <Map<String, Object?>>[
        _resource()..['id'] = 'not-a-uuid',
        _resource()..['type'] = 'academy',
        _resource()..['status'] = 'pending',
        _resource()..['created_at'] = '2026-08-07T20:00:00+05:00',
        _resource()..['created_at'] = '2026-02-30T15:00:00Z',
        _resource()..['updated_at'] = null,
        _resource()..['id'] = '',
        _resource()..['name'] = '',
      ];

      for (final resource in invalidResources) {
        expect(
          () => InstitutionProfileDto.fromJson(resource),
          throwsException,
          reason: '$resource',
        );
      }

      for (final envelope in <Object?>[
        null,
        true,
        1,
        'data',
        const <Object?>[],
        const {},
        {'data': null},
        {'data': true},
        {'data': 1},
        {'data': 'profile'},
        {'data': const <Object?>[]},
      ]) {
        expect(
          () => InstitutionProfileGetResponseDto.fromJson(envelope),
          throwsException,
        );
      }
    });

    test('malformed input never becomes an empty or default profile', () {
      final malformedInputs = <Object?>[
        null,
        const {},
        {'data': const {}},
        {'data': _resource()..['name'] = ''},
        {'data': _resource()..remove('contact_email')},
        {'data': _resource()..['type'] = 'default'},
        {'data': _resource()..['created_at'] = ''},
      ];

      for (final input in malformedInputs) {
        InstitutionProfile? converted;
        Object? caught;
        try {
          converted = InstitutionProfileGetResponseDto.fromJson(
            input,
          ).profile.toDomain();
        } catch (error) {
          caught = error;
        }

        expect(caught, isNotNull, reason: '$input');
        expect(converted, isNull, reason: '$input');
      }
    });

    test('requires the exact trusted PATCH success message', () {
      final valid = InstitutionProfileUpdateResponseDto.fromJson({
        'data': _resource(),
        'message': institutionProfileUpdateSuccessMessage,
      });
      expect(valid.profile.id, _institutionId);

      for (final message in <Object?>[
        null,
        '',
        'Institution profile updated successfully',
        'Updated.',
      ]) {
        expect(
          () => InstitutionProfileUpdateResponseDto.fromJson({
            'data': _resource(),
            'message': ?message,
          }),
          throwsFormatException,
        );
      }

      for (final malformed in <Object?>[
        null,
        const {},
        {'message': institutionProfileUpdateSuccessMessage},
        {'data': null, 'message': institutionProfileUpdateSuccessMessage},
        {
          'data': _resource()..['name'] = '',
          'message': institutionProfileUpdateSuccessMessage,
        },
      ]) {
        expect(
          () => InstitutionProfileUpdateResponseDto.fromJson(malformed),
          throwsException,
        );
      }
    });
  });
}

const _institutionId = '550e8400-e29b-41d4-a716-446655440000';

Map<String, Object?> _resource() {
  return {
    'id': _institutionId,
    'name': 'Example School',
    'type': 'school',
    'status': 'active',
    'contact_email': 'office@example.uz',
    'contact_phone': null,
    'address': 'Tashkent',
    'description': null,
    'created_at': '2026-08-07T15:00:00.123456Z',
    'updated_at': '2026-08-07T15:00:00Z',
  };
}
