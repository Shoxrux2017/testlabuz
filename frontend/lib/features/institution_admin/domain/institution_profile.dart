enum InstitutionProfileType {
  school('school'),
  college('college'),
  lyceum('lyceum'),
  university('university'),
  institute('institute'),
  learningCenter('learning_center'),
  trainingCenter('training_center'),
  privateEducation('private_education'),
  other('other');

  const InstitutionProfileType(this.value);

  final String value;

  static InstitutionProfileType parse(String value) {
    return InstitutionProfileType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw FormatException(
        'Unsupported institution profile type: $value.',
      ),
    );
  }
}

enum InstitutionProfileStatus {
  active('active'),
  inactive('inactive');

  const InstitutionProfileStatus(this.value);

  final String value;

  static InstitutionProfileStatus parse(String value) {
    return InstitutionProfileStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw FormatException(
        'Unsupported institution profile status: $value.',
      ),
    );
  }
}

class InstitutionProfile {
  const InstitutionProfile({
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
  });

  final String id;
  final String name;
  final InstitutionProfileType type;
  final InstitutionProfileStatus status;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionProfile &&
            other.id == id &&
            other.name == name &&
            other.type == type &&
            other.status == status &&
            other.contactEmail == contactEmail &&
            other.contactPhone == contactPhone &&
            other.address == address &&
            other.description == description &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    status,
    contactEmail,
    contactPhone,
    address,
    description,
    createdAt,
    updatedAt,
  );
}
