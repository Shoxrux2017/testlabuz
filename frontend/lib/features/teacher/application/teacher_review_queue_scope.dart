import '../domain/teacher_blitz.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_submission.dart';
import '../domain/teacher_submission_list_query.dart';
import '../domain/teacher_topic.dart';

/// Which submissions a review queue lists: every visible task, or one task.
class TeacherReviewQueueScope {
  const TeacherReviewQueueScope._({this.topicId, this.assessmentId, this.type});

  /// Throws [ArgumentError] unless both ids are canonical UUIDs.
  factory TeacherReviewQueueScope.task({
    required String topicId,
    required String assessmentId,
    required TeacherSubmissionTaskType type,
  }) {
    final validTask = switch (type) {
      TeacherSubmissionTaskType.homework => isCanonicalTeacherHomeworkId(
        assessmentId,
      ),
      TeacherSubmissionTaskType.blitz => isCanonicalTeacherBlitzId(
        assessmentId,
      ),
    };
    if (!isCanonicalTeacherTopicId(topicId) || !validTask) {
      throw ArgumentError('A task review queue needs canonical ids.');
    }
    return TeacherReviewQueueScope._(
      topicId: topicId.toLowerCase(),
      assessmentId: assessmentId.toLowerCase(),
      type: type,
    );
  }

  static const all = TeacherReviewQueueScope._();

  final String? topicId;
  final String? assessmentId;

  /// Null for the global queue.
  final TeacherSubmissionTaskType? type;

  TeacherSubmissionListQuery get initialQuery =>
      TeacherSubmissionListQuery.initial(
        topicId: topicId,
        assessmentId: assessmentId,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherReviewQueueScope &&
            other.topicId == topicId &&
            other.assessmentId == assessmentId &&
            other.type == type;
  }

  @override
  int get hashCode => Object.hash(topicId, assessmentId, type);
}
