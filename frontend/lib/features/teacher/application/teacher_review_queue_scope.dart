import '../domain/teacher_blitz.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_submission.dart';
import '../domain/teacher_submission_list_query.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_result.dart';
import 'teacher_review_queue_filter.dart';

/// Which submissions a review queue lists: every visible task, one task, or
/// one Student's submissions of one Topic.
class TeacherReviewQueueScope {
  const TeacherReviewQueueScope._({
    this.topicId,
    this.assessmentId,
    this.studentId,
    this.type,
  });

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

  /// One Student's submissions of one Topic in every status, opened from
  /// the Topic result; throws [ArgumentError] unless both ids are canonical.
  factory TeacherReviewQueueScope.student({
    required String topicId,
    required String studentId,
  }) {
    if (!isCanonicalTeacherTopicId(topicId) ||
        !isCanonicalTeacherStudentId(studentId)) {
      throw ArgumentError('A Student review queue needs canonical ids.');
    }
    return TeacherReviewQueueScope._(
      topicId: topicId.toLowerCase(),
      studentId: studentId.toLowerCase(),
    );
  }

  static const all = TeacherReviewQueueScope._();

  final String? topicId;
  final String? assessmentId;
  final String? studentId;

  /// Null for the global queue.
  final TeacherSubmissionTaskType? type;

  /// Whether this scope fixes [kind], so no row filter may change it. A
  /// Topic belongs to one group, so a fixed Topic fixes the group too.
  bool fixes(TeacherReviewQueueFilterKind kind) => switch (kind) {
    TeacherReviewQueueFilterKind.topic ||
    TeacherReviewQueueFilterKind.group => topicId != null,
    TeacherReviewQueueFilterKind.student => studentId != null,
  };

  TeacherSubmissionListQuery get initialQuery =>
      TeacherSubmissionListQuery.initial(
        topicId: topicId,
        assessmentId: assessmentId,
        studentId: studentId,
        checkingStatus: studentId == null
            ? TeacherSubmissionCheckingFilter.waitingForTeacherReview
            : null,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherReviewQueueScope &&
            other.topicId == topicId &&
            other.assessmentId == assessmentId &&
            other.studentId == studentId &&
            other.type == type;
  }

  @override
  int get hashCode => Object.hash(topicId, assessmentId, studentId, type);
}
