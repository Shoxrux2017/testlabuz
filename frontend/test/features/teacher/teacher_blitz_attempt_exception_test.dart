import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_blitz_attempt_exception_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_blitz_monitoring_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_attempt_exception.dart';

import 'teacher_blitz_json_fixtures.dart';
import 'teacher_blitz_monitoring_fixtures.dart';

TeacherBlitzAttemptException _parse(Object? json) =>
    TeacherBlitzAttemptExceptionDto.fromJson(
      json,
      expectedBlitzId: blitzJsonId,
      expectedStudentId: monitoringStudentA,
    ).toDomain();

void main() {
  group('request', () {
    test('sends the exact reason type and the trimmed reason', () {
      for (final (type, wire) in [
        (TeacherBlitzAttemptExceptionReasonType.technical, 'technical'),
        (TeacherBlitzAttemptExceptionReasonType.otherValid, 'other_valid'),
      ]) {
        final request = TeacherBlitzAttemptExceptionRequest(
          reasonType: type,
          reason: '  The device lost power.\n',
        );
        expect(request.reason, 'The device lost power.');
        expect(request.toJson(), {
          'reason_type': wire,
          'reason': 'The device lost power.',
        });
      }
    });

    test('the reason is required and counted in Unicode characters', () {
      expect(
        TeacherBlitzAttemptExceptionRequest.validateReason('   '),
        isNotNull,
      );
      expect(
        TeacherBlitzAttemptExceptionRequest.validateReason('x' * 4000),
        isNull,
      );
      expect(
        TeacherBlitzAttemptExceptionRequest.validateReason('x' * 4001),
        isNotNull,
      );
      // 4000 emoji are 8000 UTF-16 code units but 4000 characters.
      expect(
        TeacherBlitzAttemptExceptionRequest.validateReason('😀' * 4000),
        isNull,
      );
      expect(
        TeacherBlitzAttemptExceptionRequest.validateReason('😀' * 4001),
        isNotNull,
      );
      expect(
        () => TeacherBlitzAttemptExceptionRequest(
          reasonType: TeacherBlitzAttemptExceptionReasonType.technical,
          reason: ' ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('grant resource', () {
    test('parses the exact resource of an available unused grant', () {
      final exception = _parse(grantJson());
      expect(exception.id, monitoringExceptionId);
      expect(exception.blitzId, blitzJsonId);
      expect(exception.studentId, monitoringStudentA);
      expect(exception.invalidatedAttemptId, monitoringAttemptOne);
      expect(exception.replacementAttemptId, isNull);
      expect(
        exception.reasonType,
        TeacherBlitzAttemptExceptionReasonType.technical,
      );
      expect(exception.reason, 'The device lost power.');
      expect(exception.grantedAt, DateTime.utc(2026, 9, 18, 4, 6));
      expect(exception.replacementAttemptAvailable, isTrue);
      expect(
        exception.replacementState,
        TeacherBlitzAttemptExceptionReplacementState.available,
      );
    });

    test(
      'accepts a historical grant whose replacement can no longer start',
      () {
        final exception = _parse(grantJson(replacementAttemptAvailable: false));
        expect(exception.replacementAttemptId, isNull);
        expect(
          exception.replacementState,
          TeacherBlitzAttemptExceptionReplacementState.noLongerAvailable,
        );
      },
    );

    test('accepts a grant whose replacement already started', () {
      final exception = _parse(
        grantJson(
          replacementAttemptId: monitoringAttemptTwo,
          replacementAttemptAvailable: false,
        ),
      );
      expect(exception.replacementAttemptId, monitoringAttemptTwo);
      expect(
        exception.replacementState,
        TeacherBlitzAttemptExceptionReplacementState.started,
      );
    });

    final invalid = <String, Object?>{
      'a started replacement that is still available': grantJson(
        replacementAttemptId: monitoringAttemptTwo,
      ),
      'another Blitz': grantJson(
        blitzId: 'b0000000-0000-0000-0000-000000000009',
      ),
      'another Student': grantJson(studentId: monitoringStudentB),
      'another message': grantJson(message: 'Granted.'),
      'an unknown reason type': grantJson(reasonType: 'low_score'),
      'a blank reason': grantJson(reason: '  '),
      'an over-long reason': grantJson(reason: 'x' * 4001),
      'extra private data': {
        ...grantJson(),
        'data': {
          ...(grantJson()['data']! as Map<String, Object?>),
          'granted_by_user_id': monitoringStudentB,
        },
      },
      'a missing message': {'data': grantJson()['data']},
    };
    invalid.forEach((name, json) {
      test('rejects $name', () {
        expect(() => _parse(json), throwsFormatException);
      });
    });

    test('Active monitoring stays stricter than the grant resource', () {
      expect(
        () => TeacherBlitzMonitoringDto.fromJson(
          monitoringJson(
            students: [
              notStartedRowJson(
                monitoringStudentA,
                remainingSeconds: null,
                attemptException: monitoringExceptionJson(
                  replacementAttemptAvailable: false,
                ),
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
    });
  });
}
