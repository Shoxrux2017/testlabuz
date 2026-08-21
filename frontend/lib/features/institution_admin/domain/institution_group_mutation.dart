import 'institution_group.dart';

enum InstitutionGroupEditField {
  name('name'),
  level('level'),
  subjectDirection('subject_direction'),
  description('description');

  const InstitutionGroupEditField(this.requestKey);

  final String requestKey;

  static InstitutionGroupEditField? fromRequestKey(String key) {
    for (final field in values) {
      if (field.requestKey == key) {
        return field;
      }
    }
    return null;
  }
}

class InstitutionGroupEditFormValue {
  const InstitutionGroupEditFormValue({
    required this.name,
    required this.level,
    required this.subjectDirection,
    required this.description,
  });

  factory InstitutionGroupEditFormValue.fromGroup(InstitutionGroup group) {
    return InstitutionGroupEditFormValue(
      name: group.name,
      level: group.level ?? '',
      subjectDirection: group.subjectDirection ?? '',
      description: group.description ?? '',
    );
  }

  static const nameMaxRunes = 160;
  static const levelMaxRunes = 100;
  static const subjectDirectionMaxRunes = 160;

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

  InstitutionGroupEditFormValue copyWith({
    String? name,
    String? level,
    String? subjectDirection,
    String? description,
  }) {
    return InstitutionGroupEditFormValue(
      name: name ?? this.name,
      level: level ?? this.level,
      subjectDirection: subjectDirection ?? this.subjectDirection,
      description: description ?? this.description,
    );
  }

  Map<InstitutionGroupEditField, String> validate() {
    final errors = <InstitutionGroupEditField, String>{};
    if (normalizedName.isEmpty) {
      errors[InstitutionGroupEditField.name] = 'Group name is required.';
    } else if (normalizedName.runes.length > nameMaxRunes) {
      errors[InstitutionGroupEditField.name] =
          'Group name must be 160 characters or fewer.';
    }

    _validateOptional(
      draft: level,
      normalized: normalizedLevel,
      maxRunes: levelMaxRunes,
      field: InstitutionGroupEditField.level,
      spacesMessage: 'Level must not contain only spaces.',
      lengthMessage: 'Level must be 100 characters or fewer.',
      errors: errors,
    );
    _validateOptional(
      draft: subjectDirection,
      normalized: normalizedSubjectDirection,
      maxRunes: subjectDirectionMaxRunes,
      field: InstitutionGroupEditField.subjectDirection,
      spacesMessage: 'Subject direction must not contain only spaces.',
      lengthMessage: 'Subject direction must be 160 characters or fewer.',
      errors: errors,
    );
    if (description.isNotEmpty && normalizedDescription!.isEmpty) {
      errors[InstitutionGroupEditField.description] =
          'Description must not contain only spaces.';
    }

    return Map.unmodifiable(errors);
  }

  InstitutionGroupEditRequest changedFieldsComparedTo(
    InstitutionGroup initial,
  ) {
    final changed = <String, Object?>{};
    if (normalizedName != initial.name) {
      changed[InstitutionGroupEditField.name.requestKey] = normalizedName;
    }
    if (normalizedLevel != initial.level) {
      changed[InstitutionGroupEditField.level.requestKey] = normalizedLevel;
    }
    if (normalizedSubjectDirection != initial.subjectDirection) {
      changed[InstitutionGroupEditField.subjectDirection.requestKey] =
          normalizedSubjectDirection;
    }
    if (normalizedDescription != initial.description) {
      changed[InstitutionGroupEditField.description.requestKey] =
          normalizedDescription;
    }
    return InstitutionGroupEditRequest(changed);
  }

  static void _validateOptional({
    required String draft,
    required String? normalized,
    required int maxRunes,
    required InstitutionGroupEditField field,
    required String spacesMessage,
    required String lengthMessage,
    required Map<InstitutionGroupEditField, String> errors,
  }) {
    if (draft.isEmpty) {
      return;
    }
    if (normalized!.isEmpty) {
      errors[field] = spacesMessage;
    } else if (normalized.runes.length > maxRunes) {
      errors[field] = lengthMessage;
    }
  }
}

class InstitutionGroupEditRequest {
  InstitutionGroupEditRequest(Map<String, Object?> changedFields)
    : changedFields = _validateAndFreeze(changedFields);

  final Map<String, Object?> changedFields;

  bool get isEmpty => changedFields.isEmpty;

  Map<String, Object?> toJson() => changedFields;

  bool matches(InstitutionGroup group) {
    for (final entry in changedFields.entries) {
      final current = switch (entry.key) {
        'name' => group.name,
        'level' => group.level,
        'subject_direction' => group.subjectDirection,
        'description' => group.description,
        _ => throw StateError('Unsupported Institution Group edit field.'),
      };
      if (current != entry.value) {
        return false;
      }
    }
    return true;
  }

  static Map<String, Object?> _validateAndFreeze(
    Map<String, Object?> changedFields,
  ) {
    final allowed = InstitutionGroupEditField.values
        .map((field) => field.requestKey)
        .toSet();
    for (final entry in changedFields.entries) {
      if (!allowed.contains(entry.key)) {
        throw ArgumentError(
          'Institution Group edit contains an unsupported key.',
        );
      }
      if (entry.key == InstitutionGroupEditField.name.requestKey) {
        if (entry.value is! String) {
          throw ArgumentError('Institution Group name must be a string.');
        }
      } else if (entry.value != null && entry.value is! String) {
        throw ArgumentError(
          'Institution Group optional edit value must be a string or null.',
        );
      }
    }
    return Map<String, Object?>.unmodifiable(
      Map<String, Object?>.from(changedFields),
    );
  }
}

class InstitutionGroupMutationOutcomeUnknownException implements Exception {
  const InstitutionGroupMutationOutcomeUnknownException();
}

bool institutionGroupImmutableIdentityMatches(
  InstitutionGroup selected,
  InstitutionGroup returned,
) {
  return selected.id.toLowerCase() == returned.id.toLowerCase() &&
      selected.createdAt == returned.createdAt;
}
