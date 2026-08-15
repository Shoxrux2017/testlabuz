import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_create.dart';

void main() {
  test('requires every mandatory field and does not default the role', () {
    const form = InstitutionUserCreateFormValue();

    final errors = form.validate(password: '');

    expect(form.role, isNull);
    expect(errors.keys, [
      InstitutionUserCreateField.role,
      InstitutionUserCreateField.fullName,
      InstitutionUserCreateField.loginName,
      InstitutionUserCreateField.password,
    ]);
  });

  test('normalizes only fields allowed by the create contract', () {
    const form = InstitutionUserCreateFormValue(
      role: InstitutionUserRole.teacher,
      fullName: '  Teacher Name  ',
      loginName: '  teacher01  ',
      email: 'Teacher@Example.UZ',
      phone: '  +998 90 123 45 67  ',
    );

    final request = form.toRequest(password: '  secret password  ');

    expect(request.toJson(), {
      'role': 'teacher',
      'full_name': 'Teacher Name',
      'login_name': 'teacher01',
      'email': 'Teacher@Example.UZ',
      'phone': '+998 90 123 45 67',
      'password': '  secret password  ',
    });
    expect(request.toString(), isNot(contains('secret password')));
  });

  test('sends exact nullable contacts without inventing values', () {
    const form = InstitutionUserCreateFormValue(
      role: InstitutionUserRole.student,
      fullName: 'Student',
      loginName: 'student01',
    );

    expect(form.validate(password: 'password1'), isEmpty);
    expect(form.toRequest(password: 'password1').toJson(), {
      'role': 'student',
      'full_name': 'Student',
      'login_name': 'student01',
      'email': null,
      'phone': null,
      'password': 'password1',
    });
  });

  test('uses rune lengths and rejects rewritten or whitespace email input', () {
    final overlongName = List.filled(201, 'ф').join();
    final cases = <InstitutionUserCreateFormValue>[
      InstitutionUserCreateFormValue(
        role: InstitutionUserRole.parent,
        fullName: overlongName,
        loginName: 'parent01',
      ),
      const InstitutionUserCreateFormValue(
        role: InstitutionUserRole.parent,
        fullName: 'Parent',
        loginName: 'parent01',
        email: ' parent@example.uz ',
      ),
      const InstitutionUserCreateFormValue(
        role: InstitutionUserRole.parent,
        fullName: 'Parent',
        loginName: 'parent01',
        phone: '   ',
      ),
    ];

    expect(
      cases[0].validate(password: 'password1'),
      contains(InstitutionUserCreateField.fullName),
    );
    expect(
      cases[1].validate(password: 'password1'),
      contains(InstitutionUserCreateField.email),
    );
    expect(
      cases[2].validate(password: 'password1'),
      contains(InstitutionUserCreateField.phone),
    );
  });

  test('password validation preserves spaces and enforces rune bounds', () {
    const form = InstitutionUserCreateFormValue(
      role: InstitutionUserRole.teacher,
      fullName: 'Teacher',
      loginName: 'teacher01',
    );

    expect(form.validate(password: '        '), isEmpty);
    expect(
      form.validate(password: '1234567'),
      contains(InstitutionUserCreateField.password),
    );
    expect(
      form.validate(password: List.filled(256, 'a').join()),
      contains(InstitutionUserCreateField.password),
    );
  });

  test('accepts exact Unicode scalar bounds and rejects max plus one', () {
    final exact = InstitutionUserCreateFormValue(
      role: InstitutionUserRole.parent,
      fullName: List.filled(200, '🧪').join(),
      loginName: List.filled(191, '🧬').join(),
      email: '${List.filled(252, 'a').join()}@b',
      phone: List.filled(50, '📱').join(),
    );
    expect(exact.validate(password: List.filled(255, '🔐').join()), isEmpty);

    final over = InstitutionUserCreateFormValue(
      role: InstitutionUserRole.parent,
      fullName: List.filled(201, '🧪').join(),
      loginName: List.filled(192, '🧬').join(),
      email: '${List.filled(253, 'a').join()}@b',
      phone: List.filled(51, '📱').join(),
    );
    expect(over.validate(password: List.filled(256, '🔐').join()).keys, [
      InstitutionUserCreateField.fullName,
      InstitutionUserCreateField.loginName,
      InstitutionUserCreateField.email,
      InstitutionUserCreateField.phone,
      InstitutionUserCreateField.password,
    ]);
  });

  test('email validation is permissive one-at UX validation only', () {
    const valid = InstitutionUserCreateFormValue(
      role: InstitutionUserRole.teacher,
      fullName: 'Teacher',
      loginName: 'teacher01',
      email: 'local@host',
    );
    expect(valid.validate(password: 'password1'), isEmpty);

    for (final email in const ['@host', 'local@', 'a@b@c', 'a b@c']) {
      final errors = valid
          .copyWith(email: email)
          .validate(password: 'password1');
      expect(errors, contains(InstitutionUserCreateField.email), reason: email);
    }
  });

  test('request contains no authority, confirmation, or idempotency key', () {
    const form = InstitutionUserCreateFormValue(
      role: InstitutionUserRole.teacher,
      fullName: 'Teacher',
      loginName: 'teacher01',
    );
    final keys = form.toRequest(password: 'password1').toJson().keys.toSet();

    expect(keys, {
      'role',
      'full_name',
      'login_name',
      'email',
      'phone',
      'password',
    });
    expect(keys, isNot(contains('institution_id')));
    expect(keys, isNot(contains('password_confirmation')));
    expect(keys, isNot(contains('idempotency_key')));
  });
}
