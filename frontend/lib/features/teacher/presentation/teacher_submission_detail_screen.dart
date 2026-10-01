import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_session_key.dart';
import '../application/teacher_submission_detail_controller.dart';
import '../application/teacher_submission_detail_state.dart';
import '../application/teacher_submission_file_controller.dart';
import '../application/teacher_submission_file_state.dart';
import '../domain/teacher_submission_detail.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_learning_material_section.dart';
import 'teacher_review_formatters.dart';

/// One submission with every Question and the Student's answers
/// (`S09-FE-003A`); desktop only.
class TeacherSubmissionDetailScreen extends ConsumerWidget {
  const TeacherSubmissionDetailScreen({required this.submissionId, super.key});

  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherSubmissionDetailControllerProvider(submissionId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final fileProvider = teacherSubmissionFileControllerProvider(submissionId);
    final timezone = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey?.institutionTimezone;

    ref.listen<TeacherSubmissionFileState>(fileProvider, (previous, next) {
      final feedback = next.feedback;
      if (next.status != TeacherSubmissionFileStatus.idle ||
          feedback == null ||
          !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(feedback)));
      ref.read(fileProvider.notifier).consumeFeedback();
    });

    final detail = state.detail;
    return Scaffold(
      key: const Key('teacherSubmissionDetailScreen'),
      appBar: AppBar(
        title: const Text('Submission'),
        leading: IconButton(
          key: const Key('teacherSubmissionBackButton'),
          tooltip: 'Back to review queue',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutePaths.teacherReviews);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            key: const Key('teacherSubmissionRefreshButton'),
            tooltip: 'Refresh submission',
            onPressed: state.isLoading
                ? null
                : state.status == TeacherSubmissionDetailStatus.error
                ? controller.retry
                : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          TeacherSubmissionDetailStatus.initial ||
          TeacherSubmissionDetailStatus.loading => const Center(
            child: CircularProgressIndicator(
              key: Key('teacherSubmissionDetailLoading'),
              semanticsLabel: 'Loading submission',
            ),
          ),
          TeacherSubmissionDetailStatus.notFound => const Center(
            child: Text('This submission is not available.'),
          ),
          _ when detail == null => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('The submission could not be loaded.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('teacherSubmissionDetailRetryButton'),
                  onPressed: controller.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          _ => _DetailBody(
            detail: detail,
            state: state,
            timezone: timezone,
            submissionId: submissionId,
            onRetry: controller.retry,
          ),
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.state,
    required this.timezone,
    required this.submissionId,
    required this.onRetry,
  });

  final TeacherSubmissionDetail detail;
  final TeacherSubmissionDetailState state;
  final String? timezone;
  final String submissionId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.status == TeacherSubmissionDetailStatus.refreshing) ...[
                const LinearProgressIndicator(
                  semanticsLabel: 'Refreshing submission',
                ),
                const SizedBox(height: 12),
              ],
              if (state.isStale) ...[
                MaterialBanner(
                  key: const Key('teacherSubmissionDetailStaleMessage'),
                  content: const Text(
                    'The displayed submission may be out of date.',
                  ),
                  actions: [
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Card(
                key: const Key('teacherSubmissionHeader'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TeacherSubmissionSummary(
                    submission: detail.submission,
                    timezone: timezone,
                    submittedAt: detail.submittedAt,
                  ),
                ),
              ),
              for (final question in detail.questions) ...[
                const SizedBox(height: 12),
                _QuestionCard(question: question, submissionId: submissionId),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.submissionId});

  final TeacherReviewQuestion question;
  final String submissionId;

  @override
  Widget build(BuildContext context) {
    final answer = question.answer;
    return Card(
      key: Key('teacherSubmissionQuestion:${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Question ${question.position} · '
                '${teacherQuestionTypeLabel(question.type)} · '
                '${formatTeacherReviewPoints(question.points)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 6),
            Text(question.prompt),
            const SizedBox(height: 10),
            if (answer == null)
              const Text('No answer.')
            else ...[
              ..._answerLines(
                question.configuration,
                answer.value,
              ).map(Text.new),
              if (answer.value case TeacherReviewFileValue(:final file))
                _SubmittedFile(file: file, submissionId: submissionId),
              const SizedBox(height: 8),
              Text(_statusLine(answer, question.points)),
              if (answer.feedback case final feedback?)
                Text('Feedback: $feedback'),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusLine(TeacherReviewAnswer answer, double points) {
  String awarded() =>
      '${formatTeacherHomeworkPoints(answer.awardedPoints!)} of '
      '${formatTeacherReviewPoints(points)}';
  return switch (answer.checkingStatus) {
    TeacherReviewAnswerStatus.pending => 'Waiting for automatic checking',
    TeacherReviewAnswerStatus.autoChecked =>
      'Checked automatically · ${awarded()}',
    TeacherReviewAnswerStatus.waitingForTeacherReview => 'Waiting for review',
    TeacherReviewAnswerStatus.teacherChecked =>
      'Reviewed by ${answer.checkedBy!.fullName} · ${awarded()}',
  };
}

/// The Student's answer next to the correct answer, one line each.
List<String> _answerLines(
  TeacherReviewConfiguration configuration,
  TeacherReviewAnswerValue value,
) {
  String yesNo(bool value) => value ? 'True' : 'False';
  return switch ((configuration, value)) {
    (
      TeacherReviewChoiceConfiguration(:final options),
      TeacherReviewChoiceValue(:final selectedOptionIds),
    ) =>
      [
        for (final option in options)
          [
            option.text,
            if (selectedOptionIds.contains(option.id)) 'Student answer',
            if (option.isCorrect) 'Correct',
          ].join(' · '),
      ],
    (
      TeacherReviewTrueFalseConfiguration(:final correctValue),
      TeacherReviewTrueFalseValue(:final value),
    ) =>
      [
        'Student answer: ${yesNo(value)}',
        'Correct answer: ${yesNo(correctValue)}',
      ],
    (
      TeacherReviewShortWrittenConfiguration(:final acceptedAnswers),
      TeacherReviewTextValue(:final text),
    ) =>
      [
        'Student answer: $text',
        if (acceptedAnswers.isNotEmpty)
          'Accepted answers: ${acceptedAnswers.join(', ')}',
      ],
    (
      TeacherReviewOpenWrittenConfiguration(),
      TeacherReviewTextValue(:final text),
    ) =>
      ['Student answer: $text'],
    (
      TeacherReviewMatchingConfiguration(:final pairs),
      TeacherReviewMatchingValue(pairs: final selections),
    ) =>
      () {
        final lefts = {for (final pair in pairs) pair.leftItemId: pair.left};
        final rights = {for (final pair in pairs) pair.rightItemId: pair.right};
        final order = [for (final pair in pairs) pair.leftItemId];
        // In the configured left order, so both lists read side by side.
        final sorted = [...selections]
          ..sort(
            (left, right) => order
                .indexOf(left.leftItemId)
                .compareTo(order.indexOf(right.leftItemId)),
          );
        return [
          'Student matches:',
          for (final selection in sorted)
            '${lefts[selection.leftItemId]} → ${rights[selection.rightItemId]}',
          'Correct matches:',
          for (final pair in pairs) '${pair.left} → ${pair.right}',
        ];
      }(),
    (
      TeacherReviewOrderingConfiguration(:final items),
      TeacherReviewOrderingValue(items: final selections),
    ) =>
      () {
        final texts = {for (final item in items) item.id: item.text};
        final ordered = [...selections]
          ..sort((left, right) => left.position.compareTo(right.position));
        return [
          'Student order:',
          for (final selection in ordered)
            '${selection.position}. ${texts[selection.itemId]}',
          'Correct order:',
          for (final item in items) '${item.correctPosition}. ${item.text}',
        ];
      }(),
    (
      TeacherReviewFillInBlankConfiguration(:final blanks),
      TeacherReviewFillInBlankValue(:final values),
    ) =>
      () {
        final texts = {for (final value in values) value.blankId: value.text};
        return [
          'Student answers:',
          for (final blank in blanks)
            if (texts[blank.id] case final text?) '${blank.key}: $text',
          'Accepted answers:',
          for (final blank in blanks)
            '${blank.key}: ${blank.acceptedAnswers.join(', ')}',
        ];
      }(),
    (TeacherReviewFileConfiguration(), TeacherReviewFileValue()) => const [],
    _ => throw StateError('An answer value does not match its Question.'),
  };
}

class _SubmittedFile extends ConsumerWidget {
  const _SubmittedFile({required this.file, required this.submissionId});

  final TeacherReviewFile file;
  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherSubmissionFileControllerProvider(submissionId);
    final transfer = ref.watch(provider);
    final failed =
        transfer.status == TeacherSubmissionFileStatus.failure &&
        transfer.fileId == file.id;
    final transferring = transfer.isBusy && transfer.fileId == file.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${file.originalName} · ${file.extension.toUpperCase()} · '
          '${formatTeacherMaterialBytes(file.sizeBytes)}',
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          key: Key('teacherSubmissionFileSaveButton:${file.id}'),
          onPressed: transfer.isBusy
              ? null
              : () => ref.read(provider.notifier).saveFile(file),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Save file'),
        ),
        if (transferring) ...[
          const SizedBox(height: 6),
          const LinearProgressIndicator(
            key: Key('teacherSubmissionFileProgress'),
            semanticsLabel: 'Downloading file',
          ),
        ],
        if (failed && transfer.feedback != null) ...[
          const SizedBox(height: 6),
          Text(transfer.feedback!),
        ],
      ],
    );
  }
}
