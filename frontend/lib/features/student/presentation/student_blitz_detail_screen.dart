import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/student_blitz_answer_editor_controller.dart';
import '../application/student_blitz_attempt_start_controller.dart';
import '../application/student_blitz_attempt_start_state.dart';
import '../application/student_blitz_detail_controller.dart';
import '../application/student_blitz_detail_state.dart';
import '../application/student_blitz_execution_controller.dart';
import '../application/student_blitz_execution_operation_gate.dart';
import '../application/student_blitz_execution_state.dart';
import '../application/student_blitz_file_answer_controller.dart';
import '../application/student_blitz_submission_transfer_controller.dart';
import '../application/student_blitz_submit_controller.dart';
import '../application/student_blitz_submit_state.dart';
import '../application/student_file_answer_state.dart';
import '../application/student_submission_transfer_state.dart';
import '../domain/student_attempt_answer.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_execution_target.dart';
import '../domain/student_blitz_route_target.dart';
import '../domain/student_question.dart';
import 'student_attempt_answer_read_view.dart';
import 'student_blitz_attempt_shell.dart';
import 'student_blitz_countdown.dart';
import 'student_blitz_finalization_summary.dart';
import 'student_blitz_formatters.dart';
import 'student_file_answer_editor.dart';
import 'student_question_read_view.dart';

/// Pre-Start Blitz detail and, after an explicit successful Start/Resume in
/// this route session, the execution shell and then its finalization summary
/// on the same route.
class StudentBlitzDetailScreen extends ConsumerStatefulWidget {
  const StudentBlitzDetailScreen({required this.target, super.key});

  final StudentBlitzRouteTarget target;

  @override
  ConsumerState<StudentBlitzDetailScreen> createState() =>
      _StudentBlitzDetailScreenState();
}

class _StudentBlitzDetailScreenState
    extends ConsumerState<StudentBlitzDetailScreen> {
  /// The pre-Start class countdown that reached zero locally. Its
  /// reconciliation read moves detail out of `data`, which removes Start
  /// until a newer server snapshot arrives.
  StudentBlitzCountdownAnchor? _expiredPreStartAnchor;
  bool _leaving = false;

  StudentBlitzRouteTarget get _target => widget.target;

  @override
  Widget build(BuildContext context) {
    final detailProvider = studentBlitzDetailControllerProvider(_target);
    final startProvider = studentBlitzAttemptStartControllerProvider(_target);
    final detail = ref.watch(detailProvider);
    final start = ref.watch(startProvider);
    final execution = ref.watch(
      studentBlitzExecutionControllerProvider(_target),
    );
    ref.listen(startProvider, (_, next) {
      if (next.feedback == null) {
        return;
      }
      final feedback = ref.read(startProvider.notifier).consumeFeedback();
      if (feedback != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(studentBlitzStartFeedbackMessage(feedback))),
        );
      }
    });
    final timezone =
        ref.watch(authSessionControllerProvider).user?.institution?.timezone ??
        '';
    final attempt = execution.attempt;
    final executionTarget = attempt == null
        ? null
        : StudentBlitzExecutionTarget(
            routeTarget: _target,
            attemptId: attempt.id,
          );
    final executing =
        execution.isExecuting && execution.countdownAnchor != null;
    final guardsLeave = executing;

    return PopScope(
      canPop: !guardsLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _leave(confirm: true);
        }
      },
      child: Scaffold(
        key: const Key('studentBlitzDetailScreen'),
        appBar: AppBar(
          title: const Text('Blitz'),
          leading: IconButton(
            key: const Key('studentBlitzBackButton'),
            tooltip: 'Back to Topic',
            onPressed: () => _leave(confirm: guardsLeave),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: executing
              ? StudentBlitzAttemptShell(
                  target: executionTarget!,
                  execution: execution,
                  institutionTimezone: timezone,
                  onLeave: () => _leave(confirm: true),
                )
              : execution.isTerminal
              ? _TerminalExecution(
                  target: executionTarget!,
                  execution: execution,
                  timezone: timezone,
                  onBack: () => _leave(confirm: false),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showsStartStatus(start, detail))
                      _StartStatus(
                        state: start,
                        onRetry: ref.read(startProvider.notifier).retry,
                      ),
                    Expanded(child: _detailBody(detail, start)),
                  ],
                ),
        ),
      ),
    );
  }

  bool _showsStartStatus(
    StudentBlitzAttemptStartState start,
    StudentBlitzDetailState detail,
  ) {
    final hasOwnView =
        detail.status == StudentBlitzDetailStatus.notActive ||
        detail.status == StudentBlitzDetailStatus.timeExpired ||
        detail.status == StudentBlitzDetailStatus.notFound;
    return switch (start.status) {
      StudentBlitzAttemptStartStatus.submitting ||
      StudentBlitzAttemptStartStatus.uncertain => true,
      StudentBlitzAttemptStartStatus.failure => !hasOwnView,
      // A handed-off Attempt is shown by the execution views instead.
      StudentBlitzAttemptStartStatus.idle ||
      StudentBlitzAttemptStartStatus.active ||
      StudentBlitzAttemptStartStatus.terminal => false,
    };
  }

  Widget _detailBody(
    StudentBlitzDetailState detail,
    StudentBlitzAttemptStartState start,
  ) {
    final controller = ref.read(
      studentBlitzDetailControllerProvider(_target).notifier,
    );
    return switch (detail.status) {
      StudentBlitzDetailStatus.initial ||
      StudentBlitzDetailStatus.loading => const Center(
        child: CircularProgressIndicator(
          key: Key('studentBlitzDetailLoading'),
          semanticsLabel: 'Loading Blitz',
        ),
      ),
      StudentBlitzDetailStatus.notFound => _BlitzUnavailable(
        key: const Key('studentBlitzUnavailable'),
        title: 'Blitz unavailable',
        message: 'This Blitz is no longer available.',
        onBack: () => _leave(confirm: false),
      ),
      StudentBlitzDetailStatus.notActive => _BlitzUnavailable(
        key: const Key('studentBlitzNotActive'),
        title: 'Blitz not active',
        message: 'This Blitz is no longer active.',
        onBack: () => _leave(confirm: false),
        onRefresh: controller.refresh,
      ),
      StudentBlitzDetailStatus.timeExpired => _BlitzUnavailable(
        key: const Key('studentBlitzTimeExpired'),
        title: 'Time expired',
        message: 'The Blitz time has expired.',
        onBack: () => _leave(confirm: false),
        onRefresh: controller.refresh,
      ),
      StudentBlitzDetailStatus.error => _BlitzUnavailable(
        key: const Key('studentBlitzDetailError'),
        title: 'Unable to load Blitz',
        message: studentBlitzDetailFailureMessage(detail.failure!),
        onBack: () => _leave(confirm: false),
        onRefresh: controller.retry,
        refreshLabel: 'Retry',
      ),
      StudentBlitzDetailStatus.data ||
      StudentBlitzDetailStatus.refreshing => _PreStartContent(
        blitz: detail.blitz!,
        refreshing: detail.status == StudentBlitzDetailStatus.refreshing,
        busy: !start.acceptsNewRequest,
        expiredPreStartAnchor: _expiredPreStartAnchor,
        onRefresh: controller.refresh,
        onClassTimeExpired: (anchor) {
          setState(() => _expiredPreStartAnchor = anchor);
          controller.reconcileAfterLocalExpiry();
        },
        action: detail.status == StudentBlitzDetailStatus.data
            ? _action(detail.blitz!, start)
            : null,
      ),
    };
  }

  Widget? _action(
    StudentBlitzDetail blitz,
    StudentBlitzAttemptStartState start,
  ) {
    if (!start.acceptsNewRequest) {
      return null;
    }
    return switch (studentBlitzExecutionAction(blitz.attempts)) {
      StudentBlitzExecutionAction.resume => FilledButton.icon(
        key: const Key('studentBlitzResumeButton'),
        // The Attempt already exists and Resume never resets its timer.
        onPressed: () => _start(StudentBlitzExecutionAction.resume),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Resume Blitz'),
      ),
      StudentBlitzExecutionAction.startReplacement => FilledButton.icon(
        key: const Key('studentBlitzStartAdditionalButton'),
        onPressed: () => _confirmReplacement(blitz),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start additional attempt'),
      ),
      StudentBlitzExecutionAction.startNormal => FilledButton.icon(
        key: const Key('studentBlitzStartButton'),
        onPressed: () => _confirmStart(blitz),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Blitz'),
      ),
      null => null,
    };
  }

  Future<void> _confirmStart(StudentBlitzDetail blitz) async {
    final synchronized =
        blitz.timing.mode == StudentBlitzTimerMode.synchronized;
    final confirmed = await _confirm(
      key: const Key('studentBlitzStartDialog'),
      title: 'Start Blitz?',
      body: synchronized
          ? 'This Blitz uses a shared class timer.\n'
                'You will receive only the time remaining on the server.\n'
                'Starting does not reset the class timer.'
          : 'Your full Blitz duration starts when the server starts your '
                'attempt.',
      confirmKey: const Key('studentBlitzStartConfirmButton'),
      confirmLabel: 'Start',
    );
    if (confirmed) {
      await _start(StudentBlitzExecutionAction.startNormal);
    }
  }

  Future<void> _confirmReplacement(StudentBlitzDetail blitz) async {
    final synchronized =
        blitz.timing.mode == StudentBlitzTimerMode.synchronized;
    final confirmed = await _confirm(
      key: const Key('studentBlitzStartAdditionalDialog'),
      title: 'Start additional Blitz attempt?',
      body:
          'Your original attempt remains in history.\n'
          'This approved additional attempt receives the full configured '
          'Blitz duration from the moment the server starts it.'
          '${synchronized ? '\nThe original class timer does not restart for other Students.' : ''}',
      confirmKey: const Key('studentBlitzStartAdditionalConfirmButton'),
      confirmLabel: 'Start additional attempt',
    );
    if (confirmed) {
      await _start(StudentBlitzExecutionAction.startReplacement);
    }
  }

  Future<void> _start(StudentBlitzExecutionAction action) async {
    if (!mounted) {
      return;
    }
    await ref
        .read(studentBlitzAttemptStartControllerProvider(_target).notifier)
        .start(action);
  }

  Future<bool> _confirm({
    required Key key,
    required String title,
    required String body,
    required Key confirmKey,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: key,
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: confirmKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  /// Leaving never cancels or pauses the server Attempt and sends nothing;
  /// it discards only this route session's local execution state.
  Future<void> _leave({required bool confirm}) async {
    if (_leaving) return;
    final execution = ref.read(
      studentBlitzExecutionControllerProvider(_target),
    );
    final attempt = execution.attempt;
    final executionTarget = execution.isExecuting && attempt != null
        ? StudentBlitzExecutionTarget(
            routeTarget: _target,
            attemptId: attempt.id,
          )
        : null;
    if (confirm && executionTarget != null) {
      _leaving = true;
      final leave = await _confirmLeave(executionTarget, execution);
      _leaving = false;
      // A Submit that began meanwhile can never be abandoned by Leave.
      if (!leave ||
          !mounted ||
          ref.read(
                studentBlitzExecutionOperationGateProvider(executionTarget),
              ) ==
              StudentBlitzExecutionOperation.submitting) {
        return;
      }
    }
    if (!mounted) return;
    if (executionTarget != null) {
      ref
          .read(studentBlitzSubmitControllerProvider(executionTarget).notifier)
          .clearLocalState();
      ref
          .read(
            studentBlitzAnswerEditorControllerProvider(
              executionTarget,
            ).notifier,
          )
          .clearLocalState();
      ref
          .read(
            studentBlitzFileAnswerControllerProvider(executionTarget).notifier,
          )
          .clearLocalState();
    }
    ref
        .read(studentBlitzExecutionControllerProvider(_target).notifier)
        .clearLocalState();
    context.go(AppRoutePaths.studentTopicDetailLocation(_target.topicId));
  }

  Future<bool> _confirmLeave(
    StudentBlitzExecutionTarget target,
    StudentBlitzExecutionState execution,
  ) async {
    final gate = ref.read(studentBlitzExecutionOperationGateProvider(target));
    final submit = ref.read(studentBlitzSubmitControllerProvider(target));
    final editor = ref.read(studentBlitzAnswerEditorControllerProvider(target));
    final files = ref.read(studentBlitzFileAnswerControllerProvider(target));
    final submitting =
        gate == StudentBlitzExecutionOperation.submitting ||
        submit.status == StudentBlitzSubmitStatus.submitting;
    final submitUncertain =
        gate == StudentBlitzExecutionOperation.submitUncertain ||
        submit.status == StudentBlitzSubmitStatus.uncertain ||
        submit.status == StudentBlitzSubmitStatus.checking;
    final unconfirmedWrite =
        editor.hasUncertainMutation ||
        files.hasUncertainUpload ||
        editor.activeQuestionId != null ||
        files.activeQuestionId != null;
    final reconciling =
        gate == StudentBlitzExecutionOperation.terminalReconciliation ||
        execution.status == StudentBlitzExecutionStatus.refreshing;
    const unconfirmedReturn =
        'When you return, the app will reload the current server state.\n'
        'If this attempt is still in progress, Resume will be available.\n'
        'If it was finalized while you were away, it may no longer be '
        'resumable.';
    final (key, title, content) = submitting
        ? (
            'studentBlitzSubmitInProgressDialog',
            'Submission is in progress.',
            'Wait until the result is known.',
          )
        : submitUncertain
        ? (
            'studentBlitzSubmitLeaveDialog',
            'Leave Blitz?',
            'The submission result is unconfirmed.\n'
                'Leaving will discard this local retry key.\n'
                '$unconfirmedReturn',
          )
        : unconfirmedWrite
        ? (
            'studentBlitzUnconfirmedLeaveDialog',
            'Leave Blitz?',
            'A save result is still unconfirmed.\n'
                'Leaving discards the local reconciliation state.\n'
                '$unconfirmedReturn',
          )
        : reconciling
        ? (
            'studentBlitzReconcilingLeaveDialog',
            'Leave Blitz?',
            'The current attempt is still being checked.\n'
                'Leaving discards the local reconciliation state.\n'
                '$unconfirmedReturn',
          )
        : editor.hasDirtyDrafts || files.hasPendingSelection
        ? (
            'studentBlitzUnsavedLeaveDialog',
            'Leave Blitz?',
            [
              if (editor.hasDirtyDrafts) 'You have unsaved answer changes.',
              if (files.hasPendingSelection)
                'The selected local file has not been uploaded.',
              'Leaving discards only the unsaved local changes.',
              'Your server timer continues.',
            ].join('\n'),
          )
        : (
            'studentBlitzLeaveDialog',
            'Leave Blitz?',
            'Your server timer will continue.\n'
                'You can resume later while the attempt remains active.',
          );
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key(key),
        title: Text(title),
        scrollable: true,
        content: Text(content),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          if (!submitting)
            FilledButton(
              key: const Key('studentBlitzLeaveConfirmButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
        ],
      ),
    );
    return leave == true;
  }
}

/// The live class countdown anchor for a synchronized normal path that has
/// not started; every other pre-Start shape has no effective countdown.
StudentBlitzCountdownAnchor? studentBlitzPreStartAnchor(
  StudentBlitzDetail blitz,
) {
  final deadline = blitz.timing.deadlineAt;
  final remaining = blitz.timing.remainingSeconds;
  if (blitz.timing.mode != StudentBlitzTimerMode.synchronized ||
      blitz.attempts.normalUsed != 0 ||
      deadline == null ||
      remaining == null) {
    return null;
  }
  return StudentBlitzCountdownAnchor(
    subjectId: blitz.id.toLowerCase(),
    deadlineAt: deadline,
    serverNow: blitz.timing.serverNow,
    remainingSeconds: remaining,
  );
}

class _StartStatus extends StatelessWidget {
  const _StartStatus({required this.state, required this.onRetry});

  final StudentBlitzAttemptStartState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final resume = state.originatingIntent == StudentBlitzAttemptIntent.resume;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.status == StudentBlitzAttemptStartStatus.submitting)
              Wrap(
                key: const Key('studentBlitzStartProgress'),
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: resume
                          ? 'Resuming Blitz, please wait'
                          : 'Starting Blitz, please wait',
                    ),
                  ),
                  Text(resume ? 'Resuming Blitz…' : 'Starting Blitz…'),
                ],
              ),
            if (state.status == StudentBlitzAttemptStartStatus.uncertain) ...[
              const Text(
                'We could not confirm the Blitz attempt state.\n'
                'Retry safely using the same request.',
                key: Key('studentBlitzStartUncertain'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('studentBlitzRetryStartButton'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
            if (state.status == StudentBlitzAttemptStartStatus.failure &&
                state.failure != null)
              Text(
                studentBlitzStartFailureMessage(state.failure!),
                key: const Key('studentBlitzStartFailure'),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// The finalized Attempt: its summary and read-only saved answers. Only the
/// Student's current submitted file stays transferable.
class _TerminalExecution extends ConsumerWidget {
  const _TerminalExecution({
    required this.target,
    required this.execution,
    required this.timezone,
    required this.onBack,
  });

  final StudentBlitzExecutionTarget target;
  final StudentBlitzExecutionState execution;
  final String timezone;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempt = execution.attempt!;
    final fileState = ref.watch(
      studentBlitzFileAnswerControllerProvider(target),
    );
    final transferProvider = studentBlitzSubmissionTransferControllerProvider(
      target,
    );
    final transferState = ref.watch(transferProvider);
    final transferController = ref.read(transferProvider.notifier);
    final answers = <String, StudentAttemptAnswerState>{
      for (final answer in attempt.answers)
        answer.questionId.toLowerCase(): answer,
    };
    return SingleChildScrollView(
      key: const Key('studentBlitzTerminalView'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudentBlitzFinalizationSummary(
                attempt: attempt,
                timezone: timezone,
                confirmedBySubmit: execution.confirmedBySubmit,
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Questions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              for (final question in attempt.questions) ...[
                if (question.type == StudentQuestionType.fileBased &&
                    fileState.questions[question.id.toLowerCase()] != null)
                  _terminalFile(
                    fileState.questions[question.id.toLowerCase()]!,
                    transferState: transferState,
                    transferController: transferController,
                  )
                else ...[
                  StudentQuestionReadView(question: question),
                  StudentAttemptAnswerReadView(
                    question: question,
                    answer: answers[question.id.toLowerCase()],
                  ),
                ],
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('studentBlitzTerminalBackButton'),
                  onPressed: onBack,
                  child: const Text('Back to Topic'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _terminalFile(
    StudentFileQuestionAnswerState file, {
    required StudentSubmissionTransferState transferState,
    required StudentBlitzSubmissionTransferController transferController,
  }) {
    final question = file.question;
    final serverFile = file.serverFile;
    return StudentFileAnswerEditor(
      key: ValueKey(('blitzTerminalFile', target, question.id)),
      state: file,
      isTerminal: true,
      canChoose: false,
      canUpload: false,
      canDiscard: false,
      isReconciling: false,
      canTransfer:
          serverFile != null &&
          transferController.canTransfer(question.id, serverFile.id),
      transferState: transferState,
      onChoose: () async {},
      onUpload: () {},
      onDiscard: () {},
      onReload: () {},
      onOpen: () => transferController.open(question.id, serverFile!.id),
      onSaveAs: () => transferController.saveAs(question.id, serverFile!.id),
    );
  }
}

class _PreStartContent extends StatelessWidget {
  const _PreStartContent({
    required this.blitz,
    required this.refreshing,
    required this.busy,
    required this.expiredPreStartAnchor,
    required this.onRefresh,
    required this.onClassTimeExpired,
    required this.action,
  });

  final StudentBlitzDetail blitz;
  final bool refreshing;
  final bool busy;
  final StudentBlitzCountdownAnchor? expiredPreStartAnchor;
  final VoidCallback onRefresh;
  final ValueChanged<StudentBlitzCountdownAnchor> onClassTimeExpired;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final attempts = blitz.attempts;
    final duration = formatStudentBlitzDuration(blitz.durationSeconds);
    final classAnchor = studentBlitzPreStartAnchor(blitz);
    return SingleChildScrollView(
      key: const Key('studentBlitzDetailScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refreshing) ...[
                const LinearProgressIndicator(
                  key: Key('studentBlitzDetailRefreshing'),
                  semanticsLabel: 'Refreshing Blitz',
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          blitz.title,
                          key: const Key('studentBlitzDetailTitle'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Topic: ${blitz.topic.title}'),
                      const SizedBox(height: 12),
                      _EffectiveTiming(
                        blitz: blitz,
                        classAnchor: classAnchor,
                        classTimeExpired:
                            classAnchor != null &&
                            classAnchor == expiredPreStartAnchor,
                        duration: duration,
                        onClassTimeExpired: onClassTimeExpired,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('studentBlitzRefreshButton'),
                            onPressed: refreshing || busy ? null : onRefresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                          ?action,
                        ],
                      ),
                      if (attempts.isFinished) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'You have already finished this Blitz.',
                          key: Key('studentBlitzFinished'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _InformationCard(
                title: 'Blitz information',
                rows: [
                  ('Topic', blitz.topic.title),
                  if (blitz.description case final description?)
                    ('Description', description),
                  ('Student instructions', blitz.studentInstructions),
                  ('Duration', duration),
                  (
                    'Total possible points',
                    formatStudentBlitzPoints(blitz.totalPossiblePoints),
                  ),
                  ('Timer', studentBlitzTimerModeLabel(blitz.timing.mode)),
                ],
              ),
              const SizedBox(height: 12),
              _InformationCard(
                title: 'Attempt information',
                rows: [
                  ('Normal attempt', studentBlitzNormalAttemptLabel(attempts)),
                  (
                    'Additional attempt',
                    studentBlitzAdditionalAttemptLabel(attempts),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectiveTiming extends StatelessWidget {
  const _EffectiveTiming({
    required this.blitz,
    required this.classAnchor,
    required this.classTimeExpired,
    required this.duration,
    required this.onClassTimeExpired,
  });

  final StudentBlitzDetail blitz;
  final StudentBlitzCountdownAnchor? classAnchor;
  final bool classTimeExpired;
  final String duration;
  final ValueChanged<StudentBlitzCountdownAnchor> onClassTimeExpired;

  @override
  Widget build(BuildContext context) {
    final attempts = blitz.attempts;
    final anchor = classAnchor;
    if (attempts.replacementAttemptAvailable) {
      return Text(
        'Approved additional attempt available.\n'
        'Your full $duration starts when the server starts it.',
        key: const Key('studentBlitzReplacementTiming'),
      );
    }
    if (anchor != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudentBlitzCountdown(
            anchor: anchor,
            label: 'Class time remaining',
            onExpired: onClassTimeExpired,
          ),
          const SizedBox(height: 4),
          Text(
            classTimeExpired
                ? 'Checking current Blitz time…'
                : 'Starting does not reset this timer.',
            key: const Key('studentBlitzClassTimingNote'),
          ),
        ],
      );
    }
    if (attempts.normalUsed == 0) {
      return Text(
        'Your full $duration starts when the server starts your attempt.',
        key: const Key('studentBlitzIndividualTiming'),
      );
    }
    final remaining = blitz.timing.remainingSeconds;
    if (attempts.inProgressAttemptId != null && remaining != null) {
      return Text(
        'Attempt time remaining at last refresh: '
        '${formatStudentBlitzDuration(remaining)}',
        key: const Key('studentBlitzInProgressTiming'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in rows) ...[
              Text(row.$1, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              SelectableText(row.$2),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _BlitzUnavailable extends StatelessWidget {
  const _BlitzUnavailable({
    required this.title,
    required this.message,
    required this.onBack,
    this.onRefresh,
    this.refreshLabel = 'Refresh',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final String refreshLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  key: const Key('studentBlitzUnavailableBackButton'),
                  onPressed: onBack,
                  child: const Text('Back to Topic'),
                ),
                if (onRefresh case final refresh?)
                  FilledButton.icon(
                    key: const Key('studentBlitzUnavailableRefreshButton'),
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(refreshLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
