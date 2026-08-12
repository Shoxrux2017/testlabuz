import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_create.dart';

void main() {
  group('PlatformInstitutionAdminCreateFormValue', () {
    test('normalizes request without adding protected authority fields', () {
      const form = PlatformInstitutionAdminCreateFormValue(
        fullName: '  Ali Valiyev  ',
        loginName: '  Admin.MixedCase  ',
        email: '  ali@example.uz  ',
        phone: '  +998901234567  ',
      );

      final request = form.toRequest(password: 'valid-password');

      expect(request.toJson(), {
        'full_name': 'Ali Valiyev',
        'login_name': 'Admin.MixedCase',
        'email': 'ali@example.uz',
        'phone': '+998901234567',
        'password': 'valid-password',
      });
      expect(request.toJson().keys, hasLength(5));
      expect(
        request.toJson().keys,
        isNot(
          containsAll([
            'role',
            'institution_id',
            'is_active',
            'must_change_password',
            'created_by_user_id',
            'password_confirmation',
          ]),
        ),
      );
    });

    test('sends null optional contact fields when left empty', () {
      const form = PlatformInstitutionAdminCreateFormValue(
        fullName: 'Ali Valiyev',
        loginName: 'admin1',
        email: '   ',
        phone: '',
      );

      expect(form.toRequest(password: 'valid-password').toJson(), {
        'full_name': 'Ali Valiyev',
        'login_name': 'admin1',
        'email': null,
        'phone': null,
        'password': 'valid-password',
      });
    });

    test('validates only the five approved create fields', () {
      final errors = PlatformInstitutionAdminCreateFormValue(
        fullName: '',
        loginName: '',
        email: 'not-email',
        phone: List.filled(51, '1').join(),
      ).validate(password: 'short');

      expect(errors.keys, [
        PlatformInstitutionAdminCreateField.fullName,
        PlatformInstitutionAdminCreateField.loginName,
        PlatformInstitutionAdminCreateField.email,
        PlatformInstitutionAdminCreateField.phone,
        PlatformInstitutionAdminCreateField.password,
      ]);
    });

    test('accepts optional contacts and password bounds', () {
      const valid = PlatformInstitutionAdminCreateFormValue(
        fullName: 'Ali Valiyev',
        loginName: 'admin1',
      );

      expect(valid.validate(password: '12345678'), isEmpty);
      expect(valid.validate(password: List.filled(255, 'x').join()), isEmpty);
      expect(
        valid.validate(password: List.filled(256, 'x').join()).keys,
        contains(PlatformInstitutionAdminCreateField.password),
      );
    });
  });
}
