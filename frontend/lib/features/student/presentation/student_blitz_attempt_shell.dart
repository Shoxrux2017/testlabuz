import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/student_blitz_answer_editor_controller.dart';
import '../application/student_blitz_execution_controller.dart';
import '../application/student_blitz_execution_operation_gate.dart';
import '../application/student_blitz_execution_state.dart';
import '../application/student_blitz_file_answer_controller.dart';
import '../application/student_blitz_submission_transfer_controller.dart';
import '../domain/student_blitz_execution_target.dart';
import 'student_blitz_countdown.dart';
import 'student_blitz_formatters.dart';
import 'student_blitz_submit_controls.dart';
import 'student_file_answer_editor.dart';
import 'student_question_answer_editor.dart';
import 'student_topic_formatters.dart';

/// Timed execution of the in-progress Attempt owned by the execution
/// controller: the shared answer and file editors, then an explicit Submit.
/// Every write is decided by the server; the countdown only gates the UI.
class StudentBlitzAttemptShell extends ConsumerWidget {
  const StudentBlitzAttemptShell({
    required this.target,
    required this.execution,
    required this.institutionTimezone,
    required this.onLeave,
    super.key,
  });

  final StudentBlitzExecutionTarget target;
  final StudentBlitzExecutionState execution;
  final String institutionTimezone;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempt = execution.attempt!;
    final theme = Theme.of(context);
    final executionController = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget).notifier,
    );
    final editorProvider = studentBlitzAnswerEditorControllerProvider(target);
    final editorState = ref.watch(editorProvider);
    final editorController = ref.read(editorProvider.notifier);
    final fileProvider = studentBlitzFileAnswerControllerProvider(target);
    final fileState = ref.watch(fileProvider);
    final fileController = ref.read(fileProvider.notifier);
    final transferProvider = studentBlitzSubmissionTransferControllerProvider(
      target,
    );
    final transferState = ref.watch(transferProvider);
    final transferController = ref.read(transferProvider.notifier);
    final gateIdle =
        ref.watch(studentBlitzExecutionOperationGateProvider(target)) ==
        StudentBlitzExecutionOperation.idle;
    String instant(DateTime value) =>
        formatStudentInstitutionInstant(value, institutionTimezone) ??
        'Institution timezone unavailable';
    const recoveryLabel = 'Check current attempt';

    return SingleChildScrollView(
      key: const Key('studentBlitzAttemptShell'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StudentBlitzCountdown(
                          anchor: execution.countdownAnchor!,
                          label: 'Time remaining',
                          onExpired: executionController.markLocalTimeExpired,
                        ),
                        if (execution.localTimeExpired ||
                            execution.status !=
                                StudentBlitzExecutionStatus.active) ...[
                          const SizedBox(height: 8),
                          _ExecutionReconciliation(
                            execution: execution,
                            onCheck: executionController.refreshCurrentAttempt,
                          ),
                        ],
                        if (execution.localTimeExpired &&
                            (editorState.hasDirtyDrafts ||
                                fileState.hasPendingSelection)) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Time expired before these local changes were '
                            'confirmed.\n'
                            'Only answers saved by the server before the '
                            'deadline can be included.',
                            key: Key('studentBlitzUnconfirmedAtZero'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            execution.blitzTitle ?? 'Blitz',
                            key: const Key('studentBlitzShellTitle'),
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          studentBlitzAttemptLabel(attempt.attemptNumber),
                          key: const Key('studentBlitzAttemptNumber'),
                          style: theme.textTheme.titleMedium,
                        ),
                        if (attempt.attemptNumber == 2)
                          const Text(
                            'This is the approved additional attempt.',
                          ),
                        const SizedBox(height: 8),
                        Text(studentBlitzTimerModeLabel(attempt.timing.mode)),
                        Text('Started: ${instant(attempt.startedAt)}'),
                        Text('Deadline: ${instant(attempt.deadlineAt)}'),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            key: const Key('studentBlitzLeaveButton'),
                            onPressed: onLeave,
                            icon: const Icon(Icons.logout),
                            label: const Text('Leave Blitz'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text('Questions', style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: 12),
                if (attempt.questions.isEmpty)
                  const Text('No Questions are available.'),
                for (final question in attempt.questions) ...[
                  if (fileState.questions[question.id.toLowerCase()]
                      case final file?)
                    StudentFileAnswerEditor(
                      key: ValueKey(('blitzFile', target, question.id)),
                      state: file,
                      isTerminal: false,
                      canChoose: gateIdle && fileState.canChoose(question.id),
                      canUpload: gateIdle && fileState.canUpload(question.id),
                      canDiscard:
                          gateIdle &&
                          fileState.isAuthoritative &&
                          fileState.canDiscard(question.id),
                      isReconciling: fileState.isReconciling || !gateIdle,
                      canTransfer:
                          gateIdle &&
                          file.serverFile != null &&
                          transferController.canTransfer(
                            question.id,
                            file.serverFile!.id,
                          ),
                      transferState: transferState,
                      recoveryLabel: recoveryLabel,
                      onChoose: () => fileController.chooseFile(question.id),
                      onUpload: () => fileController.uploadAnswer(question.id),
                      onDiscard: () =>
                          fileController.discardSelectedFile(question.id),
                      onReload: fileController.checkCurrentAttempt,
                      onOpen: () => transferController.open(
                        question.id,
                        file.serverFile!.id,
                      ),
                      onSaveAs: () => transferController.saveAs(
                        question.id,
                        file.serverFile!.id,
                      ),
                    )
                  else if (editorState.questions[question.id.toLowerCase()]
                      case final entry?)
                    StudentQuestionAnswerEditor(
                      key: ValueKey(('blitzAnswer', target, question.id)),
                      state: entry,
                      canEdit: gateIdle && editorState.canEdit(question.id),
                      canSave: gateIdle && editorState.canSave(question.id),
                      isReconciling: editorState.isReconciling || !gateIdle,
                      timezone: institutionTimezone,
                      recoveryLabel: recoveryLabel,
                      onChanged: (draft) =>
                          editorController.updateDraft(question.id, draft),
                      onSave: () => editorController.saveAnswer(question.id),
                      onDiscard: () =>
                          editorController.discardChanges(question.id),
                      onClear: () => editorController.clearAnswer(question.id),
                      onReload: editorController.checkCurrentAttempt,
                    ),
                  const SizedBox(height: 12),
                ],
                StudentBlitzSubmitControls(
                  key: ValueKey(('blitzSubmit', target)),
                  target: target,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExecutionReconciliation extends StatelessWidget {
  const _ExecutionReconciliation({
    required this.execution,
    required this.onCheck,
  });

  final StudentBlitzExecutionState execution;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    if (execution.status == StudentBlitzExecutionStatus.refreshing) {
      return Semantics(
        liveRegion: true,
        child: Text(
          execution.localTimeExpired
              ? 'Checking current Blitz time…'
              : 'Checking the current attempt…',
          key: const Key('studentBlitzCheckingAttempt'),
        ),
      );
    }
    // The old snapshot is never restarted; only the server can grant time.
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            execution.localTimeExpired
                ? 'Time may have expired. Reconnect and refresh to confirm '
                      'the current Blitz state.'
                : 'The current attempt could not be confirmed. '
                      'Answers are read-only until it is checked again.',
            key: const Key('studentBlitzAttemptUnconfirmed'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('studentBlitzCheckAttemptButton'),
            onPressed: onCheck,
            icon: const Icon(Icons.refresh),
            label: const Text('Check current attempt'),
          ),
        ],
      ),
    );
  }
}
