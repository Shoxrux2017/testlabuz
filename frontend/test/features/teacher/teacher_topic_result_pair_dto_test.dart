import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_result_pair_dto.dart';
import 'package:testlabuz_client/features/teacher/data/dto/teacher_topic_result_pair_operation_dto.dart';

const _pairId = '40000000-0000-0000-0000-000000000001';
const _topicId = '10000000-0000-0000-0000-000000000001';
const _homeworkId = '20000000-0000-0000-0000-00000000000a';
const _blitzId = '30000000-0000-0000-0000-000000000001';

void main() {
  group('Teacher Topic result pair DTO', () {
    test('parses a draft partial pair', () {
      final pair = TeacherTopicResultPairDto.fromJson(_pairJson()).toDomain();

      expect(pair.id, _pairId);
      expect(pair.topicId, _topicId);
      expect(pair.homeworkAssessmentId, _homeworkId);
      expect(pair.blitzAssessmentId, isNull);
      expect(pair.cohortSnapshottedAt, isNull);
      expect(pair.lockedAt, isNull);
      expect(pair.designatedAt, DateTime.utc(2026, 9, 3, 10));
      expect(pair.createdAt, DateTime.utc(2026, 9, 3, 10));
      expect(pair.updatedAt, DateTime.utc(2026, 9, 3, 10));
    });

    test('parses cohort-snapshotted and staged locked pairs', () {
      final cohort = TeacherTopicResultPairDto.fromJson(
        _pairJson()
          ..['cohort_snapshotted_at'] = '2026-09-03T10:01:00Z'
          ..['updated_at'] = '2026-09-03T10:01:00Z',
      ).toDomain();
      final locked = TeacherTopicResultPairDto.fromJson(
        _pairJson()
          ..['cohort_snapshotted_at'] = '2026-09-03T10:01:00Z'
          ..['locked_at'] = '2026-09-03T10:02:00Z'
          ..['updated_at'] = '2026-09-03T10:02:00Z',
      ).toDomain();

      expect(cohort.cohortSnapshottedAt, DateTime.utc(2026, 9, 3, 10, 1));
      expect(cohort.lockedAt, isNull);
      expect(locked.lockedAt, DateTime.utc(2026, 9, 3, 10, 2));
      expect(locked.blitzAssessmentId, isNull);
    });

    test('accepts a forward-compatible non-null Blitz ID', () {
      final pair = TeacherTopicResultPairDto.fromJson(
        _pairJson()
          ..['blitz_assessment_id'] = _blitzId
          ..['cohort_snapshotted_at'] = '2026-09-03T10:01:00Z'
          ..['locked_at'] = '2026-09-03T10:02:00Z'
          ..['updated_at'] = '2026-09-03T10:02:00Z',
      ).toDomain();

      expect(pair.blitzAssessmentId, _blitzId);
    });

    test('rejects duplicate Homework and Blitz IDs case-insensitively', () {
      final json = _pairJson()
        ..['blitz_assessment_id'] = _homeworkId.toUpperCase();

      expect(
        () => TeacherTopicResultPairDto.fromJson(json),
        throwsFormatException,
      );
    });

    test('rejects a lock without a cohort snapshot', () {
      final json = _pairJson()..['locked_at'] = '2026-09-03T10:02:00Z';

      expect(
        () => TeacherTopicResultPairDto.fromJson(json),
        throwsFormatException,
      );
    });

    test('rejects a lock timestamp before its cohort snapshot', () {
      final lockBeforeCohort = _pairJson()
        ..['cohort_snapshotted_at'] = '2026-09-03T10:02:00Z'
        ..['locked_at'] = '2026-09-03T10:01:59Z';

      expect(
        () => TeacherTopicResultPairDto.fromJson(lockBeforeCohort),
        throwsFormatException,
      );
    });

    test('rejects malformed UUIDs and nullable Blitz UUIDs', () {
      for (final key in [
        'id',
        'topic_id',
        'homework_assessment_id',
        'blitz_assessment_id',
      ]) {
        final json = _pairJson()..[key] = 'not-a-uuid';
        expect(
          () => TeacherTopicResultPairDto.fromJson(json),
          throwsFormatException,
        );
      }
    });

    test('rejects missing and unknown resource keys', () {
      final missing = _pairJson()..remove('locked_at');
      final unknown = _pairJson()..['institution_id'] = _topicId;

      for (final json in [missing, unknown]) {
        expect(
          () => TeacherTopicResultPairDto.fromJson(json),
          throwsFormatException,
        );
      }
    });

    test('requires exact valid UTC Z timestamps', () {
      for (final key in [
        'cohort_snapshotted_at',
        'locked_at',
        'designated_at',
        'created_at',
        'updated_at',
      ]) {
        final json = _pairJson()
          ..['cohort_snapshotted_at'] = '2026-09-03T10:01:00Z'
          ..['locked_at'] = '2026-09-03T10:02:00Z'
          ..[key] = '2026-09-03T15:00:00+05:00';
        expect(
          () => TeacherTopicResultPairDto.fromJson(json),
          throwsFormatException,
        );
      }

      final impossible = _pairJson()..['updated_at'] = '2026-02-31T10:00:00Z';
      expect(
        () => TeacherTopicResultPairDto.fromJson(impossible),
        throwsFormatException,
      );
    });
  });

  group('Teacher Topic result pair envelopes', () {
    test('distinguishes confirmed data:null from a pair', () {
      expect(
        TeacherTopicResultPairReadDto.fromJson({'data': null}).pair,
        isNull,
      );
      expect(
        TeacherTopicResultPairReadDto.fromJson({'data': _pairJson()}).pair?.id,
        _pairId,
      );
    });

    test('requires exact read and mutation envelopes', () {
      final mutation = TeacherTopicResultPairMutationDto.fromJson({
        'data': _pairJson(),
        'message': TeacherTopicResultPairMutationDto.successMessage,
      });
      expect(mutation.pair.homeworkAssessmentId, _homeworkId);

      for (final json in <Object?>[
        <String, Object?>{},
        {'data': null, 'unknown': true},
        {'data': 'pair'},
      ]) {
        expect(
          () => TeacherTopicResultPairReadDto.fromJson(json),
          throwsFormatException,
        );
      }

      for (final json in <Object?>[
        {'data': _pairJson()},
        {'data': _pairJson(), 'message': 'Unexpected.'},
        {
          'data': _pairJson(),
          'message': TeacherTopicResultPairMutationDto.successMessage,
          'unknown': true,
        },
        {
          'data': null,
          'message': TeacherTopicResultPairMutationDto.successMessage,
        },
      ]) {
        expect(
          () => TeacherTopicResultPairMutationDto.fromJson(json),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, Object?> _pairJson() {
  return {
    'id': _pairId,
    'topic_id': _topicId,
    'homework_assessment_id': _homeworkId,
    'blitz_assessment_id': null,
    'cohort_snapshotted_at': null,
    'locked_at': null,
    'designated_at': '2026-09-03T10:00:00Z',
    'created_at': '2026-09-03T10:00:00Z',
    'updated_at': '2026-09-03T10:00:00Z',
  };
}
