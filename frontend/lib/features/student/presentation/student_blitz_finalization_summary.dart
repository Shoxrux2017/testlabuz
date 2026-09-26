import 'package:flutter/material.dart';

import '../domain/student_blitz_attempt.dart';
import 'student_blitz_formatters.dart';
import 'student_topic_formatters.dart';

/// Read-only summary of a finalized Blitz Attempt. Stage 8 shows no score,
/// awarded points, correctness or checking result.
class StudentBlitzFinalizationSummary extends StatelessWidget {
  const StudentBlitzFinalizationSummary({
    required this.attempt,
    required this.timezone,
    required this.confirmedBySubmit,
    super.key,
  });

  final StudentBlitzAttempt attempt;
  final String timezone;

  /// The terminal Attempt came from this route session's own Submit.
  final bool confirmedBySubmit;

  String _instant(DateTime value) =>
      formatStudentInstitutionInstant(value, timezone) ??
      'Institution timezone unavailable';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = attempt.finalizationReason;
    final (heading, lines) = _copy(reason);
    final questionIds = {
      for (final question in attempt.questions) question.id.toLowerCase(),
    };
    // Only persisted answers count; local drafts and files never do.
    final answered = {
      for (final answer in attempt.answers)
        if (questionIds.contains(answer.questionId.toLowerCase()))
          answer.questionId.toLowerCase(),
    }.length;
    final total = attempt.questions.length;
    final submitNote =
        reason == StudentBlitzAttemptFinalizationReason.studentSubmit
        ? confirmedBySubmit
              ? attempt.status == StudentBlitzAttemptStatus.submitted
                    ? 'Blitz submitted successfully.'
                    : 'Blitz submission confirmed.'
              : 'This Blitz attempt is already submitted.'
        : null;
    final fields = <(String, String)>[
      ('Attempt', studentBlitzAttemptLabel(attempt.attemptNumber)),
      ('Finalized state', studentBlitzFinalizedStateLabel(attempt.status)),
      if (reason != null)
        ('Finalization reason', studentBlitzFinalizationReasonLabel(reason)),
      ('Started', _instant(attempt.startedAt)),
      ('Deadline', _instant(attempt.deadlineAt)),
      if (attempt.finalizedAt case final finalized?)
        ('Finalized at', _instant(finalized)),
      ('Answered', '$answered of $total'),
      ('Unanswered', '${total - answered}'),
    ];
    return Card(
      key: const Key('studentBlitzFinalizationSummary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                heading,
                key: const Key('studentBlitzFinalizationHeading'),
                style: theme.textTheme.headlineSmall,
              ),
            ),
            for (final line in lines) ...[
              const SizedBox(height: 4),
              Text(line),
            ],
            if (submitNote != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  submitNote,
                  key: const Key('studentBlitzSubmitOutcome'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final field in fields) ...[
              Text(field.$1, style: theme.textTheme.labelLarge),
              SelectableText(field.$2),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  (String, List<String>) _copy(StudentBlitzAttemptFinalizationReason? reason) {
    if (attempt.status == StudentBlitzAttemptStatus.waitingForReview) {
      return ('Finalized', const ['Some answers may require Teacher review.']);
    }
    if (attempt.status == StudentBlitzAttemptStatus.checked) {
      return ('Finalized', const []);
    }
    return switch (reason) {
      StudentBlitzAttemptFinalizationReason.timeout => (
        'Time expired',
        const [
          'The server finalized the answers that were saved before the '
              'deadline.',
          'Unanswered Questions remain unanswered.',
        ],
      ),
      StudentBlitzAttemptFinalizationReason.taskClosed => (
        'Blitz closed',
        const [
          'The Teacher closed the Blitz.',
          'The answers saved before finalization were preserved.',
        ],
      ),
      StudentBlitzAttemptFinalizationReason.studentSubmit ||
      null => ('Submitted', const ['Your Blitz attempt has been submitted.']),
    };
  }
}
