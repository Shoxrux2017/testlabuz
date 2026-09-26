import 'teacher_blitz.dart';

/// Blitz lifecycle mutations; `reschedule` is only presentation wording for
/// [schedule].
enum TeacherBlitzLifecycleAction { schedule, activate, close, archive }

/// What the confirmed Topic result pair says about this Blitz.
enum TeacherBlitzOfficialKnowledge { unconfirmed, notOfficial, official }

/// Which POST of one logical activation is being sent.
enum TeacherBlitzActivationSendKind { initialSend, sameKeyRetry }

/// Desktop lifecycle actions for a confirmed current Blitz; a UX hint only.
List<TeacherBlitzLifecycleAction> teacherBlitzLifecycleActions(
  TeacherBlitz blitz, {
  required TeacherBlitzOfficialKnowledge official,
}) {
  return switch (blitz.status) {
    TeacherBlitzStatus.draft || TeacherBlitzStatus.scheduled => [
      TeacherBlitzLifecycleAction.schedule,
      TeacherBlitzLifecycleAction.activate,
      if (_canArchiveBeforeActivation(blitz, official))
        TeacherBlitzLifecycleAction.archive,
    ],
    TeacherBlitzStatus.active => const [TeacherBlitzLifecycleAction.close],
    TeacherBlitzStatus.closed => const [TeacherBlitzLifecycleAction.archive],
    TeacherBlitzStatus.archived => const [],
  };
}

// The server rejects archiving a preactivation official Blitz, so a
// whole-group Blitz is offered Archive only once it is proven practice-only.
bool _canArchiveBeforeActivation(
  TeacherBlitz blitz,
  TeacherBlitzOfficialKnowledge official,
) {
  return blitz.assignmentMode == TeacherBlitzAssignmentMode.selectedStudents ||
      official == TeacherBlitzOfficialKnowledge.notOfficial;
}

/// Whether a 200 activation response proves the requested activation.
///
/// A completed same-key replay returns the current lifecycle, which may have
/// moved on to Closed or Archived, but never back before activation.
bool isAcceptedTeacherBlitzActivation(
  TeacherBlitz blitz,
  TeacherBlitzActivationSendKind sendKind,
) {
  final hasActivationEvidence =
      blitz.activatedAt != null && blitz.timerStartModeSnapshot != null;
  return hasActivationEvidence &&
      switch (sendKind) {
        TeacherBlitzActivationSendKind.initialSend =>
          blitz.status == TeacherBlitzStatus.active,
        TeacherBlitzActivationSendKind.sameKeyRetry =>
          blitz.status == TeacherBlitzStatus.active ||
              blitz.status == TeacherBlitzStatus.closed ||
              blitz.status == TeacherBlitzStatus.archived,
      };
}
