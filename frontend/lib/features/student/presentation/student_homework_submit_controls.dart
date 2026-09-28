import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/student_attempt_answer_editor_controller.dart';
import '../application/student_homework_submit_controller.dart';
import '../application/student_homework_submit_readiness.dart';
import '../application/student_homework_submit_state.dart';
import '../domain/student_homework_attempt_route_target.dart';
import 'student_homework_formatters.dart';

class StudentHomeworkSubmitControls extends ConsumerStatefulWidget {
  const StudentHomeworkSubmitControls({
    required this.target,
    required this.attemptNumber,
    required this.isTerminal,
    super.key,
  });

  final StudentHomeworkAttemptRouteTarget target;
  final int attemptNumber;
  final bool isTerminal;

  @override
  ConsumerState<StudentHomeworkSubmitControls> createState() =>
      _StudentHomeworkSubmitControlsState();
}

class _StudentHomeworkSubmitControlsState
    extends ConsumerState<StudentHomeworkSubmitControls> {
  bool _confirming = false;
  bool _saving = false;
  bool _savingCancelled = false;
  bool _notSaved = false;

  /// Saves every pending answer first, then opens the confirmation.
  Future<void> _saveThenConfirm() async {
    if (_saving) return;
    final editor = ref.read(
      studentAttemptAnswerEditorControllerProvider(widget.target).notifier,
    );
    setState(() {
      _saving = true;
      _savingCancelled = false;
      _notSaved = false;
    });
    final saved = await editor.flushAll();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _notSaved = !saved && !_savingCancelled;
    });
    if (!saved) return;
    final token = ref
        .read(studentHomeworkSubmitReadinessProvider(widget.target))
        .readyToken;
    if (token != null) await _confirm(token);
  }

  void _cancelSaving() {
    _savingCancelled = true;
    ref
        .read(
          studentAttemptAnswerEditorControllerProvider(widget.target).notifier,
        )
        .cancelFlush();
  }

  Future<void> _confirm(StudentHomeworkSubmitReadyToken token) async {
    if (_confirming) return;
    _confirming = true;
    final target = widget.target;
    final router = GoRouter.maybeOf(context);
    final location = router?.routeInformationProvider.value.uri;
    final controller = ref.read(
      studentHomeworkSubmitControllerProvider(target).notifier,
    );
    final snapshot = token.snapshot;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('studentHomeworkSubmitConfirmDialog'),
        title: Text('Submit Attempt ${widget.attemptNumber}?'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${snapshot.confirmedAnsweredCount} of ${snapshot.questionCount} answers are saved.',
            ),
            if (snapshot.unansweredCount > 0)
              Text(
                snapshot.unansweredCount == 1
                    ? '1 Question has no saved answer.'
                    : '${snapshot.unansweredCount} Questions have no saved answer.',
              ),
            const SizedBox(height: 16),
            const Text(
              'Submitting will lock this Attempt and it cannot be edited afterward.\n'
              'Unanswered Questions are allowed.',
            ),
            const SizedBox(height: 16),
            const Text(
              'If another Homework Attempt is available later, it must be started separately.',
            ),
          ],
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('studentHomeworkSubmitConfirmButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit Attempt'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _confirming = false;
    if (confirmed == true &&
        widget.target == target &&
        router?.routeInformationProvider.value.uri == location &&
        ModalRoute.of(context)?.isCurrent == true) {
      await controller.submitConfirmed(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ref.watch(
      studentHomeworkSubmitReadinessProvider(widget.target),
    );
    final provider = studentHomeworkSubmitControllerProvider(widget.target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final submitting = state.status == StudentHomeworkSubmitStatus.submitting;
    final checking = state.status == StudentHomeworkSubmitStatus.checking;
    final uncertain =
        state.status == StudentHomeworkSubmitStatus.uncertain || checking;
    if (widget.isTerminal &&
        !submitting &&
        !uncertain &&
        state.notice == null) {
      return const SizedBox.shrink();
    }
    return Card(
      key: const Key('studentHomeworkSubmitControls'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.isTerminal) ...[
              Semantics(
                header: true,
                child: Text(
                  'Submit attempt',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (submitting) ...[
              const LinearProgressIndicator(
                semanticsLabel: 'Submitting Attempt',
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: const Text('Submitting Attempt…'),
              ),
            ] else if (uncertain) ...[
              Semantics(
                liveRegion: true,
                child: const Text(
                  'We could not confirm whether this Attempt was submitted.',
                ),
              ),
              const SizedBox(height: 8),
              const Text('Submission result unconfirmed.'),
              if (checking) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  semanticsLabel: 'Checking current Attempt',
                ),
                const Text('Checking current Attempt…'),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const Key('studentHomeworkSubmitRetryButton'),
                    onPressed: checking ? null : controller.retrySubmission,
                    child: const Text('Retry submission'),
                  ),
                  OutlinedButton(
                    key: const Key('studentHomeworkSubmitCheckButton'),
                    onPressed: checking ? null : controller.checkCurrentAttempt,
                    child: const Text('Check current Attempt'),
                  ),
                ],
              ),
            ] else if (_saving) ...[
              const LinearProgressIndicator(semanticsLabel: 'Saving answers'),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: const Text('Saving answers\u2026'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('studentHomeworkSubmitCancelSaving'),
                  onPressed: _cancelSaving,
                  child: const Text('Cancel'),
                ),
              ),
            ] else if (!widget.isTerminal) ...[
              // Answers still waiting to save are saved by Submit itself.
              for (final blocker in readiness.blockers.where(
                (blocker) => !StudentHomeworkSubmitReadiness.flushableBlockers
                    .contains(blocker),
              )) ...[
                Text(studentHomeworkSubmitBlockerMessage(blocker)),
                const SizedBox(height: 8),
              ],
              if (_notSaved) ...[
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Some answers are not saved yet. Check the marked questions.',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const Key('studentHomeworkSubmitAttemptButton'),
                    onPressed: readiness.isReady && readiness.readyToken != null
                        ? () => _confirm(readiness.readyToken!)
                        : readiness.canSubmitAfterSaving
                        ? _saveThenConfirm
                        : null,
                    child: const Text('Submit Attempt'),
                  ),
                ],
              ),
            ],
            if (state.notice case final notice?) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(notice)),
            ],
          ],
        ),
      ),
    );
  }
}
