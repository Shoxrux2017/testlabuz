import '../../domain/teacher_topic_result_pair.dart';
import 'teacher_dto_parse.dart';

class TeacherTopicResultPairDto {
  const TeacherTopicResultPairDto({
    required this.id,
    required this.topicId,
    required this.homeworkAssessmentId,
    required this.blitzAssessmentId,
    required this.cohortSnapshottedAt,
    required this.lockedAt,
    required this.designatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherTopicResultPairDto.fromJson(Object? json) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher Topic result pair resource',
      keys: _resultPairKeys,
    );
    final homeworkAssessmentId = readTeacherCanonicalUuid(
      map,
      'homework_assessment_id',
    );
    final blitzAssessmentId = _readNullableCanonicalUuid(
      map,
      'blitz_assessment_id',
    );
    if (blitzAssessmentId != null &&
        blitzAssessmentId.toLowerCase() == homeworkAssessmentId.toLowerCase()) {
      throw const FormatException(
        'Teacher Topic result pair assessments must be distinct.',
      );
    }

    final designatedAt = readTeacherRequiredUtcTimestamp(map, 'designated_at');
    final cohortSnapshottedAt = readTeacherNullableUtcTimestamp(
      map,
      'cohort_snapshotted_at',
    );
    final lockedAt = readTeacherNullableUtcTimestamp(map, 'locked_at');
    if (lockedAt != null && cohortSnapshottedAt == null) {
      throw const FormatException(
        'Teacher Topic result pair lock requires a cohort snapshot.',
      );
    }
    if (lockedAt != null && lockedAt.isBefore(cohortSnapshottedAt!)) {
      throw const FormatException(
        'Teacher Topic result pair lock cannot precede its cohort snapshot.',
      );
    }

    return TeacherTopicResultPairDto(
      id: readTeacherCanonicalUuid(map, 'id'),
      topicId: readTeacherCanonicalUuid(map, 'topic_id'),
      homeworkAssessmentId: homeworkAssessmentId,
      blitzAssessmentId: blitzAssessmentId,
      cohortSnapshottedAt: cohortSnapshottedAt,
      lockedAt: lockedAt,
      designatedAt: designatedAt,
      createdAt: readTeacherRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: readTeacherRequiredUtcTimestamp(map, 'updated_at'),
    );
  }

  final String id;
  final String topicId;
  final String homeworkAssessmentId;
  final String? blitzAssessmentId;
  final DateTime? cohortSnapshottedAt;
  final DateTime? lockedAt;
  final DateTime designatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeacherTopicResultPair toDomain() {
    return TeacherTopicResultPair(
      id: id,
      topicId: topicId,
      homeworkAssessmentId: homeworkAssessmentId,
      blitzAssessmentId: blitzAssessmentId,
      cohortSnapshottedAt: cohortSnapshottedAt,
      lockedAt: lockedAt,
      designatedAt: designatedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

String? _readNullableCanonicalUuid(Map<String, Object?> map, String key) {
  if (map[key] == null) {
    return null;
  }
  return readTeacherCanonicalUuid(map, key);
}

const _resultPairKeys = {
  'id',
  'topic_id',
  'homework_assessment_id',
  'blitz_assessment_id',
  'cohort_snapshotted_at',
  'locked_at',
  'designated_at',
  'created_at',
  'updated_at',
};
