import 'institution_user.dart';

enum InstitutionUserEditField {
  fullName('full_name'),
  email('email'),
  phone('phone');

  const InstitutionUserEditField(this.requestKey);

  final String requestKey;

  static InstitutionUserEditField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }
    return null;
  }
}

class InstitutionUserEditFormValue {
  const InstitutionUserEditFormValue({
    required this.fullName,
    required this.email,
    required this.phone,
  });

  factory InstitutionUserEditFormValue.fromUser(InstitutionUser user) {
    return InstitutionUserEditFormValue(
      fullName: user.fullName,
      email: user.email ?? '',
      phone: user.phone ?? '',
    );
  }

  static const fullNameMaxLength = 200;
  static const emailMaxLength = 254;
  static const phoneMaxLength = 50;

  final String fullName;
  final String email;
  final String phone;

  String get normalizedFullName => fullName.trim();
  String? get normalizedEmail => email.isEmpty ? null : email;
  String? get normalizedPhone => phone.isEmpty ? null : phone.trim();

  InstitutionUserEditFormValue copyWith({
    String? fullName,
    String? email,
    String? phone,
  }) {
    return InstitutionUserEditFormValue(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  Map<InstitutionUserEditField, String> validate() {
    final errors = <InstitutionUserEditField, String>{};
    if (normalizedFullName.isEmpty) {
      errors[InstitutionUserEditField.fullName] = 'Full name is required.';
    } else if (normalizedFullName.runes.length > fullNameMaxLength) {
      errors[InstitutionUserEditField.fullName] =
          'Full name must be 200 characters or fewer.';
    }

    if (email.isNotEmpty) {
      if (email.runes.length > emailMaxLength) {
        errors[InstitutionUserEditField.email] =
            'Email must be 254 characters or fewer.';
      } else if (!_hasPermissiveEmailShape(email)) {
        errors[InstitutionUserEditField.email] = 'Enter a valid email address.';
      }
    }

    if (phone.isNotEmpty) {
      if (phone.trim().isEmpty) {
        errors[InstitutionUserEditField.phone] =
            'Phone must not contain only spaces.';
      } else if (phone.trim().runes.length > phoneMaxLength) {
        errors[InstitutionUserEditField.phone] =
            'Phone must be 50 characters or fewer.';
      }
    }

    return Map.unmodifiable(errors);
  }

  InstitutionUserEditRequest changedFieldsComparedTo(InstitutionUser initial) {
    final changed = <String, Object?>{};
    if (normalizedFullName != initial.fullName) {
      changed[InstitutionUserEditField.fullName.requestKey] =
          normalizedFullName;
    }
    if (normalizedEmail != initial.email) {
      changed[InstitutionUserEditField.email.requestKey] = normalizedEmail;
    }
    if (normalizedPhone != initial.phone) {
      changed[InstitutionUserEditField.phone.requestKey] = normalizedPhone;
    }
    return InstitutionUserEditRequest(changed);
  }
}

class InstitutionUserEditRequest {
  InstitutionUserEditRequest(Map<String, Object?> changedFields)
    : changedFields = _validateAndFreeze(changedFields);

  final Map<String, Object?> changedFields;

  bool get isEmpty => changedFields.isEmpty;

  Map<String, Object?> toJson() => changedFields;

  bool matches(InstitutionUser user) {
    for (final entry in changedFields.entries) {
      final value = switch (entry.key) {
        'full_name' => user.fullName,
        'email' => user.email,
        'phone' => user.phone,
        _ => throw StateError('Unsupported Institution User edit field.'),
      };
      if (value != entry.value) {
        return false;
      }
    }
    return true;
  }

  static Map<String, Object?> _validateAndFreeze(
    Map<String, Object?> changedFields,
  ) {
    final allowed = InstitutionUserEditField.values
        .map((field) => field.requestKey)
        .toSet();
    if (changedFields.keys.any((key) => !allowed.contains(key))) {
      throw ArgumentError('Institution User edit contains an unsupported key.');
    }
    return Map.unmodifiable(changedFields);
  }
}

enum InstitutionUserLifecycleAction {
  activate,
  deactivate;

  bool get desiredActive => this == activate;

  String get endpointSegment => this == activate ? 'activate' : 'deactivate';

  static InstitutionUserLifecycleAction forUser(InstitutionUser user) {
    return user.isActive ? deactivate : activate;
  }
}

class InstitutionUserMutationOutcomeUnknownException implements Exception {
  const InstitutionUserMutationOutcomeUnknownException();
}

bool institutionUserImmutableIdentityMatches(
  InstitutionUser selected,
  InstitutionUser returned,
) {
  return selected.id.toLowerCase() == returned.id.toLowerCase() &&
      selected.role == returned.role &&
      selected.loginName == returned.loginName &&
      selected.createdAt == returned.createdAt;
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
