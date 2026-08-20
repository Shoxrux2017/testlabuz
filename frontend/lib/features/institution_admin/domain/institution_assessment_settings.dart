import 'dart:convert';

enum BlitzTimerStartMode {
  synchronized(
    wireValue: 'synchronized',
    label: 'Synchronized',
    description:
        'Teacher activation starts one shared whole-Blitz timer for all assigned Students.',
  ),
  individual(
    wireValue: 'individual',
    label: 'Individual',
    description:
        'After Teacher activation, each Student receives the full whole-Blitz duration when they start.',
  );

  const BlitzTimerStartMode({
    required this.wireValue,
    required this.label,
    required this.description,
  });

  final String wireValue;
  final String label;
  final String description;

  static BlitzTimerStartMode parse(String value) => values.singleWhere(
    (mode) => mode.wireValue == value,
    orElse: () =>
        throw const FormatException('Invalid Blitz timer start mode.'),
  );
}

enum StudentResultReleaseMode {
  automatic(
    wireValue: 'automatic',
    label: 'Automatic',
    description:
        'A fully calculated result becomes visible to the Student automatically.',
  ),
  manualTeacher(
    wireValue: 'manual_teacher',
    label: 'Teacher-controlled',
    description:
        'A fully calculated result stays hidden until an authorized Teacher releases it.',
  );

  const StudentResultReleaseMode({
    required this.wireValue,
    required this.label,
    required this.description,
  });

  final String wireValue;
  final String label;
  final String description;

  static StudentResultReleaseMode parse(String value) => values.singleWhere(
    (mode) => mode.wireValue == value,
    orElse: () =>
        throw const FormatException('Invalid Student result release mode.'),
  );
}

enum ParentResultReleaseMode {
  withStudent(
    wireValue: 'with_student',
    label: 'With Student',
    description:
        'A connected Parent receives access only after the Student result is released.',
  ),
  manualTeacher(
    wireValue: 'manual_teacher',
    label: 'Teacher-controlled',
    description:
        'A Teacher may release the Parent result only after the Student result is available.',
  ),
  hidden(
    wireValue: 'hidden',
    label: 'Hidden',
    description: 'Parents do not receive the result.',
  );

  const ParentResultReleaseMode({
    required this.wireValue,
    required this.label,
    required this.description,
  });

  final String wireValue;
  final String label;
  final String description;

  static ParentResultReleaseMode parse(String value) => values.singleWhere(
    (mode) => mode.wireValue == value,
    orElse: () =>
        throw const FormatException('Invalid Parent result release mode.'),
  );
}

class ExactAssessmentDecimal {
  ExactAssessmentDecimal._(this.coefficient, this.scale);

  factory ExactAssessmentDecimal.parseUserInput(String input) {
    if (!_userDecimal.hasMatch(input)) {
      throw const FormatException('Invalid assessment decimal input.');
    }

    return ExactAssessmentDecimal.parseJsonLexeme(input);
  }

  factory ExactAssessmentDecimal.parseJsonLexeme(String lexeme) {
    final match = _jsonNumber.firstMatch(lexeme);
    if (match == null) {
      throw const FormatException('Invalid assessment JSON number.');
    }

    if (match.group(1) == '-') {
      throw const FormatException('Assessment decimal is out of range.');
    }

    final integer = match.group(2)!;
    final fraction = match.group(3) ?? '';
    final exponent = int.parse(match.group(4) ?? '0');
    var coefficient = BigInt.parse('$integer$fraction');
    var scale = fraction.length - exponent;

    if (scale < 0) {
      coefficient *= BigInt.from(10).pow(-scale);
      scale = 0;
    }

    while (scale > 0 && coefficient.remainder(BigInt.from(10)) == BigInt.zero) {
      coefficient ~/= BigInt.from(10);
      scale -= 1;
    }

    if (scale > 8) {
      throw const FormatException(
        'Assessment decimal has more than eight fractional places.',
      );
    }

    final maximum = BigInt.from(100) * BigInt.from(10).pow(scale);
    if (coefficient > maximum) {
      throw const FormatException('Assessment decimal is out of range.');
    }

    return ExactAssessmentDecimal._(coefficient, scale);
  }

  final BigInt coefficient;
  final int scale;

  String get canonical {
    final digits = coefficient.toString();
    if (scale == 0) {
      return digits;
    }

    final padded = digits.padLeft(scale + 1, '0');
    final split = padded.length - scale;
    return '${padded.substring(0, split)}.${padded.substring(split)}';
  }

  num toJsonNumber() {
    final value = double.parse(canonical);
    if (!value.isFinite) {
      throw StateError('Assessment decimal cannot be represented as JSON.');
    }

    final encoded = jsonEncode(value);
    final encodedValue = ExactAssessmentDecimal.parseJsonLexeme(encoded);
    if (encodedValue != this) {
      throw StateError('Assessment decimal JSON serialization is not exact.');
    }

    return value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExactAssessmentDecimal &&
          other.coefficient == coefficient &&
          other.scale == scale;

  @override
  int get hashCode => Object.hash(coefficient, scale);

  @override
  String toString() => canonical;
}

final RegExp _userDecimal = RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,8})?$');
final RegExp _jsonNumber = RegExp(
  r'^(-?)(0|[1-9]\d*)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
);

class InstitutionAssessmentSettings {
  const InstitutionAssessmentSettings({
    required this.educationalPolicyConfigured,
    required this.acceptableScoreDifference,
    required this.blitzTimerStartMode,
    required this.studentResultReleaseMode,
    required this.parentResultReleaseMode,
    required this.timezone,
    required this.learningMaterialMaxMb,
    required this.studentSubmissionMaxMb,
    required this.platformLearningMaterialMaxMb,
    required this.platformStudentSubmissionMaxMb,
    required this.homeworkNormalAttempts,
    required this.blitzNormalAttempts,
    required this.blitzMaxAdditionalExceptionAttempts,
  });

  final bool educationalPolicyConfigured;
  final ExactAssessmentDecimal? acceptableScoreDifference;
  final BlitzTimerStartMode? blitzTimerStartMode;
  final StudentResultReleaseMode? studentResultReleaseMode;
  final ParentResultReleaseMode? parentResultReleaseMode;
  final String timezone;
  final int learningMaterialMaxMb;
  final int studentSubmissionMaxMb;
  final int platformLearningMaterialMaxMb;
  final int platformStudentSubmissionMaxMb;
  final int homeworkNormalAttempts;
  final int blitzNormalAttempts;
  final int blitzMaxAdditionalExceptionAttempts;

  bool matches(InstitutionAssessmentSettingsUpdateRequest request) =>
      acceptableScoreDifference == request.acceptableScoreDifference &&
      blitzTimerStartMode == request.blitzTimerStartMode &&
      studentResultReleaseMode == request.studentResultReleaseMode &&
      parentResultReleaseMode == request.parentResultReleaseMode &&
      timezone == request.timezone &&
      learningMaterialMaxMb == request.learningMaterialMaxMb &&
      studentSubmissionMaxMb == request.studentSubmissionMaxMb;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionAssessmentSettings &&
          other.educationalPolicyConfigured == educationalPolicyConfigured &&
          other.acceptableScoreDifference == acceptableScoreDifference &&
          other.blitzTimerStartMode == blitzTimerStartMode &&
          other.studentResultReleaseMode == studentResultReleaseMode &&
          other.parentResultReleaseMode == parentResultReleaseMode &&
          other.timezone == timezone &&
          other.learningMaterialMaxMb == learningMaterialMaxMb &&
          other.studentSubmissionMaxMb == studentSubmissionMaxMb &&
          other.platformLearningMaterialMaxMb ==
              platformLearningMaterialMaxMb &&
          other.platformStudentSubmissionMaxMb ==
              platformStudentSubmissionMaxMb &&
          other.homeworkNormalAttempts == homeworkNormalAttempts &&
          other.blitzNormalAttempts == blitzNormalAttempts &&
          other.blitzMaxAdditionalExceptionAttempts ==
              blitzMaxAdditionalExceptionAttempts;

  @override
  int get hashCode => Object.hash(
    educationalPolicyConfigured,
    acceptableScoreDifference,
    blitzTimerStartMode,
    studentResultReleaseMode,
    parentResultReleaseMode,
    timezone,
    learningMaterialMaxMb,
    studentSubmissionMaxMb,
    platformLearningMaterialMaxMb,
    platformStudentSubmissionMaxMb,
    homeworkNormalAttempts,
    blitzNormalAttempts,
    blitzMaxAdditionalExceptionAttempts,
  );
}

enum InstitutionAssessmentSettingsField {
  acceptableScoreDifference('acceptable_score_difference'),
  blitzTimerStartMode('blitz_timer_start_mode'),
  studentResultReleaseMode('student_result_release_mode'),
  parentResultReleaseMode('parent_result_release_mode'),
  timezone('timezone'),
  learningMaterialMaxMb('learning_material_max_mb'),
  studentSubmissionMaxMb('student_submission_max_mb');

  const InstitutionAssessmentSettingsField(this.apiKey);
  final String apiKey;

  static InstitutionAssessmentSettingsField? fromApiKey(String key) {
    for (final field in values) {
      if (field.apiKey == key) {
        return field;
      }
    }
    return null;
  }
}

class InstitutionAssessmentSettingsDraft {
  const InstitutionAssessmentSettingsDraft({
    required this.acceptableScoreDifference,
    required this.blitzTimerStartMode,
    required this.studentResultReleaseMode,
    required this.parentResultReleaseMode,
    required this.timezone,
    required this.learningMaterialMaxMb,
    required this.studentSubmissionMaxMb,
  });

  factory InstitutionAssessmentSettingsDraft.fromSettings(
    InstitutionAssessmentSettings settings,
  ) => InstitutionAssessmentSettingsDraft(
    acceptableScoreDifference:
        settings.acceptableScoreDifference?.canonical ?? '',
    blitzTimerStartMode: settings.blitzTimerStartMode,
    studentResultReleaseMode: settings.studentResultReleaseMode,
    parentResultReleaseMode: settings.parentResultReleaseMode,
    timezone: settings.timezone,
    learningMaterialMaxMb: settings.learningMaterialMaxMb.toString(),
    studentSubmissionMaxMb: settings.studentSubmissionMaxMb.toString(),
  );

  final String acceptableScoreDifference;
  final BlitzTimerStartMode? blitzTimerStartMode;
  final StudentResultReleaseMode? studentResultReleaseMode;
  final ParentResultReleaseMode? parentResultReleaseMode;
  final String timezone;
  final String learningMaterialMaxMb;
  final String studentSubmissionMaxMb;

  InstitutionAssessmentSettingsDraft withField(
    InstitutionAssessmentSettingsField field,
    Object? value,
  ) => switch (field) {
    InstitutionAssessmentSettingsField.acceptableScoreDifference => copyWith(
      acceptableScoreDifference: value! as String,
    ),
    InstitutionAssessmentSettingsField.blitzTimerStartMode => copyWith(
      blitzTimerStartMode: value as BlitzTimerStartMode?,
    ),
    InstitutionAssessmentSettingsField.studentResultReleaseMode => copyWith(
      studentResultReleaseMode: value as StudentResultReleaseMode?,
    ),
    InstitutionAssessmentSettingsField.parentResultReleaseMode => copyWith(
      parentResultReleaseMode: value as ParentResultReleaseMode?,
    ),
    InstitutionAssessmentSettingsField.timezone => copyWith(
      timezone: value! as String,
    ),
    InstitutionAssessmentSettingsField.learningMaterialMaxMb => copyWith(
      learningMaterialMaxMb: value! as String,
    ),
    InstitutionAssessmentSettingsField.studentSubmissionMaxMb => copyWith(
      studentSubmissionMaxMb: value! as String,
    ),
  };

  InstitutionAssessmentSettingsDraft copyWith({
    String? acceptableScoreDifference,
    BlitzTimerStartMode? blitzTimerStartMode,
    bool clearBlitzTimerStartMode = false,
    StudentResultReleaseMode? studentResultReleaseMode,
    bool clearStudentResultReleaseMode = false,
    ParentResultReleaseMode? parentResultReleaseMode,
    bool clearParentResultReleaseMode = false,
    String? timezone,
    String? learningMaterialMaxMb,
    String? studentSubmissionMaxMb,
  }) => InstitutionAssessmentSettingsDraft(
    acceptableScoreDifference:
        acceptableScoreDifference ?? this.acceptableScoreDifference,
    blitzTimerStartMode: clearBlitzTimerStartMode
        ? null
        : blitzTimerStartMode ?? this.blitzTimerStartMode,
    studentResultReleaseMode: clearStudentResultReleaseMode
        ? null
        : studentResultReleaseMode ?? this.studentResultReleaseMode,
    parentResultReleaseMode: clearParentResultReleaseMode
        ? null
        : parentResultReleaseMode ?? this.parentResultReleaseMode,
    timezone: timezone ?? this.timezone,
    learningMaterialMaxMb: learningMaterialMaxMb ?? this.learningMaterialMaxMb,
    studentSubmissionMaxMb:
        studentSubmissionMaxMb ?? this.studentSubmissionMaxMb,
  );

  InstitutionAssessmentSettingsValidation validate({
    required int platformLearningMaterialMaxMb,
    required int platformStudentSubmissionMaxMb,
  }) {
    final errors = <InstitutionAssessmentSettingsField, String>{};
    ExactAssessmentDecimal? score;
    try {
      score = ExactAssessmentDecimal.parseUserInput(acceptableScoreDifference);
    } on FormatException {
      errors[InstitutionAssessmentSettingsField.acceptableScoreDifference] =
          'Enter a value from 0 to 100 using up to 8 decimal places.';
    }

    if (blitzTimerStartMode == null) {
      errors[InstitutionAssessmentSettingsField.blitzTimerStartMode] =
          'Select a Blitz timer-start mode.';
    }
    if (studentResultReleaseMode == null) {
      errors[InstitutionAssessmentSettingsField.studentResultReleaseMode] =
          'Select a Student result-release mode.';
    }
    if (parentResultReleaseMode == null) {
      errors[InstitutionAssessmentSettingsField.parentResultReleaseMode] =
          'Select a Parent result-visibility mode.';
    }

    if (timezone.isEmpty ||
        timezone.length > 64 ||
        timezone.trim() != timezone ||
        _fixedNumericOffset.hasMatch(timezone)) {
      errors[InstitutionAssessmentSettingsField.timezone] =
          'Enter an exact IANA timezone identifier of 64 characters or fewer.';
    }

    final learningLimit = _strictInteger(learningMaterialMaxMb);
    if (learningLimit == null ||
        learningLimit < 1 ||
        learningLimit > platformLearningMaterialMaxMb) {
      errors[InstitutionAssessmentSettingsField.learningMaterialMaxMb] =
          'Enter a whole number from 1 to $platformLearningMaterialMaxMb.';
    }

    final submissionLimit = _strictInteger(studentSubmissionMaxMb);
    if (submissionLimit == null ||
        submissionLimit < 1 ||
        submissionLimit > platformStudentSubmissionMaxMb) {
      errors[InstitutionAssessmentSettingsField.studentSubmissionMaxMb] =
          'Enter a whole number from 1 to $platformStudentSubmissionMaxMb.';
    }

    return InstitutionAssessmentSettingsValidation(
      fieldErrors: errors,
      request: errors.isEmpty
          ? InstitutionAssessmentSettingsUpdateRequest(
              acceptableScoreDifference: score!,
              blitzTimerStartMode: blitzTimerStartMode!,
              studentResultReleaseMode: studentResultReleaseMode!,
              parentResultReleaseMode: parentResultReleaseMode!,
              timezone: timezone,
              learningMaterialMaxMb: learningLimit!,
              studentSubmissionMaxMb: submissionLimit!,
            )
          : null,
    );
  }
}

final RegExp _fixedNumericOffset = RegExp(r'^[+-]\d{2}:\d{2}$');
final RegExp _integerInput = RegExp(r'^(?:0|[1-9]\d*)$');

int? _strictInteger(String value) {
  if (!_integerInput.hasMatch(value)) {
    return null;
  }
  return int.tryParse(value);
}

class InstitutionAssessmentSettingsValidation {
  const InstitutionAssessmentSettingsValidation({
    required this.fieldErrors,
    required this.request,
  });

  final Map<InstitutionAssessmentSettingsField, String> fieldErrors;
  final InstitutionAssessmentSettingsUpdateRequest? request;
  bool get isValid => request != null;

  InstitutionAssessmentSettingsField? get firstInvalidField {
    for (final field in InstitutionAssessmentSettingsField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }
    return null;
  }
}

class InstitutionAssessmentSettingsUpdateRequest {
  const InstitutionAssessmentSettingsUpdateRequest({
    required this.acceptableScoreDifference,
    required this.blitzTimerStartMode,
    required this.studentResultReleaseMode,
    required this.parentResultReleaseMode,
    required this.timezone,
    required this.learningMaterialMaxMb,
    required this.studentSubmissionMaxMb,
  });

  final ExactAssessmentDecimal acceptableScoreDifference;
  final BlitzTimerStartMode blitzTimerStartMode;
  final StudentResultReleaseMode studentResultReleaseMode;
  final ParentResultReleaseMode parentResultReleaseMode;
  final String timezone;
  final int learningMaterialMaxMb;
  final int studentSubmissionMaxMb;

  Map<String, Object> toJson() => {
    'acceptable_score_difference': acceptableScoreDifference.toJsonNumber(),
    'blitz_timer_start_mode': blitzTimerStartMode.wireValue,
    'student_result_release_mode': studentResultReleaseMode.wireValue,
    'parent_result_release_mode': parentResultReleaseMode.wireValue,
    'timezone': timezone,
    'learning_material_max_mb': learningMaterialMaxMb,
    'student_submission_max_mb': studentSubmissionMaxMb,
  };

  bool matches(InstitutionAssessmentSettings settings) =>
      settings.matches(this);
}
