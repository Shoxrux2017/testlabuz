import 'platform_institution.dart';
import 'platform_institution_detail.dart';

class PlatformInstitutionEditFormValue {
  const PlatformInstitutionEditFormValue({
    required this.name,
    required this.type,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.description,
  });

  factory PlatformInstitutionEditFormValue.fromDetail(
    PlatformInstitutionDetail detail,
  ) {
    return PlatformInstitutionEditFormValue(
      name: detail.name,
      type: detail.type,
      contactEmail: detail.contactEmail ?? '',
      contactPhone: detail.contactPhone ?? '',
      address: detail.address ?? '',
      description: detail.description ?? '',
    );
  }

  static const nameMaxLength = 200;
  static const contactEmailMaxLength = 254;
  static const contactPhoneMaxLength = 50;

  final String name;
  final PlatformInstitutionType type;
  final String contactEmail;
  final String contactPhone;
  final String address;
  final String description;

  PlatformInstitutionEditFormValue copyWith({
    String? name,
    PlatformInstitutionType? type,
    String? contactEmail,
    String? contactPhone,
    String? address,
    String? description,
  }) {
    return PlatformInstitutionEditFormValue(
      name: name ?? this.name,
      type: type ?? this.type,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      description: description ?? this.description,
    );
  }

  PlatformInstitutionEditSnapshot normalized() {
    return PlatformInstitutionEditSnapshot(
      name: name.trim(),
      type: type,
      contactEmail: _trimmedOptional(contactEmail),
      contactPhone: _trimmedOptional(contactPhone),
      address: _multilineOptional(address),
      description: _multilineOptional(description),
    );
  }

  bool isDirtyComparedTo(PlatformInstitutionEditSnapshot initialSnapshot) {
    return normalized() != initialSnapshot;
  }

  PlatformInstitutionEditValidation validate() {
    final errors = <PlatformInstitutionEditField, List<String>>{};
    final current = normalized();

    if (current.name.isEmpty) {
      errors[PlatformInstitutionEditField.name] = const [
        'Institution name is required.',
      ];
    } else if (current.name.length > nameMaxLength) {
      errors[PlatformInstitutionEditField.name] = const [
        'Institution name must be 200 characters or fewer.',
      ];
    }

    final email = current.contactEmail;
    if (email != null) {
      if (email.length > contactEmailMaxLength) {
        errors[PlatformInstitutionEditField.contactEmail] = const [
          'Contact email must be 254 characters or fewer.',
        ];
      } else if (!_hasPermissiveEmailShape(email)) {
        errors[PlatformInstitutionEditField.contactEmail] = const [
          'Contact email must be a valid email address.',
        ];
      }
    }

    final phone = current.contactPhone;
    if (phone != null && phone.length > contactPhoneMaxLength) {
      errors[PlatformInstitutionEditField.contactPhone] = const [
        'Contact phone must be 50 characters or fewer.',
      ];
    }

    return PlatformInstitutionEditValidation(
      fieldErrors: Map.unmodifiable(errors),
    );
  }

  PlatformInstitutionEditRequest toChangedFieldsRequest(
    PlatformInstitutionEditSnapshot initialSnapshot,
  ) {
    final current = normalized();
    final changedFields = <String, Object?>{};

    if (current.name != initialSnapshot.name) {
      changedFields[PlatformInstitutionEditField.name.requestKey] =
          current.name;
    }
    if (current.type != initialSnapshot.type) {
      changedFields[PlatformInstitutionEditField.type.requestKey] =
          current.type.value;
    }
    if (current.contactEmail != initialSnapshot.contactEmail) {
      changedFields[PlatformInstitutionEditField.contactEmail.requestKey] =
          current.contactEmail;
    }
    if (current.contactPhone != initialSnapshot.contactPhone) {
      changedFields[PlatformInstitutionEditField.contactPhone.requestKey] =
          current.contactPhone;
    }
    if (current.address != initialSnapshot.address) {
      changedFields[PlatformInstitutionEditField.address.requestKey] =
          current.address;
    }
    if (current.description != initialSnapshot.description) {
      changedFields[PlatformInstitutionEditField.description.requestKey] =
          current.description;
    }

    return PlatformInstitutionEditRequest(changedFields);
  }

  static bool _hasPermissiveEmailShape(String value) {
    if (value.contains(RegExp(r'\s'))) {
      return false;
    }

    final atIndex = value.indexOf('@');
    return atIndex > 0 &&
        atIndex == value.lastIndexOf('@') &&
        atIndex < value.length - 1;
  }

  static String? _trimmedOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _multilineOptional(String value) {
    return value.trim().isEmpty ? null : value;
  }
}

class PlatformInstitutionEditSnapshot {
  const PlatformInstitutionEditSnapshot({
    required this.name,
    required this.type,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.description,
  });

  final String name;
  final PlatformInstitutionType type;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? description;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionEditSnapshot &&
            other.name == name &&
            other.type == type &&
            other.contactEmail == contactEmail &&
            other.contactPhone == contactPhone &&
            other.address == address &&
            other.description == description;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      type,
      contactEmail,
      contactPhone,
      address,
      description,
    );
  }
}

class PlatformInstitutionEditValidation {
  const PlatformInstitutionEditValidation({required this.fieldErrors});

  final Map<PlatformInstitutionEditField, List<String>> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;

  PlatformInstitutionEditField? get firstInvalidField {
    for (final field in PlatformInstitutionEditField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }
}

class PlatformInstitutionEditRequest {
  PlatformInstitutionEditRequest(Map<String, Object?> changedFields)
    : changedFields = _freezeAndValidate(changedFields);

  final Map<String, Object?> changedFields;

  bool get isEmpty => changedFields.isEmpty;

  Map<String, Object?> toJson() {
    return changedFields;
  }

  static Map<String, Object?> _freezeAndValidate(
    Map<String, Object?> changedFields,
  ) {
    final allowedKeys = PlatformInstitutionEditField.values
        .map((field) => field.requestKey)
        .toSet();

    for (final key in changedFields.keys) {
      if (!allowedKeys.contains(key)) {
        throw ArgumentError.value(key, 'changedFields', 'Unsupported key');
      }
    }

    return Map<String, Object?>.unmodifiable(changedFields);
  }
}

class PlatformInstitutionEditResult {
  const PlatformInstitutionEditResult({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.message,
  });

  final String id;
  final String name;
  final PlatformInstitutionType type;
  final PlatformInstitutionStatus status;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String message;
}

enum PlatformInstitutionEditField {
  name('name'),
  type('type'),
  contactEmail('contact_email'),
  contactPhone('contact_phone'),
  address('address'),
  description('description');

  const PlatformInstitutionEditField(this.requestKey);

  final String requestKey;

  static PlatformInstitutionEditField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }

    return null;
  }
}
