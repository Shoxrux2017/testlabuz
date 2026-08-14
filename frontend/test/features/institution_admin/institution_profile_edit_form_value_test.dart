import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile_update.dart';

void main() {
  group('InstitutionProfileEditFormValue', () {
    test(
      'initializes every profile field exactly and maps all nulls to empty form text',
      () {
        final profile = _profile(
          name: 'Exact School',
          contactEmail: null,
          contactPhone: null,
          address: null,
          description: null,
        );

        final form = InstitutionProfileEditFormValue.fromProfile(profile);

        expect(form.name, 'Exact School');
        expect(form.contactEmail, '');
        expect(form.contactPhone, '');
        expect(form.address, '');
        expect(form.description, '');
      },
    );

    test('uses exact normalization and preserves non-empty multiline text', () {
      const form = InstitutionProfileEditFormValue(
        name: '  New School  ',
        contactEmail: '  office@example.uz ',
        contactPhone: '  +998 90 123 45 67 ',
        address: '  First line\nSecond line  ',
        description: ' \n ',
      );

      final normalized = form.normalizedSnapshot();
      expect(normalized.name, 'New School');
      expect(normalized.contactEmail, 'office@example.uz');
      expect(normalized.contactPhone, '+998 90 123 45 67');
      expect(normalized.address, '  First line\nSecond line  ');
      expect(normalized.description, isNull);
    });

    test('validates only the approved non-authoritative client rules', () {
      final cases =
          <InstitutionProfileEditFormValue, InstitutionProfileEditField>{
            _form(name: '   '): InstitutionProfileEditField.name,
            _form(name: List.filled(201, 'n').join()):
                InstitutionProfileEditField.name,
            _form(contactEmail: 'two@@example.uz'):
                InstitutionProfileEditField.contactEmail,
            _form(contactEmail: 'white space@example.uz'):
                InstitutionProfileEditField.contactEmail,
            _form(contactEmail: '${List.filled(245, 'a').join()}@example.uz'):
                InstitutionProfileEditField.contactEmail,
            _form(contactPhone: List.filled(51, '1').join()):
                InstitutionProfileEditField.contactPhone,
          };

      for (final entry in cases.entries) {
        final validation = entry.key.validate();
        expect(validation.isValid, isFalse);
        expect(validation.firstInvalidField, entry.value);
      }

      expect(
        _form(
          contactEmail: '',
          address: List.filled(4000, 'a').join(),
          description: List.filled(5000, 'd').join(),
        ).validate().isValid,
        isTrue,
      );
      expect(
        _form(name: List.filled(200, 'n').join()).validate().isValid,
        isTrue,
      );
      expect(
        _form(
          contactEmail: '${List.filled(242, 'a').join()}@example.uz',
        ).validate().isValid,
        isTrue,
      );
      expect(
        _form(contactPhone: List.filled(50, '1').join()).validate().isValid,
        isTrue,
      );
    });

    test(
      'serializes each independent editable change under its exact API key',
      () {
        final profile = _profile();
        final baseline = InstitutionProfileEditSnapshot.fromProfile(profile);
        const changes = <InstitutionProfileEditField, String>{
          InstitutionProfileEditField.name: 'Renamed School',
          InstitutionProfileEditField.contactEmail: 'new@example.uz',
          InstitutionProfileEditField.contactPhone: '+99899',
          InstitutionProfileEditField.address: 'New address',
          InstitutionProfileEditField.description: 'New description',
        };

        for (final entry in changes.entries) {
          final request = InstitutionProfileUpdateRequest.fromForm(
            form: InstitutionProfileEditFormValue.fromProfile(
              profile,
            ).withField(entry.key, entry.value),
            baseline: baseline,
          );

          expect(request.toJson(), {entry.key.apiKey: entry.value});
        }
      },
    );

    test('diff omits unchanged values and sends explicit nullable clears', () {
      final profile = _profile(
        contactEmail: 'office@example.uz',
        contactPhone: '+99890',
        address: 'Address',
        description: null,
      );
      final baseline = InstitutionProfileEditSnapshot.fromProfile(profile);

      final unchanged = InstitutionProfileUpdateRequest.fromForm(
        form: InstitutionProfileEditFormValue.fromProfile(
          profile,
        ).withField(InstitutionProfileEditField.name, '  Example School '),
        baseline: baseline,
      );
      expect(unchanged.isEmpty, isTrue);

      final changed = InstitutionProfileUpdateRequest.fromForm(
        form: const InstitutionProfileEditFormValue(
          name: ' Renamed School ',
          contactEmail: '  ',
          contactPhone: ' +99890 ',
          address: ' \n ',
          description: 'New\ndescription',
        ),
        baseline: baseline,
      );
      expect(changed.toJson(), {
        'name': 'Renamed School',
        'contact_email': null,
        'address': null,
        'description': 'New\ndescription',
      });
    });

    test(
      'request allowlist rejects empty protected and non-string changes',
      () {
        expect(
          () => InstitutionProfileUpdateRequest.fromChanges({}),
          throwsArgumentError,
        );
        expect(
          () => InstitutionProfileUpdateRequest.fromChanges({
            'institution_id': 'other',
          }),
          throwsArgumentError,
        );
        expect(
          () => InstitutionProfileUpdateRequest.fromChanges({'name': null}),
          throwsArgumentError,
        );
        expect(
          () => InstitutionProfileUpdateRequest.fromChanges({
            'contact_phone': 123,
          }),
          throwsArgumentError,
        );
      },
    );

    test(
      'request and snapshots do not retain mutable or stale prior-profile state',
      () {
        final mutable = <String, Object?>{'name': 'First Name'};
        final request = InstitutionProfileUpdateRequest.fromChanges(mutable);
        mutable['name'] = 'Mutated Name';
        mutable['institution_id'] = 'foreign';
        expect(request.toJson(), {'name': 'First Name'});

        final oldSnapshot = InstitutionProfileEditSnapshot.fromProfile(
          _profile(name: 'Old School', contactEmail: 'old@example.uz'),
        );
        final newProfile = _profile(
          name: 'New School',
          contactEmail: 'new@example.uz',
        );
        final newSnapshot = InstitutionProfileEditSnapshot.fromProfile(
          newProfile,
        );
        final noChange = InstitutionProfileUpdateRequest.fromForm(
          form: InstitutionProfileEditFormValue.fromProfile(newProfile),
          baseline: newSnapshot,
        );

        expect(oldSnapshot.name, 'Old School');
        expect(newSnapshot.name, 'New School');
        expect(noChange.isEmpty, isTrue);
      },
    );

    test('reconciliation equality compares only immutable changed keys', () {
      final request = InstitutionProfileUpdateRequest.fromChanges({
        'name': 'Renamed School',
        'contact_email': null,
      });

      expect(
        request.matchesProfile(
          _profile(
            name: 'Renamed School',
            contactEmail: null,
            contactPhone: 'different ignored phone',
          ),
        ),
        isTrue,
      );
      expect(
        request.matchesProfile(
          _profile(name: 'Another School', contactEmail: null),
        ),
        isFalse,
      );
    });
  });
}

InstitutionProfileEditFormValue _form({
  String name = 'Example School',
  String contactEmail = 'office@example.uz',
  String contactPhone = '+99890',
  String address = 'Address',
  String description = 'Description',
}) {
  return InstitutionProfileEditFormValue(
    name: name,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    address: address,
    description: description,
  );
}

InstitutionProfile _profile({
  String name = 'Example School',
  String? contactEmail = 'office@example.uz',
  String? contactPhone = '+99890',
  String? address = 'Address',
  String? description = 'Description',
}) {
  return InstitutionProfile(
    id: '550e8400-e29b-41d4-a716-446655440000',
    name: name,
    type: InstitutionProfileType.school,
    status: InstitutionProfileStatus.active,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    address: address,
    description: description,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 7),
  );
}
