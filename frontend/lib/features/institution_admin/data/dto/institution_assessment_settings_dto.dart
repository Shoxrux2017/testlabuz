import 'dart:convert';

import '../../domain/institution_assessment_settings.dart';

class InstitutionAssessmentSettingsDto {
  const InstitutionAssessmentSettingsDto({required this.settings});

  factory InstitutionAssessmentSettingsDto.fromRawJson(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      throw const FormatException('Invalid assessment settings JSON.');
    }

    final envelope = _exactStringMap(
      decoded,
      expectedKeys: const {'data'},
      context: 'assessment settings envelope',
    );
    final resource = _exactStringMap(
      envelope['data'],
      expectedKeys: const {
        'educational_policy_configured',
        'acceptable_score_difference',
        'blitz_timer_start_mode',
        'student_result_release_mode',
        'parent_result_release_mode',
        'timezone',
        'upload_limits',
        'fixed_attempt_rules',
      },
      context: 'assessment settings resource',
    );
    final uploadLimits = _exactStringMap(
      resource['upload_limits'],
      expectedKeys: const {
        'learning_material_max_mb',
        'student_submission_max_mb',
        'platform_learning_material_max_mb',
        'platform_student_submission_max_mb',
      },
      context: 'assessment upload limits',
    );
    final fixedAttempts = _exactStringMap(
      resource['fixed_attempt_rules'],
      expectedKeys: const {
        'homework_normal_attempts',
        'blitz_normal_attempts',
        'blitz_max_additional_exception_attempts',
      },
      context: 'assessment fixed attempt rules',
    );

    final configured = resource['educational_policy_configured'];
    if (configured is! bool) {
      throw const FormatException('Invalid configured flag.');
    }

    final score = _readScore(rawJson, resource['acceptable_score_difference']);
    final blitzMode = _readNullableMode(
      resource,
      'blitz_timer_start_mode',
      BlitzTimerStartMode.parse,
    );
    final studentMode = _readNullableMode(
      resource,
      'student_result_release_mode',
      StudentResultReleaseMode.parse,
    );
    final parentMode = _readNullableMode(
      resource,
      'parent_result_release_mode',
      ParentResultReleaseMode.parse,
    );
    final expectedConfigured =
        score != null &&
        blitzMode != null &&
        studentMode != null &&
        parentMode != null;
    if (configured != expectedConfigured) {
      throw const FormatException('Inconsistent configured flag.');
    }

    final timezone = resource['timezone'];
    if (timezone is! String ||
        timezone.isEmpty ||
        timezone.length > 64 ||
        timezone.trim() != timezone) {
      throw const FormatException('Invalid assessment timezone.');
    }

    final learningLimit = _strictInteger(
      uploadLimits,
      'learning_material_max_mb',
    );
    final submissionLimit = _strictInteger(
      uploadLimits,
      'student_submission_max_mb',
    );
    final platformLearningLimit = _strictInteger(
      uploadLimits,
      'platform_learning_material_max_mb',
    );
    final platformSubmissionLimit = _strictInteger(
      uploadLimits,
      'platform_student_submission_max_mb',
    );
    if (platformLearningLimit != 25 ||
        platformSubmissionLimit != 15 ||
        learningLimit < 1 ||
        learningLimit > platformLearningLimit ||
        submissionLimit < 1 ||
        submissionLimit > platformSubmissionLimit) {
      throw const FormatException('Invalid assessment upload limits.');
    }

    final homeworkAttempts = _strictInteger(
      fixedAttempts,
      'homework_normal_attempts',
    );
    final blitzAttempts = _strictInteger(
      fixedAttempts,
      'blitz_normal_attempts',
    );
    final blitzExceptions = _strictInteger(
      fixedAttempts,
      'blitz_max_additional_exception_attempts',
    );
    if (homeworkAttempts != 3 || blitzAttempts != 1 || blitzExceptions != 1) {
      throw const FormatException('Invalid fixed assessment attempt rules.');
    }

    return InstitutionAssessmentSettingsDto(
      settings: InstitutionAssessmentSettings(
        educationalPolicyConfigured: configured,
        acceptableScoreDifference: score,
        blitzTimerStartMode: blitzMode,
        studentResultReleaseMode: studentMode,
        parentResultReleaseMode: parentMode,
        timezone: timezone,
        learningMaterialMaxMb: learningLimit,
        studentSubmissionMaxMb: submissionLimit,
        platformLearningMaterialMaxMb: platformLearningLimit,
        platformStudentSubmissionMaxMb: platformSubmissionLimit,
        homeworkNormalAttempts: homeworkAttempts,
        blitzNormalAttempts: blitzAttempts,
        blitzMaxAdditionalExceptionAttempts: blitzExceptions,
      ),
    );
  }

  final InstitutionAssessmentSettings settings;
}

Map<String, Object?> _exactStringMap(
  Object? value, {
  required Set<String> expectedKeys,
  required String context,
}) {
  if (value is! Map) {
    throw FormatException('Expected object for $context.');
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('Invalid key in $context.');
    }
    result[entry.key as String] = entry.value;
  }
  if (result.keys.toSet().length != expectedKeys.length ||
      !result.keys.toSet().containsAll(expectedKeys)) {
    throw FormatException('Unexpected keys in $context.');
  }
  return result;
}

ExactAssessmentDecimal? _readScore(String rawJson, Object? decodedValue) {
  final matches = _scoreToken.allMatches(rawJson).toList(growable: false);
  if (matches.length != 1) {
    throw const FormatException('Missing exact assessment score token.');
  }
  final lexeme = matches.single.group(1)!;
  if (lexeme == 'null') {
    if (decodedValue != null) {
      throw const FormatException('Assessment score token mismatch.');
    }
    return null;
  }
  if (decodedValue is! num ||
      (decodedValue is double && !decodedValue.isFinite)) {
    throw const FormatException('Invalid assessment score type.');
  }

  final exact = ExactAssessmentDecimal.parseJsonLexeme(lexeme);
  final decodedExact = ExactAssessmentDecimal.parseJsonLexeme(
    decodedValue.toString(),
  );
  if (exact != decodedExact) {
    throw const FormatException('Assessment score lost JSON precision.');
  }
  return exact;
}

final RegExp _scoreToken = RegExp(
  r'"acceptable_score_difference"\s*:\s*(null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)\s*(?=[,}])',
);

T? _readNullableMode<T>(
  Map<String, Object?> map,
  String key,
  T Function(String value) parse,
) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Invalid mode type: $key.');
  }
  return parse(value);
}

int _strictInteger(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('Invalid integer field: $key.');
  }
  return value;
}
