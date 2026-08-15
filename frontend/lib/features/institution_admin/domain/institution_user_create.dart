import 'institution_user.dart';

enum InstitutionUserCreateField {
  role('role'),
  fullName('full_name'),
  loginName('login_name'),
  email('email'),
  phone('phone'),
  password('password');

  const InstitutionUserCreateField(this.requestKey);

  final String requestKey;

  static InstitutionUserCreateField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }

    return null;
  }
}

class InstitutionUserCreateFormValue {
  const InstitutionUserCreateFormValue({
    this.role,
    this.fullName = '',
    this.loginName = '',
    this.email = '',
    this.phone = '',
  });

  factory InstitutionUserCreateFormValue.fromSnapshot(
    InstitutionUserCreateSnapshot snapshot,
  ) {
    return InstitutionUserCreateFormValue(
      role: snapshot.role,
      fullName: snapshot.fullName,
      loginName: snapshot.loginName,
      email: snapshot.email ?? '',
      phone: snapshot.phone ?? '',
    );
  }

  static const fullNameMaxLength = 200;
  static const loginNameMaxLength = 191;
  static const emailMaxLength = 254;
  static const phoneMaxLength = 50;
  static const passwordMinLength = 8;
  static const passwordMaxLength = 255;

  final InstitutionUserRole? role;
  final String fullName;
  final String loginName;
  final String email;
  final String phone;

  String get normalizedFullName => fullName.trim();

  String get normalizedLoginName => loginName.trim();

  String? get normalizedEmail => email.isEmpty ? null : email;

  String? get normalizedPhone => phone.isEmpty ? null : phone.trim();

  InstitutionUserCreateFormValue copyWith({
    Object? role = _sentinel,
    String? fullName,
    String? loginName,
    String? email,
    String? phone,
  }) {
    return InstitutionUserCreateFormValue(
      role: identical(role, _sentinel)
          ? this.role
          : role as InstitutionUserRole?,
      fullName: fullName ?? this.fullName,
      loginName: loginName ?? this.loginName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  Map<InstitutionUserCreateField, String> validate({required String password}) {
    final errors = <InstitutionUserCreateField, String>{};

    if (role == null) {
      errors[InstitutionUserCreateField.role] = 'Select a role.';
    }

    if (normalizedFullName.isEmpty) {
      errors[InstitutionUserCreateField.fullName] = 'Full name is required.';
    } else if (_runeLength(normalizedFullName) > fullNameMaxLength) {
      errors[InstitutionUserCreateField.fullName] =
          'Full name must be 200 characters or fewer.';
    }

    if (normalizedLoginName.isEmpty) {
      errors[InstitutionUserCreateField.loginName] = 'Login name is required.';
    } else if (_runeLength(normalizedLoginName) > loginNameMaxLength) {
      errors[InstitutionUserCreateField.loginName] =
          'Login name must be 191 characters or fewer.';
    }

    if (email.isNotEmpty) {
      if (_runeLength(email) > emailMaxLength) {
        errors[InstitutionUserCreateField.email] =
            'Email must be 254 characters or fewer.';
      } else if (!_hasPermissiveEmailShape(email)) {
        errors[InstitutionUserCreateField.email] =
            'Enter a valid email address.';
      }
    }

    if (phone.isNotEmpty) {
      if (phone.trim().isEmpty) {
        errors[InstitutionUserCreateField.phone] =
            'Phone must not contain only spaces.';
      } else if (_runeLength(phone.trim()) > phoneMaxLength) {
        errors[InstitutionUserCreateField.phone] =
            'Phone must be 50 characters or fewer.';
      }
    }

    if (password.isEmpty) {
      errors[InstitutionUserCreateField.password] =
          'Initial password is required.';
    } else if (_runeLength(password) < passwordMinLength) {
      errors[InstitutionUserCreateField.password] =
          'Initial password must be at least 8 characters.';
    } else if (_runeLength(password) > passwordMaxLength) {
      errors[InstitutionUserCreateField.password] =
          'Initial password must be 255 characters or fewer.';
    }

    return Map<InstitutionUserCreateField, String>.unmodifiable(errors);
  }

  InstitutionUserCreateRequest toRequest({required String password}) {
    final selectedRole = role;
    if (selectedRole == null) {
      throw StateError('A role is required before creating a request.');
    }

    return InstitutionUserCreateRequest(
      snapshot: InstitutionUserCreateSnapshot(
        role: selectedRole,
        fullName: normalizedFullName,
        loginName: normalizedLoginName,
        email: normalizedEmail,
        phone: normalizedPhone,
      ),
      password: password,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionUserCreateFormValue &&
            other.role == role &&
            other.fullName == fullName &&
            other.loginName == loginName &&
            other.email == email &&
            other.phone == phone;
  }

  @override
  int get hashCode => Object.hash(role, fullName, loginName, email, phone);
}

class InstitutionUserCreateSnapshot {
  const InstitutionUserCreateSnapshot({
    required this.role,
    required this.fullName,
    required this.loginName,
    required this.email,
    required this.phone,
  });

  final InstitutionUserRole role;
  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;

  bool matches(InstitutionUser user) {
    return user.role == role &&
        user.fullName == fullName &&
        user.loginName == loginName &&
        user.email == email &&
        user.phone == phone;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionUserCreateSnapshot &&
            other.role == role &&
            other.fullName == fullName &&
            other.loginName == loginName &&
            other.email == email &&
            other.phone == phone;
  }

  @override
  int get hashCode => Object.hash(role, fullName, loginName, email, phone);
}

class InstitutionUserCreateRequest {
  const InstitutionUserCreateRequest({
    required this.snapshot,
    required this.password,
  });

  final InstitutionUserCreateSnapshot snapshot;
  final String password;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      InstitutionUserCreateField.role.requestKey: snapshot.role.value,
      InstitutionUserCreateField.fullName.requestKey: snapshot.fullName,
      InstitutionUserCreateField.loginName.requestKey: snapshot.loginName,
      InstitutionUserCreateField.email.requestKey: snapshot.email,
      InstitutionUserCreateField.phone.requestKey: snapshot.phone,
      InstitutionUserCreateField.password.requestKey: password,
    };
  }

  @override
  String toString() => 'InstitutionUserCreateRequest(password: <redacted>)';
}

class InstitutionUserCreateOutcomeUnknownException implements Exception {
  const InstitutionUserCreateOutcomeUnknownException();
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

int _runeLength(String value) => value.runes.length;

const _sentinel = Object();
