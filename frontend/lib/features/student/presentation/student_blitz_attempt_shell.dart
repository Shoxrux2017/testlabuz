import 'package:flutter/material.dart';

import '../application/student_blitz_attempt_start_state.dart';
import '../application/student_blitz_detail_state.dart';
import '../domain/student_blitz.dart';
import 'student_blitz_countdown.dart';
import 'student_blitz_formatters.dart';
import 'student_question_read_view.dart';
import 'student_topic_formatters.dart';

/// Read-only timed execution shell for the Attempt returned by a validated
/// Start/Resume. FE-004 shows Questions and saved-answer indicators only;
/// it has no answer editor and no Submit.
class StudentBlitzAttemptShell extends StatelessWidget {
  const StudentBlitzAttemptShell({
    required this.state,
    required this.detail,
    required this.institutionTimezone,
    required this.onExpired,
    required this.onRefresh,
    required this.onLeave,
    super.key,
  });

  final StudentBlitzAttemptStartState state;
  final StudentBlitzDetailState detail;
  final String institutionTimezone;
  final ValueChanged<StudentBlitzCountdownAnchor> onExpired;
  final VoidCallback onRefresh;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final attempt = state.attempt!;
    final anchor = state.executionAnchor!;
    final theme = Theme.of(context);
    final answered = {
      for (final answer in attempt.answers) answer.questionId.toLowerCase(),
    };
    String instant(DateTime value) =>
        formatStudentInstitutionInstant(value, institutionTimezone) ??
        'Institution timezone unavailable';

    return SingleChildScrollView(
      key: const Key('studentBlitzAttemptShell'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
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
                        anchor: anchor,
                        label: 'Time remaining',
                        onExpired: onExpired,
                      ),
                      if (state.isReconcilingExpiry) ...[
                        const SizedBox(height: 8),
                        _ExpiryReconciliation(
                          detail: detail,
                          onRefresh: onRefresh,
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
                          state.blitzTitle ?? 'Blitz',
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
                        const Text('This is the approved additional attempt.'),
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
                const Text('No Questions are available.')
              else
                for (final question in attempt.questions) ...[
                  StudentQuestionReadView(question: question),
                  const SizedBox(height: 4),
                  Row(
                    key: ValueKey('studentBlitzAnswerState${question.id}'),
                    children: [
                      Icon(
                        answered.contains(question.id.toLowerCase())
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        answered.contains(question.id.toLowerCase())
                            ? 'Saved'
                            : 'Not answered',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiryReconciliation extends StatelessWidget {
  const _ExpiryReconciliation({required this.detail, required this.onRefresh});

  final StudentBlitzDetailState detail;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (detail.status != StudentBlitzDetailStatus.error) {
      return Semantics(
        liveRegion: true,
        child: const Text(
          'Checking current Blitz time…',
          key: Key('studentBlitzCheckingTime'),
        ),
      );
    }
    // The old snapshot is never restarted; only the server can grant time.
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Time may have expired. Reconnect and refresh to confirm the '
            'current Blitz state.',
            key: Key('studentBlitzTimeMayHaveExpired'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('studentBlitzExpiryRefreshButton'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
