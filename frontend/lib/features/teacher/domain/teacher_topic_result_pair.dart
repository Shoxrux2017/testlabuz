class TeacherTopicResultPair {
  const TeacherTopicResultPair({
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

  final String id;
  final String topicId;
  final String homeworkAssessmentId;
  final String? blitzAssessmentId;
  final DateTime? cohortSnapshottedAt;
  final DateTime? lockedAt;
  final DateTime designatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TeacherTopicResultPairMutationOutcomeUnknownException
    implements Exception {
  const TeacherTopicResultPairMutationOutcomeUnknownException();
}
