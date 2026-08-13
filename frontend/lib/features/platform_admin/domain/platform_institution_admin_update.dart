import 'platform_institution_admin.dart';

enum PlatformInstitutionAdminEditField {
  fullName('full_name'),
  email('email'),
  phone('phone');

  const PlatformInstitutionAdminEditField(this.requestKey);

  final String requestKey;

  static PlatformInstitutionAdminEditField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }
    return null;
  }
}

class PlatformInstitutionAdminEditFormValue {
  const PlatformInstitutionAdminEditFormValue({
    required this.fullName,
    required this.email,
    required this.phone,
  });

  factory PlatformInstitutionAdminEditFormValue.fromAdmin(
    PlatformInstitutionAdmin admin,
  ) {
    return PlatformInstitutionAdminEditFormValue(
      fullName: admin.fullName,
      email: admin.email ?? '',
      phone: admin.phone ?? '',
    );
  }

  final String fullName;
  final String email;
  final String phone;

  String get normalizedFullName => fullName.trim();

  String? get normalizedEmail {
    final value = email.trim();
    return value.isEmpty ? null : value;
  }

  String? get normalizedPhone {
    final value = phone.trim();
    return value.isEmpty ? null : value;
  }

  PlatformInstitutionAdminEditFormValue copyWith({
    String? fullName,
    String? email,
    String? phone,
  }) {
    return PlatformInstitutionAdminEditFormValue(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  Map<PlatformInstitutionAdminEditField, String> validate() {
    final errors = <PlatformInstitutionAdminEditField, String>{};

    if (normalizedFullName.isEmpty) {
      errors[PlatformInstitutionAdminEditField.fullName] =
          'Full name is required.';
    } else if (normalizedFullName.length > 200) {
      errors[PlatformInstitutionAdminEditField.fullName] =
          'Full name must be 200 characters or fewer.';
    }

    final emailValue = normalizedEmail;
    if (emailValue != null) {
      if (emailValue.length > 254) {
        errors[PlatformInstitutionAdminEditField.email] =
            'Email must be 254 characters or fewer.';
      } else if (!_hasPermissiveEmailShape(emailValue)) {
        errors[PlatformInstitutionAdminEditField.email] =
            'Enter a valid email address.';
      }
    }

    final phoneValue = normalizedPhone;
    if (phoneValue != null && phoneValue.length > 50) {
      errors[PlatformInstitutionAdminEditField.phone] =
          'Phone must be 50 characters or fewer.';
    }

    return errors;
  }

  PlatformInstitutionAdminUpdateRequest toChangedRequest({
    required PlatformInstitutionAdmin initialAdmin,
  }) {
    final changedValues = <PlatformInstitutionAdminEditField, Object?>{};
    final nextFullName = normalizedFullName;
    if (nextFullName != initialAdmin.fullName.trim()) {
      changedValues[PlatformInstitutionAdminEditField.fullName] = nextFullName;
    }

    final nextEmail = normalizedEmail;
    if (nextEmail != _normalizeOptionalContact(initialAdmin.email)) {
      changedValues[PlatformInstitutionAdminEditField.email] = nextEmail;
    }

    final nextPhone = normalizedPhone;
    if (nextPhone != _normalizeOptionalContact(initialAdmin.phone)) {
      changedValues[PlatformInstitutionAdminEditField.phone] = nextPhone;
    }

    return PlatformInstitutionAdminUpdateRequest(changedValues);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionAdminEditFormValue &&
            other.fullName == fullName &&
            other.email == email &&
            other.phone == phone;
  }

  @override
  int get hashCode => Object.hash(fullName, email, phone);
}

class PlatformInstitutionAdminUpdateRequest {
  PlatformInstitutionAdminUpdateRequest(
    Map<PlatformInstitutionAdminEditField, Object?> changedValues,
  ) : changedValues = Map.unmodifiable(changedValues);

  final Map<PlatformInstitutionAdminEditField, Object?> changedValues;

  bool get isEmpty => changedValues.isEmpty;

  Map<String, Object?> toJson() {
    return Map.unmodifiable({
      for (final entry in changedValues.entries)
        entry.key.requestKey: entry.value,
    });
  }
}

class PlatformInstitutionAdminUpdateResult {
  const PlatformInstitutionAdminUpdateResult({
    required this.admin,
    required this.message,
  });

  final PlatformInstitutionAdmin admin;
  final String message;
}

class PlatformInstitutionAdminMutationOutcomeUnknownException
    implements Exception {
  const PlatformInstitutionAdminMutationOutcomeUnknownException([this.message]);

  final String? message;
}

String? _normalizeOptionalContact(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
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
