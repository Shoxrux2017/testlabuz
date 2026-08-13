import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_admin_update.dart';

void main() {
  group('PlatformInstitutionAdminEditFormValue', () {
    test('normalizes changed update fields and omits protected authority', () {
      const form = PlatformInstitutionAdminEditFormValue(
        fullName: '  Updated Institution Admin  ',
        email: '  updated@example.uz  ',
        phone: '  +998901111111  ',
      );

      final request = form.toChangedRequest(initialAdmin: _admin());

      expect(request.toJson(), {
        'full_name': 'Updated Institution Admin',
        'email': 'updated@example.uz',
        'phone': '+998901111111',
      });
      expect(request.toJson().keys, hasLength(3));
      expect(
        request.toJson().keys,
        isNot(
          containsAll([
            'login_name',
            'password',
            'role',
            'institution_id',
            'is_active',
            'must_change_password',
            'last_login_at',
            'deactivated_at',
            'created_at',
            'updated_at',
          ]),
        ),
      );
    });

    test('sends explicit null only for optional contacts changed to empty', () {
      const form = PlatformInstitutionAdminEditFormValue(
        fullName: 'Ali Valiyev',
        email: '   ',
        phone: '',
      );

      expect(form.toChangedRequest(initialAdmin: _admin()).toJson(), {
        'email': null,
        'phone': null,
      });
    });

    test('unchanged and reverted values produce no request body', () {
      const form = PlatformInstitutionAdminEditFormValue(
        fullName: ' Ali Valiyev ',
        email: ' ali@example.uz ',
        phone: ' +998901234567 ',
      );

      expect(form.toChangedRequest(initialAdmin: _admin()).isEmpty, isTrue);
    });

    test('validates only editable update fields', () {
      final errors = PlatformInstitutionAdminEditFormValue(
        fullName: '',
        email: 'not-email',
        phone: List.filled(51, '1').join(),
      ).validate();

      expect(errors.keys, [
        PlatformInstitutionAdminEditField.fullName,
        PlatformInstitutionAdminEditField.email,
        PlatformInstitutionAdminEditField.phone,
      ]);
    });
  });
}

PlatformInstitutionAdmin _admin() {
  return PlatformInstitutionAdmin(
    id: '550e8400-e29b-41d4-a716-446655440001',
    fullName: 'Ali Valiyev',
    loginName: 'admin.school1',
    email: 'ali@example.uz',
    phone: '+998901234567',
    isActive: true,
    mustChangePassword: true,
    lastLoginAt: null,
    deactivatedAt: null,
    createdAt: DateTime.utc(2026, 8, 10, 10),
    updatedAt: DateTime.utc(2026, 8, 10, 10),
  );
}
