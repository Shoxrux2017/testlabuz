import '../domain/teacher_submission_review.dart';

enum TeacherSubmissionReviewStatus { idle, saving, reconciling }

class TeacherSubmissionReviewState {
  const TeacherSubmissionReviewState({
    this.status = TeacherSubmissionReviewStatus.idle,
    this.drafts = const {},
    this.errors = const {},
    this.failureMessage,
    this.successFeedback,
  });

  final TeacherSubmissionReviewStatus status;

  /// Keyed by answer id.
  final Map<String, TeacherAnswerReviewDraft> drafts;

  /// Keyed by answer id.
  final Map<String, TeacherAnswerReviewErrors> errors;

  /// Kept until the next edit, discard or save.
  final String? failureMessage;

  /// Consumed by the screen.
  final String? successFeedback;

  bool get isBusy => status != TeacherSubmissionReviewStatus.idle;
}
