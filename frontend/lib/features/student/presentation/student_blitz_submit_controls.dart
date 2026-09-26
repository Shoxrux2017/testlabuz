import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/student_blitz_execution_operation_gate.dart';
import '../application/student_blitz_submit_controller.dart';
import '../application/student_blitz_submit_readiness.dart';
import '../application/student_blitz_submit_state.dart';
import '../domain/student_blitz_execution_target.dart';
import 'student_blitz_formatters.dart';

/// Explicit final Submit for the active Blitz Attempt, shown after its
/// Questions. Unanswered Questions never block it.
class StudentBlitzSubmitControls extends ConsumerStatefulWidget {
  const StudentBlitzSubmitControls({required this.target, super.key});

  final StudentBlitzExecutionTarget target;

  @override
  ConsumerState<StudentBlitzSubmitControls> createState() =>
      _StudentBlitzSubmitControlsState();
}

class _StudentBlitzSubmitControlsState
    extends ConsumerState<StudentBlitzSubmitControls> {
  bool _confirming = false;

  Future<void> _confirm(StudentBlitzSubmitReadyToken token) async {
    if (_confirming) return;
    _confirming = true;
    final target = widget.target;
    final router = GoRouter.maybeOf(context);
    final location = router?.routeInformationProvider.value.uri;
    final controller = ref.read(
      studentBlitzSubmitControllerProvider(target).notifier,
    );
    final snapshot = token.snapshot;
    final unanswered = snapshot.unansweredCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('studentBlitzSubmitConfirmDialog'),
        title: const Text('Submit Blitz?'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Answered: ${snapshot.confirmedAnsweredCount} of '
              '${snapshot.questionCount}',
            ),
            Text('Unanswered: $unanswered'),
            if (unanswered > 0) ...[
              const SizedBox(height: 12),
              Row(
                key: const Key('studentBlitzUnansweredWarning'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unanswered == 1
                          ? 'You still have 1 unanswered Question.'
                          : 'You still have $unanswered unanswered Questions.',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'After submission, this attempt cannot be edited.\n'
              'Unanswered Questions will remain unanswered.',
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
            key: const Key('studentBlitzSubmitConfirmButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
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
      studentBlitzSubmitReadinessProvider(widget.target),
    );
    final provider = studentBlitzSubmitControllerProvider(widget.target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final reconciling =
        ref.watch(studentBlitzExecutionOperationGateProvider(widget.target)) ==
        StudentBlitzExecutionOperation.terminalReconciliation;
    final submitting = state.status == StudentBlitzSubmitStatus.submitting;
    final checking = state.status == StudentBlitzSubmitStatus.checking;
    final uncertain =
        state.status == StudentBlitzSubmitStatus.uncertain || checking;
    return Card(
      key: const Key('studentBlitzSubmitControls'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Submit Blitz',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            if (submitting) ...[
              const LinearProgressIndicator(semanticsLabel: 'Submitting Blitz'),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: const Text('Submitting Blitz…'),
              ),
            ] else if (uncertain) ...[
              Semantics(
                liveRegion: true,
                child: const Text(
                  'We could not confirm whether the Blitz was submitted.',
                  key: Key('studentBlitzSubmitUncertain'),
                ),
              ),
              if (checking) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  semanticsLabel: 'Checking current attempt',
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const Key('studentBlitzSubmitRetryButton'),
                    onPressed: checking ? null : controller.retrySubmission,
                    child: const Text('Retry Submit'),
                  ),
                  OutlinedButton(
                    key: const Key('studentBlitzSubmitCheckButton'),
                    onPressed: checking ? null : controller.checkCurrentAttempt,
                    child: const Text('Check current attempt'),
                  ),
                ],
              ),
            ] else if (reconciling) ...[
              const LinearProgressIndicator(
                semanticsLabel: 'Checking current attempt',
              ),
              const SizedBox(height: 8),
              const Text('Checking the current attempt…'),
            ] else ...[
              for (final blocker in readiness.blockers) ...[
                Text(studentBlitzSubmitBlockerMessage(blocker)),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('studentBlitzSubmitButton'),
                  onPressed: readiness.readyToken == null
                      ? null
                      : () => _confirm(readiness.readyToken!),
                  child: const Text('Submit Blitz'),
                ),
              ),
            ],
            if (state.notice case final notice?) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(notice, key: const Key('studentBlitzSubmitNotice')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
