import 'institution_group.dart';

enum InstitutionGroupCreateField {
  name('name'),
  level('level'),
  subjectDirection('subject_direction'),
  description('description');

  const InstitutionGroupCreateField(this.requestKey);

  final String requestKey;

  static InstitutionGroupCreateField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }

    return null;
  }
}

class InstitutionGroupCreateFormValue {
  const InstitutionGroupCreateFormValue({
    this.name = '',
    this.level = '',
    this.subjectDirection = '',
    this.description = '',
  });

  factory InstitutionGroupCreateFormValue.fromSnapshot(
    InstitutionGroupCreateSnapshot snapshot,
  ) {
    return InstitutionGroupCreateFormValue(
      name: snapshot.name,
      level: snapshot.level ?? '',
      subjectDirection: snapshot.subjectDirection ?? '',
      description: snapshot.description ?? '',
    );
  }

  static const nameMaxLength = 160;
  static const levelMaxLength = 100;
  static const subjectDirectionMaxLength = 160;

  final String name;
  final String level;
  final String subjectDirection;
  final String description;

  String get normalizedName => name.trim();
  String? get normalizedLevel => level.isEmpty ? null : level.trim();
  String? get normalizedSubjectDirection =>
      subjectDirection.isEmpty ? null : subjectDirection.trim();
  String? get normalizedDescription =>
      description.isEmpty ? null : description.trim();

  InstitutionGroupCreateFormValue copyWith({
    String? name,
    String? level,
    String? subjectDirection,
    String? description,
  }) {
    return InstitutionGroupCreateFormValue(
      name: name ?? this.name,
      level: level ?? this.level,
      subjectDirection: subjectDirection ?? this.subjectDirection,
      description: description ?? this.description,
    );
  }

  Map<InstitutionGroupCreateField, String> validate() {
    final errors = <InstitutionGroupCreateField, String>{};

    if (normalizedName.isEmpty) {
      errors[InstitutionGroupCreateField.name] = 'Group name is required.';
    } else if (normalizedName.runes.length > nameMaxLength) {
      errors[InstitutionGroupCreateField.name] =
          'Group name must be 160 characters or fewer.';
    }

    if (level.isNotEmpty) {
      if (normalizedLevel!.isEmpty) {
        errors[InstitutionGroupCreateField.level] =
            'Level must not contain only spaces.';
      } else if (normalizedLevel!.runes.length > levelMaxLength) {
        errors[InstitutionGroupCreateField.level] =
            'Level must be 100 characters or fewer.';
      }
    }

    if (subjectDirection.isNotEmpty) {
      if (normalizedSubjectDirection!.isEmpty) {
        errors[InstitutionGroupCreateField.subjectDirection] =
            'Subject direction must not contain only spaces.';
      } else if (normalizedSubjectDirection!.runes.length >
          subjectDirectionMaxLength) {
        errors[InstitutionGroupCreateField.subjectDirection] =
            'Subject direction must be 160 characters or fewer.';
      }
    }

    if (description.isNotEmpty && normalizedDescription!.isEmpty) {
      errors[InstitutionGroupCreateField.description] =
          'Description must not contain only spaces.';
    }

    return Map<InstitutionGroupCreateField, String>.unmodifiable(errors);
  }

  InstitutionGroupCreateRequest toRequest() {
    return InstitutionGroupCreateRequest(
      snapshot: InstitutionGroupCreateSnapshot(
        name: normalizedName,
        level: normalizedLevel,
        subjectDirection: normalizedSubjectDirection,
        description: normalizedDescription,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionGroupCreateFormValue &&
            other.name == name &&
            other.level == level &&
            other.subjectDirection == subjectDirection &&
            other.description == description;
  }

  @override
  int get hashCode => Object.hash(name, level, subjectDirection, description);
}

class InstitutionGroupCreateSnapshot {
  const InstitutionGroupCreateSnapshot({
    required this.name,
    required this.level,
    required this.subjectDirection,
    required this.description,
  });

  final String name;
  final String? level;
  final String? subjectDirection;
  final String? description;

  bool matches(InstitutionGroup group) {
    return group.name == name &&
        group.level == level &&
        group.subjectDirection == subjectDirection &&
        group.description == description;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionGroupCreateSnapshot &&
            other.name == name &&
            other.level == level &&
            other.subjectDirection == subjectDirection &&
            other.description == description;
  }

  @override
  int get hashCode => Object.hash(name, level, subjectDirection, description);
}

class InstitutionGroupCreateRequest {
  const InstitutionGroupCreateRequest({required this.snapshot});

  final InstitutionGroupCreateSnapshot snapshot;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      InstitutionGroupCreateField.name.requestKey: snapshot.name,
      InstitutionGroupCreateField.level.requestKey: snapshot.level,
      InstitutionGroupCreateField.subjectDirection.requestKey:
          snapshot.subjectDirection,
      InstitutionGroupCreateField.description.requestKey: snapshot.description,
    };
  }
}

class InstitutionGroupCreateOutcomeUnknownException implements Exception {
  const InstitutionGroupCreateOutcomeUnknownException();
}
