import 'package:flutter/material.dart';

import '../domain/teacher_review_summary.dart';

/// A task's review counts on every surface; on desktop it also opens the
/// task's review queue (`S09-D7`).
class TeacherTaskReviewSummaryCard extends StatelessWidget {
  const TeacherTaskReviewSummaryCard({
    required this.summary,
    required this.showsOverdue,
    required this.onOpenQueue,
    super.key = const Key('teacherTaskReviewSummary'),
  });

  final TeacherReviewSummary summary;

  /// Blitz has no review deadline, so it never shows an overdue count.
  final bool showsOverdue;

  /// Null on mobile and while another task mutation owns the route.
  final VoidCallback? onOpenQueue;

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
                'Review',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Waiting for review: ${summary.waitingForTeacherReview}',
              key: const Key('teacherTaskReviewWaitingCount'),
            ),
            if (showsOverdue)
              Text(
                'Overdue: ${summary.overdue}',
                key: const Key('teacherTaskReviewOverdueCount'),
              ),
            if (onOpenQueue case final open?) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('teacherTaskReviewQueueButton'),
                  onPressed: open,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Open review queue'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
