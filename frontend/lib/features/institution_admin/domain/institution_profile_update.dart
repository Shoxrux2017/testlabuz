import 'dart:collection';

import 'institution_profile.dart';

enum InstitutionProfileEditField {
  name('name'),
  contactEmail('contact_email'),
  contactPhone('contact_phone'),
  address('address'),
  description('description');

  const InstitutionProfileEditField(this.apiKey);

  final String apiKey;

  static InstitutionProfileEditField? fromApiKey(String key) {
    for (final field in values) {
      if (field.apiKey == key) {
        return field;
      }
    }

    return null;
  }
}

class InstitutionProfileEditFormValue {
  const InstitutionProfileEditFormValue({
    required this.name,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.description,
  });

  factory InstitutionProfileEditFormValue.fromProfile(
    InstitutionProfile profile,
  ) {
    return InstitutionProfileEditFormValue(
      name: profile.name,
      contactEmail: profile.contactEmail ?? '',
      contactPhone: profile.contactPhone ?? '',
      address: profile.address ?? '',
      description: profile.description ?? '',
    );
  }

  final String name;
  final String contactEmail;
  final String contactPhone;
  final String address;
  final String description;

  InstitutionProfileEditFormValue withField(
    InstitutionProfileEditField field,
    String value,
  ) {
    return InstitutionProfileEditFormValue(
      name: field == InstitutionProfileEditField.name ? value : name,
      contactEmail: field == InstitutionProfileEditField.contactEmail
          ? value
          : contactEmail,
      contactPhone: field == InstitutionProfileEditField.contactPhone
          ? value
          : contactPhone,
      address: field == InstitutionProfileEditField.address ? value : address,
      description: field == InstitutionProfileEditField.description
          ? value
          : description,
    );
  }

  InstitutionProfileEditSnapshot normalizedSnapshot() {
    return InstitutionProfileEditSnapshot(
      name: name.trim(),
      contactEmail: _normalizeTrimmedNullable(contactEmail),
      contactPhone: _normalizeTrimmedNullable(contactPhone),
      address: _normalizePreservedNullable(address),
      description: _normalizePreservedNullable(description),
    );
  }

  InstitutionProfileEditValidation validate() {
    final snapshot = normalizedSnapshot();
    final errors = <InstitutionProfileEditField, String>{};

    if (snapshot.name.isEmpty) {
      errors[InstitutionProfileEditField.name] = 'Name is required.';
    } else if (snapshot.name.length > 200) {
      errors[InstitutionProfileEditField.name] =
          'Name must be 200 characters or fewer.';
    }

    final email = snapshot.contactEmail;
    if (email != null) {
      if (email.length > 254) {
        errors[InstitutionProfileEditField.contactEmail] =
            'Contact email must be 254 characters or fewer.';
      } else if (!_isPermissiveEmail(email)) {
        errors[InstitutionProfileEditField.contactEmail] =
            'Enter a valid contact email.';
      }
    }

    final phone = snapshot.contactPhone;
    if (phone != null && phone.length > 50) {
      errors[InstitutionProfileEditField.contactPhone] =
          'Contact phone must be 50 characters or fewer.';
    }

    return InstitutionProfileEditValidation(errors);
  }
}

class InstitutionProfileEditSnapshot {
  const InstitutionProfileEditSnapshot({
    required this.name,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.description,
  });

  factory InstitutionProfileEditSnapshot.fromProfile(
    InstitutionProfile profile,
  ) {
    return InstitutionProfileEditFormValue.fromProfile(
      profile,
    ).normalizedSnapshot();
  }

  final String name;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? description;

  Object? valueFor(InstitutionProfileEditField field) {
    return switch (field) {
      InstitutionProfileEditField.name => name,
      InstitutionProfileEditField.contactEmail => contactEmail,
      InstitutionProfileEditField.contactPhone => contactPhone,
      InstitutionProfileEditField.address => address,
      InstitutionProfileEditField.description => description,
    };
  }
}

class InstitutionProfileEditValidation {
  InstitutionProfileEditValidation(
    Map<InstitutionProfileEditField, String> fieldErrors,
  ) : fieldErrors = Map.unmodifiable(fieldErrors);

  final Map<InstitutionProfileEditField, String> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;

  InstitutionProfileEditField? get firstInvalidField {
    for (final field in InstitutionProfileEditField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }
}

class InstitutionProfileUpdateRequest {
  InstitutionProfileUpdateRequest._(Map<String, Object?> changes)
    : _changes = UnmodifiableMapView(Map<String, Object?>.from(changes));

  factory InstitutionProfileUpdateRequest.fromForm({
    required InstitutionProfileEditFormValue form,
    required InstitutionProfileEditSnapshot baseline,
  }) {
    final current = form.normalizedSnapshot();
    final changes = <String, Object?>{};

    for (final field in InstitutionProfileEditField.values) {
      final value = current.valueFor(field);
      if (value != baseline.valueFor(field)) {
        changes[field.apiKey] = value;
      }
    }

    return InstitutionProfileUpdateRequest._(changes);
  }

  factory InstitutionProfileUpdateRequest.fromChanges(
    Map<String, Object?> changes,
  ) {
    if (changes.isEmpty) {
      throw ArgumentError.value(changes, 'changes', 'Must not be empty.');
    }

    for (final entry in changes.entries) {
      if (InstitutionProfileEditField.fromApiKey(entry.key) == null) {
        throw ArgumentError.value(
          entry.key,
          'changes',
          'Contains a protected or unknown field.',
        );
      }
      if (entry.key == InstitutionProfileEditField.name.apiKey &&
          entry.value is! String) {
        throw ArgumentError.value(entry.value, entry.key, 'Must be a string.');
      }
      if (entry.value != null && entry.value is! String) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Must be a string or null.',
        );
      }
    }

    return InstitutionProfileUpdateRequest._(changes);
  }

  final Map<String, Object?> _changes;

  bool get isEmpty => _changes.isEmpty;

  Map<String, Object?> toJson() => Map<String, Object?>.from(_changes);

  bool matchesProfile(InstitutionProfile profile) {
    final snapshot = InstitutionProfileEditSnapshot.fromProfile(profile);

    for (final entry in _changes.entries) {
      final field = InstitutionProfileEditField.fromApiKey(entry.key)!;
      if (snapshot.valueFor(field) != entry.value) {
        return false;
      }
    }

    return true;
  }
}

class InstitutionProfileUpdateResult {
  const InstitutionProfileUpdateResult({required this.profile});

  final InstitutionProfile profile;
}

String? _normalizeTrimmedNullable(String value) {
  final trimmed = value.trim();

  return trimmed.isEmpty ? null : trimmed;
}

String? _normalizePreservedNullable(String value) {
  return value.trim().isEmpty ? null : value;
}

bool _isPermissiveEmail(String value) {
  if (RegExp(r'\s').hasMatch(value)) {
    return false;
  }

  final atIndex = value.indexOf('@');

  return atIndex > 0 &&
      atIndex == value.lastIndexOf('@') &&
      atIndex < value.length - 1;
}
