import '../domain/teacher_topic_mutation.dart';

enum TeacherTopicLifecycleStatus {
  idle,
  submitting,
  reconciling,
  confirmedSuccess,
  definiteFailure,
  notAvailable,
  unconfirmedCurrentState,
  outcomeUnknown,
}

class TeacherTopicLifecycleState {
  const TeacherTopicLifecycleState({
    this.status = TeacherTopicLifecycleStatus.idle,
    this.action,
    this.feedback,
  });

  final TeacherTopicLifecycleStatus status;
  final TeacherTopicLifecycleAction? action;
  final String? feedback;

  bool get isBusy =>
      status == TeacherTopicLifecycleStatus.submitting ||
      status == TeacherTopicLifecycleStatus.reconciling;
  bool get canCheckCurrent =>
      status == TeacherTopicLifecycleStatus.outcomeUnknown && action != null;
}
