import 'package:flutter/material.dart';

import '../domain/student_homework_attempt.dart';
import 'student_homework_formatters.dart';
import 'student_topic_formatters.dart';

class StudentAttemptFinalizationSummary extends StatelessWidget {
  const StudentAttemptFinalizationSummary({
    required this.attempt,
    required this.timezone,
    super.key,
  });

  final StudentHomeworkAttempt attempt;
  final String timezone;

  String _instant(DateTime value) =>
      formatStudentInstitutionInstant(value, timezone) ??
      'Institution timezone unavailable';

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String)>[
      if (attempt.submittedAt case final submitted?)
        ('Submitted at', _instant(submitted)),
      if (attempt.finalizedAt case final finalized?)
        ('Finalized at', _instant(finalized)),
      if (attempt.finalizationReason case final reason?)
        (
          'Finalization reason',
          studentHomeworkAttemptFinalizationLabel(reason),
        ),
    ];
    return Card(
      key: const Key('studentAttemptFinalizationSummary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Attempt finalized',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Text('Status', style: Theme.of(context).textTheme.labelLarge),
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                studentHomeworkAttemptStatusLabel(attempt.status),
                key: const Key('studentHomeworkAttemptStatus'),
              ),
            ),
            const SizedBox(height: 10),
            for (final field in fields) ...[
              Text(field.$1, style: Theme.of(context).textTheme.labelLarge),
              SelectableText(field.$2),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
