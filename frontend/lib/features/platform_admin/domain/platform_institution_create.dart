import 'platform_institution.dart';

class PlatformInstitutionCreateFormValue {
  const PlatformInstitutionCreateFormValue({
    this.name = '',
    this.type,
    this.contactEmail = '',
    this.contactPhone = '',
    this.address = '',
    this.description = '',
    this.status,
  });

  static const nameMaxLength = 200;
  static const contactEmailMaxLength = 254;
  static const contactPhoneMaxLength = 50;

  final String name;
  final PlatformInstitutionType? type;
  final String contactEmail;
  final String contactPhone;
  final String address;
  final String description;
  final PlatformInstitutionStatus? status;

  bool get isDirty {
    return name.isNotEmpty ||
        type != null ||
        contactEmail.isNotEmpty ||
        contactPhone.isNotEmpty ||
        address.isNotEmpty ||
        description.isNotEmpty ||
        status != null;
  }

  PlatformInstitutionCreateFormValue copyWith({
    String? name,
    Object? type = _sentinel,
    String? contactEmail,
    String? contactPhone,
    String? address,
    String? description,
    Object? status = _sentinel,
  }) {
    return PlatformInstitutionCreateFormValue(
      name: name ?? this.name,
      type: identical(type, _sentinel)
          ? this.type
          : type as PlatformInstitutionType?,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      description: description ?? this.description,
      status: identical(status, _sentinel)
          ? this.status
          : status as PlatformInstitutionStatus?,
    );
  }

  PlatformInstitutionCreateValidation validate() {
    final errors = <PlatformInstitutionCreateField, List<String>>{};
    final trimmedName = name.trim();
    final trimmedEmail = contactEmail.trim();
    final trimmedPhone = contactPhone.trim();

    if (trimmedName.isEmpty) {
      errors[PlatformInstitutionCreateField.name] = const [
        'Institution name is required.',
      ];
    } else if (trimmedName.length > nameMaxLength) {
      errors[PlatformInstitutionCreateField.name] = const [
        'Institution name must be 200 characters or fewer.',
      ];
    }

    if (type == null) {
      errors[PlatformInstitutionCreateField.type] = const [
        'Choose an institution type.',
      ];
    }

    if (trimmedEmail.isNotEmpty) {
      if (trimmedEmail.length > contactEmailMaxLength) {
        errors[PlatformInstitutionCreateField.contactEmail] = const [
          'Contact email must be 254 characters or fewer.',
        ];
      } else if (!_hasPermissiveEmailShape(trimmedEmail)) {
        errors[PlatformInstitutionCreateField.contactEmail] = const [
          'Contact email must be a valid email address.',
        ];
      }
    }

    if (trimmedPhone.length > contactPhoneMaxLength) {
      errors[PlatformInstitutionCreateField.contactPhone] = const [
        'Contact phone must be 50 characters or fewer.',
      ];
    }

    if (status == null) {
      errors[PlatformInstitutionCreateField.status] = const [
        'Choose an institution status.',
      ];
    }

    return PlatformInstitutionCreateValidation(
      fieldErrors: Map.unmodifiable(errors),
    );
  }

  PlatformInstitutionCreateRequest toRequest() {
    final selectedType = type;
    final selectedStatus = status;
    if (selectedType == null || selectedStatus == null) {
      throw StateError('Create request requires type and status.');
    }

    return PlatformInstitutionCreateRequest(
      name: name.trim(),
      type: selectedType,
      contactEmail: _trimmedOptional(contactEmail),
      contactPhone: _trimmedOptional(contactPhone),
      address: _multilineOptional(address),
      description: _multilineOptional(description),
      status: selectedStatus,
    );
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

class PlatformInstitutionCreateValidation {
  const PlatformInstitutionCreateValidation({required this.fieldErrors});

  final Map<PlatformInstitutionCreateField, List<String>> fieldErrors;

  bool get isValid => fieldErrors.isEmpty;

  PlatformInstitutionCreateField? get firstInvalidField {
    for (final field in PlatformInstitutionCreateField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }
}

class PlatformInstitutionCreateRequest {
  const PlatformInstitutionCreateRequest({
    required this.name,
    required this.type,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.description,
    required this.status,
  });

  final String name;
  final PlatformInstitutionType type;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? description;
  final PlatformInstitutionStatus status;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'type': type.value,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'address': address,
      'description': description,
      'status': status.value,
    };
  }
}

class PlatformInstitutionCreateResult {
  const PlatformInstitutionCreateResult({
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

enum PlatformInstitutionCreateField {
  name('name'),
  type('type'),
  contactEmail('contact_email'),
  contactPhone('contact_phone'),
  address('address'),
  description('description'),
  status('status');

  const PlatformInstitutionCreateField(this.requestKey);

  final String requestKey;

  static PlatformInstitutionCreateField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }

    return null;
  }
}

const _sentinel = Object();
