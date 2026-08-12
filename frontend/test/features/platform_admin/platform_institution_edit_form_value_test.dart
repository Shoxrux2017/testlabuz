import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_edit.dart';

void main() {
  group('PlatformInstitutionEditFormValue', () {
    test('initializes exactly six editable fields from detail data', () {
      final form = PlatformInstitutionEditFormValue.fromDetail(
        _detail(
          name: 'Example School',
          type: PlatformInstitutionType.college,
          contactEmail: null,
          contactPhone: '+998901234567',
          address: 'Samarqand',
          description: null,
        ),
      );

      expect(form.name, 'Example School');
      expect(form.type, PlatformInstitutionType.college);
      expect(form.contactEmail, '');
      expect(form.contactPhone, '+998901234567');
      expect(form.address, 'Samarqand');
      expect(form.description, '');
    });

    test('normalizes only approved outer whitespace and nullable fields', () {
      const form = PlatformInstitutionEditFormValue(
        name: '  Oquv Markazi  ',
        type: PlatformInstitutionType.learningCenter,
        contactEmail: '  info@example.uz  ',
        contactPhone: '   ',
        address: "  Toshkent\nYunusobod  ",
        description: "  O'zbekcha izoh\nIkkinchi qator  ",
      );

      final snapshot = form.normalized();

      expect(snapshot.name, 'Oquv Markazi');
      expect(snapshot.type, PlatformInstitutionType.learningCenter);
      expect(snapshot.contactEmail, 'info@example.uz');
      expect(snapshot.contactPhone, isNull);
      expect(snapshot.address, "  Toshkent\nYunusobod  ");
      expect(snapshot.description, "  O'zbekcha izoh\nIkkinchi qator  ");
    });

    test(
      'emits no PATCH keys when normalized values are unchanged or reverted',
      () {
        final initialForm = PlatformInstitutionEditFormValue.fromDetail(
          _detail(
            name: 'Example School',
            contactEmail: 'info@example.uz',
            contactPhone: '+998901234567',
            address: 'Samarkand',
            description: 'Notes',
          ),
        );
        final snapshot = initialForm.normalized();

        expect(
          initialForm
              .copyWith(
                name: '  Example School  ',
                contactEmail: ' info@example.uz ',
                contactPhone: ' +998901234567 ',
              )
              .toChangedFieldsRequest(snapshot)
              .toJson(),
          isEmpty,
        );

        expect(
          initialForm
              .copyWith(name: 'Changed')
              .copyWith(name: ' Example School ')
              .toChangedFieldsRequest(snapshot)
              .toJson(),
          isEmpty,
        );
      },
    );

    test(
      'serializes each changed field only and clears nullable values as null',
      () {
        final initialForm = PlatformInstitutionEditFormValue.fromDetail(
          _detail(
            name: 'Example School',
            type: PlatformInstitutionType.school,
            contactEmail: 'info@example.uz',
            contactPhone: '+998901234567',
            address: 'Samarkand',
            description: 'Notes',
          ),
        );
        final snapshot = initialForm.normalized();

        final cases = <Map<String, Object?>>[
          initialForm
              .copyWith(name: 'Updated School')
              .toChangedFieldsRequest(snapshot)
              .toJson(),
          initialForm
              .copyWith(type: PlatformInstitutionType.university)
              .toChangedFieldsRequest(snapshot)
              .toJson(),
          initialForm
              .copyWith(contactEmail: ' updated@example.uz ')
              .toChangedFieldsRequest(snapshot)
              .toJson(),
          initialForm
              .copyWith(contactPhone: '   ')
              .toChangedFieldsRequest(snapshot)
              .toJson(),
          initialForm
              .copyWith(address: "  Toshkent\nChilonzor  ")
              .toChangedFieldsRequest(snapshot)
              .toJson(),
          initialForm
              .copyWith(description: '   ')
              .toChangedFieldsRequest(snapshot)
              .toJson(),
        ];

        expect(cases[0], {'name': 'Updated School'});
        expect(cases[1], {'type': 'university'});
        expect(cases[2], {'contact_email': 'updated@example.uz'});
        expect(cases[3], {'contact_phone': null});
        expect(cases[4], {'address': "  Toshkent\nChilonzor  "});
        expect(cases[5], {'description': null});

        for (final body in cases) {
          expect(body, hasLength(1));
          expect(
            body.keys,
            everyElement(
              isIn([
                'name',
                'type',
                'contact_email',
                'contact_phone',
                'address',
                'description',
              ]),
            ),
          );
        }
      },
    );

    test(
      'validates name email phone without status or invented field rules',
      () {
        final invalid = _form(
          name: '   ',
          contactEmail: 'not an email',
          contactPhone: List.filled(51, '1').join(),
          address: List.filled(500, 'Manzil').join('\n'),
          description: List.filled(500, 'Izoh').join('\n'),
        ).validate();

        expect(invalid.isValid, isFalse);
        expect(invalid.fieldErrors.keys, [
          PlatformInstitutionEditField.name,
          PlatformInstitutionEditField.contactEmail,
          PlatformInstitutionEditField.contactPhone,
        ]);
        expect(
          invalid.fieldErrors.keys,
          isNot(contains(PlatformInstitutionEditField.address)),
        );
        expect(
          invalid.fieldErrors.keys,
          isNot(contains(PlatformInstitutionEditField.description)),
        );

        final tooLongName = _form(
          name: List.filled(201, 'a').join(),
        ).validate();
        expect(
          tooLongName.fieldErrors.keys,
          contains(PlatformInstitutionEditField.name),
        );
      },
    );

    test('request construction rejects unsupported protected keys', () {
      expect(
        () => PlatformInstitutionEditRequest({
          'name': 'Updated',
          'status': 'active',
        }),
        throwsArgumentError,
      );
      expect(
        () => PlatformInstitutionEditRequest({'settings': {}}),
        throwsArgumentError,
      );
    });
  });
}

PlatformInstitutionEditFormValue _form({
  String name = 'Example School',
  PlatformInstitutionType type = PlatformInstitutionType.school,
  String contactEmail = '',
  String contactPhone = '',
  String address = '',
  String description = '',
}) {
  return PlatformInstitutionEditFormValue(
    name: name,
    type: type,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    address: address,
    description: description,
  );
}

PlatformInstitutionDetail _detail({
  String name = 'Example School',
  PlatformInstitutionType type = PlatformInstitutionType.school,
  String? contactEmail = 'info@example.uz',
  String? contactPhone = '+998901234567',
  String? address = 'Samarkand',
  String? description = 'Notes',
}) {
  return PlatformInstitutionDetail(
    id: '550e8400-e29b-41d4-a716-446655440000',
    name: name,
    type: type,
    status: PlatformInstitutionStatus.active,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    address: address,
    description: description,
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    userCounts: const PlatformInstitutionUserCounts(total: 42, active: 40),
  );
}
