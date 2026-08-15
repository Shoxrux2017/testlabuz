import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_assessment_settings_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_assessment_settings.dart';

void main() {
  group('ExactAssessmentDecimal', () {
    test('accepts exact ASCII decimals and ignores insignificant zeros', () {
      expect(ExactAssessmentDecimal.parseUserInput('0').canonical, '0');
      expect(
        ExactAssessmentDecimal.parseUserInput('100.00000000').canonical,
        '100',
      );
      expect(
        ExactAssessmentDecimal.parseUserInput('12.34000000'),
        ExactAssessmentDecimal.parseJsonLexeme('1.234e1'),
      );
    });

    test('rejects whitespace, sign, comma, exponent, range and precision', () {
      for (final value in [
        ' 1',
        '+1',
        '-1',
        '1,5',
        '1e1',
        '01',
        '.5',
        '100.00000001',
        '1.123456789',
      ]) {
        expect(
          () => ExactAssessmentDecimal.parseUserInput(value),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('emits an actual JSON number with exact logical value', () {
      final exact = ExactAssessmentDecimal.parseUserInput('12.12500000');
      final json = InstitutionAssessmentSettingsUpdateRequest(
        acceptableScoreDifference: exact,
        blitzTimerStartMode: BlitzTimerStartMode.synchronized,
        studentResultReleaseMode: StudentResultReleaseMode.automatic,
        parentResultReleaseMode: ParentResultReleaseMode.withStudent,
        timezone: 'Asia/Tashkent',
        learningMaterialMaxMb: 25,
        studentSubmissionMaxMb: 15,
      ).toJson();

      expect(json['acceptable_score_difference'], isA<num>());
      expect(json['acceptable_score_difference'], 12.125);
    });

    test('accepts every required boundary and eight-place value', () {
      const canonicalValues = {
        '0': '0',
        '100': '100',
        '10.5': '10.5',
        '0.00000001': '0.00000001',
        '99.12345678': '99.12345678',
        '100.00000000': '100',
        '10.50000000': '10.5',
      };

      for (final entry in canonicalValues.entries) {
        expect(
          ExactAssessmentDecimal.parseUserInput(entry.key).canonical,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('parses equivalent integer, decimal, and exponent JSON numbers', () {
      expect(
        ExactAssessmentDecimal.parseJsonLexeme('10'),
        ExactAssessmentDecimal.parseJsonLexeme('10.00000000'),
      );
      expect(ExactAssessmentDecimal.parseJsonLexeme('1e2').canonical, '100');
      expect(
        ExactAssessmentDecimal.parseJsonLexeme('1e-8').canonical,
        '0.00000001',
      );
      for (final invalid in [
        '-0.1',
        '1e-9',
        '100.00000001',
        'NaN',
        'Infinity',
      ]) {
        expect(
          () => ExactAssessmentDecimal.parseJsonLexeme(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
    });
  });

  group('assessment settings validation', () {
    test('requires all policy values and enforces platform maxima', () {
      const draft = InstitutionAssessmentSettingsDraft(
        acceptableScoreDifference: '',
        blitzTimerStartMode: null,
        studentResultReleaseMode: null,
        parentResultReleaseMode: null,
        timezone: '+05:00',
        learningMaterialMaxMb: '26',
        studentSubmissionMaxMb: '16',
      );

      final result = draft.validate(
        platformLearningMaterialMaxMb: 25,
        platformStudentSubmissionMaxMb: 15,
      );

      expect(result.request, isNull);
      expect(
        result.fieldErrors.keys,
        containsAll(InstitutionAssessmentSettingsField.values),
      );
      expect(
        result.firstInvalidField,
        InstitutionAssessmentSettingsField.acceptableScoreDifference,
      );
    });

    test('validates exact timezone and strict upload integer grammar', () {
      for (final timezone in [
        '',
        ' Asia/Tashkent',
        'Asia/Tashkent ',
        '+05:00',
        '-03:30',
        List.filled(65, 'x').join(),
      ]) {
        final result = _validDraft(timezone: timezone).validate(
          platformLearningMaterialMaxMb: 25,
          platformStudentSubmissionMaxMb: 15,
        );
        expect(
          result.fieldErrors,
          contains(InstitutionAssessmentSettingsField.timezone),
          reason: timezone,
        );
      }

      for (final value in ['0', '26', '1.0', '+1', ' 1', '01', 'true']) {
        final result = _validDraft(learningLimit: value).validate(
          platformLearningMaterialMaxMb: 25,
          platformStudentSubmissionMaxMb: 15,
        );
        expect(
          result.fieldErrors,
          contains(InstitutionAssessmentSettingsField.learningMaterialMaxMb),
          reason: value,
        );
      }
      for (final value in ['0', '16', '1.0', '-1', ' 1', '01']) {
        final result = _validDraft(submissionLimit: value).validate(
          platformLearningMaterialMaxMb: 25,
          platformStudentSubmissionMaxMb: 15,
        );
        expect(
          result.fieldErrors,
          contains(InstitutionAssessmentSettingsField.studentSubmissionMaxMb),
          reason: value,
        );
      }

      expect(
        _validDraft(timezone: 'Europe/London')
            .validate(
              platformLearningMaterialMaxMb: 25,
              platformStudentSubmissionMaxMb: 15,
            )
            .isValid,
        isTrue,
      );
    });

    test('serializes exactly seven public fields and exact wire enums', () {
      final request =
          _validDraft(
                score: '99.12345678',
                timezone: 'Europe/London',
                learningLimit: '1',
                submissionLimit: '15',
                blitzMode: BlitzTimerStartMode.individual,
                studentMode: StudentResultReleaseMode.manualTeacher,
                parentMode: ParentResultReleaseMode.hidden,
              )
              .validate(
                platformLearningMaterialMaxMb: 25,
                platformStudentSubmissionMaxMb: 15,
              )
              .request!;

      expect(request.toJson(), {
        'acceptable_score_difference': isA<num>(),
        'blitz_timer_start_mode': 'individual',
        'student_result_release_mode': 'manual_teacher',
        'parent_result_release_mode': 'hidden',
        'timezone': 'Europe/London',
        'learning_material_max_mb': 1,
        'student_submission_max_mb': 15,
      });
      expect(
        request.toJson().keys,
        isNot(
          containsAll(<String>[
            'institution_id',
            'educational_policy_configured',
            'fixed_attempt_rules',
            'upload_limits',
            'updated_by_user_id',
            'updated_at',
            'categories',
          ]),
        ),
      );
    });

    test('preserves a partially configured resource without defaults', () {
      final settings = InstitutionAssessmentSettingsDto.fromRawJson(
        _resource(
          configured: false,
          score: '7.5',
          blitzMode: '"individual"',
          studentMode: 'null',
          parentMode: '"hidden"',
        ),
      ).settings;
      final draft = InstitutionAssessmentSettingsDraft.fromSettings(settings);

      expect(draft.acceptableScoreDifference, '7.5');
      expect(draft.blitzTimerStartMode, BlitzTimerStartMode.individual);
      expect(draft.studentResultReleaseMode, isNull);
      expect(draft.parentResultReleaseMode, ParentResultReleaseMode.hidden);
      expect(draft.timezone, 'Asia/Tashkent');
    });
  });

  group('InstitutionAssessmentSettingsDto', () {
    test('parses only the exact configured resource contract', () {
      final settings = InstitutionAssessmentSettingsDto.fromRawJson(
        _resource(score: '12.125'),
      ).settings;

      expect(settings.educationalPolicyConfigured, isTrue);
      expect(settings.acceptableScoreDifference?.canonical, '12.125');
      expect(settings.platformLearningMaterialMaxMb, 25);
      expect(settings.homeworkNormalAttempts, 3);
    });

    test('accepts the exact fully unconfigured policy shape', () {
      final settings = InstitutionAssessmentSettingsDto.fromRawJson(
        _resource(
          configured: false,
          score: 'null',
          blitzMode: 'null',
          studentMode: 'null',
          parentMode: 'null',
        ),
      ).settings;

      expect(settings.educationalPolicyConfigured, isFalse);
      expect(settings.acceptableScoreDifference, isNull);
    });

    test('fails closed for extra keys, wrong constants and partial policy', () {
      expect(
        () => InstitutionAssessmentSettingsDto.fromRawJson(
          _resource(score: '10').replaceFirst(
            '"educational_policy_configured":true,',
            '"educational_policy_configured":true,"extra":1,',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => InstitutionAssessmentSettingsDto.fromRawJson(
          _resource(score: '10').replaceFirst(
            '"homework_normal_attempts":3',
            '"homework_normal_attempts":4',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => InstitutionAssessmentSettingsDto.fromRawJson(
          _resource(score: 'null'),
        ),
        throwsFormatException,
      );
    });

    test('accepts object key order changes at every level', () {
      final resource = _resourceMap();
      final reordered = <String, Object?>{
        'fixed_attempt_rules': resource.remove('fixed_attempt_rules'),
        'timezone': resource.remove('timezone'),
        ...resource,
      };

      final settings = InstitutionAssessmentSettingsDto.fromRawJson(
        jsonEncode({'data': reordered}),
      ).settings;
      expect(settings.acceptableScoreDifference?.canonical, '12.5');
      expect(settings.platformStudentSubmissionMaxMb, 15);
    });

    test('rejects every missing or private top-level/resource key', () {
      expect(
        () => InstitutionAssessmentSettingsDto.fromRawJson(
          jsonEncode(<String, Object?>{}),
        ),
        throwsFormatException,
      );
      expect(
        () => InstitutionAssessmentSettingsDto.fromRawJson(
          jsonEncode({'data': _resourceMap(), 'message': 'ok'}),
        ),
        throwsFormatException,
      );

      for (final key in _resourceMap().keys) {
        final resource = _resourceMap()..remove(key);
        expect(
          () => InstitutionAssessmentSettingsDto.fromRawJson(
            jsonEncode({'data': resource}),
          ),
          throwsFormatException,
          reason: 'missing $key',
        );
      }
      for (final key in [
        'id',
        'institution_id',
        'updated_by_user_id',
        'updated_at',
        'categories',
      ]) {
        final resource = _resourceMap()..[key] = 'private';
        expect(
          () => InstitutionAssessmentSettingsDto.fromRawJson(
            jsonEncode({'data': resource}),
          ),
          throwsFormatException,
          reason: 'extra $key',
        );
      }
    });

    test('rejects every missing or extra nested key', () {
      for (final nestedKey in ['upload_limits', 'fixed_attempt_rules']) {
        final original = Map<String, Object?>.from(
          _resourceMap()[nestedKey]! as Map,
        );
        for (final key in original.keys) {
          final resource = _resourceMap();
          final nested = Map<String, Object?>.from(resource[nestedKey]! as Map)
            ..remove(key);
          resource[nestedKey] = nested;
          expect(
            () => InstitutionAssessmentSettingsDto.fromRawJson(
              jsonEncode({'data': resource}),
            ),
            throwsFormatException,
            reason: '$nestedKey missing $key',
          );
        }
        final resource = _resourceMap();
        resource[nestedKey] = Map<String, Object?>.from(
          resource[nestedKey]! as Map,
        )..['private'] = 1;
        expect(
          () => InstitutionAssessmentSettingsDto.fromRawJson(
            jsonEncode({'data': resource}),
          ),
          throwsFormatException,
          reason: '$nestedKey extra key',
        );
      }
    });

    test('rejects wrong DTO types and configured-flag contradictions', () {
      final invalidValues = <String, List<Object?>>{
        'educational_policy_configured': [1, 'true', null],
        'acceptable_score_difference': [
          '5',
          true,
          <Object?>[],
          <String, Object?>{},
        ],
        'blitz_timer_start_mode': [
          1,
          true,
          'SYNCHRONIZED',
          ' synchronized',
          'synchronized ',
        ],
        'student_result_release_mode': [1, true, 'Automatic', 'manual-teacher'],
        'parent_result_release_mode': [1, true, 'WITH_STUDENT', 'with student'],
        'timezone': [
          1,
          true,
          '',
          ' Asia/Tashkent',
          'Asia/Tashkent ',
          List.filled(65, 'x').join(),
        ],
        'upload_limits': [null, <Object?>[]],
        'fixed_attempt_rules': [null, <Object?>[]],
      };
      for (final entry in invalidValues.entries) {
        for (final invalid in entry.value) {
          final resource = _resourceMap()..[entry.key] = invalid;
          expect(
            () => InstitutionAssessmentSettingsDto.fromRawJson(
              jsonEncode({'data': resource}),
            ),
            throwsFormatException,
            reason: '${entry.key}: $invalid',
          );
        }
      }

      for (final fixture in [
        _resource(configured: false),
        _resource(configured: true, studentMode: 'null'),
      ]) {
        expect(
          () => InstitutionAssessmentSettingsDto.fromRawJson(fixture),
          throwsFormatException,
        );
      }
    });

    test('accepts all exact enum values and each nullable policy field', () {
      for (final blitz in ['synchronized', 'individual']) {
        expect(
          InstitutionAssessmentSettingsDto.fromRawJson(
            _resource(blitzMode: '"$blitz"'),
          ).settings.blitzTimerStartMode?.wireValue,
          blitz,
        );
      }
      for (final student in ['automatic', 'manual_teacher']) {
        expect(
          InstitutionAssessmentSettingsDto.fromRawJson(
            _resource(studentMode: '"$student"'),
          ).settings.studentResultReleaseMode?.wireValue,
          student,
        );
      }
      for (final parent in ['with_student', 'manual_teacher', 'hidden']) {
        expect(
          InstitutionAssessmentSettingsDto.fromRawJson(
            _resource(parentMode: '"$parent"'),
          ).settings.parentResultReleaseMode?.wireValue,
          parent,
        );
      }
      for (final fixture in [
        _resource(configured: false, score: 'null'),
        _resource(configured: false, blitzMode: 'null'),
        _resource(configured: false, studentMode: 'null'),
        _resource(configured: false, parentMode: 'null'),
      ]) {
        expect(
          InstitutionAssessmentSettingsDto.fromRawJson(
            fixture,
          ).settings.educationalPolicyConfigured,
          isFalse,
        );
      }
    });

    test(
      'enforces decimal lexemes, strict integer types, ranges, and constants',
      () {
        for (final score in [
          '0',
          '100',
          '10.5',
          '0.00000001',
          '99.12345678',
          '100.00000000',
          '1e2',
        ]) {
          expect(
            InstitutionAssessmentSettingsDto.fromRawJson(
              _resource(score: score),
            ).settings.acceptableScoreDifference,
            isNotNull,
            reason: score,
          );
        }
        for (final score in [
          '-1',
          '100.00000001',
          '0.000000001',
          '1e-9',
          'NaN',
          'Infinity',
          '"1"',
          'true',
        ]) {
          expect(
            () => InstitutionAssessmentSettingsDto.fromRawJson(
              _resource(score: score),
            ),
            throwsFormatException,
            reason: score,
          );
        }

        final integerCases = <String, List<Object>>{
          'learning_material_max_mb': [0, 26, 1.0, '1', true],
          'student_submission_max_mb': [0, 16, 1.0, '1', true],
          'platform_learning_material_max_mb': [24, 26, 25.0, '25', true],
          'platform_student_submission_max_mb': [14, 16, 15.0, '15', true],
          'homework_normal_attempts': [2, 4, 3.0, '3', true],
          'blitz_normal_attempts': [0, 2, 1.0, '1', true],
          'blitz_max_additional_exception_attempts': [0, 2, 1.0, '1', true],
        };
        for (final entry in integerCases.entries) {
          for (final invalid in entry.value) {
            final resource = _resourceMap();
            final parentKey =
                entry.key.contains('attempt') ||
                    entry.key == 'homework_normal_attempts'
                ? 'fixed_attempt_rules'
                : 'upload_limits';
            resource[parentKey] = Map<String, Object?>.from(
              resource[parentKey]! as Map,
            )..[entry.key] = invalid;
            expect(
              () => InstitutionAssessmentSettingsDto.fromRawJson(
                jsonEncode({'data': resource}),
              ),
              throwsFormatException,
              reason: '${entry.key}: $invalid',
            );
          }
        }
      },
    );
  });
}

InstitutionAssessmentSettingsDraft _validDraft({
  String score = '10',
  BlitzTimerStartMode blitzMode = BlitzTimerStartMode.synchronized,
  StudentResultReleaseMode studentMode = StudentResultReleaseMode.automatic,
  ParentResultReleaseMode parentMode = ParentResultReleaseMode.withStudent,
  String timezone = 'Asia/Tashkent',
  String learningLimit = '25',
  String submissionLimit = '15',
}) => InstitutionAssessmentSettingsDraft(
  acceptableScoreDifference: score,
  blitzTimerStartMode: blitzMode,
  studentResultReleaseMode: studentMode,
  parentResultReleaseMode: parentMode,
  timezone: timezone,
  learningMaterialMaxMb: learningLimit,
  studentSubmissionMaxMb: submissionLimit,
);

Map<String, Object?> _resourceMap() => {
  'educational_policy_configured': true,
  'acceptable_score_difference': 12.5,
  'blitz_timer_start_mode': 'synchronized',
  'student_result_release_mode': 'automatic',
  'parent_result_release_mode': 'with_student',
  'timezone': 'Asia/Tashkent',
  'upload_limits': <String, Object?>{
    'learning_material_max_mb': 25,
    'student_submission_max_mb': 15,
    'platform_learning_material_max_mb': 25,
    'platform_student_submission_max_mb': 15,
  },
  'fixed_attempt_rules': <String, Object?>{
    'homework_normal_attempts': 3,
    'blitz_normal_attempts': 1,
    'blitz_max_additional_exception_attempts': 1,
  },
};

String _resource({
  bool configured = true,
  String score = '12.5',
  String blitzMode = '"synchronized"',
  String studentMode = '"automatic"',
  String parentMode = '"with_student"',
}) =>
    '''{"data":{"educational_policy_configured":$configured,"acceptable_score_difference":$score,"blitz_timer_start_mode":$blitzMode,"student_result_release_mode":$studentMode,"parent_result_release_mode":$parentMode,"timezone":"Asia/Tashkent","upload_limits":{"learning_material_max_mb":25,"student_submission_max_mb":15,"platform_learning_material_max_mb":25,"platform_student_submission_max_mb":15},"fixed_attempt_rules":{"homework_normal_attempts":3,"blitz_normal_attempts":1,"blitz_max_additional_exception_attempts":1}}}''';
