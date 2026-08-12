import 'platform_institution_admin.dart';

enum PlatformInstitutionAdminCreateField {
  fullName('full_name'),
  loginName('login_name'),
  email('email'),
  phone('phone'),
  password('password');

  const PlatformInstitutionAdminCreateField(this.requestKey);

  final String requestKey;

  static PlatformInstitutionAdminCreateField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }
    return null;
  }
}

class PlatformInstitutionAdminCreateFormValue {
  const PlatformInstitutionAdminCreateFormValue({
    this.fullName = '',
    this.loginName = '',
    this.email = '',
    this.phone = '',
  });

  final String fullName;
  final String loginName;
  final String email;
  final String phone;

  String get normalizedFullName => fullName.trim();

  String get normalizedLoginName => loginName.trim();

  String? get normalizedEmail {
    final value = email.trim();
    return value.isEmpty ? null : value;
  }

  String? get normalizedPhone {
    final value = phone.trim();
    return value.isEmpty ? null : value;
  }

  PlatformInstitutionAdminCreateFormValue copyWith({
    String? fullName,
    String? loginName,
    String? email,
    String? phone,
  }) {
    return PlatformInstitutionAdminCreateFormValue(
      fullName: fullName ?? this.fullName,
      loginName: loginName ?? this.loginName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  Map<PlatformInstitutionAdminCreateField, String> validate({
    required String password,
  }) {
    final errors = <PlatformInstitutionAdminCreateField, String>{};

    if (normalizedFullName.isEmpty) {
      errors[PlatformInstitutionAdminCreateField.fullName] =
          'Full name is required.';
    } else if (normalizedFullName.length > 200) {
      errors[PlatformInstitutionAdminCreateField.fullName] =
          'Full name must be 200 characters or fewer.';
    }

    if (normalizedLoginName.isEmpty) {
      errors[PlatformInstitutionAdminCreateField.loginName] =
          'Login name is required.';
    } else if (normalizedLoginName.length > 191) {
      errors[PlatformInstitutionAdminCreateField.loginName] =
          'Login name must be 191 characters or fewer.';
    }

    final emailValue = normalizedEmail;
    if (emailValue != null) {
      if (emailValue.length > 254) {
        errors[PlatformInstitutionAdminCreateField.email] =
            'Email must be 254 characters or fewer.';
      } else if (!_hasPermissiveEmailShape(emailValue)) {
        errors[PlatformInstitutionAdminCreateField.email] =
            'Enter a valid email address.';
      }
    }

    final phoneValue = normalizedPhone;
    if (phoneValue != null && phoneValue.length > 50) {
      errors[PlatformInstitutionAdminCreateField.phone] =
          'Phone must be 50 characters or fewer.';
    }

    if (password.isEmpty) {
      errors[PlatformInstitutionAdminCreateField.password] =
          'Initial password is required.';
    } else if (password.length < 8) {
      errors[PlatformInstitutionAdminCreateField.password] =
          'Initial password must be at least 8 characters.';
    } else if (password.length > 255) {
      errors[PlatformInstitutionAdminCreateField.password] =
          'Initial password must be 255 characters or fewer.';
    }

    return errors;
  }

  PlatformInstitutionAdminCreateRequest toRequest({required String password}) {
    return PlatformInstitutionAdminCreateRequest(
      fullName: normalizedFullName,
      loginName: normalizedLoginName,
      email: normalizedEmail,
      phone: normalizedPhone,
      password: password,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionAdminCreateFormValue &&
            other.fullName == fullName &&
            other.loginName == loginName &&
            other.email == email &&
            other.phone == phone;
  }

  @override
  int get hashCode => Object.hash(fullName, loginName, email, phone);
}

class PlatformInstitutionAdminCreateRequest {
  const PlatformInstitutionAdminCreateRequest({
    required this.fullName,
    required this.loginName,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;
  final String password;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      PlatformInstitutionAdminCreateField.fullName.requestKey: fullName,
      PlatformInstitutionAdminCreateField.loginName.requestKey: loginName,
      PlatformInstitutionAdminCreateField.email.requestKey: email,
      PlatformInstitutionAdminCreateField.phone.requestKey: phone,
      PlatformInstitutionAdminCreateField.password.requestKey: password,
    };
  }
}

class PlatformInstitutionAdminCreateResult {
  const PlatformInstitutionAdminCreateResult({
    required this.admin,
    required this.message,
  });

  final PlatformInstitutionAdmin admin;
  final String message;
}

class PlatformInstitutionAdminCreateOutcomeUnknownException
    implements Exception {
  const PlatformInstitutionAdminCreateOutcomeUnknownException([this.message]);

  final String? message;
}

bool _hasPermissiveEmailShape(String value) {
  if (value.contains(RegExp(r'\s'))) {
    return false;
  }

  final atIndex = value.indexOf('@');
  return atIndex > 0 &&
      atIndex == value.lastIndexOf('@') &&
      atIndex < value.length - 1;
}
