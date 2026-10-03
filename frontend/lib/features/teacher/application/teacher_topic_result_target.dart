/// One cohort Student's result of one Topic; ids compare without case.
class TeacherTopicResultTarget {
  TeacherTopicResultTarget({required String topicId, required String studentId})
    : topicId = topicId.toLowerCase(),
      studentId = studentId.toLowerCase();

  final String topicId;
  final String studentId;

  @override
  bool operator ==(Object other) {
    return other is TeacherTopicResultTarget &&
        other.topicId == topicId &&
        other.studentId == studentId;
  }

  @override
  int get hashCode => Object.hash(topicId, studentId);
}
