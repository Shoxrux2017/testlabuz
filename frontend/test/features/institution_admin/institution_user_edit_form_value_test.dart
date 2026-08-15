import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_mutation.dart';

void main() {
  test('starts from the exact confirmed editable values', () {
    final initial = _user(email: 'old@example.uz', phone: '+998900000001');

    final form = InstitutionUserEditFormValue.fromUser(initial);

    expect(form.fullName, initial.fullName);
    expect(form.email, initial.email);
    expect(form.phone, initial.phone);
  });

  test(
    'normalizes only the approved fields and emits only effective changes',
    () {
      final initial = _user(email: 'old@example.uz', phone: '+998900000001');
      final form = InstitutionUserEditFormValue(
        fullName: '  Updated Name  ',
        email: '',
        phone: '  +998900000002  ',
      );

      expect(form.validate(), isEmpty);
      expect(form.changedFieldsComparedTo(initial).toJson(), {
        'full_name': 'Updated Name',
        'email': null,
        'phone': '+998900000002',
      });
      expect(
        form.changedFieldsComparedTo(initial).toJson().keys,
        everyElement(isIn(const ['full_name', 'email', 'phone'])),
      );
    },
  );

  test(
    'empty optional controls preserve initial nulls and no-op stays empty',
    () {
      final initial = _user();
      final form = InstitutionUserEditFormValue.fromUser(initial);

      expect(form.changedFieldsComparedTo(initial).isEmpty, isTrue);
      expect(form.changedFieldsComparedTo(initial).toJson(), isEmpty);
    },
  );

  test('uses Unicode scalar lengths and exact safe validation copy', () {
    final astral = String.fromCharCode(0x1f600);
    final valid = InstitutionUserEditFormValue(
      fullName: astral * 200,
      email: 'a@example.uz',
      phone: '1' * 50,
    );
    expect(valid.validate(), isEmpty);

    final invalid = InstitutionUserEditFormValue(
      fullName: astral * 201,
      email: ' spaced@example.uz',
      phone: '   ',
    ).validate();
    expect(
      invalid[InstitutionUserEditField.fullName],
      'Full name must be 200 characters or fewer.',
    );
    expect(
      invalid[InstitutionUserEditField.email],
      'Enter a valid email address.',
    );
    expect(
      invalid[InstitutionUserEditField.phone],
      'Phone must not contain only spaces.',
    );
  });

  test('enforces exact full-name, email, and phone boundaries', () {
    final valid = InstitutionUserEditFormValue(
      fullName: 'n' * 200,
      email: '${'e' * 242}@example.uz',
      phone: '1' * 50,
    );
    expect(valid.email.runes.length, 253);
    expect(valid.validate(), isEmpty);

    final emailAtLimit = InstitutionUserEditFormValue(
      fullName: 'Name',
      email: '${'e' * 243}@example.uz',
      phone: '1',
    );
    expect(emailAtLimit.email.runes.length, 254);
    expect(emailAtLimit.validate(), isEmpty);

    final invalid = InstitutionUserEditFormValue(
      fullName: 'n' * 201,
      email: '${'e' * 244}@example.uz',
      phone: '1' * 51,
    ).validate();
    expect(
      invalid[InstitutionUserEditField.fullName],
      'Full name must be 200 characters or fewer.',
    );
    expect(
      invalid[InstitutionUserEditField.email],
      'Email must be 254 characters or fewer.',
    );
    expect(
      invalid[InstitutionUserEditField.phone],
      'Phone must be 50 characters or fewer.',
    );
  });

  test('validates email shape without rewriting and trims phone only', () {
    final initial = _user(email: 'old@example.uz', phone: '+998900000001');
    final exact = InstitutionUserEditFormValue(
      fullName: 'Teacher Name',
      email: 'Case+Tag@Example.UZ',
      phone: '  +998900000002  ',
    );

    expect(exact.validate(), isEmpty);
    expect(exact.changedFieldsComparedTo(initial).toJson(), {
      'email': 'Case+Tag@Example.UZ',
      'phone': '+998900000002',
    });
    for (final invalidEmail in const [
      'missing-at.example.uz',
      '@example.uz',
      'name@',
      'two@@example.uz',
      'name @example.uz',
      'name@example. uz',
    ]) {
      expect(
        InstitutionUserEditFormValue(
          fullName: 'Name',
          email: invalidEmail,
          phone: '',
        ).validate()[InstitutionUserEditField.email],
        'Enter a valid email address.',
        reason: invalidEmail,
      );
    }
  });

  test('clears contacts only when their confirmed values were non-null', () {
    final withContacts = _user(email: 'old@example.uz', phone: '+998900000001');
    final cleared = InstitutionUserEditFormValue(
      fullName: withContacts.fullName,
      email: '',
      phone: '',
    );
    expect(cleared.changedFieldsComparedTo(withContacts).toJson(), {
      'email': null,
      'phone': null,
    });
    expect(
      InstitutionUserEditFormValue.fromUser(
        _user(),
      ).changedFieldsComparedTo(_user()).toJson(),
      isEmpty,
    );
  });

  test('derives the only lifecycle action from current active state', () {
    expect(
      InstitutionUserLifecycleAction.forUser(_user()),
      InstitutionUserLifecycleAction.deactivate,
    );
    expect(
      InstitutionUserLifecycleAction.forUser(
        _user(isActive: false, deactivatedAt: DateTime.utc(2026, 8, 15, 8)),
      ),
      InstitutionUserLifecycleAction.activate,
    );
  });

  test('request rejects protected and unknown keys', () {
    expect(
      () => InstitutionUserEditRequest({'is_active': false}),
      throwsArgumentError,
    );
    expect(
      () => InstitutionUserEditRequest({'institution_id': 'foreign'}),
      throwsArgumentError,
    );
  });
}

InstitutionUser _user({
  String? email,
  String? phone,
  bool isActive = true,
  DateTime? deactivatedAt,
}) => InstitutionUser(
  id: '00000000-0000-0000-0000-000000000001',
  role: InstitutionUserRole.teacher,
  fullName: 'Teacher Name',
  loginName: 'teacher01',
  email: email,
  phone: phone,
  isActive: isActive,
  mustChangePassword: false,
  lastLoginAt: null,
  deactivatedAt: deactivatedAt,
  createdAt: DateTime.utc(2026, 8, 7, 15),
  updatedAt: DateTime.utc(2026, 8, 7, 16),
);
