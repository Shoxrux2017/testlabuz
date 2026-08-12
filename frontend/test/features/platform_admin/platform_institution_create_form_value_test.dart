import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_create.dart';

void main() {
  group('PlatformInstitutionCreateFormValue', () {
    test('uses exact institution type and status allowlists', () {
      expect(PlatformInstitutionType.values.map((type) => type.value), [
        'school',
        'college',
        'lyceum',
        'university',
        'institute',
        'learning_center',
        'training_center',
        'private_education',
        'other',
      ]);
      expect(PlatformInstitutionStatus.values.map((status) => status.value), [
        'active',
        'inactive',
      ]);
    });

    test('validates required fields and length boundaries', () {
      final empty = const PlatformInstitutionCreateFormValue().validate();
      expect(empty.isValid, isFalse);
      expect(
        empty.fieldErrors.keys,
        containsAll([
          PlatformInstitutionCreateField.name,
          PlatformInstitutionCreateField.type,
          PlatformInstitutionCreateField.status,
        ]),
      );

      final valid = PlatformInstitutionCreateFormValue(
        name: List.filled(200, 'a').join(),
        type: PlatformInstitutionType.school,
        contactEmail: '${List.filled(243, 'a').join()}@example.uz',
        contactPhone: List.filled(50, '+').join(),
        status: PlatformInstitutionStatus.active,
      ).validate();
      expect(valid.isValid, isTrue);

      final tooLong = PlatformInstitutionCreateFormValue(
        name: '${List.filled(200, 'a').join()}!',
        type: PlatformInstitutionType.school,
        contactEmail: '${List.filled(244, 'a').join()}@example.uz',
        contactPhone: '${List.filled(50, '+').join()}1',
        status: PlatformInstitutionStatus.active,
      ).validate();
      expect(
        tooLong.fieldErrors.keys,
        containsAll([
          PlatformInstitutionCreateField.name,
          PlatformInstitutionCreateField.contactEmail,
          PlatformInstitutionCreateField.contactPhone,
        ]),
      );
    });

    test('keeps email validation permissive and phone non-E164-only', () {
      final invalidEmail = const PlatformInstitutionCreateFormValue(
        name: 'Example',
        type: PlatformInstitutionType.school,
        contactEmail: 'not an email',
        contactPhone: '998 local ext 12',
        status: PlatformInstitutionStatus.active,
      ).validate();

      expect(invalidEmail.fieldErrors.keys, [
        PlatformInstitutionCreateField.contactEmail,
      ]);

      final localPhone = const PlatformInstitutionCreateFormValue(
        name: 'Example',
        type: PlatformInstitutionType.school,
        contactEmail: 'info@example.uz',
        contactPhone: '998 local ext 12',
        status: PlatformInstitutionStatus.active,
      ).validate();

      expect(localPhone.isValid, isTrue);
    });

    test(
      'serializes exactly seven keys with null optionals and no protected fields',
      () {
        const form = PlatformInstitutionCreateFormValue(
          name: '  Example School  ',
          type: PlatformInstitutionType.learningCenter,
          contactEmail: '   ',
          contactPhone: '',
          address: '    ',
          description: '\n\t',
          status: PlatformInstitutionStatus.inactive,
        );

        final json = form.toRequest().toJson();

        expect(json, {
          'name': 'Example School',
          'type': 'learning_center',
          'contact_email': null,
          'contact_phone': null,
          'address': null,
          'description': null,
          'status': 'inactive',
        });
        expect(json.keys, hasLength(7));
        expect(
          json.keys,
          isNot(
            containsAll([
              'id',
              'institution_id',
              'created_by_user_id',
              'created_at',
              'updated_at',
              'settings',
              'timezone',
              'role',
              'user_counts',
            ]),
          ),
        );
      },
    );

    test('preserves meaningful Unicode and multiline content', () {
      const form = PlatformInstitutionCreateFormValue(
        name: "  O'zbekiston Ta'lim Markazi  ",
        type: PlatformInstitutionType.privateEducation,
        contactEmail: '  info@example.uz ',
        contactPhone: '  +998 90 123 45 67 ',
        address: "Samarqand\nKo'cha 1",
        description: "O'quv markazi\nIkkinchi qator",
        status: PlatformInstitutionStatus.active,
      );

      final json = form.toRequest().toJson();

      expect(json['name'], "O'zbekiston Ta'lim Markazi");
      expect(json['contact_email'], 'info@example.uz');
      expect(json['contact_phone'], '+998 90 123 45 67');
      expect(json['address'], "Samarqand\nKo'cha 1");
      expect(json['description'], "O'quv markazi\nIkkinchi qator");
    });
  });
}
