import 'package:flutter/material.dart';

import '../../../core/scoring/score_display.dart';
import '../domain/teacher_submission.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_topic_formatters.dart';

String teacherSubmissionTaskTypeLabel(TeacherSubmissionTaskType type) {
  return switch (type) {
    TeacherSubmissionTaskType.homework => 'Homework',
    TeacherSubmissionTaskType.blitz => 'Blitz',
  };
}

String teacherSubmissionStatusLabel(TeacherSubmissionStatus status) {
  return switch (status) {
    TeacherSubmissionStatus.waitingForTeacherReview => 'Waiting for review',
    TeacherSubmissionStatus.checked => 'Checked',
    TeacherSubmissionStatus.submitted ||
    TeacherSubmissionStatus.timedOutFinalized => 'Automatic checking pending',
  };
}

/// An instant in the Institution timezone, or in UTC when it is unavailable.
String formatTeacherReviewTime(DateTime instant, String? timezone) {
  return (timezone == null
          ? null
          : formatInstitutionInstant(instant, timezone)) ??
      formatUtcInstant(instant);
}

/// `1 point`, `2.5 points`.
String formatTeacherReviewPoints(double points) {
  return '${formatTeacherHomeworkPoints(points)} '
      '${points == 1 ? 'point' : 'points'}';
}

/// The Student, the chips and the task, attempt and review lines of a
/// submission, shared by the review queue and the submission detail.
class TeacherSubmissionSummary extends StatelessWidget {
  const TeacherSubmissionSummary({
    required this.submission,
    required this.timezone,
    this.submittedAt,
    super.key,
  });

  final TeacherSubmission submission;
  final String? timezone;

  /// Shown on the detail only.
  final DateTime? submittedAt;

  @override
  Widget build(BuildContext context) {
    final answers = submission.waitingAnswers + submission.reviewedAnswers;
    final details = [
      if (answers > 0)
        'Reviewed ${submission.reviewedAnswers} of $answers '
            '${answers == 1 ? 'answer' : 'answers'}',
      if (submission.reviewDueAt case final reviewDueAt?)
        'Review by ${formatTeacherReviewTime(reviewDueAt, timezone)}',
      if (submission.normalizedScore case final score?)
        'Score ${formatScoreOneDecimal(score)}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              submission.studentName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Chip(label: Text(submission.official ? 'Official' : 'Practice')),
            if (!submission.officialScoreEligible)
              const Chip(label: Text('Invalidated attempt')),
            if (submission.reviewOverdue) const Chip(label: Text('Overdue')),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${teacherSubmissionTaskTypeLabel(submission.taskType)} · '
          '${submission.taskTitle} · ${submission.topicTitle} · '
          '${submission.groupName}',
        ),
        Text(
          'Attempt ${submission.attemptNumber} · '
          '${teacherSubmissionStatusLabel(submission.status)} · '
          'Finalized ${formatTeacherReviewTime(submission.finalizedAt, timezone)}',
        ),
        if (submittedAt case final submitted?)
          Text('Submitted ${formatTeacherReviewTime(submitted, timezone)}'),
        if (details.isNotEmpty) Text(details.join(' · ')),
      ],
    );
  }
}
