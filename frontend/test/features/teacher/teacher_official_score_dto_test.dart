import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_official_score_dto.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_official_score.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_submission.dart';

import 'teacher_submission_test_support.dart';

TeacherOfficialScore _parse(Map<String, Object?> json) =>
    TeacherOfficialScoreDto.fromJson(json).toDomain();

void main() {
  group('Teacher official score DTO', () {
    test('parses a ready Homework score', () {
      final score = _parse(officialScoreJson());

      expect(score.assessmentId, officialAssessmentId);
      expect(score.assessmentType, TeacherSubmissionTaskType.homework);
      expect(score.studentId, officialStudentId);
      expect(score.status, TeacherOfficialScoreStatus.ready);
      expect(score.officialAttemptId, submissionId);
      expect(score.attemptNumber, 2);
      expect(score.normalizedScore, 87.25);
      expect(
        score.selectionPolicy,
        TeacherOfficialScoreSelectionPolicy.highestValidCompleted,
      );
      expect(score.selectedAt, DateTime.utc(2026, 9, 30, 11));
    });

    test('parses ready Blitz scores, normal and replacement', () {
      final normal = _parse(
        officialScoreJson(
          type: 'blitz',
          attemptNumber: 1,
          policy: 'valid_normal_blitz',
          normalized: 100,
        ),
      );
      final replacement = _parse(
        officialScoreJson(
          type: 'blitz',
          attemptNumber: 2,
          policy: 'approved_blitz_exception_replacement',
          normalized: 0,
        ),
      );

      expect(
        normal.selectionPolicy,
        TeacherOfficialScoreSelectionPolicy.validNormalBlitz,
      );
      expect(normal.normalizedScore, 100);
      expect(
        replacement.selectionPolicy,
        TeacherOfficialScoreSelectionPolicy.approvedBlitzExceptionReplacement,
      );
      expect(replacement.attemptNumber, 2);
    });

    test('parses every status that is not ready with null fields', () {
      for (final (status, type) in [
        ('not_applicable', 'homework'),
        ('waiting_for_replacement', 'blitz'),
        ('automatic_checking_pending', 'homework'),
        ('waiting_for_teacher_review', 'blitz'),
        ('no_completed_attempt', 'homework'),
      ]) {
        final score = _parse(officialScoreJson(status: status, type: type));

        expect(score.status.value, status);
        expect(score.officialAttemptId, isNull, reason: status);
        expect(score.attemptNumber, isNull, reason: status);
        expect(score.normalizedScore, isNull, reason: status);
        expect(score.selectionPolicy, isNull, reason: status);
        expect(score.selectedAt, isNull, reason: status);
      }
    });

    test('rejects a missing or an extra key', () {
      for (final key in officialScoreJson().keys) {
        final json = officialScoreJson()..remove(key);
        expect(() => _parse(json), throwsFormatException, reason: key);
      }
      expect(
        () => _parse(officialScoreJson()..['extra'] = null),
        throwsFormatException,
      );
    });

    test('rejects every contradiction', () {
      final cases = <String, Map<String, Object?>>{
        'unknown status': officialScoreJson()..['status'] = 'pending',
        'unknown type': officialScoreJson()..['assessment_type'] = 'quiz',
        'unknown policy': officialScoreJson()
          ..['selection_policy_code'] = 'latest',
        'ready without attempt': officialScoreJson()
          ..['official_attempt_id'] = null,
        'ready without number': officialScoreJson()..['attempt_number'] = null,
        'ready without score': officialScoreJson()..['normalized_score'] = null,
        'ready without policy': officialScoreJson()
          ..['selection_policy_code'] = null,
        'ready without time': officialScoreJson()..['selected_at'] = null,
        'not ready with a score': officialScoreJson(
          status: 'no_completed_attempt',
        )..['normalized_score'] = 50,
        'not ready with an attempt': officialScoreJson(
          status: 'automatic_checking_pending',
        )..['official_attempt_id'] = submissionId,
        'not ready with a number': officialScoreJson(status: 'not_applicable')
          ..['attempt_number'] = 1,
        'not ready with a policy': officialScoreJson(
          status: 'waiting_for_teacher_review',
        )..['selection_policy_code'] = 'highest_valid_completed',
        'not ready with a time': officialScoreJson(
          status: 'no_completed_attempt',
        )..['selected_at'] = '2026-09-30T11:00:00Z',
        'Homework with a Blitz policy': officialScoreJson(
          policy: 'valid_normal_blitz',
        ),
        'Blitz with the Homework policy': officialScoreJson(type: 'blitz'),
        'normal Blitz on Attempt 2': officialScoreJson(
          type: 'blitz',
          policy: 'valid_normal_blitz',
        ),
        'replacement on Attempt 1': officialScoreJson(
          type: 'blitz',
          attemptNumber: 1,
          policy: 'approved_blitz_exception_replacement',
        ),
        'replacement waited for on Homework': officialScoreJson(
          status: 'waiting_for_replacement',
        ),
        'score above 100': officialScoreJson(normalized: 100.5),
        'negative score': officialScoreJson(normalized: -1),
        'Attempt 0': officialScoreJson(attemptNumber: 0),
        'non-canonical attempt id': officialScoreJson(
          officialAttemptId: 'attempt-1',
        ),
        'non-canonical assessment id': officialScoreJson()
          ..['assessment_id'] = 'homework-1',
        'local timestamp': officialScoreJson(
          selectedAt: '2026-09-30T11:00:00+05:00',
        ),
      };

      for (final MapEntry(key: name, value: json) in cases.entries) {
        expect(() => _parse(json), throwsFormatException, reason: name);
      }
    });
  });

  group('Teacher official score target', () {
    test('is built from a submission and compares without case', () {
      final target = TeacherOfficialScoreTarget.ofSubmission(
        teacherSubmission(),
      );

      expect(target.assessmentId, officialAssessmentId);
      expect(target.studentId, officialStudentId);
      expect(target.type, TeacherSubmissionTaskType.homework);
      expect(
        TeacherOfficialScoreTarget(
          assessmentId: officialAssessmentId.toUpperCase(),
          studentId: officialStudentId,
          type: TeacherSubmissionTaskType.homework,
        ),
        target,
      );
      expect(
        TeacherOfficialScoreTarget(
          assessmentId: officialAssessmentId,
          studentId: officialStudentId,
          type: TeacherSubmissionTaskType.blitz,
        ),
        isNot(target),
      );
    });

    test('lowercases ids that have letters', () {
      const assessmentId = 'ABCDEF00-0000-4000-8000-00000000000A';
      const studentId = 'FEDCBA00-0000-4000-8000-00000000000B';
      final upper = TeacherOfficialScoreTarget(
        assessmentId: assessmentId,
        studentId: studentId,
        type: TeacherSubmissionTaskType.blitz,
      );

      expect(upper.assessmentId, assessmentId.toLowerCase());
      expect(upper.studentId, studentId.toLowerCase());
      expect(
        upper,
        TeacherOfficialScoreTarget(
          assessmentId: assessmentId.toLowerCase(),
          studentId: studentId.toLowerCase(),
          type: TeacherSubmissionTaskType.blitz,
        ),
      );
    });

    test('rejects non-canonical ids', () {
      expect(
        () => TeacherOfficialScoreTarget(
          assessmentId: 'homework-1',
          studentId: officialStudentId,
          type: TeacherSubmissionTaskType.homework,
        ),
        throwsArgumentError,
      );
      expect(
        () => TeacherOfficialScoreTarget(
          assessmentId: officialAssessmentId,
          studentId: 'student-1',
          type: TeacherSubmissionTaskType.homework,
        ),
        throwsArgumentError,
      );
    });
  });
}
