enum UnderstandingCategoryDefinition {
  understoodWell(
    code: 'understood_well',
    label: 'Understood well',
    sortOrder: 1,
    numeric: true,
  ),
  partiallyUnderstood(
    code: 'partially_understood',
    label: 'Partially understood',
    sortOrder: 2,
    numeric: true,
  ),
  needsRevision(
    code: 'needs_revision',
    label: 'Needs revision',
    sortOrder: 3,
    numeric: true,
  ),
  needsTeacherSupport(
    code: 'needs_teacher_support',
    label: 'Needs teacher support',
    sortOrder: 4,
    numeric: true,
  ),
  notCompleted(
    code: 'not_completed',
    label: 'Not completed',
    sortOrder: 5,
    numeric: false,
  );

  const UnderstandingCategoryDefinition({
    required this.code,
    required this.label,
    required this.sortOrder,
    required this.numeric,
  });

  final String code;
  final String label;
  final int sortOrder;
  final bool numeric;

  static UnderstandingCategoryDefinition parse(String code) =>
      values.singleWhere(
        (definition) => definition.code == code,
        orElse: () =>
            throw const FormatException('Unknown understanding category code.'),
      );
}

class InstitutionUnderstandingCategory {
  const InstitutionUnderstandingCategory({
    required this.definition,
    required this.minScore,
    required this.maxScore,
  });

  final UnderstandingCategoryDefinition definition;
  final int? minScore;
  final int? maxScore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionUnderstandingCategory &&
          other.definition == definition &&
          other.minScore == minScore &&
          other.maxScore == maxScore;

  @override
  int get hashCode => Object.hash(definition, minScore, maxScore);
}

class InstitutionUnderstandingCategoryConfiguration {
  InstitutionUnderstandingCategoryConfiguration._({
    required this.configured,
    required List<InstitutionUnderstandingCategory> categories,
  }) : categories = List.unmodifiable(categories);

  factory InstitutionUnderstandingCategoryConfiguration.unconfigured() =>
      InstitutionUnderstandingCategoryConfiguration._(
        configured: false,
        categories: const [],
      );

  factory InstitutionUnderstandingCategoryConfiguration.configured(
    List<InstitutionUnderstandingCategory> categories,
  ) {
    _validateCompleteSet(categories);
    return InstitutionUnderstandingCategoryConfiguration._(
      configured: true,
      categories: categories,
    );
  }

  final bool configured;
  final List<InstitutionUnderstandingCategory> categories;

  InstitutionUnderstandingCategory categoryFor(
    UnderstandingCategoryDefinition definition,
  ) => categories.singleWhere((category) => category.definition == definition);

  bool matches(InstitutionUnderstandingCategoryUpdateRequest request) =>
      configured && request.matches(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionUnderstandingCategoryConfiguration &&
          other.configured == configured &&
          _categoryListsEqual(other.categories, categories);

  @override
  int get hashCode => Object.hash(configured, Object.hashAll(categories));
}

enum InstitutionUnderstandingCategoryField {
  understoodWellMin(
    definition: UnderstandingCategoryDefinition.understoodWell,
    apiPath: 'categories.0.min_score',
    isMinimum: true,
  ),
  understoodWellMax(
    definition: UnderstandingCategoryDefinition.understoodWell,
    apiPath: 'categories.0.max_score',
    isMinimum: false,
  ),
  partiallyUnderstoodMin(
    definition: UnderstandingCategoryDefinition.partiallyUnderstood,
    apiPath: 'categories.1.min_score',
    isMinimum: true,
  ),
  partiallyUnderstoodMax(
    definition: UnderstandingCategoryDefinition.partiallyUnderstood,
    apiPath: 'categories.1.max_score',
    isMinimum: false,
  ),
  needsRevisionMin(
    definition: UnderstandingCategoryDefinition.needsRevision,
    apiPath: 'categories.2.min_score',
    isMinimum: true,
  ),
  needsRevisionMax(
    definition: UnderstandingCategoryDefinition.needsRevision,
    apiPath: 'categories.2.max_score',
    isMinimum: false,
  ),
  needsTeacherSupportMin(
    definition: UnderstandingCategoryDefinition.needsTeacherSupport,
    apiPath: 'categories.3.min_score',
    isMinimum: true,
  ),
  needsTeacherSupportMax(
    definition: UnderstandingCategoryDefinition.needsTeacherSupport,
    apiPath: 'categories.3.max_score',
    isMinimum: false,
  );

  const InstitutionUnderstandingCategoryField({
    required this.definition,
    required this.apiPath,
    required this.isMinimum,
  });

  final UnderstandingCategoryDefinition definition;
  final String apiPath;
  final bool isMinimum;

  static InstitutionUnderstandingCategoryField? fromApiPath(String path) {
    for (final field in values) {
      if (field.apiPath == path) return field;
    }
    return null;
  }
}

class InstitutionUnderstandingCategoryDraft {
  InstitutionUnderstandingCategoryDraft._(
    Map<InstitutionUnderstandingCategoryField, String> values,
  ) : values = Map.unmodifiable(values);

  factory InstitutionUnderstandingCategoryDraft.fromConfiguration(
    InstitutionUnderstandingCategoryConfiguration configuration,
  ) {
    final values = <InstitutionUnderstandingCategoryField, String>{};
    for (final field in InstitutionUnderstandingCategoryField.values) {
      if (!configuration.configured) {
        values[field] = '';
        continue;
      }
      final category = configuration.categoryFor(field.definition);
      values[field] = (field.isMinimum ? category.minScore : category.maxScore)
          .toString();
    }
    return InstitutionUnderstandingCategoryDraft._(values);
  }

  final Map<InstitutionUnderstandingCategoryField, String> values;

  String valueFor(InstitutionUnderstandingCategoryField field) =>
      values[field] ?? '';

  InstitutionUnderstandingCategoryDraft withField(
    InstitutionUnderstandingCategoryField field,
    String value,
  ) => InstitutionUnderstandingCategoryDraft._({...values, field: value});

  InstitutionUnderstandingCategoryValidation validate() {
    final errors = <InstitutionUnderstandingCategoryField, String>{};
    final parsed = <InstitutionUnderstandingCategoryField, int>{};

    for (final field in InstitutionUnderstandingCategoryField.values) {
      final value = valueFor(field);
      if (!_integerInput.hasMatch(value)) {
        errors[field] =
            'Enter a whole number from 0 to 100 without leading zeroes.';
        continue;
      }
      final number = int.parse(value);
      if (number > 100) {
        errors[field] = 'Enter a whole number from 0 to 100.';
        continue;
      }
      parsed[field] = number;
    }

    for (final definition in UnderstandingCategoryDefinition.values.where(
      (definition) => definition.numeric,
    )) {
      final minField = _minimumField(definition);
      final maxField = _maximumField(definition);
      final minimum = parsed[minField];
      final maximum = parsed[maxField];
      if (minimum != null && maximum != null && minimum > maximum) {
        errors[minField] = 'Minimum must not exceed maximum.';
        errors[maxField] = 'Maximum must not be below minimum.';
      }
    }

    final firstMaximum =
        parsed[InstitutionUnderstandingCategoryField.understoodWellMax];
    if (firstMaximum != null && firstMaximum != 100) {
      errors[InstitutionUnderstandingCategoryField.understoodWellMax] =
          'Understood well must end at 100.';
    }
    final lastMinimum =
        parsed[InstitutionUnderstandingCategoryField.needsTeacherSupportMin];
    if (lastMinimum != null && lastMinimum != 0) {
      errors[InstitutionUnderstandingCategoryField.needsTeacherSupportMin] =
          'Needs teacher support must start at 0.';
    }

    final numericDefinitions = UnderstandingCategoryDefinition.values
        .where((definition) => definition.numeric)
        .toList(growable: false);
    for (var index = 0; index < numericDefinitions.length - 1; index++) {
      final higherMinimumField = _minimumField(numericDefinitions[index]);
      final lowerMaximumField = _maximumField(numericDefinitions[index + 1]);
      final higherMinimum = parsed[higherMinimumField];
      final lowerMaximum = parsed[lowerMaximumField];
      if (higherMinimum != null &&
          lowerMaximum != null &&
          higherMinimum != lowerMaximum + 1) {
        errors[higherMinimumField] =
            'Adjacent ranges must meet without a gap or overlap.';
        errors[lowerMaximumField] =
            'Adjacent ranges must meet without a gap or overlap.';
      }
    }

    if (errors.isNotEmpty) {
      return InstitutionUnderstandingCategoryValidation(
        fieldErrors: errors,
        setError:
            'Ranges must cover every integer score from 0 through 100 exactly once without gaps or overlaps.',
        request: null,
      );
    }

    final categories = <InstitutionUnderstandingCategoryUpdateEntry>[
      for (final definition in numericDefinitions)
        InstitutionUnderstandingCategoryUpdateEntry(
          definition: definition,
          minScore: parsed[_minimumField(definition)],
          maxScore: parsed[_maximumField(definition)],
        ),
      const InstitutionUnderstandingCategoryUpdateEntry(
        definition: UnderstandingCategoryDefinition.notCompleted,
        minScore: null,
        maxScore: null,
      ),
    ];
    return InstitutionUnderstandingCategoryValidation(
      fieldErrors: const {},
      setError: null,
      request: InstitutionUnderstandingCategoryUpdateRequest(categories),
    );
  }
}

class InstitutionUnderstandingCategoryValidation {
  InstitutionUnderstandingCategoryValidation({
    required Map<InstitutionUnderstandingCategoryField, String> fieldErrors,
    required this.setError,
    required this.request,
  }) : fieldErrors = Map.unmodifiable(fieldErrors);

  final Map<InstitutionUnderstandingCategoryField, String> fieldErrors;
  final String? setError;
  final InstitutionUnderstandingCategoryUpdateRequest? request;

  bool get isValid => request != null;

  InstitutionUnderstandingCategoryField? get firstInvalidField {
    for (final field in InstitutionUnderstandingCategoryField.values) {
      if (fieldErrors.containsKey(field)) return field;
    }
    return null;
  }
}

class InstitutionUnderstandingCategoryUpdateEntry {
  const InstitutionUnderstandingCategoryUpdateEntry({
    required this.definition,
    required this.minScore,
    required this.maxScore,
  });

  final UnderstandingCategoryDefinition definition;
  final int? minScore;
  final int? maxScore;

  Map<String, Object?> toJson() => {
    'code': definition.code,
    'min_score': minScore,
    'max_score': maxScore,
    'sort_order': definition.sortOrder,
  };
}

class InstitutionUnderstandingCategoryUpdateRequest {
  InstitutionUnderstandingCategoryUpdateRequest(
    List<InstitutionUnderstandingCategoryUpdateEntry> categories,
  ) : categories = List.unmodifiable(categories) {
    _validateUpdateSet(categories);
  }

  final List<InstitutionUnderstandingCategoryUpdateEntry> categories;

  Map<String, Object> toJson() => {
    'categories': categories
        .map((category) => category.toJson())
        .toList(growable: false),
  };

  bool matches(InstitutionUnderstandingCategoryConfiguration configuration) {
    if (!configuration.configured ||
        configuration.categories.length != categories.length) {
      return false;
    }
    for (var index = 0; index < categories.length; index++) {
      final requestCategory = categories[index];
      final currentCategory = configuration.categories[index];
      if (requestCategory.definition != currentCategory.definition ||
          requestCategory.minScore != currentCategory.minScore ||
          requestCategory.maxScore != currentCategory.maxScore) {
        return false;
      }
    }
    return true;
  }
}

final RegExp _integerInput = RegExp(r'^(?:0|[1-9][0-9]{0,2})$');

InstitutionUnderstandingCategoryField _minimumField(
  UnderstandingCategoryDefinition definition,
) => switch (definition) {
  UnderstandingCategoryDefinition.understoodWell =>
    InstitutionUnderstandingCategoryField.understoodWellMin,
  UnderstandingCategoryDefinition.partiallyUnderstood =>
    InstitutionUnderstandingCategoryField.partiallyUnderstoodMin,
  UnderstandingCategoryDefinition.needsRevision =>
    InstitutionUnderstandingCategoryField.needsRevisionMin,
  UnderstandingCategoryDefinition.needsTeacherSupport =>
    InstitutionUnderstandingCategoryField.needsTeacherSupportMin,
  UnderstandingCategoryDefinition.notCompleted => throw ArgumentError.value(
    definition,
    'definition',
  ),
};

InstitutionUnderstandingCategoryField _maximumField(
  UnderstandingCategoryDefinition definition,
) => switch (definition) {
  UnderstandingCategoryDefinition.understoodWell =>
    InstitutionUnderstandingCategoryField.understoodWellMax,
  UnderstandingCategoryDefinition.partiallyUnderstood =>
    InstitutionUnderstandingCategoryField.partiallyUnderstoodMax,
  UnderstandingCategoryDefinition.needsRevision =>
    InstitutionUnderstandingCategoryField.needsRevisionMax,
  UnderstandingCategoryDefinition.needsTeacherSupport =>
    InstitutionUnderstandingCategoryField.needsTeacherSupportMax,
  UnderstandingCategoryDefinition.notCompleted => throw ArgumentError.value(
    definition,
    'definition',
  ),
};

void _validateCompleteSet(List<InstitutionUnderstandingCategory> categories) {
  final definitions = UnderstandingCategoryDefinition.values;
  if (categories.length != definitions.length) {
    throw const FormatException('Incomplete understanding category set.');
  }
  for (var index = 0; index < definitions.length; index++) {
    final category = categories[index];
    final definition = definitions[index];
    if (category.definition != definition) {
      throw const FormatException('Non-canonical understanding category set.');
    }
    if (definition.numeric) {
      final minimum = category.minScore;
      final maximum = category.maxScore;
      if (minimum == null ||
          maximum == null ||
          minimum < 0 ||
          maximum > 100 ||
          minimum > maximum) {
        throw const FormatException('Invalid numeric category range.');
      }
    } else if (category.minScore != null || category.maxScore != null) {
      throw const FormatException('Not completed must be non-numeric.');
    }
  }
  if (categories.first.maxScore != 100 || categories[3].minScore != 0) {
    throw const FormatException('Category endpoints do not cover 0 to 100.');
  }
  for (var index = 0; index < 3; index++) {
    if (categories[index].minScore != categories[index + 1].maxScore! + 1) {
      throw const FormatException('Category ranges contain a gap or overlap.');
    }
  }
}

bool _categoryListsEqual(
  List<InstitutionUnderstandingCategory> left,
  List<InstitutionUnderstandingCategory> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void _validateUpdateSet(
  List<InstitutionUnderstandingCategoryUpdateEntry> categories,
) {
  final definitions = UnderstandingCategoryDefinition.values;
  if (categories.length != definitions.length) {
    throw ArgumentError.value(categories, 'categories');
  }
  for (var index = 0; index < definitions.length; index++) {
    final entry = categories[index];
    if (entry.definition != definitions[index] ||
        entry.definition.sortOrder != index + 1) {
      throw ArgumentError.value(categories, 'categories');
    }
  }
  try {
    InstitutionUnderstandingCategoryConfiguration.configured([
      for (final entry in categories)
        InstitutionUnderstandingCategory(
          definition: entry.definition,
          minScore: entry.minScore,
          maxScore: entry.maxScore,
        ),
    ]);
  } on FormatException {
    throw ArgumentError.value(categories, 'categories');
  }
}
