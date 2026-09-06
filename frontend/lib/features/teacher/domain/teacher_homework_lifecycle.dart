import 'teacher_homework.dart';

enum TeacherHomeworkLifecycleAction {
  activate(
    segment: 'activate',
    expectedStatus: TeacherHomeworkStatus.active,
    successMessage: 'Homework activated successfully.',
  ),
  close(
    segment: 'close',
    expectedStatus: TeacherHomeworkStatus.closed,
    successMessage: 'Homework closed successfully.',
  ),
  archive(
    segment: 'archive',
    expectedStatus: TeacherHomeworkStatus.archived,
    successMessage: 'Homework archived successfully.',
  );

  const TeacherHomeworkLifecycleAction({
    required this.segment,
    required this.expectedStatus,
    required this.successMessage,
  });

  final String segment;
  final TeacherHomeworkStatus expectedStatus;
  final String successMessage;
}

List<TeacherHomeworkLifecycleAction> teacherHomeworkLifecycleActions(
  TeacherHomework homework,
) {
  return switch (homework.status) {
    TeacherHomeworkStatus.draft => const [
      TeacherHomeworkLifecycleAction.activate,
      TeacherHomeworkLifecycleAction.archive,
    ],
    TeacherHomeworkStatus.active => const [
      TeacherHomeworkLifecycleAction.close,
    ],
    TeacherHomeworkStatus.closed => const [
      TeacherHomeworkLifecycleAction.archive,
    ],
    TeacherHomeworkStatus.archived => const [],
  };
}
